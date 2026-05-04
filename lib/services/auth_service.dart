// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:linguachat/models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserModel> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final usernameDocRef = _firestore.collection('usernames').doc(displayName);

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

    await _firestore.collection('users').doc(credential.user!.uid).set({
      'isOnline': true,
      'lastSeen': FieldValue.serverTimestamp(),
      'email': credential.user!.email ?? email,
      // We don't overwrite displayName if it exists, so merge guarantees safety.
    }, SetOptions(merge: true));

    final doc = await _firestore
        .collection('users')
        .doc(credential.user!.uid)
        .get();

    return UserModel.fromFirestore(doc);
  }

  Future<UserModel?> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null; // Kapatıldı

    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final OAuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final UserCredential userCredential = await _auth.signInWithCredential(credential);
    final User? user = userCredential.user;

    if (user != null) {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (!userDoc.exists) {
        // Yeni kullanıcı oluştur (Google bilgileriyle)
        String baseDisplayName = user.displayName?.replaceAll(' ', '').toLowerCase() ?? user.email?.split('@').first ?? 'user';
        String displayName = baseDisplayName;
        
        // Benzersiz kullanıcı adı kontrolü
        final usernameDocRef = _firestore.collection('usernames').doc(displayName);
        final usernameDoc = await usernameDocRef.get();
        if (usernameDoc.exists) {
          displayName = '${baseDisplayName}_${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
        }

        await _firestore.collection('usernames').doc(displayName).set({'uid': user.uid});

        final userModel = UserModel(
          uid: user.uid,
          email: user.email ?? '',
          displayName: displayName,
          isOnline: true,
          createdAt: DateTime.now(),
        );

        await _firestore.collection('users').doc(user.uid).set(userModel.toFirestore());
        return userModel;
      } else {
        // Var olan kullanıcı
        await _firestore.collection('users').doc(user.uid).set({
          'isOnline': true,
          'lastSeen': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        final updatedDoc = await _firestore.collection('users').doc(user.uid).get();
        return UserModel.fromFirestore(updatedDoc);
      }
    }
    return null;
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
    await Future.wait([
      _googleSignIn.signOut(),
      _auth.signOut(),
    ]);
  }

  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }
}
