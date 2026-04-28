// lib/models/user_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String photoUrl;
  final String bio;
  final List<Map<String, String>> knownLanguages;
  final List<Map<String, String>> learningLanguages;
  final List<String> interests;
  final String city;
  final bool _isOnlineRaw;
  final DateTime? lastSeen;
  final int followersCount;
  final int followingCount;
  final int postsCount;
  
  bool get isOnline {
    if (lastSeen != null) {
      if (DateTime.now().difference(lastSeen!) < const Duration(minutes: 2)) {
        return true;
      }
      return false; 
    }
    return _isOnlineRaw;
  }
  final DateTime createdAt;
  final bool isPremium;
  final DateTime? premiumEndDate;
  final int dailyVoiceMinutes;
  final DateTime lastResetDate;

  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl = '',
    this.bio = '',
    this.knownLanguages = const [],
    this.learningLanguages = const [],
    this.interests = const [],
    this.city = '',
    bool isOnline = false,
    this.lastSeen,
    DateTime? createdAt,
    this.isPremium = false,
    this.premiumEndDate,
    this.dailyVoiceMinutes = 0,
    DateTime? lastResetDate,
    this.followersCount = 0,
    this.followingCount = 0,
    this.postsCount = 0,
  })  : _isOnlineRaw = isOnline,
        createdAt = createdAt ?? DateTime.now(),
        lastResetDate = lastResetDate ?? DateTime.now();

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    var rawData = doc.data();
    if (rawData == null) {
      return UserModel(
        uid: doc.id,
        email: '',
        displayName: 'Kullanıcı',
      );
    }
    
    final data = rawData as Map<String, dynamic>;
    
    // Safely parse known languages
    List<Map<String, String>> parsedKnown = [];
    if (data['knownLanguages'] is List) {
      for (var item in data['knownLanguages']) {
        if (item is Map) {
          parsedKnown.add(item.map((key, value) => MapEntry(key.toString(), value.toString())));
        }
      }
    }

    // Safely parse learning languages (supports both old string list and new map list)
    List<Map<String, String>> parsedLearning = [];
    if (data['learningLanguages'] is List) {
      for (var item in data['learningLanguages']) {
        if (item is Map) {
          parsedLearning.add(item.map((k, v) => MapEntry(k.toString(), v.toString())));
        } else if (item is String) {
          // Migrate old format: plain string -> map with no level
          parsedLearning.add({'lang': item, 'level': 'Başlangıç'});
        }
      }
    }

    // Safely parse interests
    List<String> parsedInterests = [];
    if (data['interests'] is List) {
      parsedInterests = (data['interests'] as List).map((e) => e.toString()).toList();
    }

    // Safely parse dates
    DateTime? parsedLastSeen;
    if (data['lastSeen'] is Timestamp) {
      parsedLastSeen = (data['lastSeen'] as Timestamp).toDate();
    } else if (data['lastSeen'] is String) {
      parsedLastSeen = DateTime.tryParse(data['lastSeen']);
    }

    DateTime parsedCreatedAt = DateTime.now();
    if (data['createdAt'] is Timestamp) {
      parsedCreatedAt = (data['createdAt'] as Timestamp).toDate();
    } else if (data['createdAt'] is String) {
      parsedCreatedAt = DateTime.tryParse(data['createdAt']) ?? DateTime.now();
    }

    DateTime parsedLastResetDate = DateTime.now();
    if (data['lastResetDate'] is Timestamp) {
      parsedLastResetDate = (data['lastResetDate'] as Timestamp).toDate();
    } else if (data['lastResetDate'] is String) {
      parsedLastResetDate = DateTime.tryParse(data['lastResetDate']) ?? DateTime.now();
    }

    DateTime? parsedPremiumEndDate;
    if (data['premiumEndDate'] is Timestamp) {
      parsedPremiumEndDate = (data['premiumEndDate'] as Timestamp).toDate();
    } else if (data['premiumEndDate'] is String) {
      parsedPremiumEndDate = DateTime.tryParse(data['premiumEndDate']);
    }

    return UserModel(
      uid: doc.id,
      email: data['email']?.toString() ?? '',
      displayName: data['displayName']?.toString() ?? '',
      photoUrl: data['photoUrl']?.toString() ?? '',
      bio: data['bio']?.toString() ?? '',
      city: data['city']?.toString() ?? '',
      knownLanguages: parsedKnown,
      learningLanguages: parsedLearning,
      interests: parsedInterests,
      isOnline: data['isOnline'] == true,
      lastSeen: parsedLastSeen,
      createdAt: parsedCreatedAt,
      isPremium: data['isPremium'] == true,
      premiumEndDate: parsedPremiumEndDate,
      dailyVoiceMinutes: data['dailyVoiceMinutes'] as int? ?? 0,
      lastResetDate: parsedLastResetDate,
      followersCount: data['followersCount'] as int? ?? 0,
      followingCount: data['followingCount'] as int? ?? 0,
      postsCount: data['postsCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'bio': bio,
      'city': city,
      'knownLanguages': knownLanguages,
      'learningLanguages': learningLanguages,
      'interests': interests,
      'isOnline': _isOnlineRaw,
      'lastSeen': lastSeen != null ? Timestamp.fromDate(lastSeen!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'isPremium': isPremium,
      'premiumEndDate': premiumEndDate != null ? Timestamp.fromDate(premiumEndDate!) : null,
      'dailyVoiceMinutes': dailyVoiceMinutes,
      'lastResetDate': Timestamp.fromDate(lastResetDate),
      'followersCount': followersCount,
      'followingCount': followingCount,
      'postsCount': postsCount,
    };
  }

  UserModel copyWith({
    String? displayName,
    String? photoUrl,
    String? bio,
    String? city,
    List<Map<String, String>>? knownLanguages,
    List<Map<String, String>>? learningLanguages,
    List<String>? interests,
    bool? isOnline,
    DateTime? lastSeen,
    bool? isPremium,
    DateTime? premiumEndDate,
    int? dailyVoiceMinutes,
    DateTime? lastResetDate,
    int? followersCount,
    int? followingCount,
    int? postsCount,
  }) {
    return UserModel(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      bio: bio ?? this.bio,
      city: city ?? this.city,
      knownLanguages: knownLanguages ?? this.knownLanguages,
      learningLanguages: learningLanguages ?? this.learningLanguages,
      interests: interests ?? this.interests,
      isOnline: isOnline ?? _isOnlineRaw,
      lastSeen: lastSeen ?? this.lastSeen,
      createdAt: createdAt,
      isPremium: isPremium ?? this.isPremium,
      premiumEndDate: premiumEndDate ?? this.premiumEndDate,
      dailyVoiceMinutes: dailyVoiceMinutes ?? this.dailyVoiceMinutes,
      lastResetDate: lastResetDate ?? this.lastResetDate,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      postsCount: postsCount ?? this.postsCount,
    );
  }
}
