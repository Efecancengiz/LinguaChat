import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:linguachat/config/theme.dart';
import 'package:linguachat/providers/auth_provider.dart';
import 'package:linguachat/services/firestore_service.dart';
import 'package:linguachat/models/post_model.dart';
import 'package:linguachat/widgets/user_avatar.dart';
import 'package:timeago/timeago.dart' as timeago;

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final FirestoreService _firestoreService = FirestoreService();

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
        decoration: const BoxDecoration(
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
                    const Text(
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
                    _PostsList(
                      stream: _firestoreService.getFeedPostsStream(user.uid),
                      currentUserId: user.uid,
                      currentUserDisplayName: user.displayName,
                      currentUserPhotoUrl: user.photoUrl,
                      firestoreService: _firestoreService,
                      emptyMessage: 'Henüz gönderi yok.',
                    ),
                    _FriendsFeed(
                      currentUserId: user.uid,
                      currentUserDisplayName: user.displayName,
                      currentUserPhotoUrl: user.photoUrl,
                      firestoreService: _firestoreService,
                    ),
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
class _PostsList extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return StreamBuilder<List<PostModel>>(
      stream: stream,
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
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
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
                  showAddFriendsButton
                      ? Icons.people_outline_rounded
                      : Icons.dynamic_feed_rounded,
                  size: 64,
                  color: AppTheme.textSecondary.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 16),
                Text(emptyMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                if (showAddFriendsButton) ...[
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
              currentUserId: currentUserId,
              currentUserDisplayName: currentUserDisplayName,
              currentUserPhotoUrl: currentUserPhotoUrl,
              firestoreService: firestoreService,
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// FRIENDS FEED (real-time stream)
// ─────────────────────────────────────────────────────────────
class _FriendsFeed extends StatelessWidget {
  final String currentUserId;
  final String currentUserDisplayName;
  final String currentUserPhotoUrl;
  final FirestoreService firestoreService;

  const _FriendsFeed({
    required this.currentUserId,
    required this.currentUserDisplayName,
    required this.currentUserPhotoUrl,
    required this.firestoreService,
  });

  @override
  Widget build(BuildContext context) {
    return _PostsList(
      stream: firestoreService.getFriendsFeedStream2(currentUserId),
      currentUserId: currentUserId,
      currentUserDisplayName: currentUserDisplayName,
      currentUserPhotoUrl: currentUserPhotoUrl,
      firestoreService: firestoreService,
      emptyMessage: 'Arkadaşların henüz paylaşım yapmadı.',
      showAddFriendsButton: true,
    );
  }
}



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

  void _showRepostConfirm(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tekrar Paylaş',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Bu gönderiyi profilinde tekrar paylaşmak istiyor musun?',
                style: TextStyle(
                    color: AppTheme.textSecondary.withValues(alpha: 0.9),
                    fontSize: 14),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('İptal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        try {
                          await firestoreService.repostPost(
                            originalPost: post,
                            currentUserId: currentUserId,
                            currentUserDisplayName: currentUserDisplayName,
                            currentUserPhotoUrl: currentUserPhotoUrl,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Gönderi tekrar paylaşıldı!')),
                            );
                          }
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Bir hata oluştu.')),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.repeat_rounded, size: 18),
                      label: const Text('Paylaş'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    timeago.setLocaleMessages('tr', timeago.TrMessages());
    final timeStr = timeago.format(post.createdAt, locale: 'tr');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassDecoration.copyWith(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 8),
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
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      timeStr,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (post.userId == currentUserId)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded,
                      color: AppTheme.textSecondary, size: 20),
                  color: AppTheme.surfaceLight,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppTheme.border, width: 0.5),
                  ),
                  onSelected: (value) async {
                    if (value == 'delete') {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: AppTheme.surface,
                          title: const Text('Gönderiyi Sil', style: TextStyle(color: AppTheme.textPrimary)),
                          content: const Text('Bu gönderiyi kalıcı olarak silmek istediğine emin misin?', style: TextStyle(color: AppTheme.textSecondary)),
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
                    }
                  },
                  itemBuilder: (context) => [
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
            style: const TextStyle(
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
                  child: const Center(
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

              // Tekrar paylaş
              _ActionButton(
                icon: Icons.repeat_rounded,
                label: post.repostsCount > 0 ? post.repostsCount.toString() : '',
                isActive: false,
                activeColor: Colors.greenAccent,
                onTap: () => _showRepostConfirm(context),
              ),

              const Spacer(),

              // Dış paylaş
              _ActionButton(
                icon: Icons.share_outlined,
                label: '',
                isActive: false,
                activeColor: AppTheme.primary,
                onTap: () {},
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
  final bool isActive;
  final Color activeColor;

  const _ActionButton({
    required this.icon,
    this.activeIcon,
    required this.label,
    required this.onTap,
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
              Text(
                label,
                style: TextStyle(
                    color: color,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                    fontSize: 13),
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
          decoration: const BoxDecoration(
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
                    const Text(
                      'Yorumlar',
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close,
                          color: AppTheme.textSecondary, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              const Divider(color: AppTheme.border, height: 1),

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
                            const Text('Henüz yorum yok.',
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
                          final dt = (ts as dynamic).toDate() as DateTime;
                          timeStr = timeago.format(dt, locale: 'tr');
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            UserAvatar(
                              photoUrl: c['userPhotoUrl'] ?? '',
                              displayName: c['userDisplayName'] ?? '?',
                              radius: 16,
                              isOnline: false,
                              showOnlineIndicator: false,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        c['userDisplayName'] ?? '',
                                        style: const TextStyle(
                                            color: AppTheme.textPrimary,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        timeStr,
                                        style: const TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontSize: 11),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    c['content'] ?? '',
                                    style: const TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontSize: 14,
                                        height: 1.4),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),

              const Divider(color: AppTheme.border, height: 1),

              // Input box
              Padding(
                padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + bottom),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        style: const TextStyle(color: AppTheme.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Yorum yaz...',
                          hintStyle: const TextStyle(
                              color: AppTheme.textSecondary),
                          filled: true,
                          fillColor: AppTheme.surfaceLight,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide:
                                const BorderSide(color: AppTheme.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide:
                                const BorderSide(color: AppTheme.border),
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
