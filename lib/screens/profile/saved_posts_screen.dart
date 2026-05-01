import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:linguachat/config/theme.dart';
import 'package:linguachat/models/post_model.dart';
import 'package:linguachat/providers/auth_provider.dart';
import 'package:linguachat/services/firestore_service.dart';

class SavedPostsScreen extends StatelessWidget {
  const SavedPostsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.read<AuthProvider>().currentUserId;
    if (currentUserId == null) return const Scaffold();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        title: const Text('Kaydedilenler', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
      ),
      body: StreamBuilder<List<PostModel>>(
        stream: FirestoreService().getSavedPostsStream(currentUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Hata: ${snapshot.error}', style: const TextStyle(color: AppTheme.danger)));
          }
          
          final posts = snapshot.data ?? [];
          if (posts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bookmark_border_rounded, size: 64, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  const Text('Henüz kaydedilmiş gönderi yok.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(2),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 2,
              mainAxisSpacing: 2,
            ),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              return GestureDetector(
                onTap: () {
                  // Show bottom sheet or navigate to single post view.
                  // For now, let's just show a simple bottom sheet with the post content to view it!
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: AppTheme.surface,
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                    builder: (ctx) => SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: () {
                                Navigator.pop(ctx);
                                context.push('/user/${post.userId}');
                              },
                              child: Text(
                                post.userDisplayName, 
                                style: const TextStyle(
                                  color: AppTheme.primary, 
                                  fontWeight: FontWeight.bold, 
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(post.content, style: const TextStyle(color: AppTheme.textSecondary)),
                            const SizedBox(height: 16),
                            if (post.imageUrl != null && post.imageUrl!.isNotEmpty)
                               ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(post.imageUrl!, height: 200, width: double.infinity, fit: BoxFit.cover)),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                child: post.imageUrl != null && post.imageUrl!.isNotEmpty
                    ? Image.network(post.imageUrl!, fit: BoxFit.cover)
                    : Container(
                        color: AppTheme.surfaceLight,
                        padding: const EdgeInsets.all(8),
                        child: Center(
                          child: Text(
                            post.content,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 10),
                            textAlign: TextAlign.center,
                          ),
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
