// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';
import 'app.dart';
import 'services/notification_service.dart';
import 'services/onesignal_service.dart';
import 'services/revenuecat_service.dart';
import 'services/admob_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Status bar style
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF161B22),
      systemNavigationBarIconBrightness: Brightness.light,
    ));

    // Initialize Firebase
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      if (!e.toString().contains('duplicate-app')) {
        rethrow;
      }
    }

    // Bildirim sistemini başlat
    await NotificationService.initialize();
    OneSignalService.initialize(); // DİKKAT: await kaldırıldı, çünkü izin penceresi runApp'i engelleyebilir!

    // RevenueCat (Ödeme) sistemini başlat
    await RevenueCatService.init();

    // AdMob sistemini başlat
    await AdMobService.initialize();
    AdMobService.loadAppOpenAd();

    // Turkish localization for timeago and intl
    timeago.setLocaleMessages('tr', timeago.TrMessages());
    timeago.setDefaultLocale('tr');
    await initializeDateFormatting('tr', null);

    runApp(const LinguaChatApp());
  } catch (e) {
    debugPrint('STARTUP ERROR: $e');
    runApp(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Center(
              child: Text(
                'Uygulama başlatılamadı. Lütfen yeniden başlatın.\n(Hata: $e)',
                style: const TextStyle(color: Colors.red, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
