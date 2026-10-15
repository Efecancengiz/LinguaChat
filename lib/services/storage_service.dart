import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String?> uploadProfileImage(String uid, XFile file) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ref = _storage.ref().child('users/$uid/profile_$timestamp.jpg');
      final bytes = await file.readAsBytes().timeout(const Duration(seconds: 15));
      
      final metadata = SettableMetadata(
        contentType: file.mimeType ?? 'image/jpeg',
      );

      await ref.putData(bytes, metadata).timeout(const Duration(seconds: 30));
      return await ref.getDownloadURL().timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('Profile image upload error: $e');
      throw Exception('Yükleme hatası: $e');
    }
  }
}
