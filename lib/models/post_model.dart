import 'package:cloud_firestore/cloud_firestore.dart';

class PostModel {
  final String id;
  final String userId;
  final String userDisplayName;
  final String userPhotoUrl;
  final String content;
  final String? imageUrl;
  final int likesCount;
  final int commentsCount;
  final int repostsCount;
  final DateTime createdAt;
  /// 'everyone' = herkese görünür, 'friends' = sadece arkadaşlara görünür
  final String audience;
  final String? location;

  PostModel({
    required this.id,
    required this.userId,
    required this.userDisplayName,
    this.userPhotoUrl = '',
    required this.content,
    this.imageUrl,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.repostsCount = 0,
    DateTime? createdAt,
    this.audience = 'everyone',
    this.location,
  }) : createdAt = createdAt ?? DateTime.now();

  factory PostModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      return PostModel(id: doc.id, userId: '', userDisplayName: '', content: '');
    }

    return PostModel(
      id: doc.id,
      userId: data['userId']?.toString() ?? '',
      userDisplayName: data['userDisplayName']?.toString() ?? '',
      userPhotoUrl: data['userPhotoUrl']?.toString() ?? '',
      content: data['content']?.toString() ?? '',
      imageUrl: data['imageUrl']?.toString(),
      likesCount: (data['likesCount'] as num?)?.toInt() ?? 0,
      commentsCount: (data['commentsCount'] as num?)?.toInt() ?? 0,
      repostsCount: (data['repostsCount'] as num?)?.toInt() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      audience: data['audience']?.toString() ?? 'everyone',
      location: data['location']?.toString(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userDisplayName': userDisplayName,
      'userPhotoUrl': userPhotoUrl,
      'content': content,
      if (imageUrl != null) 'imageUrl': imageUrl,
      'likesCount': likesCount,
      'commentsCount': commentsCount,
      'repostsCount': repostsCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'audience': audience,
      if (location != null) 'location': location,
    };
  }

  PostModel copyWith({
    String? id,
    String? userDisplayName,
    String? userPhotoUrl,
    String? content,
    String? imageUrl,
    int? likesCount,
    int? commentsCount,
    int? repostsCount,
    String? audience,
    String? location,
  }) {
    return PostModel(
      id: id ?? this.id,
      userId: userId,
      userDisplayName: userDisplayName ?? this.userDisplayName,
      userPhotoUrl: userPhotoUrl ?? this.userPhotoUrl,
      content: content ?? this.content,
      imageUrl: imageUrl ?? this.imageUrl,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      repostsCount: repostsCount ?? this.repostsCount,
      createdAt: createdAt,
      audience: audience ?? this.audience,
      location: location ?? this.location,
    );
  }
}
