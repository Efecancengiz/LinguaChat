// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:linguachat/models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _isGoogleSignInInitialized = false;

  Future<void> _ensureGoogleSignInInitialized() async {
    if (!_isGoogleSignInInitialized) {
      await _googleSignIn.initialize();
      _isGoogleSignInInitialized = true;
    }
  }

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserModel> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final usernameDocRef = _firestore.collection('usernames').doc(displayName.toLowerCase());

    // Hızlı kontrol
    final usernameDoc = await usernameDocRef.get();
    if (usernameDoc.exists) {
      throw Exception('username-taken');
    }

    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    try {
      // Atomik benzersizlik kontrolü
      await _firestore.runTransaction((txn) async {
        final snap = await txn.get(usernameDocRef);
        if (snap.exists) {
          throw Exception('username-taken');
        }
        txn.set(usernameDocRef, {'uid': credential.user!.uid});
      });
    } catch (e) {
      await credential.user?.delete();
      rethrow;
    }

    await credential.user?.updateDisplayName(displayName);

    final userModel = UserModel(
      uid: credential.user!.uid,
      email: email,
      displayName: displayName,
      isOnline: true,
      createdAt: DateTime.now(),
    );

    await _firestore
        .collection('users')
        .doc(credential.user!.uid)
        .set(userModel.toFirestore());

    return userModel;
  }

  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    try {
      await _firestore.collection('users').doc(credential.user!.uid).update({
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
        'email': credential.user!.email ?? email,
      });
    } catch (e) {
      // Document might not exist (e.g. manually created test account). 
      // Create it fully to pass Firestore security rules.
      final userModel = UserModel(
        uid: credential.user!.uid,
        email: credential.user!.email ?? email,
        displayName: credential.user!.displayName ?? credential.user!.email?.split('@').first ?? 'Kullanıcı',
        isOnline: true,
        createdAt: DateTime.now(),
      );
      await _firestore.collection('users').doc(credential.user!.uid).set(userModel.toFirestore());
      if (userModel.displayName.isNotEmpty) {
        try {
          await _firestore.collection('usernames').doc(userModel.displayName.toLowerCase()).set({'uid': userModel.uid});
        } catch (_) {}
      }
    }

    final doc = await _firestore
        .collection('users')
        .doc(credential.user!.uid)
        .get();

    return UserModel.fromFirestore(doc);
  }

  Future<void> signOut() async {
    if (_auth.currentUser != null) {
      try {
        await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
          'isOnline': false,
          'lastSeen': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        // Ignore if document not found or permissions fail
      }
    }
    try {
      await _ensureGoogleSignInInitialized();
      await _googleSignIn.signOut();
    } catch (_) {}
    await _auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<UserModel> signInWithGoogle() async {
    // Google oturum açma eklentisini ilklendir
    await _ensureGoogleSignInInitialized();

    // Google oturum açma akışını tetikle
    final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();

    // İstekten kimlik doğrulama detaylarını al
    final GoogleSignInAuthentication googleAuth = googleUser.authentication;

    // Yeni bir Firebase kimliği oluştur
    final OAuthCredential credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );

    // Firebase ile oturum aç
    final UserCredential userCredential = await _auth.signInWithCredential(credential);
    final User? firebaseUser = userCredential.user;

    if (firebaseUser == null) {
      throw Exception('Firebase oturumu açılamadı.');
    }

    // Firestore'da kullanıcının zaten mevcut olup olmadığını kontrol et
    final userDocRef = _firestore.collection('users').doc(firebaseUser.uid);
    final userDoc = await userDocRef.get();

    UserModel userModel;
    if (!userDoc.exists) {
      // İlk defa Google ile giren kullanıcı: usernames ve users dökümanlarını oluştur
      String baseName = firebaseUser.displayName ?? firebaseUser.email?.split('@').first ?? 'Kullanıcı';
      // Kullanıcı adından geçersiz karakterleri temizle
      baseName = baseName.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
      if (baseName.isEmpty) baseName = 'user';
      
      // Benzersiz kullanıcı adı üret (zaten varsa sonuna sayı ekle)
      String uniqueName = baseName;
      int suffix = 1;
      while (true) {
        final check = await _firestore.collection('usernames').doc(uniqueName.toLowerCase()).get();
        if (!check.exists) {
          break;
        }
        uniqueName = '$baseName$suffix';
        suffix++;
      }

      // Önce usernames kaydını oluştur
      await _firestore.collection('usernames').doc(uniqueName.toLowerCase()).set({'uid': firebaseUser.uid});

      userModel = UserModel(
        uid: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        displayName: uniqueName,
        photoUrl: firebaseUser.photoURL ?? '',
        isOnline: true,
        createdAt: DateTime.now(),
      );

      await userDocRef.set(userModel.toFirestore());
    } else {
      // Zaten mevcut olan kullanıcı: durumunu online yap ve güncelle
      await userDocRef.update({
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
      });
      userModel = UserModel.fromFirestore(userDoc);
    }

    return userModel;
  }
}
