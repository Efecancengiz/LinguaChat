// lib/screens/dm/dm_chat_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:linguachat/config/theme.dart';
import 'package:linguachat/models/message_model.dart';
import 'package:linguachat/models/user_model.dart';
import 'package:linguachat/providers/auth_provider.dart';
import 'package:linguachat/services/firestore_service.dart';
import 'package:linguachat/services/translation_service.dart';
import 'package:linguachat/config/constants.dart';
import 'package:linguachat/widgets/message_bubble.dart';
import 'package:linguachat/widgets/user_avatar.dart';
import 'package:linguachat/services/message_listener_service.dart';
import 'package:intl/intl.dart';

class DmChatScreen extends StatefulWidget {
  final String chatId;
  final String otherUserId;

  const DmChatScreen({
    super.key,
    required this.chatId,
    required this.otherUserId,
  });

  @override
  State<DmChatScreen> createState() => _DmChatScreenState();
}

class _DmChatScreenState extends State<DmChatScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final TranslationService _translationService = TranslationService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTranslatingInput = false;

  @override
  void initState() {
    super.initState();
    // Bu sohbet açıkken bildirim gelmesin
    MessageListenerService.setActiveChatId(widget.chatId);
  }

  void _showLanguagePickerAndTranslate() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Hangi dile çevrilsin?',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: AppConstants.languageRooms.length,
                  itemBuilder: (context, index) {
                    final lang = AppConstants.languageRooms[index];
                    return ListTile(
                      leading: Text(lang['flag'] as String, style: const TextStyle(fontSize: 24)),
                      title: Text(lang['name'] as String, style: const TextStyle(color: AppTheme.textPrimary)),
                      onTap: () {
                        Navigator.pop(ctx);
                        _translateInput(lang['code'] as String);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _translateInput(String targetLang) async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isTranslatingInput = true);

    try {
      final translated = await _translationService.translateText(text, targetLang);
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Çeviri yapılamadı.'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isTranslatingInput = false);
    }
  }

  void _showMessageOptions(MessageModel message) {
    if (DateTime.now().difference(message.timestamp).inMinutes > 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Sadece ilk 10 dakika içindeki mesajları düzenleyebilir veya silebilirsiniz.'),
          backgroundColor: AppTheme.danger.withValues(alpha: 0.8),
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
              ListTile(
                leading: const Icon(Icons.edit_rounded, color: AppTheme.primary),
                title: const Text('Düzenle', style: TextStyle(color: AppTheme.textPrimary)),
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
            ],
          ),
        );
      },
    );
  }

  void _showEditMessageDialog(MessageModel message) {
    final TextEditingController editController = TextEditingController(text: message.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceLight,
        title: const Text('Mesajı Düzenle', style: TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: editController,
          style: const TextStyle(color: AppTheme.textPrimary),
          maxLines: 3,
          minLines: 1,
          decoration: InputDecoration(
            hintText: 'Mesajınız...',
            hintStyle: const TextStyle(color: AppTheme.textSecondary),
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
            child: const Text('İptal', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            onPressed: () async {
              final newText = editController.text.trim();
              if (newText.isNotEmpty && newText != message.text) {
                await _firestoreService.editDmMessage(widget.chatId, message.id, newText);
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
        title: const Text('Mesajı Sil', style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text(
          'Bu mesajı silmek istediğinize emin misiniz? (Karşı taraftan da silinir)',
          style: TextStyle(color: AppTheme.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () async {
              await _firestoreService.deleteDmMessage(widget.chatId, message.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Sil', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _sendMessage() {
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

    _firestoreService.sendDmMessage(widget.chatId, message);
    _messageController.clear();
  }

  @override
  void dispose() {
    // Sohbet kapatılınca aktif ID'yi sıfırla
    MessageListenerService.setActiveChatId(null);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.read<AuthProvider>().currentUserId;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: AppBar(
              backgroundColor: AppTheme.background.withValues(alpha: 0.65),
              elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: StreamBuilder<UserModel?>(
          stream: _firestoreService.userStream(widget.otherUserId),
          builder: (context, snapshot) {
            final otherUser = snapshot.data;
            return GestureDetector(
              onTap: () =>
                  context.push('/user/${widget.otherUserId}'),
              child: Row(
                children: [
                  UserAvatar(
                    photoUrl: otherUser?.photoUrl,
                    displayName: otherUser?.displayName ?? '',
                    radius: 18,
                    showOnlineIndicator: true,
                    isOnline: otherUser?.isOnline ?? false,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        otherUser?.displayName ?? 'Kullanıcı',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        otherUser?.isOnline == true
                            ? 'Çevrimiçi'
                            : otherUser?.lastSeen != null
                                ? 'Son görülme: ${DateFormat('HH:mm').format(otherUser!.lastSeen!)}'
                                : 'Çevrimdışı',
                        style: TextStyle(
                          fontSize: 12,
                          color: otherUser?.isOnline == true
                              ? AppTheme.accent
                              : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          StreamBuilder<UserModel?>(
            stream: _firestoreService.userStream(widget.otherUserId),
            builder: (context, snapshot) {
              final otherUserName = snapshot.data?.displayName ?? 'Özel Görüşme';
              return IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.headset_mic_rounded, color: AppTheme.primary, size: 20),
                ),
                onPressed: () {
                   context.push(
                     '/voice-room/${widget.chatId}',
                     extra: {'name': otherUserName},
                   );
                },
                tooltip: 'Sesli Odaya Katıl',
              );
            }
          ),
          const SizedBox(width: 8),
        ],
      ),
            ),
          ),
        ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.surfaceGradient,
        ),
        child: Column(
          children: [
          Expanded(
            child: StreamBuilder<List<MessageModel>>(
              stream:
                  _firestoreService.dmMessagesStream(widget.chatId),
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                        color: AppTheme.primary),
                  );
                }

                final messages = snapshot.data ?? [];
                
                if (currentUserId != null && messages.isNotEmpty) {
                  final hasUnread = messages.any((m) => m.senderId != currentUserId && !m.isRead);
                  if (hasUnread) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _firestoreService.markChatAsRead(widget.chatId, currentUserId);
                    });
                  }
                }

                if (messages.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.waving_hand_rounded,
                          size: 64,
                          color: AppTheme.primary,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Sohbete başla!',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe =
                        message.senderId == currentUserId;
                    final showAvatar =
                        index == messages.length - 1 ||
                            messages[index + 1].senderId !=
                                message.senderId;

                    return MessageBubble(
                      message: message,
                      isMe: isMe,
                      showAvatar: showAvatar,
                      onLongPress: isMe && !message.isDeleted
                          ? () => _showMessageOptions(message)
                          : null,
                    );
                  },
                );
              },
            ),
          ),
          // Message input
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                decoration: BoxDecoration(
                  color: AppTheme.surface.withValues(alpha: 0.65),
                  border: const Border(
                    top: BorderSide(
                        color: AppTheme.border, width: 0.5),
                  ),
                ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                            color:
                                AppTheme.border.withValues(alpha: 0.5)),
                      ),
                      child: TextField(
                        controller: _messageController,
                        style: const TextStyle(
                            color: AppTheme.textPrimary),
                        maxLines: 4,
                        minLines: 1,
                        decoration: const InputDecoration(
                          hintText: 'Mesaj yaz...',
                          hintStyle: TextStyle(
                              color: AppTheme.textSecondary),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
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
                      color: AppTheme.surfaceLight,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.border.withValues(alpha: 0.5)),
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
                      onPressed: _isTranslatingInput ? null : _showLanguagePickerAndTranslate,
                      tooltip: 'Çevir',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary
                              .withValues(alpha: 0.3),
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
          ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

