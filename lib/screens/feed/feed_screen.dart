import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:linguachat/config/theme.dart';
import 'package:linguachat/providers/auth_provider.dart';
import 'package:linguachat/services/firestore_service.dart';
import 'package:linguachat/models/post_model.dart';
import 'package:linguachat/widgets/user_avatar.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:linguachat/widgets/liked_users_sheet.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final FirestoreService _firestoreService = FirestoreService();
  Stream<List<PostModel>>? _feedPostsStream;
  Stream<List<PostModel>>? _friendsFeedStream;
  String? _lastUserId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = context.watch<AuthProvider>().user;
    final currentUserId = user?.uid;
    
    if (currentUserId != null && currentUserId != _lastUserId) {
      _lastUserId = currentUserId;
      _feedPostsStream = _firestoreService.getFeedPostsStream(currentUserId);
      _friendsFeedStream = _firestoreService.getFriendsFeedStream2(currentUserId);
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.surfaceGradient,
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 16, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Akış',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: IconButton(
                        onPressed: () => context.push('/create-post'),
                        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                        tooltip: 'Yeni Gönderi',
                      ),
                    ),
                  ],
                ),
              ),
              // ── Tabs ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.border.withValues(alpha: 0.4)),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    labelColor: Colors.white,
                    unselectedLabelColor: AppTheme.textSecondary,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                    indicator: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(text: '🌍  Herkes'),
                      Tab(text: '👥  Arkadaşlar'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // ── Tab Views ──────────────────────────────────────
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    if (_feedPostsStream != null)
                      _PostsList(
                        stream: _feedPostsStream!,
                        currentUserId: user.uid,
                        currentUserDisplayName: user.displayName,
                        currentUserPhotoUrl: user.photoUrl,
                        firestoreService: _firestoreService,
                        emptyMessage: 'Henüz gönderi yok.',
                      )
                    else
                      const Center(child: CircularProgressIndicator()),
                    
                    if (_friendsFeedStream != null)
                      _PostsList(
                        stream: _friendsFeedStream!,
                        currentUserId: user.uid,
                        currentUserDisplayName: user.displayName,
                        currentUserPhotoUrl: user.photoUrl,
                        firestoreService: _firestoreService,
                        emptyMessage: 'Arkadaşların henüz paylaşım yapmadı.',
                        showAddFriendsButton: true,
                      )
                    else
                      const Center(child: CircularProgressIndicator()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// POSTS LIST (generic, works with Stream)
// ─────────────────────────────────────────────────────────────
class _PostsList extends StatefulWidget {
  final Stream<List<PostModel>> stream;
  final String currentUserId;
  final String currentUserDisplayName;
  final String currentUserPhotoUrl;
  final FirestoreService firestoreService;
  final String emptyMessage;
  final bool showAddFriendsButton;

  const _PostsList({
    required this.stream,
    required this.currentUserId,
    required this.currentUserDisplayName,
    required this.currentUserPhotoUrl,
    required this.firestoreService,
    required this.emptyMessage,
    this.showAddFriendsButton = false,
  });

  @override
  State<_PostsList> createState() => _PostsListState();
}

class _PostsListState extends State<_PostsList> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return StreamBuilder<List<PostModel>>(
      stream: widget.stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline_rounded, size: 48,
                      color: AppTheme.danger.withValues(alpha: 0.7)),
                  const SizedBox(height: 12),
                  Text('Bir hata oluştu:\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                ],
              ),
            ),
          );
        }
        final posts = snapshot.data ?? [];
        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.showAddFriendsButton
                      ? Icons.people_outline_rounded
                      : Icons.dynamic_feed_rounded,
                  size: 64,
                  color: AppTheme.textSecondary.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 16),
                Text(widget.emptyMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                if (widget.showAddFriendsButton) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => context.push('/friends'),
                    child: const Text('Arkadaş Ekle'),
                  ),
                ],
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 110),
          itemCount: posts.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final post = posts[index];
            return _PostCard(
              post: post,
              currentUserId: widget.currentUserId,
              currentUserDisplayName: widget.currentUserDisplayName,
              currentUserPhotoUrl: widget.currentUserPhotoUrl,
              firestoreService: widget.firestoreService,
            );
          },
        );
      },
    );
  }
}

// Removed _FriendsFeed as it's directly rendered in the tab view now



// ─────────────────────────────────────────────────────────────
// POST CARD
// ─────────────────────────────────────────────────────────────
class _PostCard extends StatelessWidget {
  final PostModel post;
  final String currentUserId;
  final String currentUserDisplayName;
  final String currentUserPhotoUrl;
  final FirestoreService firestoreService;

  const _PostCard({
    required this.post,
    required this.currentUserId,
    required this.currentUserDisplayName,
    required this.currentUserPhotoUrl,
    required this.firestoreService,
  });

  void _showReportDialog(BuildContext context) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('Gönderiyi Şikayet Et', style: TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: reasonController,
          decoration: InputDecoration(
            hintText: 'Şikayet nedeni...',
            hintStyle: TextStyle(color: AppTheme.textSecondary),
          ),
          style: TextStyle(color: AppTheme.textPrimary),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('İptal', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) return;
              await firestoreService.reportPost(post.id, currentUserId, reasonController.text.trim());
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Şikayetiniz alındı ve incelenecektir.')),
                );
              }
            },
            child: const Text('Gönder', style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
  }

  void _showBlockDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('Kullanıcıyı Engelle', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text('Bu kullanıcıyı engellemek istediğinize emin misiniz? Artık ondan mesaj almayacak ve içeriklerini görmeyeceksiniz.', style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('İptal', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              await firestoreService.blockUser(currentUserId, post.userId);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Kullanıcı engellendi.')),
                );
              }
            },
            child: const Text('Engelle', style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    final controller = TextEditingController(text: post.content);
    showDialog(
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
                            await firestoreService.updatePostContent(post.id, text);
                            if (dialogCtx.mounted) {
                              Navigator.pop(dialogCtx);
                            }
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Gönderi güncellendi.')),
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

  void _showComments(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommentsSheet(
        post: post,
        currentUserId: currentUserId,
        currentUserDisplayName: currentUserDisplayName,
        currentUserPhotoUrl: currentUserPhotoUrl,
        firestoreService: firestoreService,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    timeago.setLocaleMessages('tr', timeago.TrMessages());
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
          // ── Header ──────────────────────────────────────────
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  context.push('/user/${post.userId}');
                },
                child: UserAvatar(
                  photoUrl: post.userPhotoUrl,
                  displayName: post.userDisplayName,
                  radius: 20,
                  isOnline: false,
                  showOnlineIndicator: false,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.userDisplayName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          timeStr,
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 12),
                        ),
                        if (post.location != null && post.location!.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.location_on_rounded, size: 12, color: AppTheme.primary),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              post.location!,
                              style: const TextStyle(
                                  color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded,
                      color: AppTheme.textSecondary, size: 20),
                  color: AppTheme.surfaceLight,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: AppTheme.border, width: 0.5),
                  ),
                  onSelected: (value) async {
                    if (value == 'admin_delete') {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: AppTheme.surface,
                          title: Text('Yönetici Olarak Sil', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
                          content: Text('Bu gönderiyi yönetici yetkisiyle kalıcı olarak kaldırmak istediğinizden emin misiniz?', style: TextStyle(color: AppTheme.textSecondary)),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text('İptal', style: TextStyle(color: AppTheme.textSecondary)),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Kaldır', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        try {
                          await firestoreService.adminDeletePost(post.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Gönderi yönetici tarafından kaldırıldı! ✅')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Silinirken hata oluştu: $e')),
                            );
                          }
                        }
                      }
                    } else if (value == 'delete') {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: AppTheme.surface,
                          title: Text('Gönderiyi Sil', style: TextStyle(color: AppTheme.textPrimary)),
                          content: Text('Bu gönderiyi kalıcı olarak silmek istediğine emin misin?', style: TextStyle(color: AppTheme.textSecondary)),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('İptal'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Sil', style: TextStyle(color: AppTheme.danger)),
                            ),
                          ],
                        ),
                      );
                      
                      if (confirm == true) {
                        try {
                          await firestoreService.deletePost(post.id, currentUserId);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Gönderi silindi.')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Silinirken bir hata oluştu.')),
                            );
                          }
                        }
                      }
                    } else if (value == 'edit') {
                      _showEditDialog(context);
                    } else if (value == 'report') {
                      _showReportDialog(context);
                    } else if (value == 'block') {
                      _showBlockDialog(context);
                    }
                  },
                  itemBuilder: (context) {
                    final currentUser = context.read<AuthProvider>().user;
                    final isAdmin = currentUser?.isAdmin == true;

                    return [
                      if (post.userId == currentUserId) ...[
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
                              Icon(Icons.delete_outline, color: AppTheme.danger, size: 20),
                              SizedBox(width: 8),
                              Text('Sil', style: TextStyle(color: AppTheme.danger)),
                            ],
                          ),
                        ),
                      ],
                      if (post.userId != currentUserId) ...[
                        if (isAdmin) ...[
                          const PopupMenuItem(
                            value: 'admin_delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_forever_rounded, color: AppTheme.danger, size: 20),
                                SizedBox(width: 8),
                                Text('Yönetici Olarak Sil 🗑️', style: TextStyle(color: AppTheme.danger, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                        const PopupMenuItem(
                          value: 'report',
                          child: Row(
                            children: [
                              Icon(Icons.flag_rounded, color: AppTheme.warning, size: 20),
                              SizedBox(width: 8),
                              Text('Gönderiyi Şikayet Et', style: TextStyle(color: AppTheme.warning)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'block',
                          child: Row(
                            children: [
                              Icon(Icons.block_rounded, color: AppTheme.danger, size: 20),
                              SizedBox(width: 8),
                              Text('Kullanıcıyı Engelle', style: TextStyle(color: AppTheme.danger)),
                            ],
                          ),
                        ),
                      ],
                    ];
                  },
                ),
            ],
          ),

          // Audience badge – sadece 'friends' gönderilerinde göster
          if (post.audience == 'friends')
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  const SizedBox(width: 52), // avatar + gap hizalama
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.3),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.people_rounded,
                            size: 11,
                            color: AppTheme.primary.withValues(alpha: 0.85)),
                        const SizedBox(width: 4),
                        Text(
                          'Sadece Arkadaşlar',
                          style: TextStyle(
                            color: AppTheme.primary.withValues(alpha: 0.85),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 12),

          // ── Content ─────────────────────────────────────────
          Text(
            post.content,
            style: TextStyle(
                color: AppTheme.textPrimary, fontSize: 15, height: 1.4),
          ),

          if (post.imageUrl != null && post.imageUrl!.isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CachedNetworkImage(
                imageUrl: post.imageUrl!,
                width: double.infinity,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
                memCacheWidth: 1200,
                placeholder: (context, url) => Container(
                  height: 220,
                  color: AppTheme.surfaceLight,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primary.withValues(alpha: 0.5),
                      strokeWidth: 2,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 180,
                  color: AppTheme.surface,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image_rounded, color: AppTheme.textSecondary, size: 36),
                        SizedBox(height: 8),
                        Text('Görsel yüklenemedi', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 14),

          // ── Actions ─────────────────────────────────────────
          Row(
            children: [
              // Beğeni — gerçek zamanlı stream ile
              StreamBuilder<bool>(
                stream: firestoreService.isLikedStream(post.id, currentUserId),
                builder: (context, snap) {
                  final isLiked = snap.data ?? false;
                  return _ActionButton(
                    icon: Icons.favorite_border_rounded,
                    activeIcon: Icons.favorite_rounded,
                    label: post.likesCount.toString(),
                    isActive: isLiked,
                    activeColor: Colors.redAccent,
                    onTap: () => firestoreService.togglePostLike(
                        post.id, currentUserId),
                    onLabelTap: () {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.transparent,
                        builder: (_) => LikedUsersSheet(postId: post.id),
                      );
                    },
                  );
                },
              ),

              const SizedBox(width: 8),

              // Yorum
              _ActionButton(
                icon: Icons.chat_bubble_outline_rounded,
                activeIcon: Icons.chat_bubble_rounded,
                label: post.commentsCount.toString(),
                isActive: false,
                activeColor: AppTheme.primary,
                onTap: () => _showComments(context),
              ),

              const SizedBox(width: 8),

              _ActionButton(
                icon: Icons.share_outlined,
                label: '',
                isActive: false,
                activeColor: AppTheme.primary,
                onTap: () {
                   final shareText = '${post.userDisplayName} WorldPals\'te bir gönderi paylaştı:\n\n"${post.content}"\n\nHemen sen de aramıza katıl!';
                   SharePlus.instance.share(ShareParams(text: shareText));
                },
              ),

              const Spacer(),

              // Kaydet
              StreamBuilder<bool>(
                stream: firestoreService.isSavedStream(post.id, currentUserId),
                builder: (context, snap) {
                  final isSaved = snap.data ?? false;
                  return _ActionButton(
                    icon: Icons.bookmark_border_rounded,
                    activeIcon: Icons.bookmark_rounded,
                    label: '',
                    isActive: isSaved,
                    activeColor: AppTheme.primary,
                    onTap: () => firestoreService.toggleSavePost(post.id, currentUserId),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ACTION BUTTON
// ─────────────────────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLabelTap;
  final bool isActive;
  final Color activeColor;

  const _ActionButton({
    required this.icon,
    this.activeIcon,
    required this.label,
    required this.onTap,
    this.onLabelTap,
    required this.activeColor,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? activeColor : AppTheme.textSecondary;
    final bgColor = isActive ? activeColor.withValues(alpha: 0.12) : AppTheme.surfaceLight.withValues(alpha: 0.5);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? activeColor.withValues(alpha: 0.35) : AppTheme.border.withValues(alpha: 0.4),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Icon(
                isActive ? (activeIcon ?? icon) : icon,
                key: ValueKey(isActive),
                size: 18,
                color: color,
              ),
            ),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 5),
              GestureDetector(
                onTap: onLabelTap ?? onTap,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    label,
                    style: TextStyle(
                        color: color,
                        fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                        fontSize: 13),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// COMMENTS BOTTOM SHEET
// ─────────────────────────────────────────────────────────────
class _CommentsSheet extends StatefulWidget {
  final PostModel post;
  final String currentUserId;
  final String currentUserDisplayName;
  final String currentUserPhotoUrl;
  final FirestoreService firestoreService;

  const _CommentsSheet({
    required this.post,
    required this.currentUserId,
    required this.currentUserDisplayName,
    required this.currentUserPhotoUrl,
    required this.firestoreService,
  });

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await widget.firestoreService.addComment(
        postId: widget.post.id,
        userId: widget.currentUserId,
        userDisplayName: widget.currentUserDisplayName,
        userPhotoUrl: widget.currentUserPhotoUrl,
        content: text,
      );
      _controller.clear();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Yorum gönderilemedi.')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text(
                      'Yorumlar',
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.close,
                          color: AppTheme.textSecondary, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              Divider(color: AppTheme.border, height: 1),

              // Comment list
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: widget.firestoreService
                      .getCommentsStream(widget.post.id),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator(
                              color: AppTheme.primary));
                    }
                    final comments = snap.data ?? [];
                    if (comments.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline_rounded,
                                size: 48,
                                color: AppTheme.textSecondary
                                    .withValues(alpha: 0.4)),
                            const SizedBox(height: 12),
                            Text('Henüz yorum yok.',
                                style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 14)),
                          ],
                        ),
                      );
                    }
                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      itemCount: comments.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 16),
                      itemBuilder: (context, i) {
                        final c = comments[i];
                        final ts = c['createdAt'];
                        String timeStr = '';
                        if (ts != null) {
                          if (ts is Timestamp) {
                            timeStr = timeago.format(ts.toDate(), locale: 'tr');
                          } else {
                            timeStr = 'Şimdi';
                          }
                        }
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                GestureDetector(
                                  onTap: () {
                                    Navigator.pop(context);
                                    context.push('/user/${c['userId']}');
                                  },
                                  child: UserAvatar(
                                    photoUrl: c['userPhotoUrl'] ?? '',
                                    displayName: c['userDisplayName'] ?? '?',
                                    radius: 16,
                                    isOnline: false,
                                    showOnlineIndicator: false,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          GestureDetector(
                                            onTap: () {
                                              Navigator.pop(context);
                                              context.push('/user/${c['userId']}');
                                            },
                                            child: Text(
                                              c['userDisplayName'] ?? '',
                                              style: TextStyle(
                                                  color: AppTheme.textPrimary,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                        Text(
                                          timeStr,
                                          style: TextStyle(
                                              color: AppTheme.textSecondary,
                                              fontSize: 11),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      c['content'] ?? '',
                                      style: TextStyle(
                                          color: AppTheme.textPrimary,
                                          fontSize: 14,
                                          height: 1.4),
                                    ),
                                  ],
                                ),
                              ),
                              if (c['userId'] == widget.currentUserId || widget.post.userId == widget.currentUserId)
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: PopupMenuButton<String>(
                                    padding: EdgeInsets.zero,
                                    icon: Icon(Icons.more_vert_rounded, color: AppTheme.textSecondary, size: 18),
                                    color: AppTheme.surfaceLight,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(color: AppTheme.border, width: 0.5),
                                    ),
                                    onSelected: (value) async {
                                      if (value == 'delete') {
                                        showDialog(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            backgroundColor: AppTheme.surfaceLight,
                                            title: Text('Yorumu Sil', style: TextStyle(color: AppTheme.textPrimary)),
                                            content: Text('Bu yorumu silmek istediğinize emin misiniz?', style: TextStyle(color: AppTheme.textSecondary)),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(ctx),
                                                child: Text('İptal', style: TextStyle(color: AppTheme.textSecondary)),
                                              ),
                                              TextButton(
                                                onPressed: () async {
                                                  Navigator.pop(ctx);
                                                  try {
                                                    await widget.firestoreService.deleteComment(widget.post.id, c['id']);
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
                                            Text('Sil', style: TextStyle(color: AppTheme.danger, fontSize: 13)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              Divider(color: AppTheme.border, height: 1),

              // Input box
              Padding(
                padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + bottom),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        style: TextStyle(color: AppTheme.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Yorum yaz...',
                          hintStyle: TextStyle(
                              color: AppTheme.textSecondary),
                          filled: true,
                          fillColor: AppTheme.surfaceLight,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide:
                                BorderSide(color: AppTheme.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide:
                                BorderSide(color: AppTheme.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: const BorderSide(
                                color: AppTheme.primary, width: 2),
                          ),
                        ),
                        onSubmitted: (_) => _send(),
                        textInputAction: TextInputAction.send,
                      ),
                    ),
                    const SizedBox(width: 10),
                    _sending
                        ? const SizedBox(
                            width: 42,
                            height: 42,
                            child: CircularProgressIndicator(
                                color: AppTheme.primary, strokeWidth: 2),
                          )
                        : InkWell(
                            onTap: _send,
                            borderRadius: BorderRadius.circular(21),
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: AppTheme.primary,
                                borderRadius: BorderRadius.circular(21),
                              ),
                              child: const Icon(Icons.send_rounded,
                                  color: Colors.white, size: 20),
                            ),
                          ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
