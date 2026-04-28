// lib/widgets/language_badge.dart
import 'package:flutter/material.dart';
import 'package:linguachat/config/theme.dart';
import 'package:linguachat/config/constants.dart';

class LanguageBadge extends StatelessWidget {
  final String languageCode;
  final String level;
  final bool compact;
  final bool isLearning;

  const LanguageBadge({
    super.key,
    required this.languageCode,
    required this.level,
    this.compact = false,
    this.isLearning = false,
  });

  @override
  Widget build(BuildContext context) {
    final room = AppConstants.languageRooms.firstWhere(
      (r) => r['code'] == languageCode,
      orElse: () => <String, dynamic>{'flag': '🏳️', 'name': languageCode, 'color': 0xFF8B949E},
    );

    final baseColor = Color(room['color'] as int);
    final color = isLearning ? AppTheme.accent : baseColor;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isLearning ? 0.08 : 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: isLearning ? 0.5 : 0.3),
          width: isLearning ? 1.2 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            room['flag'] as String,
            style: TextStyle(fontSize: compact ? 14 : 16),
          ),
          SizedBox(width: compact ? 4 : 6),
          if (!compact)
            Text(
              room['name'] as String,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          if (!compact) const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              level,
              style: TextStyle(
                color: color,
                fontSize: compact ? 9 : 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OnlineIndicator extends StatelessWidget {
  final bool isOnline;
  final double size;

  const OnlineIndicator({
    super.key,
    required this.isOnline,
    this.size = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isOnline ? AppTheme.accent : AppTheme.textSecondary,
        shape: BoxShape.circle,
        border: Border.all(
          color: AppTheme.background,
          width: 2,
        ),
        boxShadow: isOnline
            ? [
                BoxShadow(
                  color: AppTheme.accent.withValues(alpha: 0.4),
                  blurRadius: 6,
                ),
              ]
            : null,
      ),
    );
  }
}
