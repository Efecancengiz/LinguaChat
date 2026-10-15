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
  final Set<String> _syncedRooms = {};

  List<String> get _levels => [
    'Başlangıç (A1-A2)',
    'Orta (B1-B2)',
    'İleri (C1-C2)',
    'Ana Dil (C2+)'
  ];
  String _selectedLevel = 'Başlangıç (A1-A2)';

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
                    childAspectRatio: 0.58,
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

        if (snapshot.hasError) {
          debugPrint('RoomsListScreen rooms stream error: ${snapshot.error}');
        }

        final rooms = snapshot.data ?? [];

        // Background sync for rooms with stale/active member counts
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            for (final room in rooms) {
              if (room.memberCount > 0 && !_syncedRooms.contains(room.id)) {
                _syncedRooms.add(room.id);
                _firestoreService.syncRoomMembersCount(room.id);
              }
            }
          }
        });
        
        // Map of actual rooms fetched from Firestore
        final Map<String, RoomModel> firestoreRoomsMap = {
          for (var room in rooms) room.id : room
        };

        // Create the list of all language rooms for the selected level, merging stream data if available
        final levelRooms = AppConstants.languageRooms.map((room) {
          final docId = '${room['code']}_$_selectedLevel';
          final firestoreRoom = firestoreRoomsMap[docId];
          
          return RoomModel(
            id: docId,
            name: firestoreRoom?.name ?? '${room['name']} Room',
            languageCode: room['code'] as String,
            flagEmoji: firestoreRoom?.flagEmoji ?? room['flag'] as String,
            description: firestoreRoom?.description ?? '${room['name']} dilinde $_selectedLevel sohbet odası',
            memberCount: firestoreRoom?.memberCount ?? 0,
            level: _selectedLevel,
            lastMessage: firestoreRoom?.lastMessage,
            isCustom: false,
          );
        }).toList();

        return CustomScrollView(
          slivers: [
            _buildFilterPillsSliver(),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  childAspectRatio: 0.58,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final room = levelRooms[index];
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
                  childCount: levelRooms.length,
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
                final isDark = Theme.of(context).brightness == Brightness.dark;

                return GestureDetector(
                  onTap: () => setState(() => _selectedLevel = level),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primary
                          : (isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primary
                            : (isDark ? const Color(0xFF333333) : const Color(0xFFE2E8F0)),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      level,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : (isDark ? const Color(0xFFE2E8F0) : const Color(0xFF475569)),
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

