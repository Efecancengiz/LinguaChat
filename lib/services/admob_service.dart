import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdMobService {
  static AppOpenAd? _appOpenAd;
  static bool _isShowingAd = false;
  
  // Test vs Gerçek Reklam ID'lerini ayarlıyoruz.
  static String get appOpenAdUnitId {
    if (Platform.isAndroid) {
      if (kReleaseMode) {
        // TODO: Android gerçek Ad Unit ID eklenecek (Şimdilik test)
        return 'ca-app-pub-3940256099942544/9257395921'; 
      } else {
        // Android Test ID
        return 'ca-app-pub-3940256099942544/9257395921';
      }
    } else if (Platform.isIOS) {
      if (kReleaseMode) {
        // iOS Gerçek Ad Unit ID
        return 'ca-app-pub-8374639525815726/9320629461'; 
      } else {
        // iOS Test ID
        return 'ca-app-pub-3940256099942544/5575463023';
      }
    } else {
      throw UnsupportedError("Unsupported platform");
    }
  }

  static Future<void> initialize() async {
    if (kIsWeb) return;
    await MobileAds.instance.initialize();
  }

  static void loadAppOpenAd() {
    if (kIsWeb) return;
    
    AppOpenAd.load(
      adUnitId: appOpenAdUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenAd = ad;
          debugPrint('AppOpenAd loaded successfully');
        },
        onAdFailedToLoad: (error) {
          debugPrint('AppOpenAd failed to load: $error');
          _appOpenAd = null;
        },
      ),
    );
  }

  static void showAppOpenAdIfAvailable() {
    if (_appOpenAd == null || _isShowingAd) {
      debugPrint('Warning: Ad not loaded or already showing.');
      loadAppOpenAd();
      return;
    }
    
    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        _isShowingAd = true;
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('AppOpenAd failed to show: $error');
        _isShowingAd = false;
        ad.dispose();
        _appOpenAd = null;
        loadAppOpenAd();
      },
      onAdDismissedFullScreenContent: (ad) {
        _isShowingAd = false;
        ad.dispose();
        _appOpenAd = null;
        loadAppOpenAd();
      },
    );

    _appOpenAd!.show();
  }
}
