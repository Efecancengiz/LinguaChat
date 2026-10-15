// lib/screens/rooms/room_chat_screen.dart
import 'dart:ui';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:linguachat/config/theme.dart';
import 'package:linguachat/config/constants.dart';
import 'package:linguachat/models/message_model.dart';
import 'package:linguachat/providers/auth_provider.dart';
import 'package:linguachat/services/firestore_service.dart';
import 'package:linguachat/services/translation_service.dart';
import 'package:flutter/services.dart';
import 'package:linguachat/widgets/message_bubble.dart';
import 'package:linguachat/widgets/flag_sphere.dart';

class RoomChatScreen extends StatefulWidget {
  final String roomId;
  final String roomName;
  final String roomFlag;
  final String? roomCode;
  final bool isCustom;
  final String languageCode;

  const RoomChatScreen({
    super.key,
    required this.roomId,
    required this.roomName,
    required this.roomFlag,
    this.roomCode,
    this.isCustom = false,
    required this.languageCode,
  });

  @override
  State<RoomChatScreen> createState() => _RoomChatScreenState();
}

class _RoomChatScreenState extends State<RoomChatScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final TranslationService _translationService = TranslationService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTranslatingInput = false;
  final Set<String> _invitedUserIds = {};
  Timer? _presenceTimer;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = context.read<AuthProvider>().currentUserId;
    _joinRoom();
    _startPresenceHeartbeat();
  }

  void _startPresenceHeartbeat() {
    _presenceTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_currentUserId != null) {
        _firestoreService.updateRoomPresence(widget.roomId, _currentUserId!);
      }
    });
  }

  Future<void> _joinRoom() async {
    if (_currentUserId == null) return;
    try {
      await _firestoreService.joinRoom(widget.roomId, _currentUserId!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Oda mevcudu güncellenemedi: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  Future<void> _translateInput() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isTranslatingInput = true);

    try {
      final translated = await _translationService.translateText(text, widget.languageCode);
      if (mounted) {
        setState(() {
          _messageController.text = translated;
          _messageController.selection = TextSelection.fromPosition(
            TextPosition(offset: _messageController.text.length),
          );
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Çeviri yapılamadı.'),
            backgroundColor: AppTheme.danger,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isTranslatingInput = false);
    }
  }

  void _showMessageOptions(MessageModel message, bool isMe) {
    final currentUser = context.read<AuthProvider>().user;
    final isAdmin = currentUser?.isAdmin == true;

    if (isMe && !isAdmin && DateTime.now().difference(message.timestamp).inMinutes > 10) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Sadece ilk 10 dakika içindeki mesajları düzenleyebilir veya silebilirsiniz.'),
          backgroundColor: AppTheme.danger.withValues(alpha: 0.8),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isMe) ...[
                ListTile(
                  leading: const Icon(Icons.edit_rounded, color: AppTheme.primary),
                  title: Text('Düzenle', style: TextStyle(color: AppTheme.textPrimary)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showEditMessageDialog(message);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_rounded, color: AppTheme.danger),
                  title: const Text('Sil', style: TextStyle(color: AppTheme.danger)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showDeleteConfirmDialog(message);
                  },
                ),
              ] else ...[
                if (isAdmin) ...[
                  ListTile(
                    leading: const Icon(Icons.delete_forever_rounded, color: AppTheme.danger),
                    title: const Text('Yönetici Olarak Sil 🗑️', style: TextStyle(color: AppTheme.danger, fontWeight: FontWeight.bold)),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          backgroundColor: AppTheme.surface,
                          title: Text('Yönetici Olarak Sil', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                          content: Text('Bu mesajı yönetici yetkisiyle odadan kalıcı olarak silmek istediğinizden emin misiniz?', style: TextStyle(color: AppTheme.textSecondary)),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(c, false),
                              child: Text('İptal', style: TextStyle(color: AppTheme.textSecondary)),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
                              onPressed: () => Navigator.pop(c, true),
                              child: const Text('Sil', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        try {
                          await _firestoreService.adminDeleteRoomMessage(widget.roomId, message.id);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Mesaj yönetici tarafından silindi! ✅')),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Mesaj silinirken hata oluştu: $e')),
                            );
                          }
                        }
                      }
                    },
                  ),
                ],
                ListTile(
                  leading: const Icon(Icons.flag_rounded, color: AppTheme.danger),
                  title: const Text('Mesajı Şikayet Et', style: TextStyle(color: AppTheme.danger)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showReportMessageDialog(message);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.block_rounded, color: AppTheme.danger),
                  title: const Text('Kullanıcıyı Engelle', style: TextStyle(color: AppTheme.danger)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showBlockUserDialog(message.senderId);
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showReportMessageDialog(MessageModel message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceLight,
        title: Text('Mesajı Şikayet Et', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text('Bu mesajı sakıncalı içerik olarak bildirmek istiyor musunuz? Geri bildiriminiz için teşekkür ederiz.', style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('İptal', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () async {
              Navigator.pop(ctx);
              final currentUserId = context.read<AuthProvider>().currentUserId;
              if (currentUserId != null) {
                await _firestoreService.reportMessage(message.id, currentUserId, message.text);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Mesaj şikayet edildi. İncelenmek üzere iletildi.'), backgroundColor: AppTheme.primary),
                  );
                }
              }
            },
            child: const Text('Şikayet Et', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showBlockUserDialog(String userId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceLight,
        title: Text('Kullanıcıyı Engelle', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text('Bu kullanıcıyı engellemek istediğinize emin misiniz? Artık ondan mesaj almayacaksınız.', style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('İptal', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () async {
              Navigator.pop(ctx);
              final currentUserId = context.read<AuthProvider>().currentUserId;
              if (currentUserId != null) {
                await _firestoreService.blockUser(currentUserId, userId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Kullanıcı engellendi.'), backgroundColor: AppTheme.primary),
                  );
                  context.pop(); // Go back since blocked
                }
              }
            },
            child: const Text('Engelle', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEditMessageDialog(MessageModel message) {
    final TextEditingController editController = TextEditingController(text: message.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceLight,
        title: Text('Mesajı Düzenle', style: TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: editController,
          style: TextStyle(color: AppTheme.textPrimary),
          maxLines: 3,
          minLines: 1,
          decoration: InputDecoration(
            hintText: 'Mesajınız...',
            hintStyle: TextStyle(color: AppTheme.textSecondary),
            filled: true,
            fillColor: AppTheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('İptal', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            onPressed: () async {
              final newText = editController.text.trim();
              if (newText.isNotEmpty && newText != message.text) {
                await _firestoreService.editRoomMessage(widget.roomId, message.id, newText);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Kaydet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog(MessageModel message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceLight,
        title: Text('Mesajı Sil', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          'Bu mesajı silmek istediğinize emin misiniz? (Odadan silinecektir)',
          style: TextStyle(color: AppTheme.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('İptal', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () async {
              await _firestoreService.deleteRoomMessage(widget.roomId, message.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Sil', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    final message = MessageModel(
      id: '',
      senderId: user.uid,
      senderName: user.displayName,
      senderPhotoUrl: user.photoUrl,
      text: text,
      senderIsPremium: user.isPremium,
    );

    _messageController.clear();
    try {
      await _firestoreService.sendRoomMessage(widget.roomId, message);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mesaj gönderilemedi. Lütfen bağlantınızı kontrol edin.'),
            backgroundColor: AppTheme.danger,
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
  }

  void _showInviteFriendsSheet() {
    final currentUserId = context.read<AuthProvider>().currentUserId;
    if (currentUserId == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Arkadaşlarını Davet Et',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _firestoreService.friendsStream(currentUserId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
                      }

                      final friends = snapshot.data ?? [];
                      if (friends.isEmpty) {
                        return Center(
                          child: Text(
                            'Henüz hiç arkadaşın yok.',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
                          ),
                        );
                      }

                      return ListView.separated(
                        itemCount: friends.length,
                        separatorBuilder: (context2, index2) => Divider(color: AppTheme.border.withValues(alpha: 0.5)),
                        itemBuilder: (context, index) {
                          final friend = friends[index];
                          final friendId = friend['friendId'] as String;
                          final friendName = friend['friendName'] as String;
                          final friendPhoto = friend['friendPhotoUrl'] as String?;
                          final isInvited = _invitedUserIds.contains(friendId);

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                              backgroundImage: friendPhoto != null ? NetworkImage(friendPhoto) : null,
                              child: friendPhoto == null
                                  ? const Icon(Icons.person, color: AppTheme.primary)
                                  : null,
                            ),
                            title: Text(
                              friendName,
                              style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                            ),
                            trailing: ElevatedButton(
                              onPressed: isInvited
                                  ? null
                                  : () async {
                                      // Capture context-dependent values BEFORE any await
                                      final authUser = context.read<AuthProvider>().user!;
                                      final senderName = authUser.displayName;
                                      final senderPhoto = authUser.photoUrl;
                                      final senderIsPremium = authUser.isPremium;
                                      final inviteText = 'Seni ${widget.roomName} odasına davet ediyorum! Özel odaya katılmak için gereken kod: ${widget.roomCode}';
                                      final chatId = _firestoreService.getDmChatId(currentUserId, friendId);

                                      try {
                                        await _firestoreService.createDmChat(currentUserId, friendId);
                                        
                                        final message = MessageModel(
                                          id: '',
                                          senderId: currentUserId,
                                          senderName: senderName,
                                          senderPhotoUrl: senderPhoto,
                                          text: inviteText,
                                          senderIsPremium: senderIsPremium,
                                        );

                                        await _firestoreService.sendDmMessage(chatId, message);
                                        
                                        setSheetState(() => _invitedUserIds.add(friendId));
                                        
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).clearSnackBars();
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('$friendName adlı kişiye davet gönderildi!'),
                                              backgroundColor: AppTheme.primary,
                                              duration: const Duration(seconds: 1),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).clearSnackBars();
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Davet gönderilirken hata oluştu.'),
                                              backgroundColor: AppTheme.danger,
                                              duration: Duration(seconds: 1),
                                            ),
                                          );
                                        }
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isInvited ? AppTheme.surfaceLight : AppTheme.primary,
                                foregroundColor: isInvited ? AppTheme.textSecondary : Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                              child: Text(isInvited ? 'Gönderildi' : 'Davet Et'),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _presenceTimer?.cancel();
    if (_currentUserId != null) {
      _firestoreService.leaveRoom(widget.roomId, _currentUserId!);
    }
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.read<AuthProvider>().currentUserId;
    final accentColor = AppConstants.getColorFromCode(widget.roomId);

    return Scaffold(
      backgroundColor: AppTheme.background,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: AppBar(
              backgroundColor: AppTheme.isDark ? Colors.black.withValues(alpha: 0.8) : AppTheme.background.withValues(alpha: 0.85),
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => context.pop(),
              ),
        title: Row(
          children: [
            FlagSphere(
              languageCode: widget.languageCode,
              flagEmoji: widget.roomFlag,
              size: 38,
              glowColor: accentColor,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.roomName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  widget.isCustom && widget.roomCode != null
                      ? 'Özel Oda • Kod: ${widget.roomCode}'
                      : 'Herkese açık oda',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary.withValues(alpha: 0.7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (widget.isCustom && widget.roomCode != null)
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.copy_rounded, color: AppTheme.primary, size: 20),
              ),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: widget.roomCode!));
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Oda kodu kopyalandı: ${widget.roomCode!}'),
                    backgroundColor: AppTheme.primary,
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
              tooltip: 'Kodu Kopyala',
            ),
          if (widget.isCustom && widget.roomCode != null)
            const SizedBox(width: 4),
          if (widget.isCustom && widget.roomCode != null)
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_add_rounded, color: AppTheme.primary, size: 20),
              ),
              onPressed: _showInviteFriendsSheet,
              tooltip: 'Arkadaş Davet Et',
            ),
          if (widget.isCustom && widget.roomCode != null)
            const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Center(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                  foregroundColor: AppTheme.primary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  minimumSize: const Size(0, 36),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.headset_mic_rounded, size: 16),
                label: const Text('Sesli Katıl', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                onPressed: () {
                  final user = context.read<AuthProvider>().user;
                  if (user == null) return;
                  
                  bool hasBonus = false;
                  final now = DateTime.now();
                  if (user.lastSpinDate != null && 
                      user.lastSpinDate!.year == now.year && 
                      user.lastSpinDate!.month == now.month && 
                      user.lastSpinDate!.day == now.day && 
                      user.bonusMinutes > 0) {
                    hasBonus = true;
                  }
                  
                  if (!user.isPremium && !hasBonus) {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppTheme.surface,
                        title: const Text('Premium Özel', style: TextStyle(color: Colors.white)),
                        content: Text('Sesli sohbet sadece Premium kullanıcılara veya Şans Çarkından dakika kazananlara özeldir. Lütfen Premium\'a geçin veya Şans Çarkını çevirin.', style: TextStyle(color: AppTheme.textSecondary)),
                        actions: [
                          TextButton(
                            onPressed: () { 
                              Navigator.pop(ctx); 
                              context.push('/premium'); 
                            },
                            child: const Text('Premium Al', style: TextStyle(color: AppTheme.primary)),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('İptal', style: TextStyle(color: Colors.grey)),
                          ),
                        ],
                      )
                    );
                    return;
                  }

                  context.push(
                    '/voice-room/${widget.roomId}',
                    extra: {'name': widget.roomName},
                  );
                },
              ),
            ),
          ),
        ],
      ),
            ),
          ),
        ),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.surfaceGradient,
        ),
        child: Column(
          children: [
          // Messages list
          Expanded(
            child: StreamBuilder<List<MessageModel>>(
              stream: _firestoreService.roomMessagesStream(widget.roomId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  );
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FlagSphere(
                          languageCode: widget.languageCode,
                          flagEmoji: widget.roomFlag,
                          size: 72,
                          glowColor: accentColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Henüz mesaj yok',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'İlk mesajı sen gönder! 🎯',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Align(
                  alignment: Alignment.bottomCenter,
                  child: ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final isMe = message.senderId == currentUserId;
                      final showAvatar = index == messages.length - 1 ||
                          messages[index + 1].senderId != message.senderId;

                      return MessageBubble(
                        message: message,
                        isMe: isMe,
                        showAvatar: showAvatar,
                        onLongPress: !message.isDeleted
                            ? () => _showMessageOptions(message, isMe)
                            : null,
                        onAvatarTap: isMe
                            ? null
                            : () =>
                                context.push('/user/${message.senderId}'),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          // Message input
          Builder(
            builder: (context) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              final barBg = isDark ? const Color(0xFF000000) : AppTheme.surface;
              final inputBg = isDark ? const Color(0xFF1C1C1E) : AppTheme.surfaceLight;
              final borderCol = isDark ? const Color(0xFF262626) : AppTheme.border;
              final textCol = isDark ? Colors.white : AppTheme.textPrimary;
              final hintCol = isDark ? const Color(0xFFA8A8A8) : AppTheme.textSecondary;

              return Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                decoration: BoxDecoration(
                  color: barBg,
                  border: Border(
                    top: BorderSide(color: borderCol, width: 0.8),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  bottom: true,
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: inputBg,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: borderCol.withValues(alpha: 0.6)),
                          ),
                          child: TextField(
                            controller: _messageController,
                            style: TextStyle(color: textCol),
                            maxLines: 4,
                            minLines: 1,
                            decoration: InputDecoration(
                              hintText: 'Mesaj yaz...',
                              hintStyle: TextStyle(color: hintCol),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                            ),
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: inputBg,
                          shape: BoxShape.circle,
                          border: Border.all(color: borderCol.withValues(alpha: 0.6)),
                        ),
                        child: IconButton(
                          icon: _isTranslatingInput
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.primary,
                                  ),
                                )
                              : const Icon(Icons.g_translate_rounded, color: AppTheme.primary, size: 20),
                          onPressed: _isTranslatingInput ? null : _translateInput,
                          tooltip: 'Odanın diline çevir',
                        ),
                      ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded,
                          color: Colors.white, size: 20),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ],
  ),
),
);
  }
}
