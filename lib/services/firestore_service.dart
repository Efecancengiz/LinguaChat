// lib/services/firestore_service.dart
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:math';
import 'package:linguachat/models/user_model.dart';
import 'package:linguachat/models/message_model.dart';
import 'package:linguachat/models/room_model.dart';
import 'package:linguachat/models/friend_request_model.dart';
import 'package:linguachat/models/post_model.dart';
import 'package:linguachat/config/constants.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============ USERS ============
  Future<UserModel?> getUser(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      return UserModel.fromFirestore(doc);
    } catch (e) {
      debugPrint('FirestoreService.getUser hata: $e');
      return null;
    }
  }

  Stream<UserModel?> userStream(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? UserModel.fromFirestore(doc) : null);
  }

  Future<void> _updateUserPostsProfileInfo(String uid, {String? displayName, String? photoUrl}) async {
    if (displayName == null && photoUrl == null) return;
    
    try {
      final postsQuery = await _firestore
          .collection('posts')
          .where('userId', isEqualTo: uid)
          .get();
          
      if (postsQuery.docs.isNotEmpty) {
        final updateData = <String, dynamic>{};
        if (displayName != null) updateData['userDisplayName'] = displayName;
        if (photoUrl != null) updateData['userPhotoUrl'] = photoUrl;
        
        const batchSize = 400;
        final docs = postsQuery.docs;
        for (var i = 0; i < docs.length; i += batchSize) {
          final batch = _firestore.batch();
          for (var doc in docs.skip(i).take(batchSize)) {
            batch.update(doc.reference, updateData);
          }
          await batch.commit();
        }
      }
    } catch (e) {
      debugPrint('FirestoreService._updateUserPostsProfileInfo hata: $e');
    }
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('users').doc(uid).set(data, SetOptions(merge: true));
      
      final displayName = data['displayName'] as String?;
      final photoUrl = data['photoUrl'] as String?;
      if (displayName != null || photoUrl != null) {
        await _updateUserPostsProfileInfo(uid, displayName: displayName, photoUrl: photoUrl);
      }
    } catch (e) {
      debugPrint('FirestoreService.updateUser hata: $e');
      rethrow;
    }
  }

  Future<void> updateUserDisplayName(String uid, String oldName, String newName) async {
    if (oldName == newName) return;

    // 1. Ekstra Güvenlik: users koleksiyonunda birebir eşleşen başka bir kullanıcı var mı kontrol et
    final existingUserQuery = await _firestore
        .collection('users')
        .where('displayName', isEqualTo: newName)
        .get();
        
    for (var doc in existingUserQuery.docs) {
      if (doc.id != uid) {
        throw Exception('username-taken');
      }
    }

    final newUsernameRef = _firestore.collection('usernames').doc(newName.toLowerCase());
    final oldUsernameRef = _firestore.collection('usernames').doc(oldName.toLowerCase());
    
    try {
      await _firestore.runTransaction((txn) async {
        if (oldName.toLowerCase() != newName.toLowerCase()) {
          final snap = await txn.get(newUsernameRef);
          if (snap.exists) {
            final ownerUid = snap.data()?['uid'];
            if (ownerUid != null && ownerUid != uid) {
              throw Exception('username-taken');
            }
          }
          
          final oldSnap = await txn.get(oldUsernameRef);
          
          // Yeni kullanıcı adını al
          txn.set(newUsernameRef, {'uid': uid});
          
          // Eskisini sadece varsa ve bize aitse sil
          if (oldSnap.exists) {
            final oldOwnerUid = oldSnap.data()?['uid'];
            if (oldOwnerUid == uid) {
              txn.delete(oldUsernameRef);
            }
          }
        }
        
        // Kullanıcı belgesini güncelle
        txn.update(_firestore.collection('users').doc(uid), {'displayName': newName});
      });

      // Update displayName in all of the user's posts
      await _updateUserPostsProfileInfo(uid, displayName: newName);
    } catch (e) {
      debugPrint('FirestoreService.updateUserDisplayName hata: $e');
      rethrow;
    }
  }

  /// Arkadaş olmayan tüm kullanıcıları stream olarak döndürür (ağ ekranı için)
  Stream<List<UserModel>> getNonFriendsStream(String currentUserId) {
    // Önce arkadaş ID'lerini stream olarak al, ardından kullanıcıları filtrele
    return _firestore
        .collection('friends')
        .doc(currentUserId)
        .collection('userFriends')
        .snapshots()
        .asyncExpand((friendsSnap) {
          final friendIds = friendsSnap.docs.map((d) => d.id).toSet();
          return _firestore
              .collection('users')
              .limit(100)
              .snapshots()
              .map((usersSnap) => usersSnap.docs
                  .map((doc) => UserModel.fromFirestore(doc))
                  .where((user) =>
                      user.uid != currentUserId &&
                      !friendIds.contains(user.uid))
                  .toList());
        });
  }

  /// Tüm kullanıcıları döndürür (eski - geriye uyumluluk için)
  Stream<List<UserModel>> getAllUsersStream(String currentUserId) {
    return _firestore
        .collection('users')
        .limit(100)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserModel.fromFirestore(doc))
            .where((user) => user.uid != currentUserId)
            .toList());
  }

  Future<void> updateProfilePhoto(String uid, String photoUrl) async {
    await updateUser(uid, {'photoUrl': photoUrl});
  }

  Future<void> updatePresence(String uid, bool isOnline) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('FirestoreService.updatePresence hata: $e');
    }
  }

  Future<void> deleteUser(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      final displayName = doc.data()?['displayName'] as String?;
      
      final batch = _firestore.batch();
      batch.delete(_firestore.collection('users').doc(uid));
      
      if (displayName != null && displayName.isNotEmpty) {
        batch.delete(_firestore.collection('usernames').doc(displayName.toLowerCase()));
      }
      
      await batch.commit();
    } catch (e) {
      debugPrint('FirestoreService.deleteUser hata: $e');
      rethrow;
    }
  }

  Future<void> restoreUser(UserModel user) async {
    try {
      final batch = _firestore.batch();
      batch.set(_firestore.collection('users').doc(user.uid), user.toFirestore());
      if (user.displayName.isNotEmpty) {
        batch.set(_firestore.collection('usernames').doc(user.displayName.toLowerCase()), {'uid': user.uid});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('FirestoreService.restoreUser hata: $e');
      rethrow;
    }
  }

  Future<List<UserModel>> searchUsers(String query) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('displayName', isGreaterThanOrEqualTo: query)
          .where('displayName', isLessThanOrEqualTo: '$query\uf8ff')
          .limit(20)
          .get();
      return snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('FirestoreService.searchUsers hata: $e');
      return [];
    }
  }

  // ============ ROOMS ============
  Future<void> initializeRooms() async {
    try {
      final snapshot = await _firestore.collection('rooms').get();
      final existingDocIds = snapshot.docs.map((doc) => doc.id).toSet();

      int batchCount = 0;
      WriteBatch batch = _firestore.batch();
      bool hasNewRooms = false;

      final levelsToInit = ['Tümü', 'Başlangıç (A1-A2)', 'Orta (B1-B2)', 'İleri (C1-C2)', 'Ana Dil (C2+)'];

      for (final room in AppConstants.languageRooms) {
        for (final level in levelsToInit) {
          final docId = level == 'Tümü' ? room['code'] as String : '${room['code']}_$level';
          
          if (!existingDocIds.contains(docId)) {
            hasNewRooms = true;
            final roomRef = _firestore.collection('rooms').doc(docId);
            batch.set(roomRef, {
              'name': '${room['name']} Room',
              'languageCode': room['code'],
              'flagEmoji': room['flag'],
              'description': level == 'Tümü' 
                  ? '${room['name']} dilinde genel sohbet odası' 
                  : '${room['name']} dilinde $level sohbet odası',
              'memberCount': 0,
              'level': level,
              'lastMessage': null,
              'isCustom': false,
            });
            
            batchCount++;
            if (batchCount >= 400) {
              await batch.commit();
              batch = _firestore.batch();
              batchCount = 0;
              hasNewRooms = false;
            }
          }
        }
      }

      if (hasNewRooms && batchCount > 0) {
        await batch.commit();
      }
    } catch (e) {
      debugPrint('FirestoreService.initializeRooms hata: $e');
    }
  }

  Future<RoomModel> createCustomRoom({
    required String name,
    required String languageCode,
    required String flagEmoji,
    required String ownerId,
  }) async {
    try {
      final String code = _generateRoomCode();
      final docRef = _firestore.collection('rooms').doc();
      
      final room = RoomModel(
        id: docRef.id,
        name: name,
        languageCode: languageCode,
        flagEmoji: flagEmoji,
        description: 'Özel Oda',
        memberCount: 0,
        roomCode: code,
        ownerId: ownerId,
        isCustom: true,
      );
      
      await docRef.set(room.toFirestore());
      return room;
    } catch (e) {
      debugPrint('FirestoreService.createCustomRoom hata: $e');
      rethrow;
    }
  }

  Future<RoomModel?> getRoomByCode(String code) async {
    try {
      final snapshot = await _firestore
          .collection('rooms')
          .where('roomCode', isEqualTo: code)
          .where('isCustom', isEqualTo: true)
          .limit(1)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        return RoomModel.fromFirestore(snapshot.docs.first);
      }
      return null;
    } catch (e) {
      debugPrint('FirestoreService.getRoomByCode hata: $e');
      return null;
    }
  }

  String _generateRoomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return String.fromCharCodes(Iterable.generate(
        6, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
  }

  Stream<List<RoomModel>> roomsStream() {
    return _firestore.collection('rooms').snapshots().map(
          (snapshot) {
            final rooms = <RoomModel>[];
            for (final doc in snapshot.docs) {
              try {
                rooms.add(RoomModel.fromFirestore(doc));
              } catch (e) {
                debugPrint('FirestoreService.roomsStream parsing hatası (doc: ${doc.id}): $e');
              }
            }
            final codeOrder = AppConstants.languageRooms.map((r) => r['code'] as String).toList();
            rooms.sort((a, b) {
              final idxA = codeOrder.indexOf(a.languageCode);
              final idxB = codeOrder.indexOf(b.languageCode);
              return (idxA == -1 ? 999 : idxA).compareTo(idxB == -1 ? 999 : idxB);
            });
            return rooms;
          },
        );
  }

  Stream<List<MessageModel>> roomMessagesStream(String roomId) {
    return _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => MessageModel.fromFirestore(doc)).toList());
  }

  Future<void> sendRoomMessage(String roomId, MessageModel message) async {
    try {
      await _firestore
          .collection('rooms')
          .doc(roomId)
          .collection('messages')
          .add(message.toFirestore());

      await _firestore.collection('rooms').doc(roomId).update({
        'lastMessage': {
          'text': message.text,
          'senderId': message.senderId,
          'senderName': message.senderName,
          'timestamp': FieldValue.serverTimestamp(),
        },
      });
    } catch (e) {
      debugPrint('FirestoreService.sendRoomMessage hata: $e');
      rethrow;
    }
  }

  Future<void> editRoomMessage(String roomId, String messageId, String newText) async {
    try {
      await _firestore
          .collection('rooms')
          .doc(roomId)
          .collection('messages')
          .doc(messageId)
          .update({
        'text': newText,
        'isEdited': true,
      });
    } catch (e) {
      debugPrint('FirestoreService.editRoomMessage hata: $e');
      rethrow;
    }
  }

  Future<void> deleteRoomMessage(String roomId, String messageId) async {
    try {
      await _firestore
          .collection('rooms')
          .doc(roomId)
          .collection('messages')
          .doc(messageId)
          .update({
        'isDeleted': true,
        'text': '🚫 Bu mesaj silindi',
      });
    } catch (e) {
      debugPrint('FirestoreService.deleteRoomMessage hata: $e');
      rethrow;
    }
  }

  Future<void> syncRoomMembersCount(String roomId) async {
    try {
      final roomRef = _firestore.collection('rooms').doc(roomId);
      final roomDoc = await roomRef.get();
      if (!roomDoc.exists) return;
      final currentCount = roomDoc.data()?['memberCount'] ?? 0;

      final activeUsersSnap = await roomRef.collection('activeUsers').get();
      
      final now = DateTime.now();
      int activeCount = 0;
      final batch = _firestore.batch();
      bool hasDeletions = false;
      
      for (var doc in activeUsersSnap.docs) {
        final data = doc.data();
        final lastSeenTimestamp = data['lastSeen'] as Timestamp?;
        if (lastSeenTimestamp != null) {
          final lastSeen = lastSeenTimestamp.toDate();
          final difference = now.difference(lastSeen).inMinutes;
          
          if (difference.abs() <= 2) {
            activeCount++;
          } else {
            batch.delete(doc.reference);
            hasDeletions = true;
          }
        } else {
          activeCount++;
        }
      }
      
      if (currentCount != activeCount || hasDeletions) {
        batch.update(roomRef, {'memberCount': activeCount});
        await batch.commit();
      }
    } catch (e) {
      debugPrint('FirestoreService.syncRoomMembersCount hata: $e');
    }
  }

  Future<void> joinRoom(String roomId, String userId) async {
    try {
      final roomRef = _firestore.collection('rooms').doc(roomId);
      final activeUserRef = roomRef.collection('activeUsers').doc(userId);
      
      await activeUserRef.set({
        'lastSeen': FieldValue.serverTimestamp(),
      });
      
      // Parse roomId to get languageCode and level if room doesn't exist
      final doc = await roomRef.get();
      if (!doc.exists) {
        final parts = roomId.split('_');
        final langCode = parts[0];
        final level = parts.length > 1 ? parts[1] : 'Tümü';
        
        final roomInfo = AppConstants.languageRooms.firstWhere(
          (r) => r['code'] == langCode,
          orElse: () => {'name': langCode, 'flag': '🌍'},
        );
        
        await roomRef.set({
          'name': '${roomInfo['name']} Room',
          'languageCode': langCode,
          'flagEmoji': roomInfo['flag'],
          'description': level == 'Tümü' 
              ? '${roomInfo['name']} dilinde genel sohbet odası' 
              : '${roomInfo['name']} dilinde $level sohbet odası',
          'memberCount': 1,
          'level': level,
          'lastMessage': null,
          'isCustom': false,
        });
      }
      
      await syncRoomMembersCount(roomId);
    } catch (e) {
      debugPrint('FirestoreService.joinRoom hata: $e');
      rethrow;
    }
  }

  Future<void> leaveRoom(String roomId, String userId) async {
    try {
      final roomRef = _firestore.collection('rooms').doc(roomId);
      final activeUserRef = roomRef.collection('activeUsers').doc(userId);
      
      await activeUserRef.delete();
      await syncRoomMembersCount(roomId);
    } catch (e) {
      debugPrint('FirestoreService.leaveRoom hata: $e');
      rethrow;
    }
  }

  Future<void> updateRoomPresence(String roomId, String userId) async {
    try {
      await _firestore
          .collection('rooms')
          .doc(roomId)
          .collection('activeUsers')
          .doc(userId)
          .set({
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('FirestoreService.updateRoomPresence hata: $e');
    }
  }

  // ============ FRIEND REQUESTS ============
  Future<void> sendFriendRequest(FriendRequestModel request) async {
    try {
      // Check if request already exists
      final existing = await _firestore
          .collection('friendRequests')
          .where('fromUserId', isEqualTo: request.fromUserId)
          .where('toUserId', isEqualTo: request.toUserId)
          .where('status', isEqualTo: 'pending')
          .get();

      if (existing.docs.isNotEmpty) return;

      // Check reverse request
      final reverse = await _firestore
          .collection('friendRequests')
          .where('fromUserId', isEqualTo: request.toUserId)
          .where('toUserId', isEqualTo: request.fromUserId)
          .where('status', isEqualTo: 'pending')
          .get();

      if (reverse.docs.isNotEmpty) {
        // Auto-accept if already sent from other side
        await acceptFriendRequest(reverse.docs.first.id,
            request.toUserId, request.fromUserId,
            request.toUserName, request.fromUserName,
            request.toUserPhoto, request.fromUserPhoto);
        return;
      }

      await _firestore.collection('friendRequests').add(request.toFirestore());

      // Arkadaşlık isteği bildirimi gönder
      await _sendPushNotification(
        recipientId: request.toUserId,
        title: 'Yepyeni Bir İstek! 👋',
        body: '${request.fromUserName} sana arkadaşlık isteği gönderdi.',
        data: {'type': 'friend_request', 'fromUserId': request.fromUserId},
      );
    } catch (e) {
      debugPrint('FirestoreService.sendFriendRequest hata: $e');
      rethrow;
    }
  }

  Stream<List<FriendRequestModel>> pendingRequestsStream(String userId) {
    return _firestore
        .collection('friendRequests')
        .where('toUserId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
            final docs = snapshot.docs.map((doc) => FriendRequestModel.fromFirestore(doc)).toList();
            docs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            return docs;
        });
  }

  Stream<List<FriendRequestModel>> sentRequestsStream(String userId) {
    return _firestore
        .collection('friendRequests')
        .where('fromUserId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FriendRequestModel.fromFirestore(doc))
            .toList());
  }

  Future<void> acceptFriendRequest(
    String requestId,
    String userId1,
    String userId2,
    String userName1,
    String userName2,
    String userPhoto1,
    String userPhoto2,
  ) async {
    try {
      await _firestore.collection('friendRequests').doc(requestId).update({
        'status': 'accepted',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Add to friends subcollection for both users
      final batch = _firestore.batch();

      batch.set(
        _firestore.collection('friends').doc(userId1).collection('userFriends').doc(userId2),
        {
          'friendId': userId2,
          'friendName': userName2,
          'friendPhotoUrl': userPhoto2,
          'addedAt': FieldValue.serverTimestamp(),
        },
      );

      batch.set(
        _firestore.collection('friends').doc(userId2).collection('userFriends').doc(userId1),
        {
          'friendId': userId1,
          'friendName': userName1,
          'friendPhotoUrl': userPhoto1,
          'addedAt': FieldValue.serverTimestamp(),
        },
      );

      // Check existing follow states to prevent double incrementing
      final u1FollowingU2 = await _firestore.collection('users').doc(userId1).collection('following').doc(userId2).get();
      if (!u1FollowingU2.exists) {
         batch.set(_firestore.collection('users').doc(userId1).collection('following').doc(userId2), {'createdAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
         batch.set(_firestore.collection('users').doc(userId2).collection('followers').doc(userId1), {'createdAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
         
         batch.set(_firestore.collection('users').doc(userId1), {'followingCount': FieldValue.increment(1)}, SetOptions(merge: true));
         batch.set(_firestore.collection('users').doc(userId2), {'followersCount': FieldValue.increment(1)}, SetOptions(merge: true));
      }

      final u2FollowingU1 = await _firestore.collection('users').doc(userId2).collection('following').doc(userId1).get();
      if (!u2FollowingU1.exists) {
         batch.set(_firestore.collection('users').doc(userId2).collection('following').doc(userId1), {'createdAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
         batch.set(_firestore.collection('users').doc(userId1).collection('followers').doc(userId2), {'createdAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
         
         batch.set(_firestore.collection('users').doc(userId2), {'followingCount': FieldValue.increment(1)}, SetOptions(merge: true));
         batch.set(_firestore.collection('users').doc(userId1), {'followersCount': FieldValue.increment(1)}, SetOptions(merge: true));
      }

      await batch.commit();
      
      // Bildirimi kime atacağımızı bulalım. İsteği zaten atan kişi 'fromUserId'dir. 
      // requestId'den orijinal isteği atan kişiyi bulup ona bildirim gönderelim.
      final requestDoc = await _firestore.collection('friendRequests').doc(requestId).get();
      if (requestDoc.exists && requestDoc.data() != null) {
        final data = requestDoc.data()!;
        final fromUserId = data['fromUserId'];
        // Kabul eden kişinin adı 'toUserName' içinde kayıtlı.
        final toUserName = data['toUserName'];
        
        await _sendPushNotification(
          recipientId: fromUserId,
          title: 'Harika Haber! 🎉',
          body: '$toUserName arkadaşlık isteğini kabul etti. Hemen sohbete başla!',
          data: {'type': 'friend_accepted', 'userId': data['toUserId']},
        );
      }
    } catch (e) {
      debugPrint('FirestoreService.acceptFriendRequest hata: $e');
      rethrow;
    }
  }

  Future<void> rejectFriendRequest(String requestId) async {
    try {
      await _firestore.collection('friendRequests').doc(requestId).update({
        'status': 'rejected',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('FirestoreService.rejectFriendRequest hata: $e');
      rethrow;
    }
  }

  Stream<List<Map<String, dynamic>>> friendsStream(String userId) {
    return _firestore
        .collection('friends')
        .doc(userId)
        .collection('userFriends')
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }

  Future<bool> isFriend(String userId, String otherUserId) async {
    try {
      final doc = await _firestore
          .collection('friends')
          .doc(userId)
          .collection('userFriends')
          .doc(otherUserId)
          .get();
      return doc.exists;
    } catch (e) {
      debugPrint('FirestoreService.isFriend hata: $e');
      return false;
    }
  }

  Future<bool> hasPendingRequest(String fromUserId, String toUserId) async {
    try {
      final snapshot = await _firestore
          .collection('friendRequests')
          .where('fromUserId', isEqualTo: fromUserId)
          .where('toUserId', isEqualTo: toUserId)
          .where('status', isEqualTo: 'pending')
          .get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('FirestoreService.hasPendingRequest hata: $e');
      return false;
    }
  }

  // ============ DIRECT MESSAGES ============
  String getDmChatId(String userId1, String userId2) {
    final sorted = [userId1, userId2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  Future<void> createDmChat(String userId1, String userId2) async {
    try {
      final chatId = getDmChatId(userId1, userId2);
      final doc = await _firestore.collection('directMessages').doc(chatId).get();
      if (!doc.exists) {
        await _firestore.collection('directMessages').doc(chatId).set({
          'participants': [userId1, userId2],
          'lastMessage': null,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('FirestoreService.createDmChat hata: $e');
      rethrow;
    }
  }

  Stream<List<Map<String, dynamic>>> dmListStream(String userId) {
    return _firestore
        .collection('directMessages')
        .where('participants', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
      final docs = snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .where((chat) => chat['lastMessage'] != null)
          .toList();
      docs.sort((a, b) {
        final t1 = a['updatedAt'] as Timestamp?;
        final t2 = b['updatedAt'] as Timestamp?;
        if (t1 == null && t2 == null) return 0;
        if (t1 == null) return 1;
        if (t2 == null) return -1;
        return t2.compareTo(t1);
      });
      return docs;
    });
  }

  Stream<List<MessageModel>> dmMessagesStream(String chatId) {
    return _firestore
        .collection('directMessages')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => MessageModel.fromFirestore(doc)).toList());
  }

  Future<void> sendDmMessage(String chatId, MessageModel message) async {
    try {
      await _firestore
          .collection('directMessages')
          .doc(chatId)
          .collection('messages')
          .add(message.toFirestore());

      final parts = chatId.split('_');
      await _firestore.collection('directMessages').doc(chatId).set({
        if (parts.length == 2) 'participants': parts,
        'lastMessage': {
          'text': message.text,
          'senderId': message.senderId,
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('FirestoreService.sendDmMessage hata: $e');
      rethrow;
    }
  }

  Future<void> editDmMessage(String chatId, String messageId, String newText) async {
    try {
      await _firestore
          .collection('directMessages')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({
        'text': newText,
        'isEdited': true,
      });
    } catch (e) {
      debugPrint('FirestoreService.editDmMessage hata: $e');
      rethrow;
    }
  }

  Future<void> deleteDmMessage(String chatId, String messageId) async {
    try {
      await _firestore
          .collection('directMessages')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({
        'isDeleted': true,
        'text': '🚫 Bu mesaj silindi',
      });
    } catch (e) {
      debugPrint('FirestoreService.deleteDmMessage hata: $e');
      rethrow;
    }
  }

  Future<void> deleteDmChat(String chatId) async {
    try {
      final batch = _firestore.batch();
      final messages = await _firestore.collection('directMessages').doc(chatId).collection('messages').limit(100).get();
      for (var doc in messages.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(_firestore.collection('directMessages').doc(chatId));
      await batch.commit();
    } catch (e) {
      debugPrint('FirestoreService.deleteDmChat hata: $e');
      rethrow;
    }
  }

  /// Genel Push Bildirimi Gönderme Fonksiyonu
  Future<void> _sendPushNotification({
    required String recipientId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Client'ta secret taşımamak için push server (Cloud Functions) üzerinden gönderilir.
      final callable =
          FirebaseFunctions.instance.httpsCallable('sendPushNotification');
      await callable.call({
        'recipientId': recipientId,
        'title': title,
        'body': body,
        if (data != null) ...{'data': data},
      });
    } catch (e) {
      debugPrint('OneSignal catch hata: $e');
    }
  }

  Future<void> markChatAsRead(String chatId, String currentUserId) async {
    try {
      final parts = chatId.split('_');
      String otherUserId = '';
      if (parts.length == 2) {
        otherUserId = parts.firstWhere((id) => id != currentUserId, orElse: () => '');
      }

      if (otherUserId.isEmpty) {
        final chatDoc = await _firestore.collection('directMessages').doc(chatId).get();
        if (chatDoc.exists) {
          final participants = chatDoc.data()?['participants'] as List<dynamic>?;
          if (participants != null) {
            otherUserId = participants.firstWhere((id) => id != currentUserId, orElse: () => '') as String;
          }
        }
      }

      if (otherUserId.isEmpty) return;

      final messagesSnapshot = await _firestore
          .collection('directMessages')
          .doc(chatId)
          .collection('messages')
          .where('senderId', isEqualTo: otherUserId)
          .where('isRead', isEqualTo: false)
          .get();

      if (messagesSnapshot.docs.isNotEmpty) {
        const batchSize = 400;
        final docs = messagesSnapshot.docs;
        for (var i = 0; i < docs.length; i += batchSize) {
          final batch = _firestore.batch();
          for (var doc in docs.skip(i).take(batchSize)) {
            batch.update(doc.reference, {'isRead': true});
          }
          await batch.commit();
        }
      }

      final chatDoc = await _firestore.collection('directMessages').doc(chatId).get();
      if (chatDoc.exists) {
        final data = chatDoc.data();
        if (data != null && data['lastMessage'] != null) {
          final lastMessage = data['lastMessage'] as Map<String, dynamic>;
          if (lastMessage['senderId'] != currentUserId && lastMessage['isRead'] == false) {
            await _firestore.collection('directMessages').doc(chatId).update({
              'lastMessage.isRead': true,
            });
          }
        }
      }
    } catch (e) {
      debugPrint('FirestoreService.markChatAsRead hata: $e');
    }
  }

  // ============ PREMIUM & VOICE LIMITS ============
  Future<void> upgradeToPremium(String uid, {required Duration duration}) async {
    try {
      final now = DateTime.now();
      final currentDoc = await getUser(uid);
      
      DateTime newEndDate = now.add(duration);
      if (currentDoc != null && currentDoc.isPremium && currentDoc.premiumEndDate != null) {
        if (currentDoc.premiumEndDate!.isAfter(now)) {
          newEndDate = currentDoc.premiumEndDate!.add(duration);
        }
      }

      await _firestore.collection('users').doc(uid).update({
        'isPremium': true,
        'premiumEndDate': Timestamp.fromDate(newEndDate),
      });
    } catch (e) {
      debugPrint('FirestoreService.upgradeToPremium hata: $e');
      rethrow;
    }
  }

  Future<int> syncVoiceUsage({bool increment = false, int? usedSeconds}) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('syncVoiceUsage');
      final result = await callable.call(<String, dynamic>{
        'increment': increment,
        'usedSeconds': ?usedSeconds,
      });
      final data = Map<String, dynamic>.from(result.data as Map);
      return (data['dailyVoiceSeconds'] as num?)?.toInt() ?? 0;
    } catch (e) {
      debugPrint('FirestoreService.syncVoiceUsage hata: $e');
      rethrow;
    }
  }

  // ============ FOLLOW & FEED SYSTEM ============
  
  /// Geçiş dönemi V3: Eski arkadaşları otomatik olarak karşılıklı Takipçi/Takip Edilen'e çevirir ve sayıları düzeltir.
  Future<void> syncFriendsToFollowers(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return;
      
      final data = doc.data() as Map<String, dynamic>;
      if (data['friendsSyncedV3'] == true) return; // Zaten düzeltildiyse tekrar etme
      
      final friendsSnap = await _firestore.collection('friends').doc(uid).collection('userFriends').get();
      
      if (friendsSnap.docs.isNotEmpty) {
        final batch = _firestore.batch();
        
        // Önce herkesin alt koleksiyonlarını doldur (Arkadaşlık karşılıklıdır)
        for (var friendDoc in friendsSnap.docs) {
          String friendId = friendDoc.id;
          
          batch.set(_firestore.collection('users').doc(uid).collection('following').doc(friendId), {'createdAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
          batch.set(_firestore.collection('users').doc(uid).collection('followers').doc(friendId), {'createdAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
          
           batch.set(_firestore.collection('users').doc(friendId).collection('following').doc(uid), {'createdAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
          batch.set(_firestore.collection('users').doc(friendId).collection('followers').doc(uid), {'createdAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
        }
        await batch.commit();

        // Şimdi Gerçek sayıları hesapla (Idempotent: Çift saymayı önler)
        final myFollowing = await _firestore.collection('users').doc(uid).collection('following').get();
        final myFollowers = await _firestore.collection('users').doc(uid).collection('followers').get();
        
        await _firestore.collection('users').doc(uid).set({
          'followingCount': myFollowing.docs.length,
          'followersCount': myFollowers.docs.length,
          'friendsSyncedV3': true
        }, SetOptions(merge: true));

        // Arkadaşların için de sayıları senkronize et
        await Future.wait(friendsSnap.docs.map((friendDoc) async {
          String friendId = friendDoc.id;
          final theirFollowing = await _firestore.collection('users').doc(friendId).collection('following').get();
          final theirFollowers = await _firestore.collection('users').doc(friendId).collection('followers').get();
          await _firestore.collection('users').doc(friendId).set({
             'followingCount': theirFollowing.docs.length,
             'followersCount': theirFollowers.docs.length,
          }, SetOptions(merge: true));
        }));
      } else {
        await _firestore.collection('users').doc(uid).set({'friendsSyncedV3': true}, SetOptions(merge: true));
      }
    } catch(e) {
      debugPrint('FirestoreService.syncFriendsToFollowers hata: $e');
    }
  }

  /// Gerçek takip ve takipçi belgelerini sayarak sayıları günceller (kendi kendini onarma)
  Future<void> syncUserFollowCounts(String uid) async {
    try {
      final myFollowing = await _firestore.collection('users').doc(uid).collection('following').get();
      final myFollowers = await _firestore.collection('users').doc(uid).collection('followers').get();

      await _firestore.collection('users').doc(uid).update({
        'followingCount': max(0, myFollowing.docs.length),
        'followersCount': max(0, myFollowers.docs.length),
      });
    } catch (e) {
      debugPrint('FirestoreService.syncUserFollowCounts hata: $e');
    }
  }

  /// Kullanıcının posts koleksiyonundaki gerçek post sayısını sayıp,
  /// postsCount alanına eşitler. (Eksi düşmeleri engeller)
  Future<void> syncUserPostsCount(String uid) async {
    try {
      final aggregateQuery = await _firestore.collection('posts').where('userId', isEqualTo: uid).count().get();
      final count = aggregateQuery.count ?? 0;
      await _firestore.collection('users').doc(uid).set({'postsCount': count}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('FirestoreService.syncUserPostsCount hata: $e');
    }
  }

  /// Kullanıcıyı takip et (tek yönlü — karşılıklı değil)
  Future<void> followUser(String currentUserId, String targetUserId) async {
    try {
      // Çift takibi önle
      final followingRef = _firestore.collection('users').doc(currentUserId).collection('following').doc(targetUserId);
      final alreadyFollowing = await followingRef.get();
      if (alreadyFollowing.exists) return;

      final batch = _firestore.batch();

      // 1. Alt koleksiyonlara ekle (tek yönlü)
      final followerRef = _firestore.collection('users').doc(targetUserId).collection('followers').doc(currentUserId);
      batch.set(followingRef, {'createdAt': FieldValue.serverTimestamp()});
      batch.set(followerRef, {'createdAt': FieldValue.serverTimestamp()});

      // 2. Sayaçları güncelle (sadece ilgili taraflar)
      final currentUserRef = _firestore.collection('users').doc(currentUserId);
      final targetUserRef = _firestore.collection('users').doc(targetUserId);
      batch.set(currentUserRef, {'followingCount': FieldValue.increment(1)}, SetOptions(merge: true));
      batch.set(targetUserRef, {'followersCount': FieldValue.increment(1)}, SetOptions(merge: true));

      await batch.commit();

      // Bildirim gönder
      final currentUserDoc = await currentUserRef.get();
      if (currentUserDoc.exists) {
        final name = currentUserDoc.data()?['displayName'] ?? 'Biri';
        await _sendPushNotification(
          recipientId: targetUserId,
          title: 'Yeni Takipçi!',
          body: '$name seni takip etmeye başladı.',
          data: {'type': 'new_follower', 'userId': currentUserId},
        );
      }
    } catch (e) {
      debugPrint('FirestoreService.followUser hata: $e');
      rethrow;
    }
  }

  /// Takipten çık
  Future<void> unfollowUser(String currentUserId, String targetUserId) async {
    try {
      final batch = _firestore.batch();
      
      // 1. Alt koleksiyonlardan sil (Eğer takip ediyorsak)
      final followingRef = _firestore.collection('users').doc(currentUserId).collection('following').doc(targetUserId);
      final followerRef = _firestore.collection('users').doc(targetUserId).collection('followers').doc(currentUserId);
      
      final followingSnap = await followingRef.get();
      final wasFollowing = followingSnap.exists;

      if (wasFollowing) {
        batch.delete(followingRef);
        batch.delete(followerRef);
      }
      
      // 1.5. Karşı tarafın listelerinden de sil (Arkadaşlık modeli = Karşılıklı takip)
      final theirFollowingRef = _firestore.collection('users').doc(targetUserId).collection('following').doc(currentUserId);
      final theirFollowerRef = _firestore.collection('users').doc(currentUserId).collection('followers').doc(targetUserId);
      
      final theirFollowingSnap = await theirFollowingRef.get();
      final wasTheirFollowing = theirFollowingSnap.exists;

      if (wasTheirFollowing) {
        batch.delete(theirFollowingRef);
        batch.delete(theirFollowerRef);
      }

      // 1.6. Arkadaşlık listelerinden sil
      final friendRef1 = _firestore.collection('friends').doc(currentUserId).collection('userFriends').doc(targetUserId);
      final friendRef2 = _firestore.collection('friends').doc(targetUserId).collection('userFriends').doc(currentUserId);
      batch.delete(friendRef1);
      batch.delete(friendRef2);
      
      // 2. Sayaçları azalt (sadece silinen ilişkiler için)
      final currentUserRef = _firestore.collection('users').doc(currentUserId);
      final targetUserRef = _firestore.collection('users').doc(targetUserId);
      
      final Map<String, dynamic> currentUserUpdates = {};
      final Map<String, dynamic> targetUserUpdates = {};

      if (wasFollowing) {
        currentUserUpdates['followingCount'] = FieldValue.increment(-1);
        targetUserUpdates['followersCount'] = FieldValue.increment(-1);
      }

      if (wasTheirFollowing) {
        currentUserUpdates['followersCount'] = FieldValue.increment(-1);
        targetUserUpdates['followingCount'] = FieldValue.increment(-1);
      }

      if (currentUserUpdates.isNotEmpty) {
        batch.set(currentUserRef, currentUserUpdates, SetOptions(merge: true));
      }
      if (targetUserUpdates.isNotEmpty) {
        batch.set(targetUserRef, targetUserUpdates, SetOptions(merge: true));
      }
      
      await batch.commit();
    } catch (e) {
      debugPrint('FirestoreService.unfollowUser hata: $e');
      rethrow;
    }
  }

  /// Takip durumunu kontrol et
  Future<bool> isFollowing(String currentUserId, String targetUserId) async {
    try {
      final doc = await _firestore.collection('users').doc(currentUserId).collection('following').doc(targetUserId).get();
      return doc.exists;
    } catch (e) {
      debugPrint('FirestoreService.isFollowing hata: $e');
      return false;
    }
  }

  /// Gönderi paylaş
  Future<void> createPost(PostModel post) async {
    try {
      final postRef = _firestore.collection('posts').doc();
      final finalPost = post.copyWith(id: postRef.id);

      // Önce gönderiyi kaydet
      final data = finalPost.toFirestore();
      // Akış sıralaması için server timestamp kullan (client clock drift sorunlarını azaltır).
      data['createdAt'] = FieldValue.serverTimestamp();
      await postRef.set(data);

      // Kullanıcı postsCount'unu güncelle (set+merge → alan yoksa da çalışır)
      await _firestore
          .collection('users')
          .doc(post.userId)
          .set({'postsCount': FieldValue.increment(1)}, SetOptions(merge: true));

      // Garanti senkronizasyon (asenkron, UI'ı bekletmez)
      syncUserPostsCount(post.userId);
    } catch (e) {
      debugPrint('FirestoreService.createPost hata: $e');
      rethrow;
    }
  }

  /// Tüm kullanıcıların gönderilerini getir (Keşfet / Herkes)
  /// audience=='everyone' olanları client-side filtreler;
  /// bu sayede Firestore composite index gerektirmez ve
  /// eski geri dönüşsüz gönderiler de (audience alanı olmayan) herkese görünür.
  Stream<List<PostModel>> getFeedPostsStream(String currentUserId) async* {
    yield* _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('blockedUsers')
        .snapshots()
        .asyncExpand((blockedSnap) {
      final blockedIds = blockedSnap.docs.map((d) => d.id).toSet();
      return _firestore
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs
            .map((doc) => PostModel.fromFirestore(doc))
            .where((post) => post.audience == 'everyone' && !blockedIds.contains(post.userId))
            .toList();
      });
    });
  }

  /// Arkadaşların gönderilerini gerçek zamanlı stream ile getir
  /// (kendi paylaşımlar dahil; hem 'everyone' hem 'friends' görünür)
  Stream<List<PostModel>> getFriendsFeedStream(String currentUserId) async* {
    // Arkadaş listesini tek seferlik çek
    final friendsSnap = await _firestore
        .collection('friends')
        .doc(currentUserId)
        .collection('userFriends')
        .get();
    final friendIds = friendsSnap.docs.map((d) => d.id).toList();
    
    // Engellenenleri bul
    final blockedSnap = await _firestore.collection('users').doc(currentUserId).collection('blockedUsers').get();
    final blockedIds = blockedSnap.docs.map((d) => d.id).toSet();
    
    final ids = [currentUserId, ...friendIds].where((id) => !blockedIds.contains(id)).toList();
    final batchIds = ids.take(30).toList();

    if (batchIds.isEmpty) {
      yield [];
      return;
    }

    yield* _firestore
        .collection('posts')
        .where('userId', whereIn: batchIds)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => PostModel.fromFirestore(doc)).toList());
  }

  /// Arkadaşlar + kendinin gönderilerini Stream olarak getir (İndeks hatasını önlemek için client-side filtreleme)
  Stream<List<PostModel>> getFriendsFeedStream2(String currentUserId) async* {
    yield* _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('blockedUsers')
        .snapshots()
        .asyncExpand((blockedSnap) {
      final blockedIds = blockedSnap.docs.map((d) => d.id).toSet();
      return Stream.fromFuture(_firestore
          .collection('friends')
          .doc(currentUserId)
          .collection('userFriends')
          .get()).asyncExpand((friendsSnap) {
        final friendIds = friendsSnap.docs.map((d) => d.id).toList();
        final allowedIds = {currentUserId, ...friendIds}.difference(blockedIds);

        return _firestore
            .collection('posts')
            .orderBy('createdAt', descending: true)
            .limit(100)
            .snapshots()
            .map((snap) {
          return snap.docs
              .map((doc) => PostModel.fromFirestore(doc))
              .where((post) => allowedIds.contains(post.userId))
              .toList();
        });
      });
    });
  }

  /// Belirli bir kullanıcının gönderilerini getir
  Stream<List<PostModel>> getUserPostsStream(String userId) {
    return _firestore
        .collection('posts')
        .where('userId', isEqualTo: userId)
        .limit(30)
        .snapshots()
        .map((snapshot) {
          final posts = snapshot.docs
              .map((doc) => PostModel.fromFirestore(doc))
              .toList();
          // Sort client-side to avoid needing composite index
          posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return posts;
        });
  }

  /// Gönderi beğen / beğeniyi çek
  Future<void> togglePostLike(String postId, String userId) async {
    try {
      final likeRef = _firestore.collection('posts').doc(postId).collection('likes').doc(userId);
      final doc = await likeRef.get();
      
      if (doc.exists) {
        // Unlike
        final batch = _firestore.batch();
        batch.delete(likeRef);
        batch.update(_firestore.collection('posts').doc(postId), {'likesCount': FieldValue.increment(-1)});
        await batch.commit();
      } else {
        // Like
        final batch = _firestore.batch();
        batch.set(likeRef, {'createdAt': FieldValue.serverTimestamp()});
        batch.update(_firestore.collection('posts').doc(postId), {'likesCount': FieldValue.increment(1)});
        await batch.commit();
      }
    } catch (e) {
      debugPrint('FirestoreService.togglePostLike hata: $e');
      rethrow;
    }
  }

  /// Kullanıcının gönderiyi beğenip beğenmediğini gerçek zamanlı izle
  Stream<bool> isLikedStream(String postId, String userId) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('likes')
        .doc(userId)
        .snapshots()
        .map((doc) => doc.exists);
  }

  /// Gönderiyi beğenen kullanıcıları gerçek zamanlı dinle
  Stream<List<UserModel>> postLikesStream(String postId) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('likes')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((snap) async {
      final uids = snap.docs.map((doc) => doc.id).toList();
      if (uids.isEmpty) return [];

      final users = await Future.wait(uids.map((uid) => getUser(uid)));
      return users.whereType<UserModel>().toList();
    });
  }

  /// Gönderi yorumu ekle
  Future<void> addComment({
    required String postId,
    required String userId,
    required String userDisplayName,
    required String userPhotoUrl,
    required String content,
  }) async {
    try {
      final batch = _firestore.batch();
      final commentRef = _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .doc();
      batch.set(commentRef, {
        'userId': userId,
        'userDisplayName': userDisplayName,
        'userPhotoUrl': userPhotoUrl,
        'content': content,
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.update(
        _firestore.collection('posts').doc(postId),
        {'commentsCount': FieldValue.increment(1)},
      );
      await batch.commit();
    } catch (e) {
      debugPrint('FirestoreService.addComment hata: $e');
      rethrow;
    }
  }

  /// Gönderi yorumunu sil
  Future<void> deleteComment(String postId, String commentId) async {
    try {
      final batch = _firestore.batch();
      batch.delete(
        _firestore.collection('posts').doc(postId).collection('comments').doc(commentId)
      );
      batch.update(
        _firestore.collection('posts').doc(postId),
        {'commentsCount': FieldValue.increment(-1)},
      );
      await batch.commit();
    } catch (e) {
      debugPrint('FirestoreService.deleteComment hata: $e');
      rethrow;
    }
  }

  /// Gönderi yorumlarını getir
  Stream<List<Map<String, dynamic>>> getCommentsStream(String postId) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  /// Gönderiyi tekrar paylaş (Repost)
  Future<void> repostPost({
    required PostModel originalPost,
    required String currentUserId,
    required String currentUserDisplayName,
    required String currentUserPhotoUrl,
  }) async {
    try {
      final batch = _firestore.batch();

      // Yeni post oluştur (repost olarak işaretle)
      final repostRef = _firestore.collection('posts').doc();
      batch.set(repostRef, {
        'userId': currentUserId,
        'userDisplayName': currentUserDisplayName,
        'userPhotoUrl': currentUserPhotoUrl,
        'content': originalPost.content,
        if (originalPost.imageUrl != null) 'imageUrl': originalPost.imageUrl,
        'likesCount': 0,
        'commentsCount': 0,
        'repostsCount': 0,
        'isRepost': true,
        'originalPostId': originalPost.id,
        'originalUserId': originalPost.userId,
        'originalUserDisplayName': originalPost.userDisplayName,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Orijinal gönderinin repostsCount'unu artır
      batch.update(
        _firestore.collection('posts').doc(originalPost.id),
        {'repostsCount': FieldValue.increment(1)},
      );

      // Kullanıcının postsCount'unu artır
      batch.update(
        _firestore.collection('users').doc(currentUserId),
        {'postsCount': FieldValue.increment(1)},
      );

      await batch.commit();
    } catch (e) {
      debugPrint('FirestoreService.repostPost hata: $e');
      rethrow;
    }
  }

  /// Gönderiyi sil
  Future<void> deletePost(String postId, String userId) async {
    try {
      final batch = _firestore.batch();
      batch.delete(_firestore.collection('posts').doc(postId));
      batch.update(
        _firestore.collection('users').doc(userId),
        {'postsCount': FieldValue.increment(-1)},
      );
      await batch.commit();

      // Garanti senkronizasyon (asenkron, UI'ı bekletmez)
      syncUserPostsCount(userId);
    } catch (e) {
      debugPrint('FirestoreService.deletePost hata: $e');
      rethrow;
    }
  }

  /// Gönderiyi düzenle (İçerik güncellemesi)
  Future<void> updatePostContent(String postId, String newContent) async {
    try {
      await _firestore.collection('posts').doc(postId).update({
        'content': newContent,
      });
    } catch (e) {
      debugPrint('FirestoreService.updatePostContent hata: $e');
      rethrow;
    }
  }

  /// Get user's followers
  Future<List<UserModel>> getFollowers(String userId) async {
    try {
      final snap = await _firestore.collection('users').doc(userId).collection('followers').orderBy('createdAt', descending: true).get();
      final userIds = snap.docs.map((doc) => doc.id).toList();
      if (userIds.isEmpty) return [];
      
      // Fetch user docs (max 30 for now to prevent whereIn limit issues)
      final userDocs = await _firestore.collection('users').where(FieldPath.documentId, whereIn: userIds.take(30).toList()).get();
      return userDocs.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('FirestoreService.getFollowers hata: $e');
      return [];
    }
  }

  /// Get user's following
  Future<List<UserModel>> getFollowing(String userId) async {
    try {
      final snap = await _firestore.collection('users').doc(userId).collection('following').orderBy('createdAt', descending: true).get();
      final userIds = snap.docs.map((doc) => doc.id).toList();
      if (userIds.isEmpty) return [];
      
      final userDocs = await _firestore.collection('users').where(FieldPath.documentId, whereIn: userIds.take(30).toList()).get();
      return userDocs.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('FirestoreService.getFollowing hata: $e');
      return [];
    }
  }

  // ============ SAVED POSTS ============

  /// Toggle save post
  Future<void> toggleSavePost(String postId, String userId) async {
    try {
      final saveRef = _firestore.collection('users').doc(userId).collection('savedPosts').doc(postId);
      final doc = await saveRef.get();
      
      if (doc.exists) {
        await saveRef.delete();
      } else {
        await saveRef.set({'createdAt': FieldValue.serverTimestamp()});
      }
    } catch (e) {
      debugPrint('FirestoreService.toggleSavePost hata: $e');
      rethrow;
    }
  }

  /// Is post saved stream
  Stream<bool> isSavedStream(String postId, String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('savedPosts')
        .doc(postId)
        .snapshots()
        .map((doc) => doc.exists);
  }

  /// Get saved posts
  Future<List<PostModel>> getSavedPosts(String userId) async {
    try {
      final snap = await _firestore
          .collection('users')
          .doc(userId)
          .collection('savedPosts')
          .orderBy('createdAt', descending: true)
          .get();

      if (snap.docs.isEmpty) return [];
      final postIds = snap.docs.map((d) => d.id).toList();
      
      List<PostModel> posts = [];
      for (var i = 0; i < postIds.length; i += 30) {
        final chunk = postIds.skip(i).take(30).toList();
        final postsSnap = await _firestore.collection('posts').where(FieldPath.documentId, whereIn: chunk).get();
        posts.addAll(postsSnap.docs.map((doc) => PostModel.fromFirestore(doc)));
      }
      
      // Preserve ordering from savedPosts
      posts.sort((a, b) {
        final idxA = postIds.indexOf(a.id);
        final idxB = postIds.indexOf(b.id);
        return idxA.compareTo(idxB);
      });
      
      return posts;
    } catch (e) {
      debugPrint('FirestoreService.getSavedPosts hata: $e');
      return [];
    }
  }

  // ============ STATS ============
  Future<int> getOnlineUsersCount() async {
    try {
      final query = await _firestore.collection('users').where('isOnline', isEqualTo: true).count().get();
      return query.count ?? 0;
    } catch (e) {
      debugPrint('FirestoreService.getOnlineUsersCount hata: $e');
      return 0;
    }
  }

  Stream<int> onlineUsersCountStream() async* {
    // İlk değeri hemen yolla
    yield await getOnlineUsersCount();
    // Sonra her 60 saniyede bir güncelle
    yield* Stream.periodic(const Duration(seconds: 60), (_) {}).asyncMap((_) async {
      return await getOnlineUsersCount();
    });
  }

  // ============ BLOCKING & REPORTING (UGC Requirements) ============

  Future<void> blockUser(String currentUserId, String targetUserId) async {
    try {
      await _firestore.collection('users').doc(currentUserId).collection('blockedUsers').doc(targetUserId).set({
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      // Engellendiğinde her iki yöndeki takip/arkadaşlık ilişkilerini tamamen temizle
      await unfollowUser(currentUserId, targetUserId);
    } catch (e) {
      debugPrint('FirestoreService.blockUser hata: $e');
      rethrow;
    }
  }

  Future<void> unblockUser(String currentUserId, String targetUserId) async {
    try {
      await _firestore.collection('users').doc(currentUserId).collection('blockedUsers').doc(targetUserId).delete();
    } catch (e) {
      debugPrint('FirestoreService.unblockUser hata: $e');
      rethrow;
    }
  }

  Future<bool> isBlocked(String currentUserId, String targetUserId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('blockedUsers')
          .doc(targetUserId)
          .get();
      return doc.exists;
    } catch (e) {
      debugPrint('FirestoreService.isBlocked hata: $e');
      return false;
    }
  }

  Stream<bool> isBlockedStream(String currentUserId, String targetUserId) {
    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('blockedUsers')
        .doc(targetUserId)
        .snapshots()
        .map((doc) => doc.exists);
  }
  
  Future<List<String>> getBlockedUserIds(String currentUserId) async {
    try {
      final snap = await _firestore.collection('users').doc(currentUserId).collection('blockedUsers').get();
      return snap.docs.map((doc) => doc.id).toList();
    } catch (e) {
      debugPrint('FirestoreService.getBlockedUserIds hata: $e');
      return [];
    }
  }

  Stream<List<UserModel>> blockedUsersStream(String currentUserId) {
    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('blockedUsers')
        .snapshots()
        .asyncMap((snap) async {
      final blockedIds = snap.docs.map((doc) => doc.id).toList();
      if (blockedIds.isEmpty) return [];

      final users = await Future.wait(blockedIds.map((id) => getUser(id)));
      return users.whereType<UserModel>().toList();
    });
  }

  Future<void> reportUser(String reportedUserId, String reporterId, String reason) async {
    try {
      await _firestore.collection('reports').add({
        'type': 'user',
        'reportedUserId': reportedUserId,
        'reporterId': reporterId,
        'reason': reason,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
    } catch (e) {
      debugPrint('FirestoreService.reportUser hata: $e');
      rethrow;
    }
  }

  Future<void> reportMessage(String messageId, String reporterId, String text) async {
    try {
      await _firestore.collection('reports').add({
        'type': 'message',
        'messageId': messageId,
        'reporterId': reporterId,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
    } catch (e) {
      debugPrint('FirestoreService.reportMessage hata: $e');
      rethrow;
    }
  }

  Future<void> reportPost(String postId, String reporterId, String reason) async {
    try {
      await _firestore.collection('reports').add({
        'type': 'post',
        'postId': postId,
        'reporterId': reporterId,
        'reason': reason,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
    } catch (e) {
      debugPrint('FirestoreService.reportPost hata: $e');
      rethrow;
    }
  }

  // ============ ADMIN MODERATION ============
  Stream<List<Map<String, dynamic>>> getPendingReportsStream() {
    return _firestore
        .collection('reports')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  Future<void> resolveReport(String reportId, {String action = 'resolved'}) async {
    try {
      await _firestore.collection('reports').doc(reportId).update({
        'status': action,
        'resolvedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('FirestoreService.resolveReport hata: $e');
      rethrow;
    }
  }

  Future<void> adminDeleteRoomMessage(String roomId, String messageId) async {
    try {
      await _firestore
          .collection('rooms')
          .doc(roomId)
          .collection('messages')
          .doc(messageId)
          .delete();
    } catch (e) {
      debugPrint('FirestoreService.adminDeleteRoomMessage hata: $e');
      rethrow;
    }
  }

  Future<void> adminDeleteDmMessage(String chatId, String messageId) async {
    try {
      await _firestore
          .collection('dm_chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .delete();
    } catch (e) {
      debugPrint('FirestoreService.adminDeleteDmMessage hata: $e');
      rethrow;
    }
  }

  Future<void> adminDeletePost(String postId) async {
    try {
      await _firestore.collection('posts').doc(postId).delete();
    } catch (e) {
      debugPrint('FirestoreService.adminDeletePost hata: $e');
      rethrow;
    }
  }

  Future<void> adminSetUserBanStatus(String uid, bool isBanned, {String? reason}) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'isBanned': isBanned,
        'banReason': isBanned ? (reason ?? 'Topluluk kuralları ihlali') : null,
      });
    } catch (e) {
      debugPrint('FirestoreService.adminSetUserBanStatus hata: $e');
      rethrow;
    }
  }

  Future<void> adminSetUserAdminRole(String uid, bool isAdmin) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'isAdmin': isAdmin,
      });
    } catch (e) {
      debugPrint('FirestoreService.adminSetUserAdminRole hata: $e');
      rethrow;
    }
  }

  Stream<List<UserModel>> getAdminAllUsersStream({int limit = 100}) {
    return _firestore
        .collection('users')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map((d) => UserModel.fromFirestore(d)).toList());
  }
}

