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

  final Duration _tickDuration = const Duration(minutes: 1);
  
  bool get showWarning => !_isPremium && _usedMinutes >= 18 && _usedMinutes < 20;
  int get usedMinutes => _usedMinutes;
  int get remainingMinutes => 20 - _usedMinutes;

  Future<void> initialize(String uid) async {
    final user = await _firestoreService.getUser(uid);
    if (user == null) return;

    _isPremium = user.isPremium;
    _usedMinutes = user.dailyVoiceMinutes;

    final syncedMinutes = await _firestoreService.syncVoiceUsage();
    _usedMinutes = syncedMinutes;
    
    notifyListeners();
  }

  bool canJoinRoom() {
    if (_isPremium) return true;
    return _usedMinutes < 20;
  }

  void startTimer(String uid, BuildContext context, HmsService hmsService, VoidCallback onKick) {
    if (_isPremium) return; // Premium users have unmetered access

    _timer?.cancel();
    _timer = Timer.periodic(_tickDuration, (timer) async {
      final syncedMinutes =
          await _firestoreService.syncVoiceUsage(increment: true);
      _usedMinutes = syncedMinutes;
      notifyListeners();

      if (_usedMinutes == 18) {
         if (context.mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(
               content: Text('Uyarı: Günlük ücretsiz sesli sohbet limitinizin dolmasına 2 dakika kaldı!'),
               duration: Duration(seconds: 10),
               backgroundColor: AppTheme.warning,
             ),
           );
         }
      } else if (_usedMinutes >= 20) {
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
