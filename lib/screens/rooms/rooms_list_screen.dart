// lib/screens/rooms/rooms_list_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:linguachat/config/theme.dart';
import 'package:linguachat/config/constants.dart';
import 'package:linguachat/services/firestore_service.dart';
import 'package:linguachat/models/room_model.dart';
import 'package:linguachat/widgets/room_card.dart';

class RoomsListScreen extends StatefulWidget {
  const RoomsListScreen({super.key});

  @override
  State<RoomsListScreen> createState() => _RoomsListScreenState();
}

class _RoomsListScreenState extends State<RoomsListScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  static bool _roomsInitialized = false;

  final List<String> _levels = [
    'Tümü',
    'Başlangıç (A1-A2)',
    'Orta (B1-B2)',
    'İleri (C1-C2)',
    'Ana Dil (C2+)'
  ];
  String _selectedLevel = 'Tümü';

  @override
  void initState() {
    super.initState();
    if (!_roomsInitialized) {
      _firestoreService.initializeRooms();
      _roomsInitialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        StreamBuilder<List<RoomModel>>(
      stream: _firestoreService.roomsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CustomScrollView(
            slivers: [
              _buildFilterPillsSliver(),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    childAspectRatio: 0.65,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildShimmerCard(),
                    childCount: 6,
                  ),
                ),
              ),
            ],
          );
        }

        final rooms = snapshot.data ?? [];
        
        // Seçilen seviyeye göre filtreleme (Özel odaları gizle)
        final filteredRooms = rooms.where((room) {
          if (room.isCustom) return false;
          if (_selectedLevel == 'Tümü') {
            return room.level == 'Tümü' || room.level == null;
          }
          return room.level == _selectedLevel;
        }).toList();

        // Eğer veritabanı boşsa (örneğin offline durum) veya yüklenememişse, o anki filtrenin varsayılan odaları üretilsin
        final defaultRooms = AppConstants.languageRooms.map((room) {
          return {
            'code': _selectedLevel == 'Tümü' ? room['code'] : '${room['code']}_$_selectedLevel',
            'name': room['name'],
            'flag': room['flag'],
            'color': room['color'],
          };
        }).toList();

        final hasRooms = filteredRooms.isNotEmpty;
        final count = hasRooms ? filteredRooms.length : defaultRooms.length;

        return CustomScrollView(
          slivers: [
            _buildFilterPillsSliver(),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  childAspectRatio: 0.65,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (!hasRooms) {
                      final room = defaultRooms[index];
                      return RoomCard(
                        name: '${room['name']} Room',
                        flagEmoji: room['flag'] as String,
                        languageCode: room['code'] as String,
                        memberCount: 0,
                        accentColor: Color(room['color'] as int),
                        onTap: () => context.push(
                          '/room/${room['code']}',
                          extra: {
                            'name': '${room['name']} Room',
                            'flag': room['flag'],
                          },
                        ),
                      );
                    }

                    final room = filteredRooms[index];
                    return RoomCard(
                      name: room.name,
                      flagEmoji: room.flagEmoji,
                      languageCode: room.languageCode,
                      memberCount: room.memberCount,
                      lastMessage: room.lastMessage?['text'],
                      accentColor: AppConstants.getColorFromCode(room.languageCode),
                      onTap: () => context.push(
                        '/room/${room.id}',
                        extra: {
                          'name': room.name,
                          'flag': room.flagEmoji,
                          'languageCode': room.languageCode,
                        },
                      ),
                    );
                  },
                  childCount: count,
                ),
              ),
            ),
          ],
        );
      },
    ),
   ],
  );
 }

  Widget _buildFilterPillsSliver() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: 120, bottom: 24),
        child: SizedBox(
          height: 40,
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              dragDevices: {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
                PointerDeviceKind.trackpad,
              },
            ),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _levels.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final level = _levels[index];
                final isSelected = _selectedLevel == level;
                return GestureDetector(
                  onTap: () => setState(() => _selectedLevel = level),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primary : AppTheme.surfaceLight.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: isSelected ? AppTheme.primary : AppTheme.border.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      level,
                      style: TextStyle(
                        color: isSelected ? Colors.white : AppTheme.textSecondary,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            color: AppTheme.primary.withValues(alpha: 0.3),
            strokeWidth: 2,
          ),
        ),
      ),
    );
  }
}

