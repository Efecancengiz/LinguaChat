import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:linguachat/config/theme.dart';
import 'package:linguachat/providers/auth_provider.dart';
import 'package:linguachat/providers/voice_room_timer_provider.dart';
import 'package:linguachat/services/hms_service.dart';
import 'package:linguachat/services/hms_api_service.dart';
import 'package:hmssdk_flutter/hmssdk_flutter.dart';
import 'package:linguachat/services/firestore_service.dart';
import 'package:linguachat/models/user_model.dart';
import 'package:linguachat/widgets/user_avatar.dart';

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
  final FirestoreService _firestoreService = FirestoreService();
  final Map<String, UserModel?> _userCache = {};
  late final VoiceRoomTimerProvider _timerProvider;
  
  bool _isMuted = false;
  bool _isConnecting = true;
  bool _isLeaving = false;
  bool _isSpeakerOn = true;
  List<HMSPeer> _peers = [];
  Set<String> _activeSpeakers = {};

  @override
  void initState() {
    super.initState();
    _timerProvider = context.read<VoiceRoomTimerProvider>();
    _initializeVoiceRoom();
  }

  Future<UserModel?> _getCachedUser(String userId) async {
    if (userId.isEmpty) return null;
    if (_userCache.containsKey(userId)) {
      return _userCache[userId];
    }
    final user = await _firestoreService.getUser(userId);
    _userCache[userId] = user;
    return user;
  }

  Future<void> _initializeVoiceRoom() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    
    await _timerProvider.initialize(user.uid);

    if (!_timerProvider.isPremium && !_timerProvider.canJoinRoom()) {
      if (mounted) {
        setState(() => _isConnecting = false);
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppTheme.surface,
            title: const Text('Premium Özel', style: TextStyle(color: Colors.white)),
            content: Text('Sesli sohbet sadece Premium kullanıcılara veya Şans Çarkından dakika kazananlara özeldir. Lütfen Premium\'a geçin.', style: TextStyle(color: AppTheme.textSecondary)),
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

    if (!_timerProvider.canJoinRoom()) {
      if (mounted) {
        setState(() => _isConnecting = false);
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppTheme.surface,
            title: Text('Süre Limiti', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
            content: Text('Sesli sohbet süreniz bulunmuyor. Çarkı çevirerek bonus süre kazanabilir veya sınırsız sohbet için Premium\'a geçebilirsiniz!', style: TextStyle(color: AppTheme.textSecondary)),
            actions: [
              TextButton(
                onPressed: () { 
                  Navigator.pop(ctx); 
                  context.push('/premium'); 
                },
                child: const Text('Premium\'a Geç', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
              ),
              TextButton(
                onPressed: () { 
                  Navigator.pop(ctx); 
                  context.pop(); 
                },
                child: const Text('Kapat', style: TextStyle(color: AppTheme.primary)),
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
      
      // Callbacks setup
      _hmsService.onUpdate = () async {
        final list = await _hmsService.getPeers();
        if (mounted) {
          setState(() {
            _peers = list;
          });
        }
      };

      _hmsService.onSpeakersUpdate = (speakers) {
        if (mounted) {
          setState(() {
            _activeSpeakers = speakers.map((s) => s.peer.peerId).toSet();
          });
        }
      };

      // Get initial peer list
      final initialPeers = await _hmsService.getPeers();

      if (mounted) {
        setState(() {
          _isConnecting = false;
          _peers = initialPeers;
        });
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
    
    // Timer ve HMS işlemlerini arka planda hallet
    _timerProvider.stopTimer();
    try {
      await _hmsService.leaveChannel().timeout(const Duration(seconds: 2));
    } catch (_) {}
    
    if (mounted) {
      context.pop();
    }
  }

  void _toggleMute() async {
    setState(() => _isMuted = !_isMuted);
    await _hmsService.muteMic(_isMuted);
  }

  void _toggleSpeaker() async {
    setState(() => _isSpeakerOn = !_isSpeakerOn);
    await _hmsService.switchAudioOutput(_isSpeakerOn);
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
        decoration: BoxDecoration(
          gradient: AppTheme.surfaceGradient,
        ),
        child: _isConnecting
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
            : SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    // Participants Grid
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 20,
                          childAspectRatio: 0.85,
                        ),
                        itemCount: _peers.length,
                        itemBuilder: (context, index) {
                          final peer = _peers[index];
                          final isPeerMuted = peer.isLocal 
                              ? _isMuted 
                              : (peer.audioTrack?.isMute ?? false);
                          final isSpeaking = _activeSpeakers.contains(peer.peerId);
                          final userId = peer.customerUserId ?? '';

                          return FutureBuilder<UserModel?>(
                            future: _getCachedUser(userId),
                            builder: (context, snapshot) {
                              final user = snapshot.data;
                              final displayName = user?.displayName ?? peer.name;
                              final photoUrl = user?.photoUrl ?? '';

                              return GestureDetector(
                                onTap: () {
                                  if (userId.isNotEmpty) {
                                    context.push('/user/$userId');
                                  }
                                },
                                child: Column(
                                  children: [
                                    Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        // Glowing speaking indicator border
                                        AnimatedContainer(
                                          duration: const Duration(milliseconds: 200),
                                          width: 68,
                                          height: 68,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: isSpeaking ? AppTheme.accent : Colors.transparent,
                                              width: 2.5,
                                            ),
                                            boxShadow: isSpeaking
                                                ? [
                                                    BoxShadow(
                                                      color: AppTheme.accent.withValues(alpha: 0.4),
                                                      blurRadius: 10,
                                                      spreadRadius: 2,
                                                    )
                                                  ]
                                                : null,
                                          ),
                                        ),
                                        // Avatar
                                        UserAvatar(
                                          photoUrl: photoUrl,
                                          displayName: displayName,
                                          radius: 28,
                                        ),
                                        // Mute Badge
                                        if (isPeerMuted)
                                          Positioned(
                                            bottom: 0,
                                            right: 0,
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: AppTheme.surfaceLight,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.mic_off_rounded,
                                                size: 12,
                                                color: AppTheme.danger,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Timer Section
                    Consumer<VoiceRoomTimerProvider>(
                      builder: (context, timer, child) {
                        if (timer.isPremium) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Premium Sınırsız Sesli Sohbet',
                                  style: TextStyle(
                                    color: Colors.amber,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        if (timer.remainingSeconds > 0) {
                          return Column(
                            children: [
                              Text(
                                'Kalan Bonus Süre:',
                                style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                timer.formattedRemainingTime,
                                style: TextStyle(
                                  fontSize: 28, 
                                  color: timer.showWarning ? AppTheme.warning : AppTheme.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2.0,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                            ],
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                    const SizedBox(height: 24),
                    // Controls Row
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
                            child: Icon(_isMuted ? Icons.mic_off_rounded : Icons.mic_rounded, size: 24, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 24),
                        GestureDetector(
                          onTap: _toggleSpeaker,
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: _isSpeakerOn ? AppTheme.surfaceLight.withValues(alpha: 0.3) : AppTheme.surfaceLight,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _isSpeakerOn ? AppTheme.primary.withValues(alpha: 0.5) : AppTheme.border,
                              ),
                            ),
                            child: Icon(_isSpeakerOn ? Icons.volume_up_rounded : Icons.hearing_rounded, size: 24, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 24),
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
                                  width: 24, 
                                  height: 24, 
                                  child: CircularProgressIndicator(color: AppTheme.danger, strokeWidth: 2)
                                )
                              : const Icon(Icons.call_end_rounded, size: 24, color: AppTheme.danger),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
      ),
    );
  }
}
