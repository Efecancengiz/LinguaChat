// lib/screens/profile/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:linguachat/config/theme.dart';
import 'package:linguachat/providers/auth_provider.dart';
import 'package:flutter/services.dart';
import 'package:linguachat/widgets/user_avatar.dart';
import 'package:linguachat/widgets/language_badge.dart';
import 'package:linguachat/models/post_model.dart';
import 'package:linguachat/models/user_model.dart';

import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:linguachat/services/firestore_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthProvider>();
      if (auth.user != null) {
         await FirestoreService().syncFriendsToFollowers(auth.user!.uid);
         if (mounted) auth.refreshUser(); // UI'ı anında güncelle
      }
    });
  }

  Future<void> _pickAndUploadImage(BuildContext context, AuthProvider auth, String uid) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 256,
        maxHeight: 256,
        imageQuality: 30,
      );
      if (image == null) return;
      
      setState(() => _isUploading = true);

      final Uint8List imageBytes = await image.readAsBytes();
      final String base64Image = "data:image/jpeg;base64,${base64Encode(imageBytes)}";
      
      final firestoreService = FirestoreService();
      await firestoreService.updateProfilePhoto(uid, base64Image);
      await auth.refreshUser();

      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Profil fotoğrafı güncellendi!', style: TextStyle(color: Colors.white)), backgroundColor: AppTheme.accent),
        );
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Fotoğraf yüklenemedi: $e', style: const TextStyle(color: Colors.white)), backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.read<AuthProvider>().currentUserId;
    if (currentUserId == null) {
       return const Center(child: Text("Oturum açılmadı"));
    }
    
    return StreamBuilder<UserModel?>(
      stream: FirestoreService().userStream(currentUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
           return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
        }

        final user = snapshot.data;
        if (user == null) {
          return const Center(
            child: Text('Profil yüklenemedi', style: TextStyle(color: AppTheme.textSecondary)),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 120, 24, 120),
          child: Column(
            children: [
              // Top actions row
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.edit_outlined,
                          color: AppTheme.primary, size: 18),
                    ),
                    onPressed: () => context.push('/edit-profile'),
                  ),
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.logout_rounded,
                          color: AppTheme.danger, size: 18),
                    ),
                    onPressed: () async {
                      final authProvider = context.read<AuthProvider>();
                      final router = GoRouter.of(context);
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: AppTheme.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          title: const Text('Çıkış Yap',
                              style: TextStyle(color: AppTheme.textPrimary)),
                          content: const Text(
                            'Çıkış yapmak istediğinize emin misiniz?',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('İptal'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Çıkış Yap',
                                  style: TextStyle(color: AppTheme.danger)),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true && mounted) {
                        await authProvider.signOut();
                        if (mounted) router.go('/login');
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Avatar
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  UserAvatar(
                    photoUrl: user.photoUrl,
                    displayName: user.displayName,
                    radius: 50,
                    showOnlineIndicator: false,
                    isOnline: true,
                  ),
                  if (_isUploading)
                    const Positioned.fill(
                      child: CircularProgressIndicator(color: AppTheme.primary),
                    ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _isUploading ? null : () => _pickAndUploadImage(context, context.read<AuthProvider>(), user.uid),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.background, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Name
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
              Text(
                user.email,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
              if (user.city.isNotEmpty) ...[
                const SizedBox(height: 4),
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
              // Learning languages
              if (user.learningLanguages.isNotEmpty) ...[
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
                const SizedBox(height: 24),
              ],
              // Stats row
              Container(
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
              const SizedBox(height: 24),
              // Known languages
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
                const SizedBox(height: 24),
              ],
              // Interests
              if (user.interests.isNotEmpty) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'İlgi Alanları',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: user.interests.map((interest) {
                      return IntrinsicWidth(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2C2C3E),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.deepPurpleAccent, width: 1),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.deepPurpleAccent.withValues(alpha: 0.2),
                                blurRadius: 4,
                                spreadRadius: 1,
                              )
                            ]
                          ),
                          child: Text(
                            interest,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              
              // Posts Grid
              StreamBuilder<List<PostModel>>(
                  stream: FirestoreService().getUserPostsStream(user.uid),
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
              const SizedBox(height: 24),
              // Menu items
              _buildMenuItem(
                icon: Icons.people_outline_rounded,
                title: 'Arkadaşlarım',
                subtitle: 'Arkadaş listeni görüntüle',
                onTap: () => context.push('/friends'),
              ),
              _buildMenuItem(
                icon: Icons.person_add_outlined,
                title: 'Arkadaşlık İstekleri',
                subtitle: 'Gelen istekleri yönet',
                onTap: () => context.push('/friend-requests'),
              ),
              _buildMenuItem(
                icon: Icons.info_outline_rounded,
                title: 'Hakkında',
                subtitle: 'LinguaChat v1.0.0',
                onTap: () {},
              ),
            ],
          ),
        );
      },
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

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border, width: 0.5),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: AppTheme.textSecondary,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
