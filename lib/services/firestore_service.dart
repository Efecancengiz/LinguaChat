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

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('users').doc(uid).update(data);
    } catch (e) {
      debugPrint('FirestoreService.updateUser hata: $e');
      rethrow;
    }
  }

  Future<void> updateUserDisplayName(String uid, String oldName, String newName) async {
    if (oldName == newName) return;
    
    final newUsernameRef = _firestore.collection('usernames').doc(newName);
    final oldUsernameRef = _firestore.collection('usernames').doc(oldName);
    
    try {
      await _firestore.runTransaction((txn) async {
        final snap = await txn.get(newUsernameRef);
        if (snap.exists) {
          throw Exception('username-taken');
        }
        
        // Yeni kullanıcı adını al ve eskisini sil
        txn.set(newUsernameRef, {'uid': uid});
        txn.delete(oldUsernameRef);
        
        // Kullanıcı belgesini güncelle
        txn.update(_firestore.collection('users').doc(uid), {'displayName': newName});
      });
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
            final rooms = snapshot.docs.map((doc) => RoomModel.fromFirestore(doc)).toList();
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
      final docs = snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
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

      await _firestore.collection('directMessages').doc(chatId).update({
        'lastMessage': {
          'text': message.text,
          'senderId': message.senderId,
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      });
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
      final messagesSnapshot = await _firestore
          .collection('directMessages')
          .doc(chatId)
          .collection('messages')
          .where('senderId', isNotEqualTo: currentUserId)
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

  Future<int> syncVoiceUsage({bool increment = false}) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('syncVoiceUsage');
      final result = await callable.call(<String, dynamic>{'increment': increment});
      final data = Map<String, dynamic>.from(result.data as Map);
      return (data['dailyVoiceMinutes'] as num?)?.toInt() ?? 0;
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

  /// Kullanıcıyı takip et
  Future<void> followUser(String currentUserId, String targetUserId) async {
    try {
      final batch = _firestore.batch();
      
      // 1. Alt koleksiyonlara ekle
      final followingRef = _firestore.collection('users').doc(currentUserId).collection('following').doc(targetUserId);
      final followerRef = _firestore.collection('users').doc(targetUserId).collection('followers').doc(currentUserId);
      
      batch.set(followingRef, {'createdAt': FieldValue.serverTimestamp()});
      batch.set(followerRef, {'createdAt': FieldValue.serverTimestamp()});
      
      // 2. Sayaçları güncelle
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
      
      // 1. Alt koleksiyonlardan sil
      final followingRef = _firestore.collection('users').doc(currentUserId).collection('following').doc(targetUserId);
      final followerRef = _firestore.collection('users').doc(targetUserId).collection('followers').doc(currentUserId);
      
      batch.delete(followingRef);
      batch.delete(followerRef);
      
      // 1.5. Karşı tarafın listelerinden de sil (Arkadaşlık modeli = Karşılıklı takip)
      final theirFollowingRef = _firestore.collection('users').doc(targetUserId).collection('following').doc(currentUserId);
      final theirFollowerRef = _firestore.collection('users').doc(currentUserId).collection('followers').doc(targetUserId);
      
      batch.delete(theirFollowingRef);
      batch.delete(theirFollowerRef);

      // 1.6. Arkadaşlık listelerinden sil
      final friendRef1 = _firestore.collection('friends').doc(currentUserId).collection('userFriends').doc(targetUserId);
      final friendRef2 = _firestore.collection('friends').doc(targetUserId).collection('userFriends').doc(currentUserId);
      batch.delete(friendRef1);
      batch.delete(friendRef2);
      
      // 2. Sayaçları azalt (hem kendisi hem karşı taraf için)
      final currentUserRef = _firestore.collection('users').doc(currentUserId);
      final targetUserRef = _firestore.collection('users').doc(targetUserId);
      
      batch.set(currentUserRef, {
         'followingCount': FieldValue.increment(-1),
         'followersCount': FieldValue.increment(-1)
      }, SetOptions(merge: true));
      
      batch.set(targetUserRef, {
         'followersCount': FieldValue.increment(-1),
         'followingCount': FieldValue.increment(-1)
      }, SetOptions(merge: true));
      
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
    } catch (e) {
      debugPrint('FirestoreService.createPost hata: $e');
      rethrow;
    }
  }

  /// Tüm kullanıcıların gönderilerini getir (Keşfet / Herkes)
  /// audience=='everyone' olanları client-side filtreler;
  /// bu sayede Firestore composite index gerektirmez ve
  /// eski geri dönüşsüz gönderiler de (audience alanı olmayan) herkese görünür.
  Stream<List<PostModel>> getFeedPostsStream(String currentUserId) {
    return _firestore
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => PostModel.fromFirestore(doc))
              .where((post) => post.audience == 'everyone')
              .toList();
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
    final ids = [currentUserId, ...friendIds];
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
    final friendsSnap = await _firestore
        .collection('friends')
        .doc(currentUserId)
        .collection('userFriends')
        .get();
    final friendIds = friendsSnap.docs.map((d) => d.id).toList();
    // Kendi UID'ini her zaman dahil et
    final allowedIds = {currentUserId, ...friendIds};

    yield* _firestore
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) =>
            snap.docs
                .map((doc) => PostModel.fromFirestore(doc))
                .where((post) => allowedIds.contains(post.userId))
                .toList());
  }

  /// Belirli bir kullanıcının gönderilerini getir
  Stream<List<PostModel>> getUserPostsStream(String userId) {
    return _firestore
        .collection('posts')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PostModel.fromFirestore(doc))
            .toList());
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
    } catch (e) {
      debugPrint('FirestoreService.deletePost hata: $e');
      rethrow;
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
}
