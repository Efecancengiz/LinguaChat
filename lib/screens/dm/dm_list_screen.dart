// lib/screens/dm/dm_list_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:linguachat/config/theme.dart';
import 'package:linguachat/providers/auth_provider.dart';
import 'package:linguachat/services/firestore_service.dart';
import 'package:linguachat/models/user_model.dart';
import 'package:linguachat/widgets/user_avatar.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cloud_firestore/cloud_firestore.dart';

class DmListScreen extends StatefulWidget {
  const DmListScreen({super.key});

  @override
  State<DmListScreen> createState() => _DmListScreenState();
}

class _DmListScreenState extends State<DmListScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  /// Kullanıcı verilerini önbelleğe al
  /// N+1 query sorununu önler
  final Map<String, UserModel?> _userCache = {};

  Future<UserModel?> _getCachedUser(String userId) async {
    if (_userCache.containsKey(userId)) {
      return _userCache[userId];
    }
    final user = await _firestoreService.getUser(userId);
    _userCache[userId] = user;
    return user;
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.read<AuthProvider>().currentUserId;

    return currentUserId == null
        ? const SizedBox.shrink()
        : StreamBuilder<List<Map<String, dynamic>>>(
            stream: _firestoreService.dmListStream(currentUserId),
            builder: (context, snapshot) {
              if (snapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                      color: AppTheme.primary),
                );
              }

              final chats = snapshot.data ?? [];

              if (chats.isEmpty) {
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
                          Icons.chat_bubble_outline_rounded,
                          size: 48,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Henüz mesajın yok',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Arkadaşlarınla sohbet etmeye başla!',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        onPressed: () => context.push('/friends'),
                        icon: const Icon(Icons.people_outline),
                        label: const Text('Arkadaşlar'),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 120, 16, 120),
                itemCount: chats.length,
                itemBuilder: (context, index) {
                  final chat = chats[index];
                  final participants =
                      (chat['participants'] as List<dynamic>?) ?? [];
                  final otherUserId = participants.firstWhere(
                    (id) => id != currentUserId,
                    orElse: () => '',
                  );
                  final lastMessage =
                      chat['lastMessage'] as Map<String, dynamic>?;
                  final updatedAt =
                      (chat['updatedAt'] as Timestamp?)?.toDate();
                  
                  final isUnread = lastMessage != null && 
                                   lastMessage['isRead'] == false && 
                                   lastMessage['senderId'] != currentUserId;

                  return FutureBuilder<UserModel?>(
                    future: _getCachedUser(otherUserId),
                    builder: (context, userSnapshot) {
                      final otherUser = userSnapshot.data;
                      final displayName =
                          otherUser?.displayName ?? 'Kullanıcı';
                      final photoUrl = otherUser?.photoUrl ?? '';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: AppTheme.glassDecoration,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => context.push(
                              '/dm/${chat['id']}',
                              extra: {'userId': otherUserId},
                            ),
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              UserAvatar(
                                photoUrl: photoUrl,
                                displayName: displayName,
                                radius: 26,
                                showOnlineIndicator: true,
                                isOnline:
                                    otherUser?.isOnline ?? false,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      displayName,
                                      style: TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontWeight: isUnread ? FontWeight.w900 : FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    if (lastMessage != null)
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              lastMessage['text'] ?? '',
                                              style: TextStyle(
                                                color: isUnread ? AppTheme.textPrimary : AppTheme.textSecondary,
                                                fontSize: 13,
                                                fontWeight: isUnread ? FontWeight.w800 : FontWeight.normal,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (isUnread) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              width: 10,
                                              height: 10,
                                              decoration: const BoxDecoration(
                                                color: AppTheme.primary,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ]
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (updatedAt != null)
                                    Text(
                                      timeago.format(updatedAt, locale: 'tr'),
                                      style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: PopupMenuButton<String>(
                                      padding: EdgeInsets.zero,
                                      icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textSecondary, size: 18),
                                      color: AppTheme.surfaceLight,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: const BorderSide(color: AppTheme.border, width: 0.5),
                                      ),
                                      onSelected: (value) async {
                                        if (value == 'delete') {
                                          showDialog(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              backgroundColor: AppTheme.surfaceLight,
                                              title: const Text('Sohbeti Sil', style: TextStyle(color: AppTheme.textPrimary)),
                                              content: const Text('Bu sohbeti tamamen silmek istediğinize emin misiniz?', style: TextStyle(color: AppTheme.textSecondary)),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(ctx),
                                                  child: const Text('İptal', style: TextStyle(color: AppTheme.textSecondary)),
                                                ),
                                                TextButton(
                                                  onPressed: () async {
                                                    Navigator.pop(ctx);
                                                    try {
                                                      await _firestoreService.deleteDmChat(chat['id']);
                                                    } catch (_) {}
                                                  },
                                                  child: const Text('Sil', style: TextStyle(color: AppTheme.danger)),
                                                ),
                                              ],
                                            ),
                                          );
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(
                                          value: 'delete',
                                          height: 36,
                                          child: Row(
                                            children: [
                                              Icon(Icons.delete_outline, color: AppTheme.danger, size: 18),
                                              SizedBox(width: 8),
                                              Text('Sohbeti Sil', style: TextStyle(color: AppTheme.danger, fontSize: 13)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                    },
                  );
                },
              );
            },
          );
  }
}
