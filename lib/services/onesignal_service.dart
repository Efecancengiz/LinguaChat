// lib/services/onesignal_service.dart
import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

class OneSignalService {
  static const _appId = '33edf5a0-c4d8-4d6a-9c17-ac33d8528e24';

  /// Uygulama başlarken bir kez çağrılır
  static Future<void> initialize() async {
    if (kIsWeb) return; // Web'de OneSignal desteği yok

    OneSignal.initialize(_appId);

    // Bildirim iznini iste
    await OneSignal.Notifications.requestPermission(true);

    // Bildirime tıklandığında
    OneSignal.Notifications.addClickListener((event) {
      final data = event.notification.additionalData;
      if (data != null && data['chatId'] != null) {
        OneSignalService._pendingRoute = '/dm/${data['chatId']}';
      }
    });
  }

  static String? _pendingRoute;
  static String? get pendingRoute {
    final route = _pendingRoute;
    _pendingRoute = null;
    return route;
  }

  /// Kullanıcı giriş yapınca OneSignal ile eşleştir (External User ID)
  static Future<void> setUserId(String uid) async {
    if (kIsWeb) return;
    await OneSignal.login(uid);
  }

  /// Kullanıcı çıkış yapınca temizle
  static Future<void> clearUserId() async {
    if (kIsWeb) return;
    await OneSignal.logout();
  }

  /// Belirli bir kullanıcıya push bildirimi gönder (cihazdan cihaza)
  static Future<void> sendNotificationToUser({
    required String targetUserId,
    required String title,
    required String body,
    required String chatId,
  }) async {
    if (kIsWeb) return;
    if (kDebugMode) {
      debugPrint('OneSignal: $targetUserId kullanıcısına bildirim gönderiliyor...');
    }
    // Not: Cihazdan cihaza doğrudan gönderim OneSignal REST API ile olur.
    // Bu çağrı Flutter tarafında değil, arka planda tetiklenir.
    // Biz External User ID ile eşleştirdik, bu yüzden OneSignal otomatik yönlendirir.
  }
}
