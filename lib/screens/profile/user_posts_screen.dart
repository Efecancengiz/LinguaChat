import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:linguachat/config/theme.dart';
import 'package:linguachat/models/post_model.dart';
import 'package:linguachat/services/firestore_service.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:linguachat/widgets/liked_users_sheet.dart';

class UserPostsScreen extends StatelessWidget {
  final String userId;

  const UserPostsScreen({super.key, required this.userId});

  Future<void> _deletePost(BuildContext context, PostModel post) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Gönderiyi Sil', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
        content: Text(
          'Bu gönderiyi kalıcı olarak silmek istediğine emin misin?',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('İptal', style: TextStyle(color: AppTheme.textSecondary)),
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

  Future<void> _editPost(BuildContext context, PostModel post) async {
    final controller = TextEditingController(text: post.content);
    await showDialog(
      context: context,
      builder: (dialogCtx) {
        bool isLoading = false;
        return StatefulBuilder(
          builder: (stateCtx, setState) {
            return AlertDialog(
              backgroundColor: AppTheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('Gönderiyi Düzenle', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: double.maxFinite,
                child: TextField(
                  controller: controller,
                  style: TextStyle(color: AppTheme.textPrimary),
                  maxLines: 6,
                  minLines: 1,
                  decoration: InputDecoration(
                    hintText: 'Gönderi içeriği...',
                    hintStyle: TextStyle(color: AppTheme.textSecondary),
                    filled: true,
                    fillColor: AppTheme.surfaceLight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(dialogCtx),
                  child: Text('İptal', style: TextStyle(color: AppTheme.textSecondary)),
                ),
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          final text = controller.text.trim();
                          if (text.isEmpty) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Gönderi içeriği boş olamaz.')),
                              );
                            }
                            return;
                          }
                          setState(() => isLoading = true);
                          try {
                            await FirestoreService().updatePostContent(post.id, text);
                            if (dialogCtx.mounted) {
                              Navigator.pop(dialogCtx);
                            }
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Gönderi güncellendi.'), backgroundColor: AppTheme.primary),
                              );
                            }
                          } catch (e) {
                            setState(() => isLoading = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Güncellenirken bir hata oluştu.')),
                              );
                            }
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: AppTheme.primary,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Kaydet', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    timeago.setLocaleMessages('tr', timeago.TrMessages());
    final firestoreService = FirestoreService();
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

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
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.w600),
            );
          },
        ),
        iconTheme: IconThemeData(color: AppTheme.textPrimary),
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
                  Text('Henüz gönderi yok.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: posts.length,
            separatorBuilder: (_, i) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final post = posts[index];
              final timeStr = timeago.format(post.createdAt, locale: 'tr');

              final isDark = Theme.of(context).brightness == Brightness.dark;

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF121212) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? const Color(0xFF262626) : const Color(0xFFE2E8F0),
                    width: 0.8,
                  ),
                  boxShadow: isDark
                      ? null
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: zaman + sil menüsü
                    Row(
                      children: [
                        Text(timeStr, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                        if (post.location != null && post.location!.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.location_on_rounded, size: 12, color: AppTheme.primary),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              post.location!,
                              style: const TextStyle(
                                  color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        const Spacer(),
                        if (post.userId == currentUserId)
                          PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert_rounded, color: AppTheme.textSecondary, size: 20),
                            color: AppTheme.surfaceLight,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: AppTheme.border, width: 0.5),
                            ),
                            onSelected: (value) {
                              if (value == 'delete') {
                                _deletePost(context, post);
                              } else if (value == 'edit') {
                                _editPost(context, post);
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit_outlined, color: AppTheme.textPrimary, size: 20),
                                    SizedBox(width: 8),
                                    Text('Düzenle', style: TextStyle(color: AppTheme.textPrimary)),
                                  ],
                                ),
                              ),
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
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, height: 1.4),
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
                            child: Center(
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
                        GestureDetector(
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              backgroundColor: Colors.transparent,
                              builder: (_) => LikedUsersSheet(postId: post.id),
                            );
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Row(
                            children: [
                              Icon(Icons.favorite_rounded, size: 14, color: Colors.redAccent.withValues(alpha: 0.8)),
                              const SizedBox(width: 4),
                              Text('${post.likesCount}', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(Icons.chat_bubble_rounded, size: 14, color: AppTheme.primary.withValues(alpha: 0.8)),
                        const SizedBox(width: 4),
                        Text('${post.commentsCount}', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
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
