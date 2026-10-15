// lib/app.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:linguachat/config/theme.dart';
import 'package:linguachat/providers/auth_provider.dart';
import 'package:linguachat/screens/splash/splash_screen.dart';
import 'package:linguachat/screens/auth/login_screen.dart';
import 'package:linguachat/screens/auth/register_screen.dart';
import 'package:linguachat/screens/auth/forgot_password_screen.dart';
import 'package:linguachat/screens/home/home_screen.dart';
import 'package:linguachat/screens/rooms/room_chat_screen.dart';
import 'package:linguachat/screens/profile/edit_profile_screen.dart';
import 'package:linguachat/screens/profile/user_profile_screen.dart';
import 'package:linguachat/screens/profile/follow_list_screen.dart';
import 'package:linguachat/screens/profile/saved_posts_screen.dart';
import 'package:linguachat/screens/profile/user_posts_screen.dart';
import 'package:linguachat/screens/friends/friends_list_screen.dart';
import 'package:linguachat/screens/friends/friend_requests_screen.dart';
import 'package:linguachat/screens/dm/dm_chat_screen.dart';
import 'package:linguachat/screens/premium/premium_screen.dart';
import 'package:linguachat/screens/premium/fortune_wheel_screen.dart';
import 'package:linguachat/screens/rooms/voice_room_screen.dart';
import 'package:linguachat/providers/voice_room_timer_provider.dart';
import 'package:linguachat/screens/feed/create_post_screen.dart';
import 'package:linguachat/services/admob_service.dart';
import 'package:linguachat/screens/profile/blocked_users_screen.dart';
import 'package:linguachat/screens/admin/admin_panel_screen.dart';

class WorldPalsApp extends StatelessWidget {
  const WorldPalsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => VoiceRoomTimerProvider()),
      ],
      child: const _WorldPalsRouter(),
    );
  }
}

/// GoRouter'ı Provider ağacının altında oluşturur
/// böylece redirect callback'i AuthProvider'a erişebilir.
class _WorldPalsRouter extends StatefulWidget {
  const _WorldPalsRouter();

  @override
  State<_WorldPalsRouter> createState() => _WorldPalsRouterState();
}

class _WorldPalsRouterState extends State<_WorldPalsRouter> with WidgetsBindingObserver {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final authProvider = context.read<AuthProvider>();

    _router = GoRouter(
      initialLocation: '/splash',
      refreshListenable: authProvider,
      redirect: (context, state) {
        final isAuthenticated = authProvider.isAuthenticated;
        final isAuthRoute = state.matchedLocation == '/login' ||
            state.matchedLocation == '/register' ||
            state.matchedLocation == '/forgot-password';
        final isSplashRoute = state.matchedLocation == '/splash';

        if (isSplashRoute) return null;

        if (!isAuthenticated && !isAuthRoute) {
          return '/login';
        }
        if (isAuthenticated && isAuthRoute) {
          return '/';
        }
        return null;
      },
      routes: [
        GoRoute(
          path: '/splash',
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) {
            final tabStr = state.uri.queryParameters['tab'];
            final initialTab = tabStr != null ? int.tryParse(tabStr) ?? 0 : 0;
            return HomeScreen(initialTab: initialTab);
          },
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterScreen(),
        ),
        GoRoute(
          path: '/forgot-password',
          builder: (context, state) => const ForgotPasswordScreen(),
        ),
        GoRoute(
          path: '/room/:roomId',
          builder: (context, state) {
            final roomId = state.pathParameters['roomId']!;
            final extra = state.extra as Map<String, dynamic>?;
            return RoomChatScreen(
              roomId: roomId,
              roomName: extra?['name'] ?? '$roomId Room',
              roomFlag: extra?['flag'] ?? '🌍',
              roomCode: extra?['code'] as String?,
              isCustom: extra?['isCustom'] as bool? ?? false,
              languageCode: extra?['languageCode'] as String? ?? roomId,
            );
          },
        ),
        GoRoute(
          path: '/edit-profile',
          builder: (context, state) => const EditProfileScreen(),
        ),
        GoRoute(
          path: '/user/:userId',
          builder: (context, state) {
            final userId = state.pathParameters['userId']!;
            return UserProfileScreen(userId: userId);
          },
        ),
        GoRoute(
          path: '/follows/:userId/:type',
          builder: (context, state) {
            final userId = state.pathParameters['userId']!;
            final type = state.pathParameters['type']!;
            return FollowListScreen(userId: userId, type: type);
          },
        ),
        GoRoute(
          path: '/saved-posts',
          builder: (context, state) => const SavedPostsScreen(),
        ),
        GoRoute(
          path: '/user-posts/:userId',
          builder: (context, state) {
            final userId = state.pathParameters['userId']!;
            return UserPostsScreen(userId: userId);
          },
        ),
        GoRoute(
          path: '/friends',
          builder: (context, state) => const FriendsListScreen(),
        ),
        GoRoute(
          path: '/friend-requests',
          builder: (context, state) => const FriendRequestsScreen(),
        ),
        GoRoute(
          path: '/dm/:chatId',
          builder: (context, state) {
            final chatId = state.pathParameters['chatId']!;
            final extra = state.extra as Map<String, dynamic>?;
            final otherUserId = extra?['userId'] as String?;
            if (otherUserId == null || otherUserId.isEmpty) {
              return Scaffold(
                appBar: AppBar(title: const Text('Hata')),
                body: const Center(child: Text('Geçersiz kullanıcı ID')),
              );
            }
            return DmChatScreen(
              chatId: chatId,
              otherUserId: otherUserId,
            );
          },
        ),
        GoRoute(
          path: '/premium',
          builder: (context, state) => const PremiumScreen(),
        ),
        GoRoute(
          path: '/fortune-wheel',
          builder: (context, state) => const FortuneWheelScreen(),
        ),
        GoRoute(
          path: '/voice-room/:roomId',
          builder: (context, state) {
            final roomId = state.pathParameters['roomId']!;
            final extra = state.extra as Map<String, dynamic>?;
            return VoiceRoomScreen(
              roomId: roomId,
              roomName: extra?['name'] ?? '$roomId Oda',
            );
          },
        ),
        GoRoute(
          path: '/create-post',
          builder: (context, state) => const CreatePostScreen(),
        ),
        GoRoute(
          path: '/blocked-users',
          builder: (context, state) => const BlockedUsersScreen(),
        ),
        GoRoute(
          path: '/admin',
          builder: (context, state) => const AdminPanelScreen(),
        ),
      ],
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final authProvider = context.read<AuthProvider>();
      if (authProvider.user?.isPremium != true) {
        AdMobService.showAppOpenAdIfAvailable();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'WorldPals',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: _router,
    );
  }
}
