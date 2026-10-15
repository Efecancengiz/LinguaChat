// lib/screens/network/network_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:linguachat/config/theme.dart';
import 'package:linguachat/providers/auth_provider.dart';
import 'package:linguachat/services/firestore_service.dart';
import 'package:linguachat/models/user_model.dart';
import 'package:linguachat/models/friend_request_model.dart';
import 'package:linguachat/widgets/user_avatar.dart';

class NetworkScreen extends StatefulWidget {
  const NetworkScreen({super.key});

  @override
  State<NetworkScreen> createState() => _NetworkScreenState();
}

class _NetworkScreenState extends State<NetworkScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // context.watch kullanarak Firebase verisi yüklendiğinde sayfanın güncellenmesini (açılmasını) sağladık
    final currentUserId = context.watch<AuthProvider>().currentUserId;
    final currentUser = context.watch<AuthProvider>().user;

    if (currentUserId == null || currentUser == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent, // the background comes from the parent home_screen
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.surfaceGradient,
        ),
        child: Column(
          children: [
            // Top padding for the safe area as this doesn't have an AppBar directly
            SizedBox(height: MediaQuery.of(context).padding.top + 56), 
            
            // Search Bar (Arama Çubuğu)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                ),
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Kullanıcı adı ara...',
                    hintStyle: TextStyle(color: AppTheme.textSecondary),
                    prefixIcon: Icon(Icons.search_rounded, color: AppTheme.textSecondary),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear_rounded, color: AppTheme.textSecondary),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.trim();
                    });
                  },
                ),
              ),
            ),

            Expanded(
              child: StreamBuilder<List<UserModel>>(
                stream: _firestoreService.getNonFriendsStream(currentUserId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppTheme.primary),
                    );
                  }

                  final users = snapshot.data ?? [];

                  // Arama sorgusuna göre kullanıcıları filtrele
                  final filteredUsers = _searchQuery.isEmpty 
                      ? users 
                      : users.where((user) => 
                          user.displayName.toLowerCase().contains(_searchQuery.toLowerCase())
                        ).toList();

                  if (filteredUsers.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.public_off_rounded,
                              size: 64, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isEmpty 
                                ? 'Gösterilecek kullanıcı yok' 
                                : 'Arama kriterine uygun kullanıcı bulunamadı',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                    itemCount: filteredUsers.length,
                    itemBuilder: (context, index) {
                      final targetUser = filteredUsers[index];
                      // Filter logic for hiding current friends can be done here.
                      // For now, we allow sending request to everyone, Firestore logic prevents dupes.
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: AppTheme.glassDecoration,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => context.push('/user/${targetUser.uid}'),
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  UserAvatar(
                                    photoUrl: targetUser.photoUrl,
                                    displayName: targetUser.displayName,
                                    radius: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          targetUser.displayName,
                                          style: TextStyle(
                                            color: AppTheme.textPrimary,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Row(
                                          children: [
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                color: targetUser.isOnline 
                                                    ? AppTheme.accent 
                                                    : AppTheme.textSecondary,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              targetUser.isOnline 
                                                  ? 'Çevrimiçi' 
                                                  : 'Çevrimdışı',
                                              style: TextStyle(
                                                color: targetUser.isOnline 
                                                    ? AppTheme.accent 
                                                    : AppTheme.textSecondary,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                                    ),
                                    child: IconButton(
                                      icon: const Icon(Icons.person_add_rounded, color: AppTheme.primary),
                                      tooltip: 'Arkadaş Ekle',
                                      onPressed: () {
                                        final request = FriendRequestModel(
                                          id: '',
                                          fromUserId: currentUserId,
                                          toUserId: targetUser.uid,
                                          fromUserName: currentUser.displayName,
                                          toUserName: targetUser.displayName,
                                          fromUserPhoto: currentUser.photoUrl,
                                          toUserPhoto: targetUser.photoUrl,
                                          status: 'pending',
                                        );
                                        _firestoreService.sendFriendRequest(request);
                                        
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('${targetUser.displayName} kişisine istek gönderildi'),
                                            backgroundColor: AppTheme.primary,
                                            duration: const Duration(seconds: 2),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
