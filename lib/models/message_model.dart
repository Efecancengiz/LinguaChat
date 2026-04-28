// lib/models/message_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String id;
  final String senderId;
  final String senderName;
  final String senderPhotoUrl;
  final String text;
  final DateTime timestamp;
  final String type;
  final bool senderIsPremium;
  final bool isRead;
  final bool isEdited;
  final bool isDeleted;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.senderPhotoUrl = '',
    required this.text,
    DateTime? timestamp,
    this.type = 'text',
    this.senderIsPremium = false,
    this.isRead = false,
    this.isEdited = false,
    this.isDeleted = false,
  }) : timestamp = timestamp ?? DateTime.now();

  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MessageModel(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      senderPhotoUrl: data['senderPhotoUrl'] ?? '',
      text: data['text'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      type: data['type'] ?? 'text',
      senderIsPremium: data['senderIsPremium'] == true,
      isRead: data['isRead'] == true,
      isEdited: data['isEdited'] == true,
      isDeleted: data['isDeleted'] == true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'senderPhotoUrl': senderPhotoUrl,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'type': type,
      'senderIsPremium': senderIsPremium,
      'isRead': isRead,
      'isEdited': isEdited,
      'isDeleted': isDeleted,
    };
  }
}
