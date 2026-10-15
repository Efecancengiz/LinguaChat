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
    
    // Sohbet açıldığında okunmuş olarak işaretle (out-of-sync durumlarını düzeltmek için)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final currentUserId = context.read<AuthProvider>().currentUserId;
        if (currentUserId != null) {
          _firestoreService.markChatAsRead(widget.chatId, currentUserId);
        }
      }
    });
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
              Text(
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
                      title: Text(lang['name'] as String, style: TextStyle(color: AppTheme.textPrimary)),
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

  void _showMessageOptions(MessageModel message, bool isMe) {
    final currentUser = context.read<AuthProvider>().user;
    final isAdmin = currentUser?.isAdmin == true;

    if (isMe && !isAdmin && DateTime.now().difference(message.timestamp).inMinutes > 10) {
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
                          content: Text('Bu özel mesajı yönetici yetkisiyle kalıcı olarak silmek istediğinizden emin misiniz?', style: TextStyle(color: AppTheme.textSecondary)),
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
                          await _firestoreService.adminDeleteDmMessage(widget.chatId, message.id);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('DM mesajı yönetici tarafından silindi! ✅')),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Silinirken hata oluştu: $e')),
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
                    _showBlockDialog(context, context.read<AuthProvider>().currentUserId ?? '', widget.otherUserId);
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
        title: Text('Mesajı Sil', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          'Bu mesajı silmek istediğinize emin misiniz? (Karşı taraftan da silinir)',
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
              await _firestoreService.deleteDmMessage(widget.chatId, message.id);
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
      await _firestoreService.sendDmMessage(widget.chatId, message);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mesaj gönderilemedi. Lütfen bağlantınızı kontrol edin.'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  void _showReportDialog(BuildContext context, String currentUserId, String otherUserId) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('Kullanıcıyı Şikayet Et', style: TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: reasonController,
          decoration: InputDecoration(
            hintText: 'Şikayet nedeni...',
            hintStyle: TextStyle(color: AppTheme.textSecondary),
          ),
          style: TextStyle(color: AppTheme.textPrimary),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('İptal', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) return;
              await _firestoreService.reportUser(otherUserId, currentUserId, reasonController.text.trim());
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Şikayetiniz alındı ve incelenecektir.')),
                );
              }
            },
            child: const Text('Gönder', style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
  }

  void _showBlockDialog(BuildContext context, String currentUserId, String otherUserId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('Kullanıcıyı Engelle', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text('Bu kullanıcıyı engellemek istediğinize emin misiniz? Artık ondan mesaj almayacak ve içeriklerini görmeyeceksiniz.', style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('İptal', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              await _firestoreService.blockUser(currentUserId, otherUserId);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Kullanıcı engellendi.')),
                );
                context.pop(); // Go back from chat
              }
            },
            child: const Text('Engelle', style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
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
                        style: TextStyle(
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
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
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
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded),
                    onSelected: (value) async {
                      if (value == 'report') {
                        _showReportDialog(context, currentUserId ?? '', widget.otherUserId);
                      } else if (value == 'block') {
                        _showBlockDialog(context, currentUserId ?? '', widget.otherUserId);
                      }
                    },
                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                      const PopupMenuItem<String>(
                        value: 'report',
                        child: Row(
                          children: [
                            Icon(Icons.flag_rounded, color: AppTheme.warning, size: 20),
                            SizedBox(width: 8),
                            Text('Şikayet Et', style: TextStyle(color: AppTheme.warning)),
                          ],
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'block',
                        child: Row(
                          children: [
                            Icon(Icons.block_rounded, color: AppTheme.danger, size: 20),
                            SizedBox(width: 8),
                            Text('Engelle', style: TextStyle(color: AppTheme.danger)),
                          ],
                        ),
                      ),
                    ],
                    color: AppTheme.surfaceLight,
                  ),
                ],
              );
            }
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
                  return Center(
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
                        onLongPress: !message.isDeleted
                            ? () => _showMessageOptions(message, isMe)
                            : null,
                      );
                    },
                  ),
                );
              },
            ),
          ),
          // Message input
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
          );
        },
      ),
    ],
  ),
),
);
  }
}

