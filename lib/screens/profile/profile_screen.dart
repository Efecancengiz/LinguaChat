// lib/screens/profile/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:linguachat/config/theme.dart';
import 'package:linguachat/providers/auth_provider.dart';
import 'package:linguachat/widgets/user_avatar.dart';
import 'package:linguachat/widgets/language_badge.dart';
import 'package:linguachat/models/user_model.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'dart:convert';
import 'package:linguachat/services/storage_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:linguachat/services/firestore_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math' as math;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();
  Stream<UserModel?>? _userStream;
  String? _lastUserId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authProvider = context.watch<AuthProvider>();
    final currentUserId = authProvider.currentUserId;
    
    if (currentUserId != null && currentUserId != _lastUserId) {
      _lastUserId = currentUserId;
      _userStream = FirestoreService().userStream(currentUserId);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthProvider>();
      if (auth.user != null) {
         final fs = FirestoreService();
         await fs.syncFriendsToFollowers(auth.user!.uid);
         await fs.syncUserFollowCounts(auth.user!.uid);
         await fs.syncUserPostsCount(auth.user!.uid);
         if (mounted) auth.refreshUser(); // UI'ı anında güncelle
      }
    });
  }

  Future<void> _pickAndUploadImage(BuildContext context, AuthProvider auth, String uid) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 90,
      );
      if (image == null) return;
      
      setState(() => _isUploading = true);

      final storageService = StorageService();
      final downloadUrl = await storageService.uploadProfileImage(uid, image);
      
      if (downloadUrl != null) {
        final firestoreService = FirestoreService();
        await firestoreService.updateUser(uid, {'photoUrl': downloadUrl});
        await auth.refreshUser();

        if (mounted) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('Profil fotoğrafı güncellendi! ✅', style: TextStyle(color: Colors.white)), backgroundColor: AppTheme.accent),
          );
        }
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
                      tag: 'profilePic_$photoUrl',
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

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    // AuthProvider yüklendikten sonra ana ekranı oluştur

    final currentUserId = authProvider.currentUserId;
    if (currentUserId == null) {
      return Center(
        child: Text('Oturum açılmadı', style: TextStyle(color: AppTheme.textSecondary)),
      );
    }

    return StreamBuilder<UserModel?>(
      stream: _userStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
           return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
        }

        final user = snapshot.data;
        if (user == null) {
          return Center(
            child: Text('Profil yüklenemedi', style: TextStyle(color: AppTheme.textSecondary)),
          );
        }

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 120),
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
                          title: Text('Çıkış Yap',
                              style: TextStyle(color: AppTheme.textPrimary)),
                          content: Text(
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
                    onTap: () => _showFullScreenProfilePicture(context, user.photoUrl),
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

              if (user.city.isNotEmpty) ...[
                const SizedBox(height: 4),
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
                padding: const EdgeInsets.all(16),
                decoration: AppTheme.glassDecoration,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStat('${math.max(0, user.postsCount)}', 'Gönderi', onTap: () => context.push('/user-posts/${user.uid}')),
                    Container(width: 1, height: 40, color: AppTheme.border),
                    _buildStat('${user.followersCount}', 'Takipçi', onTap: () => context.push('/follows/${user.uid}/followers')),
                    Container(width: 1, height: 40, color: AppTheme.border),
                    _buildStat('${user.followingCount}', 'Takip Edilen', onTap: () => context.push('/follows/${user.uid}/following')),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Learning languages
              if (user.learningLanguages.isNotEmpty) ...[
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
                const SizedBox(height: 16),
              ],
              // Known languages
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
                const SizedBox(height: 24),
              ],
              // Interests
              if (user.interests.isNotEmpty) ...[
                Align(
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

              // Menu items
              if (user.isAdmin) ...[
                _buildMenuItem(
                  icon: Icons.admin_panel_settings_rounded,
                  title: 'Yönetici Paneli',
                  subtitle: 'Şikayetleri ve kullanıcıları yönet',
                  onTap: () => context.push('/admin'),
                ),
              ],
              _buildMenuItem(
                icon: Icons.bookmark_border_rounded,
                title: 'Kaydedilenler',
                subtitle: 'Kaydettiğin gönderileri gör',
                onTap: () => context.push('/saved-posts'),
              ),
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
                subtitle: 'WorldPals v1.1.0',
                onTap: () {},
              ),
              _buildMenuItem(
                icon: Icons.block_rounded,
                title: 'Engellenen Kişiler',
                subtitle: 'Engellediğin kullanıcıları yönet',
                onTap: () => context.push('/blocked-users'),
              ),
              _buildMenuItem(
                icon: Icons.settings_outlined,
                title: 'Ayarlar',
                subtitle: 'Hesap ve gizlilik ayarları',
                onTap: () => _showSettingsModal(context),
              ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSettingsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Ayarlar',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined, color: AppTheme.primary),
                title: Text('Gizlilik Politikası', style: TextStyle(color: AppTheme.textPrimary)),
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(context);
                  final Uri url = Uri.parse('https://linguachat-550b1.web.app/privacy.html');
                  if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                    if (mounted) {
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Bağlantı açılamadı')),
                      );
                    }
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppTheme.danger),
                title: const Text('Hesabımı Sil', style: TextStyle(color: AppTheme.danger)),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteAccountDialog(context);
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text('Hesabı Sil', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          'Hesabınızı silmek istediğinize emin misiniz? Bu işlem geri alınamaz.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () async {
               Navigator.pop(ctx);
               
               // Geçici yükleniyor penceresi göster
               showDialog(
                 context: context,
                 barrierDismissible: false,
                 builder: (loadingCtx) => const Center(
                   child: CircularProgressIndicator(color: AppTheme.primary),
                 ),
               );

               final authProvider = context.read<AuthProvider>();
               final messenger = ScaffoldMessenger.of(context);
               final success = await authProvider.deleteAccount();
               
               // Yükleniyor penceresini kapat
               if (context.mounted) {
                 Navigator.pop(context);
               }

               if (!success) {
                 messenger.showSnackBar(
                   SnackBar(
                     content: Text(authProvider.error ?? 'Hesap silinirken hata oluştu'),
                     backgroundColor: AppTheme.danger,
                   )
                 );
               }
            },
            child: const Text('Sil', style: TextStyle(color: AppTheme.danger)),
          ),
        ],
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
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
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
