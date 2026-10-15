import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_fortune_wheel/flutter_fortune_wheel.dart';
import 'package:provider/provider.dart';
import 'package:linguachat/config/theme.dart';
import 'package:linguachat/providers/auth_provider.dart';
import 'package:linguachat/services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FortuneWheelScreen extends StatefulWidget {
  const FortuneWheelScreen({super.key});

  @override
  State<FortuneWheelScreen> createState() => _FortuneWheelScreenState();
}

class _FortuneWheelScreenState extends State<FortuneWheelScreen> {
  StreamController<int> selected = StreamController<int>();

  final items = <String>[
    '5 Dk',
    'Pas',
    '10 Dk',
    'Pas',
    '15 Dk',
    'Pas',
    '20 Dk',
    'Pas',
    '25 Dk',
    'Pas',
    '30 Dk',
    'Pas',
  ];

  final itemMinutes = <int>[
    5,
    0,
    10,
    0,
    15,
    0,
    20,
    0,
    25,
    0,
    30,
    0,
  ];

  bool _isSpinning = false;
  bool _hasSpunToday = false;
  int? _lastSpunValue;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkSpinStatus();
    });
  }

  void _checkSpinStatus() async {
    final uid = context.read<AuthProvider>().user?.uid;
    if (uid == null) return;

    final userDoc = await FirestoreService().getUser(uid);
    if (userDoc?.lastSpinDate != null) {
      final now = DateTime.now();
      if (userDoc!.lastSpinDate!.year == now.year &&
          userDoc.lastSpinDate!.month == now.month &&
          userDoc.lastSpinDate!.day == now.day) {
        if (mounted) {
          setState(() {
            _hasSpunToday = true;
          });
        }
      }
    }
  }

  Color _getSliceColor(int index) {
    final colors = [
      const Color(0xFF0D6EFD), // Blue
      const Color(0xFF198754), // Green
      const Color(0xFFDC3545), // Red
      const Color(0xFFFFC107), // Yellow
      const Color(0xFF6F42C1), // Purple
      const Color(0xFF0DCAF0), // Cyan
    ];
    return colors[index % colors.length];
  }

  @override
  void dispose() {
    selected.close();
    super.dispose();
  }

  void _spin() {
    if (_hasSpunToday || _isSpinning) {
      if (_hasSpunToday && !_isSpinning) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bugünkü çevirme hakkınızı kullandınız. Yarın tekrar bekleriz!'),
            backgroundColor: AppTheme.warning,
          ),
        );
      }
      return;
    }

    setState(() {
      _isSpinning = true;
    });

    final value = Fortune.randomInt(0, items.length);
    _lastSpunValue = value;
    selected.add(value);
  }

  void _onSpinComplete() async {
    if (_lastSpunValue == null) return;
    final value = _lastSpunValue!;
    final extraMinutes = itemMinutes[value];

    final uid = context.read<AuthProvider>().user?.uid;
    if (uid != null) {
      await FirestoreService().updateUser(uid, {
        'bonusMinutes': extraMinutes,
        'lastSpinDate': Timestamp.now(),
      });
      if (mounted) {
        await context.read<AuthProvider>().refreshUser();
      }
    }

    if (mounted) {
      setState(() {
        _isSpinning = false;
        _hasSpunToday = true;
      });

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            extraMinutes > 0 ? 'Tebrikler! 🎉' : 'Maalesef! 😢',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Text(
            extraMinutes > 0
                ? 'Tebrikler, $extraMinutes dakika kazandınız!'
                : 'Pas geldi! Bu sefer ödül kazanamadın. Şansını yarın tekrar dene!',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tamam', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF0F0C20), // Dark Indigo
              Color(0xFF06040A), // Near Black
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom Premium Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Text(
                      'Şans Çarkı',
                      style: TextStyle(
                        color: Colors.amber,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        shadows: [
                          Shadow(
                            color: Colors.amberAccent,
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 48), // Spacer to balance back button
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // The Wheel Section with Gold Frame
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: AspectRatio(
                      aspectRatio: 1.0,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Glow behind the frame
                          Container(
                            width: double.infinity,
                            height: double.infinity,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.amber.withValues(alpha: 0.15),
                                  blurRadius: 40,
                                  spreadRadius: 10,
                                ),
                              ],
                            ),
                          ),
                          // Golden frame image
                          Image.asset(
                            'assets/images/fortune_wheel_frame.png',
                            fit: BoxFit.contain,
                          ),
                          // Fortune wheel overlaid inside the golden frame
                          FractionallySizedBox(
                            widthFactor: 0.77,
                            heightFactor: 0.77,
                            child: FortuneWheel(
                              animateFirst: false,
                              selected: selected.stream,
                              indicators: <FortuneIndicator>[
                                // Gold Top pointer
                                FortuneIndicator(
                                  alignment: Alignment.topCenter,
                                  child: Container(
                                    transform: Matrix4.translationValues(0.0, -10.0, 0.0),
                                    child: const Icon(
                                      Icons.arrow_drop_down_rounded,
                                      color: Colors.amberAccent,
                                      size: 54,
                                    ),
                                  ),
                                ),
                                // Center Gold Star Cap
                                FortuneIndicator(
                                  alignment: Alignment.center,
                                  child: Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: Colors.amber,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.amberAccent, width: 3),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.amber.withValues(alpha: 0.5),
                                          blurRadius: 10,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.star_rounded,
                                      color: Colors.white,
                                      size: 26,
                                    ),
                                  ),
                                ),
                              ],
                              items: [
                                for (int i = 0; i < items.length; i++)
                                  FortuneItem(
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 30.0),
                                      child: Text(
                                        items[i],
                                        style: TextStyle(
                                          fontSize: items[i] == 'Pas' ? 14 : 16,
                                          fontWeight: FontWeight.w900,
                                          color: items[i] == 'Pas' ? Colors.white70 : Colors.white,
                                          shadows: const [
                                            Shadow(
                                              color: Colors.black54,
                                              offset: Offset(1, 1),
                                              blurRadius: 3,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    style: FortuneItemStyle(
                                      color: _getSliceColor(i),
                                      borderColor: Colors.amber.withValues(alpha: 0.3),
                                      borderWidth: 2,
                                    ),
                                  ),
                              ],
                              onAnimationEnd: _onSpinComplete,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Description Info Box
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Şansını Dene, Süre Kazan!',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Günde 1 kez çarkı çevirerek ücretsiz ek konuşma süresi kazanabilirsin! Pas hariç gelen tüm süreler anında mevcut dakikana eklenir.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),

              // Spin Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: _hasSpunToday
                        ? []
                        : [
                            BoxShadow(
                              color: Colors.amber.withValues(alpha: 0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                  ),
                  child: ElevatedButton(
                    onPressed: _hasSpunToday ? null : _spin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      disabledBackgroundColor: Colors.white.withValues(alpha: 0.1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: EdgeInsets.zero,
                    ),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: _hasSpunToday
                            ? null
                            : const LinearGradient(
                                colors: [
                                  Color(0xFFFFD700), // Gold
                                  Color(0xFFFFA500), // Orange
                                ],
                              ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Container(
                        alignment: Alignment.center,
                        child: Text(
                          _hasSpunToday ? 'Bugün Çevrildi' : 'Çarkı Çevir',
                          style: TextStyle(
                            color: _hasSpunToday ? Colors.white38 : Colors.black,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
