import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:linguachat/config/theme.dart';
import 'package:linguachat/providers/auth_provider.dart';
import 'package:linguachat/providers/voice_room_timer_provider.dart';
import 'package:linguachat/services/hms_service.dart';
import 'package:linguachat/services/hms_api_service.dart';

class VoiceRoomScreen extends StatefulWidget {
  final String roomId;
  final String roomName;

  const VoiceRoomScreen({
    super.key,
    required this.roomId,
    required this.roomName,
  });

  @override
  State<VoiceRoomScreen> createState() => _VoiceRoomScreenState();
}

class _VoiceRoomScreenState extends State<VoiceRoomScreen> {
  final HmsService _hmsService = HmsService();
  late final VoiceRoomTimerProvider _timerProvider;
  bool _isMuted = false;
  bool _isConnecting = true;
  bool _isLeaving = false;

  @override
  void initState() {
    super.initState();
    _timerProvider = context.read<VoiceRoomTimerProvider>();
    _initializeVoiceRoom();
  }

  Future<void> _initializeVoiceRoom() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    
    await _timerProvider.initialize(user.uid);

    if (!_timerProvider.canJoinRoom()) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppTheme.surface,
            title: const Text('Limit Doldu', style: TextStyle(color: Colors.white)),
            content: const Text('Günlük sesli sohbet limitiniz doldu. Lütfen Premium\'a geçin.', style: TextStyle(color: AppTheme.textSecondary)),
            actions: [
              TextButton(
                onPressed: () { 
                  Navigator.pop(ctx); 
                  context.pop(); 
                  context.push('/premium'); 
                },
                child: const Text('Premium Al', style: TextStyle(color: AppTheme.primary)),
              ),
              TextButton(
                onPressed: () { Navigator.pop(ctx); context.pop(); },
                child: const Text('İptal', style: TextStyle(color: Colors.grey)),
              ),
            ],
          )
        );
      }
      return;
    }

    try {
      // HmsApiService üzerinden odaya ait 100ms kodunu al (Yoksa oluşturur)
      final hmsCode = await HmsApiService.getOrCreateHmsRoom(widget.roomId);

      // 3. Elde edilen dinamik oda koduyla 100ms'e bağlan
      await _hmsService.initializeAndJoin(hmsCode, user.displayName, user.uid);
      
      if (mounted) {
        setState(() => _isConnecting = false);
        _timerProvider.startTimer(
          user.uid, 
          context, 
          _hmsService, 
          () { if (mounted) context.pop(); }
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bağlantı hatası: $e')),
        );
        _leaveRoom();
      }
    }
  }

  @override
  void dispose() {
    _timerProvider.stopTimer();
    if (!_isLeaving) {
      _hmsService.leaveChannel();
    }
    super.dispose();
  }

  Future<void> _leaveRoom() async {
    if (_isLeaving) return;
    setState(() => _isLeaving = true);
    
    // Timer ve HMS işlemlerini await ile senkron şekilde sonlandır
    _timerProvider.stopTimer();
    await _hmsService.leaveChannel();
    
    if (mounted) {
      context.pop();
    }
  }

  void _toggleMute() async {
    setState(() => _isMuted = !_isMuted);
    await _hmsService.muteMic(_isMuted);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _leaveRoom();
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: AppBar(
                backgroundColor: AppTheme.background.withValues(alpha: 0.5),
                elevation: 0,
                centerTitle: true,
                title: Text('${widget.roomName} (Sesli)'),
                leading: IconButton(
                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  onPressed: _leaveRoom,
                ),
              ),
            ),
          ),
        ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.surfaceGradient,
        ),
        child: Center(
          child: _isConnecting
            ? const CircularProgressIndicator(color: AppTheme.primary)
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppTheme.primaryGradient,
                    boxShadow: [
                      if (!_isMuted)
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.3),
                          blurRadius: 30,
                          spreadRadius: 10,
                        ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      _isMuted ? Icons.mic_off_rounded : Icons.graphic_eq_rounded, 
                      size: 72, 
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Consumer<VoiceRoomTimerProvider>(
                  builder: (context, timer, child) {
                    if (!timer.isPremium && timer.remainingSeconds > 0) {
                      return Column(
                        children: [
                          Text(
                            'Kalan Ücretsiz Süre:',
                            style: const TextStyle(fontSize: 16, color: AppTheme.textSecondary),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            timer.formattedRemainingTime,
                            style: TextStyle(
                              fontSize: 40, 
                              color: timer.showWarning ? AppTheme.warning : Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2.0,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      );
                    } else if (timer.isPremium) {
                      return const Text('Sınırsız Premium Süre 🎉', style: TextStyle(color: AppTheme.accent, fontSize: 18));
                    }
                    return const SizedBox.shrink();
                  },
                ),
                const SizedBox(height: 64),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: _toggleMute,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: _isMuted ? AppTheme.surfaceLight : AppTheme.surfaceLight.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _isMuted ? AppTheme.border : AppTheme.primary.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Icon(_isMuted ? Icons.mic_off_rounded : Icons.mic_rounded, size: 28, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 40),
                    GestureDetector(
                      onTap: _leaveRoom,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppTheme.danger.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.danger.withValues(alpha: 0.5)),
                        ),
                        child: _isLeaving 
                          ? const SizedBox(
                              width: 28, 
                              height: 28, 
                              child: CircularProgressIndicator(color: AppTheme.danger, strokeWidth: 2)
                            )
                          : const Icon(Icons.call_end_rounded, size: 28, color: AppTheme.danger),
                      ),
                    ),
                  ],
                ),
              ],
            ),
        ),
      ),
      ),
    );
  }
}
