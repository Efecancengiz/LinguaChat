import 'dart:async';
import 'package:flutter/material.dart';
import 'package:linguachat/services/firestore_service.dart';
import 'package:linguachat/services/hms_service.dart';
import 'package:linguachat/config/theme.dart';

class VoiceRoomTimerProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  Timer? _timer;
  
  bool _isPremium = false;
  int _usedSeconds = 0;
  int _remainingSeconds = 0;
  int _bonusMinutes = 0;
  
  bool get showWarning => !_isPremium && _bonusMinutes > 0 && _remainingSeconds <= 120 && _remainingSeconds > 0;
  int get remainingSeconds => _remainingSeconds;
  bool get isPremium => _isPremium;

  String get formattedRemainingTime {
    if (_isPremium) return '∞';
    if (!_isPremium && _bonusMinutes == 0) return '00:00';
    if (_remainingSeconds <= 0) return '00:00';
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String? _currentUid;

  Future<void> initialize(String uid) async {
    _currentUid = uid;
    final user = await _firestoreService.getUser(uid);
    if (user == null) return;

    _isPremium = user.isPremium;
    
    // Sadece bugün içinde kullanılmışsa dbSeconds'ı al
    int dbSeconds = 0;
    final now = DateTime.now();
    if (user.lastResetDate.year == now.year && 
        user.lastResetDate.month == now.month && 
        user.lastResetDate.day == now.day) {
      dbSeconds = user.dailyVoiceSeconds > 0 ? user.dailyVoiceSeconds : user.dailyVoiceMinutes * 60;
    }
    
    // RAM'deki saniye, veritabanından gelen dakikadan küçükse güncelle (ilk açılış)
    if (dbSeconds > _usedSeconds) {
      _usedSeconds = dbSeconds;
    }

    _bonusMinutes = 0;
    if (user.lastSpinDate != null) {
      final now = DateTime.now();
      if (user.lastSpinDate!.year == now.year && user.lastSpinDate!.month == now.month && user.lastSpinDate!.day == now.day) {
        _bonusMinutes = user.bonusMinutes;
      }
    }
    
    if (_isPremium) {
      // Premium kullanıcılar sınırsız sesli sohbete sahiptir
      _remainingSeconds = 999999;
    } else {
      _remainingSeconds = (_bonusMinutes * 60) - _usedSeconds;
      if (_remainingSeconds < 0) _remainingSeconds = 0;
    }
    
    notifyListeners();
  }

  bool canJoinRoom() {
    if (_isPremium) return true;
    return _bonusMinutes > 0 && _remainingSeconds > 0;
  }

  void startTimer(String uid, BuildContext context, HmsService hmsService, VoidCallback onKick) {
    if (!_isPremium && _bonusMinutes == 0) return;

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      _usedSeconds++;
      
      if (!_isPremium) {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        }
      }
      
      notifyListeners();

      // Her 15 saniyede bir Cloud Function ile backend'i güncelle
      if (_usedSeconds > 0 && _usedSeconds % 15 == 0) {
        try {
          _firestoreService.syncVoiceUsage(usedSeconds: _usedSeconds);
        } catch (_) {}
      }

      if (!_isPremium) {
        if (_remainingSeconds == 120) {
           if (context.mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(
                 content: Text('Uyarı: Bonus sürenizin dolmasına 2 dakika kaldı!'),
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
                 content: Text('Şans çarkından kazandığınız bonus süreniz doldu.'),
                 duration: Duration(seconds: 5),
                 backgroundColor: AppTheme.danger,
               ),
             );
          }
          onKick(); 
        }
      }
    });
  }

  void stopTimer() {
    _timer?.cancel();
    _timer = null;
    
    if (_currentUid != null && _usedSeconds > 0) {
      try {
        _firestoreService.syncVoiceUsage(usedSeconds: _usedSeconds);
      } catch (_) {}
    }
  }
  
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
