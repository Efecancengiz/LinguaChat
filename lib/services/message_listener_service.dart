// lib/services/message_listener_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'notification_service.dart';

class MessageListenerService {
  static StreamSubscription<QuerySnapshot>? _subscription;
  static String? _currentUserId;
  static String? _activeChatId;

  static void setActiveChatId(String? chatId) {
    _activeChatId = chatId;
  }

  static void start(String userId) {
    if (kIsWeb) return; // Web'de local notifications çalışmıyor
    if (_currentUserId == userId) return;
    _currentUserId = userId;
    _subscription?.cancel();

    // DOĞRU koleksiyon adı: directMessages
    _subscription = FirebaseFirestore.instance
        .collection('directMessages')
        .where('participants', arrayContains: userId)
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.modified) {
          _handleChatUpdate(change.doc, userId);
        }
      }
    });
  }

  static Future<void> _handleChatUpdate(
      DocumentSnapshot doc, String userId) async {
    try {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return;

      final lastMessage = data['lastMessage'] as Map<String, dynamic>?;
      if (lastMessage == null) return;

      final senderId = lastMessage['senderId'] as String?;
      final isRead = lastMessage['isRead'] as bool? ?? true;
      final text = lastMessage['text'] as String? ?? '';

      // Kendi mesajımızsa veya okunmuşsa bildirim gösterme
      if (senderId == null || senderId == userId || isRead) return;

      // O sohbet zaten açıksa bildirim gösterme
      final chatId = doc.id;
      if (_activeChatId == chatId) return;

      // Gönderenin adını al
      final senderDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(senderId)
          .get();
      final senderName =
          (senderDoc.data()?['displayName'] as String?) ?? 'Biri';

      await NotificationService.showInAppNotification(
        title: senderName,
        body: text,
        chatId: chatId,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('MessageListenerService error: $e');
    }
  }

  static void stop() {
    _subscription?.cancel();
    _subscription = null;
    _currentUserId = null;
    _activeChatId = null;
  }
}
