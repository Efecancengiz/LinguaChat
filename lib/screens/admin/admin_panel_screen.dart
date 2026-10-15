// lib/screens/admin/admin_panel_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:linguachat/config/theme.dart';
import 'package:linguachat/services/firestore_service.dart';
import 'package:linguachat/models/user_model.dart';
import 'package:linguachat/widgets/user_avatar.dart';
import 'package:timeago/timeago.dart' as timeago;

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final FirestoreService _firestoreService = FirestoreService();
  String _userSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'ADMIN',
                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
            const Text('Yönetici Paneli', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: const [
            Tab(icon: Icon(Icons.report_problem_rounded, size: 20), text: 'Şikayetler & Raporlar'),
            Tab(icon: Icon(Icons.people_alt_rounded, size: 20), text: 'Kullanıcı Yönetimi'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildReportsTab(),
          _buildUsersTab(),
        ],
      ),
    );
  }

  // ── Tab 1: Gelen Raporlar ───────────────────────────────────────────
  Widget _buildReportsTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _firestoreService.getPendingReportsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
        }

        final reports = snapshot.data ?? [];

        if (reports.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_outline_rounded, color: AppTheme.accent, size: 60),
                ),
                const SizedBox(height: 16),
                Text(
                  'Bekleyen Şikayet Yok',
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tüm kullanıcı raporları incelenmiş ve temiz.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: reports.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final report = reports[index];
            final reportId = report['id'] as String;
            final type = report['type']?.toString() ?? 'unknown';
            final reason = report['reason']?.toString() ?? report['text']?.toString() ?? 'Belirtilmedi';
            final reportedUserId = report['reportedUserId']?.toString();
            final postId = report['postId']?.toString();

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.danger.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          type.toUpperCase(),
                          style: const TextStyle(
                            color: AppTheme.danger,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      Text(
                        'ID: ${reportId.substring(0, reportId.length > 6 ? 6 : reportId.length)}',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Şikayet / İçerik Nedeni:',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      reason,
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Action buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _firestoreService.resolveReport(reportId, action: 'dismissed'),
                        icon: const Icon(Icons.close_rounded, size: 16),
                        label: const Text('Reddet', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.textSecondary,
                          side: BorderSide(color: AppTheme.border),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (postId != null && postId.isNotEmpty) ...[
                        ElevatedButton.icon(
                          onPressed: () async {
                            await _firestoreService.adminDeletePost(postId);
                            await _firestoreService.resolveReport(reportId, action: 'deleted');
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Gönderi silindi ve rapor kapatıldı! ✅')),
                              );
                            }
                          },
                          icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.white),
                          label: const Text('Gönderiyi Sil', style: TextStyle(fontSize: 12, color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.danger,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ] else if (reportedUserId != null && reportedUserId.isNotEmpty) ...[
                        ElevatedButton.icon(
                          onPressed: () => _showBanUserDialog(reportedUserId, reportId: reportId),
                          icon: const Icon(Icons.block_rounded, size: 16, color: Colors.white),
                          label: const Text('Yasakla (Ban)', style: TextStyle(fontSize: 12, color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.danger,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ] else ...[
                        ElevatedButton.icon(
                          onPressed: () => _firestoreService.resolveReport(reportId, action: 'resolved'),
                          icon: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                          label: const Text('Onayla & Kapat', style: TextStyle(fontSize: 12, color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accent,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Tab 2: Kullanıcı Yönetimi ────────────────────────────────────────
  Widget _buildUsersTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            style: TextStyle(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'Kullanıcı adı veya ID ara...',
              prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primary),
              filled: true,
              fillColor: AppTheme.surfaceLight,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (val) => setState(() => _userSearchQuery = val.trim().toLowerCase()),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<UserModel>>(
            stream: _firestoreService.getAdminAllUsersStream(limit: 100),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
              }

              final allUsers = snapshot.data ?? [];
              final filtered = _userSearchQuery.isEmpty
                  ? allUsers
                  : allUsers.where((u) {
                      return u.displayName.toLowerCase().contains(_userSearchQuery) ||
                             u.uid.toLowerCase().contains(_userSearchQuery) ||
                             u.email.toLowerCase().contains(_userSearchQuery);
                    }).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Text('Kullanıcı bulunamadı.', style: TextStyle(color: AppTheme.textSecondary)),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: filtered.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final user = filtered[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    leading: UserAvatar(
                      photoUrl: user.photoUrl,
                      displayName: user.displayName,
                      radius: 22,
                    ),
                    title: Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.displayName,
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (user.isAdmin) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('ADMIN', style: TextStyle(color: Color(0xFF8B5CF6), fontSize: 9, fontWeight: FontWeight.bold)),
                          ),
                        ],
                        if (user.isBanned) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: AppTheme.danger.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('YASAKLI', style: TextStyle(color: AppTheme.danger, fontSize: 9, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Text(
                      'Kayıt: ${timeago.format(user.createdAt, locale: 'tr')}',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                    ),
                    trailing: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded),
                      onSelected: (action) {
                        if (action == 'ban') {
                          _showBanUserDialog(user.uid, userName: user.displayName, isCurrentlyBanned: user.isBanned);
                        } else if (action == 'admin') {
                          _firestoreService.adminSetUserAdminRole(user.uid, !user.isAdmin);
                        } else if (action == 'profile') {
                          context.push('/user/${user.uid}');
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'profile',
                          child: Row(
                            children: [
                              Icon(Icons.person_outline_rounded, size: 18),
                              SizedBox(width: 8),
                              Text('Profili Gör'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'ban',
                          child: Row(
                            children: [
                              Icon(
                                user.isBanned ? Icons.lock_open_rounded : Icons.block_rounded,
                                size: 18,
                                color: user.isBanned ? AppTheme.accent : AppTheme.danger,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                user.isBanned ? 'Yasağı Kaldır' : 'Kullanıcıyı Yasakla',
                                style: TextStyle(color: user.isBanned ? AppTheme.accent : AppTheme.danger),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'admin',
                          child: Row(
                            children: [
                              const Icon(Icons.admin_panel_settings_outlined, size: 18),
                              const SizedBox(width: 8),
                              Text(user.isAdmin ? 'Admin Yetkisini Al' : 'Admin Yap'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showBanUserDialog(String uid, {String? userName, String? reportId, bool isCurrentlyBanned = false}) {
    if (isCurrentlyBanned) {
      // Unban directly with confirmation
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Yasağı Kaldır'),
          content: Text('${userName ?? 'Bu kullanıcının'} yasağını kaldırmak istiyor musunuz?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _firestoreService.adminSetUserBanStatus(uid, false);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Kullanıcının yasağı kaldırıldı! ✅')),
                  );
                }
              },
              child: const Text('Yasağı Kaldır'),
            ),
          ],
        ),
      );
      return;
    }

    final reasonController = TextEditingController(text: 'Topluluk kurallarını ihlal (Uygunsuz içerik / mesaj)');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('${userName ?? 'Kullanıcı'} Yasakla (Ban)', style: const TextStyle(color: AppTheme.danger)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Yasaklama Sebebi:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'Sebebi girin...',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _firestoreService.adminSetUserBanStatus(uid, true, reason: reasonController.text.trim());
              if (reportId != null) {
                await _firestoreService.resolveReport(reportId, action: 'banned');
              }
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Kullanıcı yasaklandı! 🚫'), backgroundColor: AppTheme.danger),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('Yasakla', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
