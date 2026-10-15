// lib/screens/profile/user_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:linguachat/config/theme.dart';
import 'package:linguachat/models/user_model.dart';
import 'package:linguachat/providers/auth_provider.dart';
import 'package:linguachat/services/firestore_service.dart';
import 'package:linguachat/models/friend_request_model.dart';
import 'package:linguachat/widgets/user_avatar.dart';
import 'package:linguachat/widgets/language_badge.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';
import 'package:linguachat/models/post_model.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;

  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _isFollowing = false;
  bool _hasPendingRequest = false;
  bool _isBlocked = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkFriendship();
  }

  Future<void> _checkFriendship() async {
    final currentUserId = context.read<AuthProvider>().currentUserId;
    if (currentUserId == null) return;

    final isFollowing = await _firestoreService.isFollowing(currentUserId, widget.userId);
    final hasPendingRequest = await _firestoreService.hasPendingRequest(currentUserId, widget.userId);
    final isBlocked = await _firestoreService.isBlocked(currentUserId, widget.userId);

    // Hedef kullanıcının sayaçlarını senkronize et/düzelt (kendi kendini onarma)
    await _firestoreService.syncUserFollowCounts(widget.userId);

    if (mounted) {
      setState(() {
        _isFollowing = isFollowing;
        _hasPendingRequest = hasPendingRequest;
        _isBlocked = isBlocked;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleFriendAction() async {
    final currentUser = context.read<AuthProvider>().user;
    if (currentUser == null) return;

    setState(() => _isLoading = true);
    
    try {
      if (_isFollowing) {
        // Arkadaşlıktan çıkar
        await _firestoreService.unfollowUser(currentUser.uid, widget.userId);
        setState(() => _isFollowing = false);
      } else if (!_hasPendingRequest) {
        // Arkadaşlık isteği gönder
        final request = FriendRequestModel(
          id: '', // Firestore auto-generates
          fromUserId: currentUser.uid,
          toUserId: widget.userId,
          fromUserName: currentUser.displayName,
          fromUserPhoto: currentUser.photoUrl,
          toUserName: '', // backend doesn't strictly need it to display to the recipient
          toUserPhoto: '', // backend doesn't strictly need it to display to the recipient
          status: 'pending',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await _firestoreService.sendFriendRequest(request);
        setState(() => _hasPendingRequest = true);
      }
    } catch(e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hata oluştu')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _startDm() async {
    final currentUserId = context.read<AuthProvider>().currentUserId;
    if (currentUserId == null) return;

    try {
      await _firestoreService.createDmChat(currentUserId, widget.userId);
      if (!mounted) return;
      
      final chatId =
          _firestoreService.getDmChatId(currentUserId, widget.userId);
      context.push('/dm/$chatId', extra: {'userId': widget.userId});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sohbet başlatılamadı: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  void _showFullScreenProfilePicture(BuildContext context, String? photoUrl) {
    if (photoUrl == null || photoUrl.isEmpty) return;
    
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.transparent,
                padding: const EdgeInsets.all(40),
                child: Center(
                  child: InteractiveViewer(
                    clipBehavior: Clip.none,
                    child: Hero(
                      tag: 'userProfilePic_$photoUrl',
                      child: ClipOval(
                        child: photoUrl.startsWith('data:image')
                            ? Image.memory(
                                base64Decode(photoUrl.split(',').last),
                                fit: BoxFit.cover,
                                width: MediaQuery.of(context).size.width - 80,
                                height: MediaQuery.of(context).size.width - 80,
                              )
                            : CachedNetworkImage(
                                imageUrl: photoUrl,
                                fit: BoxFit.cover,
                                width: MediaQuery.of(context).size.width - 80,
                                height: MediaQuery.of(context).size.width - 80,
                                placeholder: (context, url) => Container(
                                  width: MediaQuery.of(context).size.width - 80,
                                  height: MediaQuery.of(context).size.width - 80,
                                  color: AppTheme.surfaceLight,
                                  child: const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
                                ),
                                errorWidget: (context, url, error) => const Icon(Icons.error_outline, color: Colors.white),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showReportDialog(BuildContext context, String currentUserId) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('Kullanıcıyı Şikayet Et', style: TextStyle(color: AppTheme.textPrimary)),
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
              await _firestoreService.reportUser(widget.userId, currentUserId, reasonController.text.trim());
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

  void _showBlockDialog(BuildContext context, String currentUserId) {
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
              await _firestoreService.blockUser(currentUserId, widget.userId);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Kullanıcı engellendi.')),
                );
                context.pop(); // Go back from profile
              }
            },
            child: const Text('Engelle', style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
  }

  void _showUnblockDialog(BuildContext context, String currentUserId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('Engeli Kaldır', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text('Bu kullanıcının engelini kaldırmak istediğinize emin misiniz?', style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('İptal', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              await _firestoreService.unblockUser(currentUserId, widget.userId);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Kullanıcı engeli kaldırıldı.')),
                );
                _checkFriendship();
              }
            },
            child: const Text('Engeli Kaldır', style: TextStyle(color: AppTheme.primary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.watch<AuthProvider>().currentUserId;
    final isMe = widget.userId == currentUserId;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Profil'),
        actions: [
          if (!isMe && currentUserId != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (value) {
                if (value == 'report') {
                  _showReportDialog(context, currentUserId);
                } else if (value == 'block') {
                  if (_isBlocked) {
                    _showUnblockDialog(context, currentUserId);
                  } else {
                    _showBlockDialog(context, currentUserId);
                  }
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'report',
                  child: Row(
                    children: [
                      Icon(Icons.flag_rounded, color: AppTheme.warning, size: 20),
                      SizedBox(width: 8),
                      Text('Şikayet Et', style: TextStyle(color: AppTheme.warning)),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'block',
                  child: Row(
                    children: [
                      Icon(_isBlocked ? Icons.lock_open_rounded : Icons.block_rounded,
                          color: _isBlocked ? AppTheme.primary : AppTheme.danger, size: 20),
                      const SizedBox(width: 8),
                      Text(_isBlocked ? 'Engeli Kaldır' : 'Engelle',
                          style: TextStyle(color: _isBlocked ? AppTheme.primary : AppTheme.danger)),
                    ],
                  ),
                ),
              ],
              color: AppTheme.surfaceLight,
            ),
        ],
      ),
      body: StreamBuilder<UserModel?>(
        stream: _firestoreService.userStream(widget.userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            );
          }

          final user = snapshot.data;
          if (user == null) {
            return Center(
              child: Text(
                'Kullanıcı bulunamadı',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Avatar
                UserAvatar(
                  photoUrl: user.photoUrl,
                  displayName: user.displayName,
                  radius: 50,
                  showOnlineIndicator: true,
                  isOnline: user.isOnline,
                  onTap: () => _showFullScreenProfilePicture(context, user.photoUrl),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      user.displayName,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (user.isPremium) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.accent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'PREMIUM',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: user.isOnline
                            ? AppTheme.accent
                            : AppTheme.textSecondary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      user.isOnline ? 'Çevrimiçi' : 'Çevrimdışı',
                      style: TextStyle(
                        color: user.isOnline
                            ? AppTheme.accent
                            : AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                if (user.city.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_city_rounded, size: 14, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        user.city,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
                if (user.bio.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    user.bio,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 24),
                // Stats row
                Container(
                  margin: const EdgeInsets.only(top: 24),
                  padding: const EdgeInsets.all(16),
                  decoration: AppTheme.glassDecoration,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStat('${user.postsCount}', 'Gönderi'),
                      Container(width: 1, height: 40, color: AppTheme.border),
                      _buildStat('${user.followersCount}', 'Takipçi', onTap: () => context.push('/follows/${user.uid}/followers')),
                      Container(width: 1, height: 40, color: AppTheme.border),
                      _buildStat('${user.followingCount}', 'Takip Edilen', onTap: () => context.push('/follows/${user.uid}/following')),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Action buttons
                if (!isMe && !_isLoading && currentUserId != null)
                  if (_isBlocked)
                    Container(
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ElevatedButton.icon(
                        onPressed: () => _showUnblockDialog(context, currentUserId),
                        icon: const Icon(Icons.lock_open_rounded, color: Colors.white, size: 18),
                        label: const Text('Engeli Kaldır', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                      ),
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ElevatedButton.icon(
                            onPressed: _startDm,
                            icon: const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 18),
                            label: const Text('Mesaj', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: _hasPendingRequest ? null : _handleFriendAction,
                          icon: Icon(
                            _isFollowing 
                                ? Icons.how_to_reg_rounded 
                                : _hasPendingRequest 
                                    ? Icons.access_time_rounded 
                                    : Icons.person_add_alt_1_rounded, 
                            size: 18
                          ),
                          label: Text(
                            _isFollowing 
                                ? 'Arkadaşsın' 
                                : _hasPendingRequest 
                                    ? 'İstek Gönderildi' 
                                    : 'Arkadaş Ekle'
                          ),
                          style: OutlinedButton.styleFrom(
                             padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                             side: BorderSide(
                               color: _isFollowing || _hasPendingRequest 
                                   ? AppTheme.textSecondary 
                                   : AppTheme.primary
                             ),
                             foregroundColor: _isFollowing || _hasPendingRequest 
                                 ? AppTheme.textSecondary 
                                 : AppTheme.primary,
                          ),
                        ),
                      ],
                    ) else if (_isLoading && !isMe) ...[
                    const CircularProgressIndicator(),
                  ],
                const SizedBox(height: 24),
                // Languages
                if (user.knownLanguages.isNotEmpty) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Bildiği Diller',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: user.knownLanguages.map((lang) {
                      return LanguageBadge(
                        languageCode: lang['lang'] ?? '',
                        level: lang['level'] ?? '',
                      );
                    }).toList(),
                  ),
                ],
                if (user.learningLanguages.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Öğreniyor',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: user.learningLanguages.map((lang) {
                      return LanguageBadge(
                        languageCode: lang['lang'] ?? '',
                        level: lang['level'] ?? '',
                        isLearning: true,
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 24),
                // Posts Grid
                StreamBuilder<List<PostModel>>(
                  stream: _firestoreService.getUserPostsStream(widget.userId),
                  builder: (context, postSnapshot) {
                     if (postSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                     }
                     final posts = postSnapshot.data ?? [];
                     if (posts.isEmpty) {
                        return const SizedBox.shrink();
                     }
                     return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 2,
                          mainAxisSpacing: 2,
                        ),
                        itemCount: posts.length,
                        itemBuilder: (context, index) {
                           final post = posts[index];
                           if (post.imageUrl != null && post.imageUrl!.isNotEmpty) {
                             return Image.network(post.imageUrl!, fit: BoxFit.cover);
                           } else {
                             return Container(
                                color: AppTheme.surfaceLight,
                                padding: const EdgeInsets.all(8),
                                child: Center(
                                  child: Text(
                                     post.content,
                                     maxLines: 4,
                                     overflow: TextOverflow.ellipsis,
                                     style: const TextStyle(fontSize: 10),
                                  )
                                )
                             );
                           }
                        },
                     );
                  }
                ),
                const SizedBox(height: 48), // Padding for bottom nav
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStat(String value, String label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

