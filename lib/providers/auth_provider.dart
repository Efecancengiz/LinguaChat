// lib/providers/auth_provider.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:linguachat/models/user_model.dart';
import 'package:linguachat/services/auth_service.dart';
import 'package:linguachat/services/firestore_service.dart';
import 'package:linguachat/services/notification_service.dart';
import 'package:linguachat/services/message_listener_service.dart';
import 'package:linguachat/services/onesignal_service.dart';
import 'package:linguachat/services/revenuecat_service.dart';

class AuthProvider extends ChangeNotifier with WidgetsBindingObserver {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  late final StreamSubscription<User?> _authSubscription;
  Timer? _heartbeatTimer;

  UserModel? _user;
  bool _isLoading = false;
  String? _error;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _authService.currentUser != null;
  String? get currentUserId => _authService.currentUser?.uid;

  AuthProvider() {
    WidgetsBinding.instance.addObserver(this);
    _authSubscription = _authService.authStateChanges.listen((User? firebaseUser) async {
      if (firebaseUser != null) {
        try {
          // Wait briefly to allow sign up function to write the document
          await firebaseUser.reload(); // Get latest display name
          final latestUser = FirebaseAuth.instance.currentUser ?? firebaseUser;
          
          UserModel? fetchedUser = await _firestoreService.getUser(latestUser.uid);
          
          // Retry logic if document isn't written yet
          if (fetchedUser == null) {
            await Future.delayed(const Duration(milliseconds: 500));
            fetchedUser = await _firestoreService.getUser(latestUser.uid);
          }
          
          if (fetchedUser != null) {
            _user = fetchedUser;
            _firestoreService.updatePresence(latestUser.uid, true);
          } else if (_user == null || _user!.uid != latestUser.uid) {
            _user = UserModel(
              uid: latestUser.uid,
              email: latestUser.email ?? '',
              displayName: latestUser.displayName ?? latestUser.email?.split('@').first ?? 'Kullanıcı',
              isOnline: true,
              photoUrl: '',
              bio: '',
              knownLanguages: const [],
              learningLanguages: const [],
              createdAt: DateTime.now(),
            );
          }
        } catch (e) {
          debugPrint('AuthProvider.authStateChanges fallback error: $e');
          // Fallback if network fails
          if (_user == null || _user!.uid != firebaseUser.uid) {
             _user = UserModel(
              uid: firebaseUser.uid,
              email: firebaseUser.email ?? '',
              displayName: firebaseUser.displayName ?? firebaseUser.email?.split('@').first ?? 'Kullanıcı',
              isOnline: true,
              photoUrl: '',
              bio: '',
              knownLanguages: const [],
              learningLanguages: const [],
              createdAt: DateTime.now(),
            );
          }
        }
        _startHeartbeat(firebaseUser.uid);
        _saveFcmToken(firebaseUser.uid);
        MessageListenerService.start(firebaseUser.uid);
        // OneSignal & RevenueCat kullanıcı eşleştirme
        OneSignalService.setUserId(firebaseUser.uid);
        RevenueCatService.login(firebaseUser.uid);
        notifyListeners();
      } else {
        _stopHeartbeat();
        MessageListenerService.stop();
        OneSignalService.clearUserId();
        RevenueCatService.logout();
        _user = null;
        notifyListeners();
      }
    });
  }

  Future<void> _saveFcmToken(String uid) async {
    try {
      final token = await NotificationService.getFcmToken();
      if (token != null) {
        await _firestoreService.updateUser(uid, {'fcmToken': token});
      }
    } catch (e) {
      debugPrint('AuthProvider._saveFcmToken error: $e');
    }
  }

  void _startHeartbeat(String uid) {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      _firestoreService.updatePresence(uid, true);
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
  }

  @override
  void dispose() {
    _stopHeartbeat();
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (currentUserId != null) {
      if (state == AppLifecycleState.resumed) {
        _firestoreService.updatePresence(currentUserId!, true);
      } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive || state == AppLifecycleState.detached || state == AppLifecycleState.hidden) {
        _firestoreService.updatePresence(currentUserId!, false);
      }
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _user = await _authService.signUp(
        email: email,
        password: password,
        displayName: displayName,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _getErrorMessage(e.code);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      if (e.toString().contains('username-taken')) {
        _error = 'Bu kullanıcı adı zaten kullanımda. Lütfen başka bir kullanıcı adı seçin.';
      } else {
        _error = 'Beklenmeyen Hata: $e';
      }
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _user = await _authService.signIn(email: email, password: password);
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _getErrorMessage(e.code);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      // Firebase Auth may have succeeded but Firestore failed.
      // Sign out to revert auth state so redirect doesn't send to home.
      try { await _authService.signOut(); } catch (signOutError) {
        debugPrint('AuthProvider.signIn signOut fallback error: $signOutError');
      }
      _user = null;
      _error = 'Beklenmeyen Hata: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final userModel = await _authService.signInWithGoogle();
      if (userModel != null) {
        _user = userModel;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        // Kullanıcı iptal etti
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } on FirebaseAuthException catch (e) {
      _error = _getErrorMessage(e.code);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      try { await _authService.signOut(); } catch (_) {}
      _user = null;
      _error = 'Beklenmeyen Hata: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _user = null;
    notifyListeners();
  }

  Future<bool> resetPassword(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.resetPassword(email);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Şifre sıfırlama e-postası gönderilemedi.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> refreshUser() async {
    if (_authService.currentUser != null) {
      final fetched = await _firestoreService.getUser(_authService.currentUser!.uid);
      if (fetched != null) {
        _user = fetched;
        notifyListeners();
      }
    }
  }

  Future<bool> deleteAccount() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = _authService.currentUser;
      if (user != null) {
        await _firestoreService.deleteUser(user.uid);
        await user.delete();
        _user = null;
        notifyListeners();
        return true;
      }
      return false;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        _error = 'Bu işlem için yeniden giriş yapmanız gerekiyor. Lütfen çıkış yapıp tekrar giriş yapın.';
      } else {
        _error = _getErrorMessage(e.code);
      }
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Hesap silinirken hata oluştu: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'weak-password':
        return 'Şifre çok zayıf. En az 6 karakter kullanın.';
      case 'email-already-in-use':
        return 'Bu e-posta adresi zaten kullanılıyor.';
      case 'invalid-email':
        return 'Geçersiz e-posta adresi.';
      case 'user-not-found':
        return 'Bu e-posta ile kayıtlı kullanıcı bulunamadı.';
      case 'wrong-password':
        return 'Yanlış şifre.';
      case 'invalid-credential':
        return 'E-posta veya şifre hatalı.';
      case 'too-many-requests':
        return 'Çok fazla deneme. Lütfen biraz bekleyin.';
      default:
        return 'Bir hata oluştu: $code';
    }
  }
}
