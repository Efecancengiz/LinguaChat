// lib/screens/profile/edit_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:linguachat/config/theme.dart';
import 'package:linguachat/config/constants.dart';
import 'package:linguachat/providers/auth_provider.dart';
import 'package:linguachat/services/firestore_service.dart';
import 'package:linguachat/services/storage_service.dart';
import 'package:linguachat/widgets/user_avatar.dart';
import 'package:linguachat/widgets/interest_tags.dart';
import 'package:image_picker/image_picker.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _cityController = TextEditingController();
  List<Map<String, String>> _knownLanguages = [];
  List<Map<String, String>> _learningLanguages = [];
  List<String> _interests = [];
  bool _isSaving = false;
  bool _isUploadingImage = false;
  final ImagePicker _picker = ImagePicker();
  final StorageService _storageService = StorageService();

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    if (user != null) {
      _nameController.text = user.displayName;
      _bioController.text = user.bio;
      _cityController.text = user.city;
      _knownLanguages = List.from(user.knownLanguages);
      _learningLanguages = List.from(user.learningLanguages);
      _interests = List.from(user.interests);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.user;
    if (user == null) return;

    // Capture context-dependent objects before any async gaps
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    final newDisplayName = _nameController.text.trim();
    if (newDisplayName.isEmpty) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Kullanıcı adı boş olamaz.'),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }

    if (newDisplayName.length < 3) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Kullanıcı adı en az 3 karakter olmalıdır.'),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    debugPrint("Kaydet butonuna basıldı, _isSaving = true yapıldı.");

    try {
      if (user.displayName != newDisplayName) {
        try {
          await _firestoreService.updateUserDisplayName(
            user.uid, 
            user.displayName, 
            newDisplayName,
          );
        } catch (e) {
          if (e.toString().contains('username-taken')) {
            throw Exception('Bu kullanıcı adı zaten alınmış.');
          }
          rethrow;
        }
      }

      await _firestoreService.updateUser(user.uid, {
        'bio': _bioController.text.trim(),
        'city': _cityController.text.trim(),
        'knownLanguages': _knownLanguages,
        'learningLanguages': _learningLanguages,
        'interests': _interests,
      });

      // 1. Show success message using pre-captured messenger
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Profil güncellendi! ✅')),
      );

      // 2. Navigate back to the profile screen
      debugPrint("Geri dönme işlemi (go) başlatılıyor...");
      router.go('/?tab=4');

      // 3. Refresh user data in background after navigation transition
      debugPrint("Firestore güncellendi. Kullanıcı verisi arka planda yenileniyor...");
      Future.delayed(const Duration(milliseconds: 100), () {
        authProvider.refreshUser();
      });

    } catch (e) {
      debugPrint('Profil kaydetme hatası: $e');
      if (!mounted) return;
      String errorMessage = e.toString();
      if (errorMessage.startsWith('Exception: ')) {
        errorMessage = errorMessage.substring('Exception: '.length);
      }
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: AppTheme.danger,
        ),
      );
    } finally {
      debugPrint("İşlem sonu (finally). _isSaving = false yapılıyor.");
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _pickAndUploadImage() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.user;
    if (user == null) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 90,
      );

      if (image == null) return;

      setState(() => _isUploadingImage = true);

      final downloadUrl = await _storageService.uploadProfileImage(user.uid, image);

      if (downloadUrl != null) {
        await _firestoreService.updateUser(user.uid, {'photoUrl': downloadUrl}).timeout(const Duration(seconds: 10));
        await authProvider.refreshUser();

        if (mounted) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Profil fotoğrafı güncellendi! ✅'),
              backgroundColor: AppTheme.accent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppTheme.danger,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  Future<void> _deleteProfileImage() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.user;
    if (user == null) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      setState(() => _isUploadingImage = true);
      // Profil resmini kaldırmak için photoUrl'i boş dize yaparız.
      await _firestoreService.updateUser(user.uid, {'photoUrl': ''}).timeout(const Duration(seconds: 10));
      await authProvider.refreshUser();

      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Profil fotoğrafı kaldırıldı! 🗑️'),
            backgroundColor: AppTheme.accent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  void _showPhotoOptionsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
                alignment: Alignment.center,
              ),
              Text('Profil Fotoğrafını Değiştir', style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              )),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: AppTheme.primary),
                title: Text('Kütüphaneden Seç', style: TextStyle(color: AppTheme.textPrimary)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadImage();
                },
              ),
              Divider(color: AppTheme.border, height: 1),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: AppTheme.danger),
                title: const Text('Profil Fotoğrafını Sil', style: TextStyle(color: AppTheme.danger)),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteProfileImage();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }


  void _addKnownLanguage() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dil Ekle',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: AppConstants.languageRooms.length,
                  itemBuilder: (context, index) {
                    final lang = AppConstants.languageRooms[index];
                    final alreadyAdded = _knownLanguages
                        .any((l) => l['lang'] == lang['code']);
                    return ListTile(
                      leading: Text(lang['flag'] as String,
                          style: const TextStyle(fontSize: 30)),
                      title: Text(
                        lang['name'] as String,
                        style:
                            TextStyle(color: AppTheme.textPrimary),
                      ),
                      trailing: alreadyAdded
                          ? const Icon(Icons.check_circle,
                              color: AppTheme.accent)
                          : null,
                      onTap: alreadyAdded
                          ? null
                          : () {
                              Navigator.pop(ctx);
                              _showLevelPicker(
                                  lang['code'] as String);
                            },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showLevelPicker(String langCode) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Seviye Seç',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              ...AppConstants.languageLevels.map((level) {
                return ListTile(
                  title: Text(level,
                      style: TextStyle(
                          color: AppTheme.textPrimary)),
                  onTap: () {
                    setState(() {
                      _knownLanguages.add({
                        'lang': langCode,
                        'level': level,
                      });
                    });
                    Navigator.pop(ctx);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _addLearningLanguage() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Öğrenmek İstediğin Dil',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: AppConstants.languageRooms.length,
                  itemBuilder: (context, index) {
                    final lang = AppConstants.languageRooms[index];
                    final alreadyAdded = _learningLanguages
                        .any((l) => l['lang'] == lang['code']);
                    return ListTile(
                      leading: Text(lang['flag'] as String,
                          style: const TextStyle(fontSize: 30)),
                      title: Text(
                        lang['name'] as String,
                        style: TextStyle(color: AppTheme.textPrimary),
                      ),
                      trailing: alreadyAdded
                          ? const Icon(Icons.check_circle, color: AppTheme.accent)
                          : null,
                      onTap: alreadyAdded
                          ? null
                          : () {
                              Navigator.pop(ctx);
                              _showLearningLevelPicker(lang['code'] as String);
                            },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showLearningLevelPicker(String langCode) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hedef Seviye',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              ...AppConstants.languageLevels.map((level) {
                return ListTile(
                  title: Text(level,
                      style: TextStyle(color: AppTheme.textPrimary)),
                  onTap: () {
                    setState(() {
                      _learningLanguages.add({'lang': langCode, 'level': level});
                    });
                    Navigator.pop(ctx);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Profili Düzenle'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primary,
                    ),
                  )
                : const Text(
                    'Kaydet',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Stack(
                children: [
                  UserAvatar(
                    photoUrl: user?.photoUrl,
                    displayName: user?.displayName ?? '',
                    radius: 50,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _isUploadingImage ? null : _showPhotoOptionsSheet,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.surface, width: 2),
                        ),
                        child: _isUploadingImage
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.edit_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Name
            Text('Kullanıcı Adı',
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameController,
              style: TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.person_outline,
                    color: AppTheme.primary),
              ),
            ),
            const SizedBox(height: 20),
            // Bio
            Text('Biyografi',
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _bioController,
              maxLines: 3,
              style: TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Kendinden bahset...',
                prefixIcon: Icon(Icons.edit_note, color: AppTheme.primary),
              ),
            ),
            const SizedBox(height: 20),
            // City
            Text('Şehir',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _cityController,
              style: TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Yaşadığın şehir...',
                prefixIcon: Icon(Icons.location_city_rounded, color: AppTheme.primary),
              ),
            ),
            const SizedBox(height: 24),
            // Known languages
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Bildiğim Diller',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.add, color: AppTheme.primary, size: 20),
                  ),
                  onPressed: _addKnownLanguage,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_knownLanguages.isEmpty)
              Text(
                'Henüz dil eklenmedi',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _knownLanguages.map((lang) {
                return Chip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _getFlagForCode(lang['lang'] ?? ''),
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        lang['level'] ?? '',
                        style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  backgroundColor: AppTheme.surfaceLight,
                  deleteIconColor: AppTheme.danger,
                  onDeleted: () {
                    setState(() => _knownLanguages.remove(lang));
                  },
                  side: BorderSide(color: AppTheme.border),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            // Learning languages
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Öğrenmek İstediğim Diller',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.add, color: AppTheme.accent, size: 20),
                  ),
                  onPressed: _addLearningLanguage,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_learningLanguages.isEmpty)
              Text(
                'Öğrenmek istediğin dil yok',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _learningLanguages.map((lang) {
                return Chip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _getFlagForCode(lang['lang'] ?? ''),
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        lang['level'] ?? '',
                        style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  backgroundColor: AppTheme.accent.withValues(alpha: 0.1),
                  deleteIconColor: AppTheme.danger,
                  onDeleted: () {
                    setState(() => _learningLanguages.remove(lang));
                  },
                  side: BorderSide(color: AppTheme.accent.withValues(alpha: 0.4)),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Text(
              'İlgi Alanları',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            InterestTagsSelector(
              availableTags: const [
                "Yazılım", "Oyun", "Müzik", "Tasarım", "Dil Öğrenimi", 
                "Yapay Zeka", "Seyahat", "Sinema", "Kitap", "Spor", "Donanım"
              ],
              initialSelectedTags: _interests,
              onSelectionChanged: (selected) {
                setState(() => _interests = selected);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _getFlagForCode(String code) {
    final room = AppConstants.languageRooms.firstWhere(
      (r) => r['code'] == code,
      orElse: () => <String, dynamic>{'flag': '🏳️'},
    );
    return room['flag'] as String;
  }
}
