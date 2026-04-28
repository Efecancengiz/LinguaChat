import 'package:flutter/material.dart';

/// Kullanıcının ilgi alanlarını seçebileceği ve yönetebileceği modüler FilterChip yapısı
class InterestTagsSelector extends StatefulWidget {
  final List<String> availableTags;
  final List<String> initialSelectedTags;
  final ValueChanged<List<String>> onSelectionChanged;

  const InterestTagsSelector({
    super.key,
    required this.availableTags,
    this.initialSelectedTags = const [],
    required this.onSelectionChanged,
  });

  @override
  State<InterestTagsSelector> createState() => _InterestTagsSelectorState();
}

class _InterestTagsSelectorState extends State<InterestTagsSelector> {
  late final List<String> _selectedTags;

  @override
  void initState() {
    super.initState();
    _selectedTags = List.from(widget.initialSelectedTags);
  }

  void _toggleTag(String tag, bool isSelected) {
    setState(() {
      if (isSelected) {
        _selectedTags.add(tag);
      } else {
        _selectedTags.remove(tag);
      }
    });
    // Her değişimde üst widget'ı bilgilendiriyoruz
    widget.onSelectionChanged(_selectedTags);
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12.0, // Yatay boşluk
      runSpacing: 12.0, // Dikey boşluk
      children: widget.availableTags.map((tag) {
        final isSelected = _selectedTags.contains(tag);
        
        return FilterChip(
          label: Text(
            tag,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white60,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          selected: isSelected,
          onSelected: (bool selected) {
            _toggleTag(tag, selected);
          },
          // Koyu temaya uygun neon mor ve gri tonları
          selectedColor: Colors.deepPurpleAccent,
          checkmarkColor: Colors.white,
          backgroundColor: const Color(0xFF2C2C3E), // Transparan/koyu gri
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isSelected ? Colors.deepPurpleAccent : Colors.transparent,
              width: 1.5,
            ),
          ),
          showCheckmark: true,
          elevation: isSelected ? 8 : 0, // Seçildiğinde neon parlaması etkisi için
          shadowColor: Colors.deepPurpleAccent.withValues(alpha: 0.6),
        );
      }).toList(),
    );
  }
}

/// Ortak ilgi alanlarını tespit eden ve özel bildirim Dialog'u gösteren yardımcı sınıf
class InterestMatchHelper {
  
  /// İki kullanıcının ilgi alanı listelerini karşılaştırır ve ortak olanları List olarak döner.
  static List<String> findCommonInterests(List<String> user1Tags, List<String> user2Tags) {
    final set1 = user1Tags.toSet();
    final set2 = user2Tags.toSet();
    return set1.intersection(set2).toList();
  }

  /// Eğer ortak ilgi alanı varsa ekranda şık, animasyonlu bir dark theme Dialog gösterir.
  static void checkAndShowMatchNotification({
    required BuildContext context,
    required List<String> currentUserTags,
    required List<String> otherUserTags,
    required VoidCallback onStartChat,
  }) {
    final commonTags = findCommonInterests(currentUserTags, otherUserTags);

    // Eğer ortak ilgi alanı varsa popup göster
    if (commonTags.isNotEmpty) {
      // Birden fazla varsa ilkini vurgula, veya en favori olanı seç.
      final highlightedTag = commonTags.first;
      
      showDialog(
        context: context,
        builder: (context) {
          return Dialog(
            backgroundColor: const Color(0xFF1E1E2C), // Koyu tema diyalog arkaplanı
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24.0),
              side: BorderSide(
                color: Colors.deepPurpleAccent.withValues(alpha: 0.3), 
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animasyonlu/Göze çarpan bir İkon Kutucuğu
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.deepPurpleAccent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.deepPurpleAccent.withValues(alpha: 0.4),
                          blurRadius: 16,
                          spreadRadius: 2,
                        )
                      ]
                    ),
                    child: const Icon(
                      Icons.diversity_1_rounded,
                      color: Colors.deepPurpleAccent,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Başlık
                  const Text(
                    "Harika Bir Eşleşme! 🎉",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // İçerik ve vurgulu ilgi alanı
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        height: 1.5,
                      ),
                      children: [
                        const TextSpan(text: "İkiniz de "),
                        TextSpan(
                          text: highlightedTag, // "Yazılım", "Oyun" vb.
                          style: const TextStyle(
                            color: Colors.deepPurpleAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const TextSpan(text: " ile ilgileniyorsunuz. Sohbete buradan başlamaya ne dersin? 🚀"),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  
                  // Aksiyon Butonu
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurpleAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 8,
                        shadowColor: Colors.deepPurpleAccent.withValues(alpha: 0.6),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop(); // Dialogu kapat
                        onStartChat(); // Dışarıdan verilen sohbet başlatma fonksiyonunu tetikle
                      },
                      child: const Text(
                        "Sohbete Başla",
                        style: TextStyle(
                          fontSize: 16, 
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  // Kapatma/Geçme Butonu
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white54,
                    ),
                    child: const Text("Belki Daha Sonra"),
                  )
                ],
              ),
            ),
          );
        },
      );
    }
  }
}
