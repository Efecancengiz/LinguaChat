class HmsSecrets {
  // RevenueCat mobile SDK keys are public client keys and should be supplied
  // via --dart-define instead of bundling a .env file into the app binary.
  static const String revenueCatAppleApiKey =
      String.fromEnvironment('REVENUECAT_APPLE_API_KEY');
  static const String revenueCatGoogleApiKey =
      String.fromEnvironment('REVENUECAT_GOOGLE_API_KEY');
}
