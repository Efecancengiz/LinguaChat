// lib/screens/friends/friend_requests_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:linguachat/config/theme.dart';
import 'package:linguachat/providers/auth_provider.dart';
import 'package:linguachat/services/firestore_service.dart';
import 'package:linguachat/models/friend_request_model.dart';
import 'package:linguachat/widgets/user_avatar.dart';

class FriendRequestsScreen extends StatelessWidget {
  const FriendRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.read<AuthProvider>().currentUserId;
    final currentUser = context.read<AuthProvider>().user;
    final firestoreService = FirestoreService();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
          title: const Text('Arkadaşlık İstekleri'),
          bottom: TabBar(
            indicatorColor: AppTheme.primary,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textSecondary,
            dividerColor: AppTheme.border,
            tabs: const [
              Tab(text: 'Gelen'),
              Tab(text: 'Gönderilen'),
            ],
          ),
        ),
        body: currentUserId == null
            ? const SizedBox.shrink()
            : Container(
                decoration: const BoxDecoration(
                  gradient: AppTheme.surfaceGradient,
                ),
                child: TabBarView(
                  children: [
                    // Incoming requests
                  StreamBuilder<List<FriendRequestModel>>(
                    stream: firestoreService
                        .pendingRequestsStream(currentUserId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                              color: AppTheme.primary),
                        );
                      }

                      final requests = snapshot.data ?? [];

                      if (requests.isEmpty) {
                        return const Center(
                          child: Column(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              Icon(Icons.mail_outline_rounded,
                                  size: 48,
                                  color: AppTheme.textSecondary),
                              SizedBox(height: 16),
                              Text(
                                'Gelen istek yok',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: requests.length,
                        itemBuilder: (context, index) {
                          final request = requests[index];
                          return Container(
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: AppTheme.glassDecoration,
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: () => context.push(
                                      '/user/${request.fromUserId}'),
                                  child: UserAvatar(
                                    photoUrl: request.fromUserPhoto,
                                    displayName:
                                        request.fromUserName,
                                    radius: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        request.fromUserName,
                                        style: const TextStyle(
                                          color: AppTheme
                                              .textPrimary,
                                          fontWeight:
                                              FontWeight.w600,
                                        ),
                                      ),
                                      const Text(
                                        'Arkadaşlık isteği gönderdi',
                                        style: TextStyle(
                                          color: AppTheme
                                              .textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Accept
                                IconButton(
                                  icon: Container(
                                    padding:
                                        const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: AppTheme.accent
                                          .withValues(alpha: 0.1),
                                      borderRadius:
                                          BorderRadius.circular(
                                              10),
                                    ),
                                    child: const Icon(
                                      Icons.check_rounded,
                                      color: AppTheme.accent,
                                      size: 20,
                                    ),
                                  ),
                                  onPressed: () {
                                    firestoreService
                                        .acceptFriendRequest(
                                      request.id,
                                      request.toUserId,
                                      request.fromUserId,
                                      currentUser?.displayName ?? '',
                                      request.fromUserName,
                                      currentUser?.photoUrl ?? '',
                                      request.fromUserPhoto,
                                    );
                                  },
                                ),
                                // Reject
                                IconButton(
                                  icon: Container(
                                    padding:
                                        const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: AppTheme.danger
                                          .withValues(alpha: 0.1),
                                      borderRadius:
                                          BorderRadius.circular(
                                              10),
                                    ),
                                    child: const Icon(
                                      Icons.close_rounded,
                                      color: AppTheme.danger,
                                      size: 20,
                                    ),
                                  ),
                                  onPressed: () {
                                    firestoreService
                                        .rejectFriendRequest(
                                            request.id);
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                  // Sent requests
                  StreamBuilder<List<FriendRequestModel>>(
                    stream:
                        firestoreService.sentRequestsStream(currentUserId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                              color: AppTheme.primary),
                        );
                      }

                      final requests = snapshot.data ?? [];

                      if (requests.isEmpty) {
                        return const Center(
                          child: Column(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              Icon(Icons.send_rounded,
                                  size: 48,
                                  color: AppTheme.textSecondary),
                              SizedBox(height: 16),
                              Text(
                                'Gönderilen istek yok',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: requests.length,
                        itemBuilder: (context, index) {
                          final request = requests[index];
                          return Container(
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: AppTheme.glassDecoration,
                            child: Row(
                              children: [
                                UserAvatar(
                                  photoUrl: request.toUserPhoto,
                                  displayName: request.toUserName,
                                  radius: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        request.toUserName.isNotEmpty
                                            ? request.toUserName
                                            : 'Kullanıcı',
                                        style: const TextStyle(
                                          color: AppTheme
                                              .textPrimary,
                                          fontWeight:
                                              FontWeight.w600,
                                        ),
                                      ),
                                      const Text(
                                        'Beklemede...',
                                        style: TextStyle(
                                          color: AppTheme.warning,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.hourglass_top_rounded,
                                  color: AppTheme.warning,
                                  size: 20,
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
      ),
    );
  }
}
