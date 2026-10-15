// lib/screens/profile/blocked_users_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:linguachat/config/theme.dart';
import 'package:linguachat/providers/auth_provider.dart';
import 'package:linguachat/services/firestore_service.dart';
import 'package:linguachat/models/user_model.dart';
import 'package:linguachat/widgets/user_avatar.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.watch<AuthProvider>().currentUserId;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Engellenen Kişiler'),
      ),
      body: currentUserId == null
          ? const SizedBox.shrink()
          : StreamBuilder<List<UserModel>>(
              stream: _firestoreService.blockedUsersStream(currentUserId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  );
                }

                final users = snapshot.data ?? [];

                if (users.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.block_rounded,
                            size: 48,
                            color: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Engellenen kullanıcı yok',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: AppTheme.glassDecoration,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            UserAvatar(
                              photoUrl: user.photoUrl,
                              displayName: user.displayName,
                              radius: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                user.displayName,
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                final scaffoldMessenger = ScaffoldMessenger.of(context);
                                try {
                                  await _firestoreService.unblockUser(currentUserId, user.uid);
                                  scaffoldMessenger.showSnackBar(
                                    SnackBar(
                                      content: Text('${user.displayName} engeli kaldırıldı.'),
                                      backgroundColor: AppTheme.accent,
                                    ),
                                  );
                                } catch (e) {
                                  scaffoldMessenger.showSnackBar(
                                    SnackBar(
                                      content: Text('Hata: $e'),
                                      backgroundColor: AppTheme.danger,
                                    ),
                                  );
                                }
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.primary,
                              ),
                              child: const Text('Engeli Kaldır', style: TextStyle(fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
