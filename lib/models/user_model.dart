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
  final bool isAdmin;
  final bool isBanned;
  final String? banReason;
  
  bool get isOnline {
    if (_isOnlineRaw) {
      if (lastSeen != null) {
        final diff = DateTime.now().difference(lastSeen!).inMinutes.abs();
        if (diff < 10) {
          return true;
        }
        return false;
      }
      return true;
    }
    return false;
  }
  final DateTime createdAt;
  final bool isPremium;
  final DateTime? premiumEndDate;
  final int dailyVoiceMinutes;
  final int dailyVoiceSeconds;
  final DateTime lastResetDate;
  final int bonusMinutes;
  final DateTime? lastSpinDate;

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
    this.dailyVoiceSeconds = 0,
    DateTime? lastResetDate,
    this.bonusMinutes = 0,
    this.lastSpinDate,
    this.followersCount = 0,
    this.followingCount = 0,
    this.postsCount = 0,
    this.isAdmin = false,
    this.isBanned = false,
    this.banReason,
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

    DateTime? parsedLastSpinDate;
    if (data['lastSpinDate'] is Timestamp) {
      parsedLastSpinDate = (data['lastSpinDate'] as Timestamp).toDate();
    } else if (data['lastSpinDate'] is String) {
      parsedLastSpinDate = DateTime.tryParse(data['lastSpinDate']);
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
      dailyVoiceSeconds: data['dailyVoiceSeconds'] as int? ?? 0,
      lastResetDate: parsedLastResetDate,
      bonusMinutes: data['bonusMinutes'] as int? ?? 0,
      lastSpinDate: parsedLastSpinDate,
      followersCount: data['followersCount'] as int? ?? 0,
      followingCount: data['followingCount'] as int? ?? 0,
      postsCount: data['postsCount'] as int? ?? 0,
      isAdmin: data['isAdmin'] == true,
      isBanned: data['isBanned'] == true,
      banReason: data['banReason']?.toString(),
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
      'dailyVoiceSeconds': dailyVoiceSeconds,
      'lastResetDate': Timestamp.fromDate(lastResetDate),
      'bonusMinutes': bonusMinutes,
      'lastSpinDate': lastSpinDate != null ? Timestamp.fromDate(lastSpinDate!) : null,
      'followersCount': followersCount,
      'followingCount': followingCount,
      'postsCount': postsCount,
      'isAdmin': isAdmin,
      'isBanned': isBanned,
      if (banReason != null) 'banReason': banReason,
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
    int? dailyVoiceSeconds,
    DateTime? lastResetDate,
    int? bonusMinutes,
    DateTime? lastSpinDate,
    int? followersCount,
    int? followingCount,
    int? postsCount,
    bool? isAdmin,
    bool? isBanned,
    String? banReason,
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
      bonusMinutes: bonusMinutes ?? this.bonusMinutes,
      lastSpinDate: lastSpinDate ?? this.lastSpinDate,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      postsCount: postsCount ?? this.postsCount,
      isAdmin: isAdmin ?? this.isAdmin,
      isBanned: isBanned ?? this.isBanned,
      banReason: banReason ?? this.banReason,
    );
  }
}
