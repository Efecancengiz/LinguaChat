// lib/services/revenuecat_service.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:linguachat/config/hms_secrets.dart';

class RevenueCatService {
  static bool _isConfigured = false;

  /// RevenueCat'i başlatır. Bu metot uygulamanın başlangıcında (main.dart) çağrılmalıdır.
  static Future<void> init() async {
    if (kIsWeb) return; // RevenueCat şimdilik web'i tam desteklemez.

    await Purchases.setLogLevel(LogLevel.debug);

    PurchasesConfiguration? configuration;

    final googleKey = HmsSecrets.revenueCatGoogleApiKey;
    final appleKey = HmsSecrets.revenueCatAppleApiKey;

    if (Platform.isAndroid && googleKey.isNotEmpty) {
      configuration = PurchasesConfiguration(googleKey);
    } else if (Platform.isIOS && appleKey.isNotEmpty) {
      configuration = PurchasesConfiguration(appleKey);
    }

    if (configuration != null) {
      await Purchases.configure(configuration);
      _isConfigured = true;
      debugPrint('RevenueCatService: Başarıyla başlatıldı.');
    } else {
      _isConfigured = false;
    }
  }

  /// Kullanıcı sisteme girdiğinde Firebase UID'sini RevenueCat'e tanıtır.
  static Future<void> login(String uid) async {
    if (kIsWeb || !_isConfigured) return;
    try {
      await Purchases.logIn(uid);
    } catch (e) {
      debugPrint('RevenueCatService.login error: $e');
    }
  }

  /// Kullanıcı çıkış yaptığında RevenueCat'ten de çıkış yapar.
  static Future<void> logout() async {
    if (kIsWeb || !_isConfigured) return;
    try {
      await Purchases.logOut();
    } catch (e) {
      debugPrint('RevenueCatService.logout error: $e');
    }
  }

  /// RevenueCat dashboard'unda tanımlanan paketleri (Offerings) getirir.
  static Future<Offerings?> getOfferings() async {
    if (kIsWeb || !_isConfigured) return null;
    try {
      return await Purchases.getOfferings();
    } on PlatformException catch (e) {
      debugPrint('RevenueCatService.getOfferings error: $e');
      return null;
    }
  }

  /// Bir paketi (örn: Haftalık) satın almak için market ödeme akışını başlatır.
  static Future<EntitlementInfo?> purchasePackage(Package package) async {
    if (kIsWeb || !_isConfigured) return null;
    try {
      final purchaseResult = await Purchases.purchase(PurchaseParams.package(package));
      // RevenueCat üzerinden tanımladığımız "premium" adlı Entitlement'ı döndürüyoruz.
      return purchaseResult.customerInfo.entitlements.all['premium'];
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode != PurchasesErrorCode.purchaseCancelledError) {
        debugPrint('RevenueCatService.purchasePackage error: $e');
      }
      return null;
    }
  }

  /// Kullanıcının mevcut premium aboneliğinin süresinin dolup dolmadığını kontrol eder.
  static Future<bool> checkSubscription() async {
    if (kIsWeb || !_isConfigured) return false;
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.entitlements.all['premium']?.isActive ?? false;
    } catch (e) {
      debugPrint('RevenueCatService.checkSubscription error: $e');
      return false;
    }
  }

  /// Önceki satınalmaları marketten tekrar geri yüklemek (Restore) için kullanılır.
  static Future<bool> restorePurchases() async {
    if (kIsWeb || !_isConfigured) return false;
    try {
      final customerInfo = await Purchases.restorePurchases();
      return customerInfo.entitlements.all['premium']?.isActive ?? false;
    } catch (e) {
      debugPrint('RevenueCatService.restorePurchases error: $e');
      return false;
    }
  }
}
