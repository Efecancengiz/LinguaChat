import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:linguachat/config/theme.dart';
import 'package:linguachat/models/user_model.dart';
import 'package:linguachat/services/firestore_service.dart';
import 'package:linguachat/widgets/user_avatar.dart';

class FollowListScreen extends StatelessWidget {
  final String userId;
  final String type; // 'followers' or 'following'

  const FollowListScreen({super.key, required this.userId, required this.type});

  @override
  Widget build(BuildContext context) {
    final title = type == 'followers' ? 'Takipçiler' : 'Takip Edilenler';
    final future = type == 'followers' 
        ? FirestoreService().getFollowers(userId)
        : FirestoreService().getFollowing(userId);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        title: Text(title, style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
        iconTheme: IconThemeData(color: AppTheme.textPrimary),
      ),
      body: FutureBuilder<List<UserModel>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Hata: ${snapshot.error}', style: const TextStyle(color: AppTheme.danger)));
          }
          
          final users = snapshot.data ?? [];
          if (users.isEmpty) {
            return Center(child: Text('Burada henüz kimse yok.', style: TextStyle(color: AppTheme.textSecondary)));
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: users.length,
            separatorBuilder: (context, index) => Divider(color: AppTheme.border, height: 1),
            itemBuilder: (context, index) {
              final user = users[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: UserAvatar(photoUrl: user.photoUrl, displayName: user.displayName, radius: 24),
                title: Text(user.displayName, style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                subtitle: user.bio.isNotEmpty 
                    ? Text(user.bio, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppTheme.textSecondary)) 
                    : null,
                onTap: () => context.push('/user/${user.uid}'),
              );
            },
          );
        },
      ),
    );
  }
}
