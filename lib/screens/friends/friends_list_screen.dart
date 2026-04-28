// lib/screens/friends/friends_list_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:linguachat/config/theme.dart';
import 'package:linguachat/providers/auth_provider.dart';
import 'package:linguachat/services/firestore_service.dart';
import 'package:linguachat/models/user_model.dart';
import 'package:linguachat/widgets/user_avatar.dart';

class FriendsListScreen extends StatelessWidget {
  const FriendsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.read<AuthProvider>().currentUserId;
    final firestoreService = FirestoreService();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Arkadaşlarım'),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  const Icon(Icons.person_add_outlined, size: 20),
            ),
            onPressed: () => context.push('/friend-requests'),
          ),
        ],
      ),
      body: currentUserId == null
          ? const SizedBox.shrink()
          : Container(
              decoration: const BoxDecoration(
                gradient: AppTheme.surfaceGradient,
              ),
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: firestoreService.friendsStream(currentUserId),
                builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                        color: AppTheme.primary),
                  );
                }

                final friends = snapshot.data ?? [];

                if (friends.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppTheme.primary
                                .withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.people_outline_rounded,
                            size: 48,
                            color: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Henüz arkadaşın yok',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Dil odalarında yeni insanlarla tanış!',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 120, 16, 120),
                  itemCount: friends.length,
                  itemBuilder: (context, index) {
                    final friend = friends[index];
                    return _FriendListTile(
                      friendId: friend['friendId'] as String,
                      fallbackName: friend['friendName'] as String? ?? '',
                      fallbackPhoto: friend['friendPhotoUrl'] as String? ?? '',
                      firestoreService: firestoreService,
                      currentUserId: currentUserId,
                    );
                  },
                );
              },
            ),
          ),
    );
  }
}

/// Her arkadaşın gerçek zamanlı online durumunu ve son görülmesini gösteren tile
class _FriendListTile extends StatelessWidget {
  final String friendId;
  final String fallbackName;
  final String fallbackPhoto;
  final FirestoreService firestoreService;
  final String currentUserId;

  const _FriendListTile({
    required this.friendId,
    required this.fallbackName,
    required this.fallbackPhoto,
    required this.firestoreService,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserModel?>(
      stream: firestoreService.userStream(friendId),
      builder: (context, snapshot) {
        final user = snapshot.data;
        final displayName = user?.displayName ?? fallbackName;
        final photoUrl = user?.photoUrl ?? fallbackPhoto;
        final isOnline = user?.isOnline ?? false;
        final lastSeen = user?.lastSeen;

        String statusText;
        Color statusColor;
        if (isOnline) {
          statusText = 'Çevrimiçi';
          statusColor = AppTheme.accent;
        } else if (lastSeen != null) {
          final now = DateTime.now();
          final diff = now.difference(lastSeen);
          if (diff.inMinutes < 60) {
            statusText = 'Son görülme: ${diff.inMinutes} dk önce';
          } else if (diff.inHours < 24) {
            statusText = 'Son görülme: ${DateFormat('HH:mm').format(lastSeen)}';
          } else {
            statusText = 'Son görülme: ${DateFormat('d MMM', 'tr').format(lastSeen)}';
          }
          statusColor = AppTheme.textSecondary;
        } else {
          statusText = 'Çevrimdışı';
          statusColor = AppTheme.textSecondary;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: AppTheme.glassDecoration,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => context.push('/user/$friendId'),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        UserAvatar(
                          photoUrl: photoUrl,
                          displayName: displayName,
                          radius: 24,
                        ),
                        if (isOnline)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: AppTheme.accent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppTheme.surface,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            statusText,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: AppTheme.primary,
                        size: 20,
                      ),
                      onPressed: () {
                        final chatId = firestoreService
                            .getDmChatId(currentUserId, friendId);
                        firestoreService.createDmChat(
                            currentUserId, friendId);
                        context.push('/dm/$chatId',
                            extra: {
                              'userId': friendId,
                            });
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

