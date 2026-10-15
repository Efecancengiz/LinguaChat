// lib/widgets/message_bubble.dart
import 'package:flutter/material.dart';
import 'package:linguachat/config/theme.dart';
import 'package:linguachat/models/message_model.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:linguachat/services/translation_service.dart';

class MessageBubble extends StatefulWidget {
  final MessageModel message;
  final bool isMe;
  final bool showAvatar;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onLongPress;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.showAvatar = true,
    this.onAvatarTap,
    this.onLongPress,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  final TranslationService _translationService = TranslationService();
  bool _isTranslating = false;
  bool _showTranslated = false;
  String? _translatedText;

  Future<void> _handleTranslate() async {
    if (_translatedText != null) {
      setState(() {
        _showTranslated = !_showTranslated;
      });
      return;
    }

    setState(() {
      _isTranslating = true;
    });

    try {
      // Varsayılan olarak Türkçe'ye çeviriyoruz (veya locale ayarlayabiliriz)
      final result = await _translationService.translateText(widget.message.text, 'tr');
      setState(() {
        _translatedText = result;
        _showTranslated = true;
        _isTranslating = false;
      });
    } catch (e) {
      setState(() {
        _isTranslating = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Çeviri yapılırken bir hata oluştu.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayText = _showTranslated && _translatedText != null 
        ? _translatedText! 
        : widget.message.text;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onLongPress: widget.onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          mainAxisAlignment:
              widget.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
          if (!widget.isMe && widget.showAvatar) ...[
            GestureDetector(
              onTap: widget.onAvatarTap,
              child: CircleAvatar(
                radius: 16,
                backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
                backgroundImage: widget.message.senderPhotoUrl.isNotEmpty
                    ? NetworkImage(widget.message.senderPhotoUrl)
                    : null,
                child: widget.message.senderPhotoUrl.isEmpty
                    ? Text(
                        widget.message.senderName.isNotEmpty
                            ? widget.message.senderName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (!widget.isMe && !widget.showAvatar) const SizedBox(width: 40),
          if (widget.isMe && widget.onLongPress != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: InkWell(
                onTap: widget.onLongPress,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Icon(Icons.more_vert_rounded, color: AppTheme.textSecondary, size: 18),
                ),
              ),
            ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: widget.isMe
                    ? const LinearGradient(
                        colors: [AppTheme.primary, AppTheme.secondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: widget.isMe ? null : (isDark ? const Color(0xFF1C1C1E) : AppTheme.surfaceLight),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(widget.isMe ? 20 : (widget.showAvatar ? 4 : 20)),
                  bottomRight: Radius.circular(widget.isMe ? (widget.showAvatar ? 4 : 20) : 20),
                ),
                border: !widget.isMe && isDark ? Border.all(color: const Color(0xFF262626), width: 0.8) : null,
                boxShadow: [
                  BoxShadow(
                    color: (widget.isMe ? AppTheme.primary : Colors.black)
                        .withValues(alpha: widget.isMe ? 0.3 : 0.05),
                    blurRadius: widget.isMe ? 12 : 6,
                    offset: Offset(0, widget.isMe ? 4 : 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!widget.isMe && widget.showAvatar)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.message.senderName,
                            style: TextStyle(
                              color: AppTheme.primary.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                          if (widget.message.senderIsPremium) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppTheme.accent,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'PREMIUM',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  Text(
                    displayText,
                    style: TextStyle(
                      color: widget.message.isDeleted
                          ? (widget.isMe ? Colors.white70 : AppTheme.textSecondary.withValues(alpha: 0.7))
                          : (widget.isMe ? Colors.white : AppTheme.textPrimary),
                      fontSize: 15,
                      fontStyle: widget.message.isDeleted ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timeago.format(widget.message.timestamp, locale: 'tr'),
                        style: TextStyle(
                          color: (widget.isMe ? Colors.white : AppTheme.textSecondary)
                              .withValues(alpha: 0.6),
                          fontSize: 11,
                        ),
                      ),
                      if (widget.message.isEdited && !widget.message.isDeleted) ...[
                        const SizedBox(width: 4),
                        Text(
                          '(düzenlendi)',
                          style: TextStyle(
                            color: (widget.isMe ? Colors.white : AppTheme.textSecondary)
                                .withValues(alpha: 0.5),
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                      if (widget.isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.done_all_rounded,
                          size: 14,
                          color: widget.message.isRead 
                              ? Colors.lightBlueAccent 
                              : Colors.white.withValues(alpha: 0.6),
                        ),
                      ],
                      if (!widget.isMe) ...[
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: _handleTranslate,
                          child: _isTranslating 
                            ? SizedBox(
                                width: 12, 
                                height: 12, 
                                child: CircularProgressIndicator(
                                  strokeWidth: 2, 
                                  color: AppTheme.primary.withValues(alpha: 0.8)
                                )
                              )
                            : Icon(
                                Icons.g_translate_rounded, 
                                size: 14, 
                                color: _showTranslated 
                                    ? AppTheme.primary 
                                    : AppTheme.textSecondary.withValues(alpha: 0.6),
                              ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ));
  }
}
