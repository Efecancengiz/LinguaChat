import 'package:flutter/material.dart';
import 'package:linguachat/config/theme.dart';
import 'package:linguachat/models/post_model.dart';
import 'package:linguachat/services/firestore_service.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cached_network_image/cached_network_image.dart';

class UserPostsScreen extends StatelessWidget {
  final String userId;

  const UserPostsScreen({super.key, required this.userId});

  Future<void> _deletePost(BuildContext context, PostModel post) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Gönderiyi Sil', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
        content: const Text(
          'Bu gönderiyi kalıcı olarak silmek istediğine emin misin?',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil', style: TextStyle(color: AppTheme.danger, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      try {
        await FirestoreService().deletePost(post.id, userId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gönderi silindi.'),
              backgroundColor: AppTheme.primary,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Silinemedi, tekrar dene.')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    timeago.setLocaleMessages('tr', timeago.TrMessages());
    final firestoreService = FirestoreService();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        title: StreamBuilder(
          stream: firestoreService.userStream(userId),
          builder: (context, snapshot) {
            final name = snapshot.data?.displayName ?? 'Gönderiler';
            return Text(
              '$name\'ın Gönderileri',
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.w600),
            );
          },
        ),
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
      ),
      body: StreamBuilder<List<PostModel>>(
        stream: firestoreService.getUserPostsStream(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Hata: ${snapshot.error}', style: const TextStyle(color: AppTheme.danger)),
            );
          }

          final posts = snapshot.data ?? [];
          if (posts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.dynamic_feed_rounded, size: 64, color: AppTheme.textSecondary.withValues(alpha: 0.4)),
                  const SizedBox(height: 16),
                  const Text('Henüz gönderi yok.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: posts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final post = posts[index];
              final timeStr = timeago.format(post.createdAt, locale: 'tr');

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: AppTheme.glassDecoration.copyWith(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: zaman + sil menüsü
                    Row(
                      children: [
                        Text(timeStr, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                        const Spacer(),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textSecondary, size: 20),
                          color: AppTheme.surfaceLight,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: AppTheme.border, width: 0.5),
                          ),
                          onSelected: (value) {
                            if (value == 'delete') _deletePost(context, post);
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline_rounded, color: AppTheme.danger, size: 20),
                                  SizedBox(width: 8),
                                  Text('Sil', style: TextStyle(color: AppTheme.danger)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // İçerik
                    Text(
                      post.content,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, height: 1.4),
                    ),
                    // Görsel
                    if (post.imageUrl != null && post.imageUrl!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: post.imageUrl!,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            height: 180,
                            color: AppTheme.surfaceLight,
                            child: const Center(
                              child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            height: 120,
                            color: AppTheme.surfaceLight,
                            child: const Center(
                              child: Icon(Icons.broken_image_rounded, color: AppTheme.textSecondary),
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    // İstatistikler
                    Row(
                      children: [
                        Icon(Icons.favorite_rounded, size: 14, color: Colors.redAccent.withValues(alpha: 0.8)),
                        const SizedBox(width: 4),
                        Text('${post.likesCount}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                        const SizedBox(width: 16),
                        Icon(Icons.chat_bubble_rounded, size: 14, color: AppTheme.primary.withValues(alpha: 0.8)),
                        const SizedBox(width: 4),
                        Text('${post.commentsCount}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
