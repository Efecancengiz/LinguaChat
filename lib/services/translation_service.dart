import 'package:translator/translator.dart';

class TranslationService {
  final GoogleTranslator _translator = GoogleTranslator();

  // Çeviri fonksiyonu
  Future<String> translateText(String originalText, String targetLang) async {
    try {
      if (originalText.trim().isEmpty) return '';
      
      final translation = await _translator.translate(
        originalText,
        to: targetLang,
      );
      return translation.text;
    } catch (e) {
      // Hata anında orijinal metni dön
      return originalText;
    }
  }
}
