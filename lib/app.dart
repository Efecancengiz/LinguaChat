// lib/app.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:linguachat/config/theme.dart';
import 'package:linguachat/providers/auth_provider.dart';
import 'package:linguachat/screens/auth/login_screen.dart';
import 'package:linguachat/screens/auth/register_screen.dart';
import 'package:linguachat/screens/auth/forgot_password_screen.dart';
import 'package:linguachat/screens/home/home_screen.dart';
import 'package:linguachat/screens/rooms/room_chat_screen.dart';
import 'package:linguachat/screens/profile/edit_profile_screen.dart';
import 'package:linguachat/screens/profile/user_profile_screen.dart';
import 'package:linguachat/screens/friends/friends_list_screen.dart';
import 'package:linguachat/screens/friends/friend_requests_screen.dart';
import 'package:linguachat/screens/dm/dm_chat_screen.dart';
import 'package:linguachat/screens/premium/premium_screen.dart';
import 'package:linguachat/screens/rooms/voice_room_screen.dart';
import 'package:linguachat/providers/voice_room_timer_provider.dart';
import 'package:linguachat/screens/feed/create_post_screen.dart';
import 'package:linguachat/services/admob_service.dart';

class LinguaChatApp extends StatelessWidget {
  const LinguaChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => VoiceRoomTimerProvider()),
      ],
      child: const _LinguaChatRouter(),
    );
  }
}

/// GoRouter'ı Provider ağacının altında oluşturur
/// böylece redirect callback'i AuthProvider'a erişebilir.
class _LinguaChatRouter extends StatefulWidget {
  const _LinguaChatRouter();

  @override
  State<_LinguaChatRouter> createState() => _LinguaChatRouterState();
}

class _LinguaChatRouterState extends State<_LinguaChatRouter> with WidgetsBindingObserver {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final authProvider = context.read<AuthProvider>();

    _router = GoRouter(
      initialLocation: '/login',
      refreshListenable: authProvider,
      redirect: (context, state) {
        final isAuthenticated = authProvider.isAuthenticated;
        final isAuthRoute = state.matchedLocation == '/login' ||
            state.matchedLocation == '/register' ||
            state.matchedLocation == '/forgot-password';

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
          path: '/',
          builder: (context, state) => const HomeScreen(),
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
      ],
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      AdMobService.showAppOpenAdIfAvailable();
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
      title: 'LinguaChat',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: _router,
    );
  }
}
