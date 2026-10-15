import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:linguachat/config/theme.dart';
import 'package:linguachat/models/post_model.dart';
import 'package:linguachat/providers/auth_provider.dart';
import 'package:linguachat/services/firestore_service.dart';

class SavedPostsScreen extends StatefulWidget {
  const SavedPostsScreen({super.key});

  @override
  State<SavedPostsScreen> createState() => _SavedPostsScreenState();
}

class _SavedPostsScreenState extends State<SavedPostsScreen> {
  late Future<List<PostModel>> _postsFuture;

  @override
  void initState() {
    super.initState();
    final currentUserId = context.read<AuthProvider>().currentUserId;
    if (currentUserId != null) {
      _postsFuture = FirestoreService().getSavedPosts(currentUserId);
    } else {
      _postsFuture = Future.value([]);
    }
  }

  Future<void> _loadPosts() async {
    final currentUserId = context.read<AuthProvider>().currentUserId;
    if (currentUserId != null) {
      setState(() {
        _postsFuture = FirestoreService().getSavedPosts(currentUserId);
      });
      await _postsFuture;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        title: Text('Kaydedilenler', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
        iconTheme: IconThemeData(color: AppTheme.textPrimary),
      ),
      body: RefreshIndicator(
        onRefresh: _loadPosts,
        color: AppTheme.primary,
        child: FutureBuilder<List<PostModel>>(
          future: _postsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
            }
            if (snapshot.hasError) {
              return Center(child: Text('Hata: ${snapshot.error}', style: const TextStyle(color: AppTheme.danger)));
            }
            
            final posts = snapshot.data ?? [];
            if (posts.isEmpty) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.7,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bookmark_border_rounded, size: 64, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      Text('Henüz kaydedilmiş gönderi yok.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                    ],
                  ),
                ),
              );
            }

            return GridView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
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
                                child: Row(
                                  children: [
                                    Text(
                                      post.userDisplayName, 
                                      style: const TextStyle(
                                        color: AppTheme.primary, 
                                        fontWeight: FontWeight.bold, 
                                        fontSize: 16,
                                      ),
                                    ),
                                    if (post.location != null && post.location!.isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      const Icon(Icons.location_on_rounded, size: 14, color: AppTheme.primary),
                                      const SizedBox(width: 2),
                                      Expanded(
                                        child: Text(
                                          post.location!,
                                          style: const TextStyle(
                                              color: AppTheme.primary, fontSize: 13, fontWeight: FontWeight.w500),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(post.content, style: TextStyle(color: AppTheme.textSecondary)),
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
                              style: TextStyle(color: AppTheme.textPrimary, fontSize: 10),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
