import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:kalla_lai/core/config/app_config.dart';

abstract final class FirebaseAppOptions {
  static FirebaseOptions? forCurrentPlatform() {
    final hasAnyConfig = [
      AppConfig.firebaseApiKey,
      AppConfig.firebaseProjectId,
      AppConfig.firebaseMessagingSenderId,
      AppConfig.firebaseWebAppId,
      AppConfig.firebaseAndroidAppId,
      AppConfig.firebaseIosAppId,
    ].any((value) => value.isNotEmpty);
    if (!hasAnyConfig) return null;

    final platformAppId =
        kIsWeb
            ? AppConfig.firebaseWebAppId
            : switch (defaultTargetPlatform) {
              TargetPlatform.android => AppConfig.firebaseAndroidAppId,
              TargetPlatform.iOS => AppConfig.firebaseIosAppId,
              _ => AppConfig.firebaseWebAppId,
            };
    if (!kIsWeb && platformAppId.isEmpty) return null;

    final required = <String, String>{
      'KALLALAI_FIREBASE_API_KEY': AppConfig.firebaseApiKey,
      'KALLALAI_FIREBASE_PROJECT_ID': AppConfig.firebaseProjectId,
      'KALLALAI_FIREBASE_MESSAGING_SENDER_ID':
          AppConfig.firebaseMessagingSenderId,
      'Firebase app ID for ${defaultTargetPlatform.name}': platformAppId,
    };
    final missing = required.entries
        .where((entry) => entry.value.isEmpty)
        .map((entry) => entry.key)
        .toList(growable: false);
    if (missing.isNotEmpty) {
      throw StateError(
        'Firebase is partially configured. Provide: ${missing.join(', ')}.',
      );
    }

    return FirebaseOptions(
      apiKey: AppConfig.firebaseApiKey,
      appId: platformAppId,
      messagingSenderId: AppConfig.firebaseMessagingSenderId,
      projectId: AppConfig.firebaseProjectId,
      authDomain:
          AppConfig.firebaseAuthDomain.isEmpty
              ? '${AppConfig.firebaseProjectId}.firebaseapp.com'
              : AppConfig.firebaseAuthDomain,
      androidClientId:
          AppConfig.firebaseAndroidClientId.isEmpty
              ? null
              : AppConfig.firebaseAndroidClientId,
      iosClientId:
          AppConfig.firebaseIosClientId.isEmpty
              ? null
              : AppConfig.firebaseIosClientId,
      iosBundleId: AppConfig.iosBundleId.isEmpty ? null : AppConfig.iosBundleId,
    );
  }

  static bool get googleNativeClientConfigured =>
      kIsWeb ||
      (AppConfig.googleWebClientId.isNotEmpty &&
          (defaultTargetPlatform == TargetPlatform.android ||
              (defaultTargetPlatform == TargetPlatform.iOS &&
                  AppConfig.firebaseIosClientId.isNotEmpty)));
}
