import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:linguachat/config/theme.dart';
import 'package:linguachat/providers/auth_provider.dart';
import 'package:linguachat/services/firestore_service.dart';
import 'package:linguachat/models/post_model.dart';
import 'package:linguachat/widgets/user_avatar.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _contentController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  bool _isPosting = false;
  XFile? _selectedImage;
  double _uploadProgress = 0;

  /// 'everyone' veya 'friends'
  String _audience = 'everyone';

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        // imageQuality ve maxWidth parametreleri iOS'ta re-encoding bug'ına (0 byte dosya veya crash)
        // yol açabildiği için kaldırıldı. Orijinal dosyayı değiştirmeden alır.
      );
      if (picked != null) {
        setState(() => _selectedImage = picked);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fotoğraf seçilemedi: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  void _showImageSourceSheet() {
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
              const Text('Fotoğraf Ekle', style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              )),
              const SizedBox(height: 16),
              _SourceTile(
                icon: Icons.photo_library_rounded,
                label: 'Galeriden Seç',
                onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.gallery); },
              ),
              const SizedBox(height: 8),
              _SourceTile(
                icon: Icons.camera_alt_rounded,
                label: 'Kamera ile Çek',
                onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.camera); },
              ),
              if (_selectedImage != null) ...[
                const SizedBox(height: 8),
                _SourceTile(
                  icon: Icons.delete_outline_rounded,
                  label: 'Fotoğrafı Kaldır',
                  color: AppTheme.danger,
                  onTap: () { Navigator.pop(ctx); setState(() => _selectedImage = null); },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _uploadImage(String uid) async {
    if (_selectedImage == null) return null;
    
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('posts/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg');
          
      // Read bytes directly like StorageService
      final bytes = await _selectedImage!.readAsBytes().timeout(const Duration(seconds: 15));
      
      if (bytes.isEmpty) {
        throw Exception("Seçilen görsel okunamadı. Lütfen başka bir görsel seçin.");
      }
      
      final metadata = SettableMetadata(
        contentType: _selectedImage!.mimeType ?? 'image/jpeg',
      );
      
      // Upload using putData with timeout
      setState(() => _uploadProgress = 0.5); 
      
      try {
        await ref.putData(bytes, metadata).timeout(const Duration(seconds: 30));
      } catch (e) {
        throw Exception("Dosya Firebase'e yüklenirken hata oluştu: $e");
      }
      
      setState(() => _uploadProgress = 1.0);
      
      await Future.delayed(const Duration(milliseconds: 500));
      
      int retryCount = 0;
      while (true) {
        try {
          return await ref.getDownloadURL().timeout(const Duration(seconds: 10));
        } catch (e) {
          if (retryCount >= 4) {
            throw Exception("Dosya yüklendi ancak linki alınamadı (4 deneme başarısız): $e");
          }
          retryCount++;
          await Future.delayed(const Duration(seconds: 1)); // 1 saniye bekle ve tekrar dene
        }
      }
    } catch (e) {
      debugPrint('UploadImage error: $e');
      rethrow;
    }
  }

  Future<void> _submitPost(BuildContext context, String uid, String name, String photoUrl) async {
    final content = _contentController.text.trim();
    if (content.isEmpty && _selectedImage == null) return;

    setState(() { _isPosting = true; _uploadProgress = 0; });

    try {
      String? imageUrl;
      if (_selectedImage != null) {
        imageUrl = await _uploadImage(uid);
      }

      final post = PostModel(
        id: '',
        userId: uid,
        userDisplayName: name,
        userPhotoUrl: photoUrl,
        content: content,
        imageUrl: imageUrl,
        audience: _audience,
      );

      final firestoreService = FirestoreService();
      await firestoreService.createPost(post);

      if (!context.mounted) return;
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gönderi paylaşıldı!'),
          backgroundColor: AppTheme.accent,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      debugPrint('CreatePost hata: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gönderi paylaşılamadı:\n$e'),
          backgroundColor: AppTheme.danger,
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) return const Scaffold();

    final hasContent = _contentController.text.trim().isNotEmpty || _selectedImage != null;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppTheme.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text('Yeni Gönderi',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SizedBox(
              height: 36,
              width: 90,
              child: ElevatedButton(
                onPressed: hasContent && !_isPosting
                    ? () => _submitPost(context, user.uid, user.displayName, user.photoUrl)
                    : null,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  backgroundColor: AppTheme.primary,
                  disabledBackgroundColor: AppTheme.surfaceLight,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isPosting
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Paylaş', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.surfaceGradient),
        child: Column(
          children: [
            if (_isPosting && _selectedImage != null)
              LinearProgressIndicator(
                value: _uploadProgress,
                backgroundColor: AppTheme.surfaceLight,
                color: AppTheme.primary,
                minHeight: 3,
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Kullanıcı & metin alanı ────────────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        UserAvatar(
                          photoUrl: user.photoUrl,
                          displayName: user.displayName,
                          radius: 24,
                          showOnlineIndicator: false,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: _contentController,
                            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 17, height: 1.5),
                            maxLines: null,
                            autofocus: _selectedImage == null,
                            decoration: InputDecoration(
                              hintText: 'Neler öğreniyorsun? Düşüncelerini paylaş...',
                              hintStyle: TextStyle(
                                color: AppTheme.textSecondary.withValues(alpha: 0.5),
                                fontSize: 17,
                              ),
                              border: InputBorder.none,
                            ),
                            onChanged: (text) => setState(() {}),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ── Kitle Seçici ────────────────────────────────────
                    _AudienceSelector(
                      selected: _audience,
                      onChanged: (val) => setState(() => _audience = val),
                    ),

                    // ── Seçili görsel ───────────────────────────────────
                    if (_selectedImage != null) ...[
                      const SizedBox(height: 16),
                      Stack(
                        alignment: Alignment.topRight,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.file(
                              File(_selectedImage!.path),
                              width: double.infinity,
                              fit: BoxFit.cover,
                              filterQuality: FilterQuality.high,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedImage = null),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, color: Colors.white, size: 18),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // ── Alt araç çubuğu ─────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
              decoration: BoxDecoration(
                color: AppTheme.surface.withValues(alpha: 0.95),
                border: const Border(top: BorderSide(color: AppTheme.border, width: 0.5)),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    _ToolbarButton(
                      icon: Icons.photo_library_rounded,
                      label: 'Galeri',
                      onTap: _showImageSourceSheet,
                    ),
                    _ToolbarButton(
                      icon: Icons.camera_alt_rounded,
                      label: 'Kamera',
                      onTap: () => _pickImage(ImageSource.camera),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// KİTLE SEÇİCİ (Herkes / Arkadaşlar)
// ─────────────────────────────────────────────────────────────
class _AudienceSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _AudienceSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Kim görebilir?',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _AudienceChip(
              icon: Icons.public_rounded,
              label: 'Herkes',
              value: 'everyone',
              selected: selected,
              onTap: onChanged,
            ),
            const SizedBox(width: 10),
            _AudienceChip(
              icon: Icons.people_rounded,
              label: 'Arkadaşlar',
              value: 'friends',
              selected: selected,
              onTap: onChanged,
            ),
          ],
        ),
      ],
    );
  }
}

class _AudienceChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String selected;
  final ValueChanged<String> onTap;

  const _AudienceChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected ? AppTheme.primaryGradient : null,
          color: isSelected ? null : AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : AppTheme.border.withValues(alpha: 0.5),
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : AppTheme.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// KAYNAK TILE
// ─────────────────────────────────────────────────────────────
class _SourceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _SourceTile({required this.icon, required this.label, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.textPrimary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color ?? AppTheme.primary, size: 22),
            const SizedBox(width: 14),
            Text(label, style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 15)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TOOLBAR BUTTON
// ─────────────────────────────────────────────────────────────
class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ToolbarButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.primary, size: 22),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
