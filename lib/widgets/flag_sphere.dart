// lib/widgets/flag_sphere.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class FlagSphere extends StatelessWidget {
  final String languageCode;
  final String flagEmoji;
  final double size;
  final Color? glowColor;
  final bool showShadow;

  const FlagSphere({
    super.key,
    required this.languageCode,
    required this.flagEmoji,
    this.size = 54,
    this.glowColor,
    this.showShadow = true,
  });

  /// Converts regional indicator symbols in emoji flag to ISO 3166-1 alpha-2 country code
  static String getCountryCode(String languageCode, String flagEmoji) {
    if (flagEmoji.runes.length >= 2) {
      final runes = flagEmoji.runes.toList();
      if (runes[0] >= 0x1F1E6 && runes[0] <= 0x1F1FF &&
          runes[1] >= 0x1F1E6 && runes[1] <= 0x1F1FF) {
        final firstChar = String.fromCharCode(runes[0] - 0x1F1E6 + 0x61);
        final secondChar = String.fromCharCode(runes[1] - 0x1F1E6 + 0x61);
        return '$firstChar$secondChar';
      }
    }

    final codeMap = <String, String>{
      'en': 'gb',
      'zh': 'cn',
      'hi': 'in',
      'es': 'es',
      'fr': 'fr',
      'ar': 'sa',
      'bn': 'in',
      'ru': 'ru',
      'pt': 'br',
      'id': 'id',
      'de': 'de',
      'ja': 'jp',
      'tr': 'tr',
      'ko': 'kr',
      'vi': 'vn',
      'it': 'it',
      'th': 'th',
      'pl': 'pl',
      'nl': 'nl',
      'el': 'gr',
      'sv': 'se',
      'no': 'no',
      'fi': 'fi',
      'da': 'dk',
      'uk': 'ua',
      'cs': 'cz',
      'hu': 'hu',
      'ro': 'ro',
      'he': 'il',
      'fa': 'ir',
      'ur': 'pk',
      'sw': 'ke',
      'tl': 'ph',
      'ms': 'my',
      'af': 'za',
      'sq': 'al',
      'am': 'et',
      'hy': 'am',
      'az': 'az',
      'eu': 'es',
      'be': 'by',
      'bs': 'ba',
      'bg': 'bg',
      'my': 'mm',
      'ca': 'es',
      'ceb': 'ph',
      'ny': 'mw',
      'co': 'fr',
      'hr': 'hr',
      'et': 'ee',
      'fj': 'fj',
      'gl': 'es',
      'ka': 'ge',
      'gu': 'in',
      'ht': 'ht',
      'ha': 'ng',
      'haw': 'us',
      'is': 'is',
      'ig': 'ng',
      'ga': 'ie',
      'jv': 'id',
      'kn': 'in',
      'kk': 'kz',
      'km': 'kh',
      'rw': 'rw',
      'ku': 'iq',
      'ky': 'kg',
      'lo': 'la',
      'la': 'va',
      'lv': 'lv',
      'lt': 'lt',
      'lb': 'lu',
      'mk': 'mk',
      'mg': 'mg',
      'ml': 'in',
      'mt': 'mt',
      'mi': 'nz',
      'mr': 'in',
      'mn': 'mn',
      'ne': 'np',
      'ps': 'af',
      'pa': 'in',
      'sm': 'ws',
      'gd': 'gb',
      'sr': 'rs',
      'st': 'ls',
      'sn': 'zw',
      'sd': 'pk',
      'si': 'lk',
      'sk': 'sk',
      'sl': 'si',
      'so': 'so',
      'su': 'id',
      'tg': 'tj',
      'ta': 'in',
      'tt': 'ru',
      'te': 'in',
      'tk': 'tm',
      'uz': 'uz',
      'cy': 'gb',
      'xh': 'za',
      'yi': 'il',
      'yo': 'ng',
      'zu': 'za',
    };

    return codeMap[languageCode.toLowerCase()] ?? 'un';
  }

  @override
  Widget build(BuildContext context) {
    final countryCode = getCountryCode(languageCode, flagEmoji);
    final accent = glowColor ?? const Color(0xFF3B82F6);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.38),
                  blurRadius: 14,
                  spreadRadius: 2,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: ClipOval(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Base High-Res Flag Image from Flagcdn
            CachedNetworkImage(
              imageUrl: 'https://flagcdn.com/w160/$countryCode.png',
              fit: BoxFit.cover,
              fadeInDuration: const Duration(milliseconds: 150),
              placeholder: (context, url) => _buildEmojiFallback(),
              errorWidget: (context, url, error) => _buildEmojiFallback(),
            ),
            // 2. 3D Spherical Volume & Curvature Shading (Realistic Marble Depth)
            Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.35, -0.35),
                  radius: 0.90,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.05),
                    Colors.black.withValues(alpha: 0.25),
                    Colors.black.withValues(alpha: 0.58),
                  ],
                  stops: const [0.0, 0.40, 0.70, 1.0],
                ),
              ),
            ),
            // 3. Top-Left Specular Highlight (High Gloss Shine Glare)
            Positioned(
              top: size * 0.06,
              left: size * 0.12,
              child: Container(
                width: size * 0.52,
                height: size * 0.28,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.all(
                    Radius.elliptical(size * 0.52, size * 0.28),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.85),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            // 4. Subtle Bottom Ambient Reflection Light
            Positioned(
              bottom: size * 0.03,
              right: size * 0.10,
              child: Container(
                width: size * 0.45,
                height: size * 0.20,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.all(
                    Radius.elliptical(size * 0.45, size * 0.20),
                  ),
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.35),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // 5. Outer Glass Rim Ring
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.50),
                  width: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmojiFallback() {
    return Container(
      color: Colors.white.withValues(alpha: 0.95),
      child: Center(
        child: Text(
          flagEmoji,
          style: TextStyle(fontSize: size * 0.55),
        ),
      ),
    );
  }
}
