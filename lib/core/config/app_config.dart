abstract final class AppConfig {
  static const mapsConfigured = bool.fromEnvironment(
    'KALLALAI_MAPS_CONFIGURED',
    defaultValue: false,
  );

  /// Base URL of the Kalla-Lai API.
  ///
  /// Pass `--dart-define=KALLALAI_API_URL=https://api.example.com` to use an
  /// explicit API. Web builds default to same-origin `/v1`; native builds use
  /// the local development API when no URL is configured.
  static const apiBaseUrl = String.fromEnvironment(
    'KALLALAI_API_URL',
    defaultValue: '',
  );

  /// Set `--dart-define=KALLALAI_LIVE_API=false` to run the offline demo data.
  /// The live API is the default so the client never silently pretends that
  /// sample data is real production data.
  static const liveApiEnabled = bool.fromEnvironment(
    'KALLALAI_LIVE_API',
    defaultValue: true,
  );

  static const firebaseApiKey = String.fromEnvironment(
    'KALLALAI_FIREBASE_API_KEY',
    defaultValue: 'AIzaSyCRtLFo85ccfQJJCi7h8wGCGAcv4LslQ14',
  );
  static const firebaseProjectId = String.fromEnvironment(
    'KALLALAI_FIREBASE_PROJECT_ID',
    defaultValue: 'kalla-lai',
  );
  static const firebaseMessagingSenderId = String.fromEnvironment(
    'KALLALAI_FIREBASE_MESSAGING_SENDER_ID',
    defaultValue: '613077726999',
  );
  static const firebaseWebAppId = String.fromEnvironment(
    'KALLALAI_FIREBASE_WEB_APP_ID',
    defaultValue: '1:613077726999:web:6c805db93ebb96a5e7a952',
  );
  static const firebaseAndroidAppId = String.fromEnvironment(
    'KALLALAI_FIREBASE_ANDROID_APP_ID',
  );
  static const firebaseIosAppId = String.fromEnvironment(
    'KALLALAI_FIREBASE_IOS_APP_ID',
  );
  static const firebaseAuthDomain = String.fromEnvironment(
    'KALLALAI_FIREBASE_AUTH_DOMAIN',
    defaultValue: 'kalla-lai.firebaseapp.com',
  );
  static const firebaseAndroidClientId = String.fromEnvironment(
    'KALLALAI_GOOGLE_ANDROID_CLIENT_ID',
  );
  static const firebaseIosClientId = String.fromEnvironment(
    'KALLALAI_GOOGLE_IOS_CLIENT_ID',
  );
  static const googleWebClientId = String.fromEnvironment(
    'KALLALAI_GOOGLE_WEB_CLIENT_ID',
  );
  static const iosBundleId = String.fromEnvironment('KALLALAI_IOS_BUNDLE_ID');
}
