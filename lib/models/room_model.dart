// lib/models/room_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class RoomModel {
  final String id;
  final String name;
  final String languageCode;
  final String flagEmoji;
  final String description;
  final int memberCount;
  final String? level;
  final String? roomCode;
  final Map<String, dynamic>? lastMessage;
  final String? ownerId;
  final bool isCustom;

  RoomModel({
    required this.id,
    required this.name,
    required this.languageCode,
    required this.flagEmoji,
    this.description = '',
    this.memberCount = 0,
    this.level,
    this.roomCode,
    this.lastMessage,
    this.ownerId,
    this.isCustom = false,
  });

  factory RoomModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RoomModel(
      id: doc.id,
      name: data['name'] ?? '',
      languageCode: data['languageCode'] ?? '',
      flagEmoji: data['flagEmoji'] ?? '',
      description: data['description'] ?? '',
      memberCount: data['memberCount'] is num
          ? ((data['memberCount'] as num).toInt() < 0 ? 0 : (data['memberCount'] as num).toInt())
          : 0,
      level: data['level'] as String?,
      roomCode: data['roomCode'] as String?,
      lastMessage: data['lastMessage'] as Map<String, dynamic>?,
      ownerId: data['ownerId'] as String?,
      isCustom: data['isCustom'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'languageCode': languageCode,
      'flagEmoji': flagEmoji,
      'description': description,
      'memberCount': memberCount,
      'level': level,
      'roomCode': roomCode,
      'lastMessage': lastMessage,
      'ownerId': ownerId,
      'isCustom': isCustom,
    };
  }
}
