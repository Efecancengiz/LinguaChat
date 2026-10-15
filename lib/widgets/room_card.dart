// lib/widgets/room_card.dart
import 'package:flutter/material.dart';
import 'package:linguachat/config/theme.dart';
import 'package:linguachat/widgets/flag_sphere.dart';

class RoomCard extends StatefulWidget {
  final String name;
  final String flagEmoji;
  final String languageCode;
  final int memberCount;
  final String? lastMessage;
  final Color accentColor;
  final VoidCallback onTap;

  const RoomCard({
    super.key,
    required this.name,
    required this.flagEmoji,
    required this.languageCode,
    required this.memberCount,
    this.lastMessage,
    required this.accentColor,
    required this.onTap,
  });

  @override
  State<RoomCard> createState() => _RoomCardState();
}

class _RoomCardState extends State<RoomCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 120),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasMessage = widget.lastMessage != null && widget.lastMessage!.trim().isNotEmpty;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: child,
            );
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF121212) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isHovered
                    ? widget.accentColor.withValues(alpha: 0.6)
                    : (isDark ? const Color(0xFF262626) : const Color(0xFFE2E8F0)),
                width: 0.8,
              ),
              boxShadow: isDark
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 3D Flag Sphere
                FlagSphere(
                  languageCode: widget.languageCode,
                  flagEmoji: widget.flagEmoji,
                  size: 50,
                  glowColor: widget.accentColor,
                  showShadow: true,
                ),
                const SizedBox(height: 8),

                // Room Name
                Text(
                  widget.name,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    letterSpacing: -0.2,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),

                // Online Pill Badge (Always visible, clean design)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF064E3B).withValues(alpha: 0.45)
                        : const Color(0xFFE6FDF4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF059669) : const Color(0xFF86EFAC),
                      width: 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.25 : 0.15),
                        blurRadius: 4,
                        spreadRadius: 0.5,
                      ),
                    ],
                  ),
                  child: Text(
                    'Online: ${widget.memberCount}',
                    style: TextStyle(
                      color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
