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

    if (mounted) {
      setState(() {
        _isFollowing = isFollowing;
        _hasPendingRequest = hasPendingRequest;
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

  void _startDm() {
    final currentUserId = context.read<AuthProvider>().currentUserId;
    if (currentUserId == null) return;

    _firestoreService.createDmChat(currentUserId, widget.userId);
    final chatId =
        _firestoreService.getDmChatId(currentUserId, widget.userId);
    context.push('/dm/$chatId', extra: {'userId': widget.userId});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Profil'),
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
            return const Center(
              child: Text(
                'Kullanıcı bulunamadı',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
              ),
            );
          }
          final isMe = widget.userId ==
              context.read<AuthProvider>().currentUserId;

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
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      user.displayName,
                      style: const TextStyle(
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
                      const Icon(Icons.location_city_rounded, size: 14, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        user.city,
                        style: const TextStyle(
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
                    style: const TextStyle(
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
                      _buildStat('${user.followersCount}', 'Takipçi'),
                      Container(width: 1, height: 40, color: AppTheme.border),
                      _buildStat('${user.followingCount}', 'Takip Edilen'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Action buttons
                if (!isMe && !_isLoading)
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
                  const Align(
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
                  const Align(
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

  Widget _buildStat(String value, String label) {
    return Column(
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
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

