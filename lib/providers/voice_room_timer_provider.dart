import 'dart:async';
import 'package:flutter/material.dart';
import 'package:linguachat/services/firestore_service.dart';
import 'package:linguachat/services/hms_service.dart';
import 'package:linguachat/config/theme.dart';

class VoiceRoomTimerProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  Timer? _timer;
  
  bool _isPremium = false;
  int _usedMinutes = 0;
  int _remainingSeconds = 0;
  
  bool get showWarning => !_isPremium && _remainingSeconds <= 120 && _remainingSeconds > 0;
  int get remainingSeconds => _remainingSeconds;
  bool get isPremium => _isPremium;

  String get formattedRemainingTime {
    if (_isPremium) return 'Sınırsız';
    if (_remainingSeconds <= 0) return '00:00';
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> initialize(String uid) async {
    final user = await _firestoreService.getUser(uid);
    if (user == null) return;

    _isPremium = user.isPremium;
    _usedMinutes = user.dailyVoiceMinutes;
    _remainingSeconds = (20 - _usedMinutes) * 60;
    if (_remainingSeconds < 0) _remainingSeconds = 0;

    final syncedMinutes = await _firestoreService.syncVoiceUsage();
    _usedMinutes = syncedMinutes;
    _remainingSeconds = (20 - _usedMinutes) * 60;
    if (_remainingSeconds < 0) _remainingSeconds = 0;
    
    notifyListeners();
  }

  bool canJoinRoom() {
    if (_isPremium) return true;
    return _remainingSeconds > 0;
  }

  void startTimer(String uid, BuildContext context, HmsService hmsService, VoidCallback onKick) {
    if (_isPremium) return;

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
      }
      
      notifyListeners();

      // Firestore'a dakikada bir kaydet (60 saniyede 1)
      if (_remainingSeconds > 0 && _remainingSeconds % 60 == 0) {
        final syncedMinutes = await _firestoreService.syncVoiceUsage(increment: true);
        _usedMinutes = syncedMinutes;
      }

      if (_remainingSeconds == 120) {
         if (context.mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(
               content: Text('Uyarı: Günlük ücretsiz sesli sohbet limitinizin dolmasına 2 dakika kaldı!'),
               duration: Duration(seconds: 10),
               backgroundColor: AppTheme.warning,
             ),
           );
         }
      } else if (_remainingSeconds <= 0) {
        timer.cancel();
        await hmsService.leaveChannel();
        if (context.mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(
               content: Text('Günlük sesli sohbet limitiniz doldu. Lütfen Premium\'a geçin.'),
               duration: Duration(seconds: 5),
               backgroundColor: AppTheme.danger,
             ),
           );
        }
        onKick(); 
      }
    });
  }

  void stopTimer() {
    _timer?.cancel();
    _timer = null;
  }
  
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
