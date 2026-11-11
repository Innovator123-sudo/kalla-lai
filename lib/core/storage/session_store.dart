import 'package:kalla_lai/core/storage/kv_store.dart';

/// Persisted sign-in state.
///
/// Only the rotating refresh token is required to restore a session: the API's
/// `/v1/auth/refresh` endpoint returns a fresh access token AND the current
/// user. The access token is cached too so a restored session can make its
/// first call without an extra round trip.
abstract final class SessionStore {
  static const _refreshKey = 'kalla_lai.refresh_token.v1';
  static const _accessKey = 'kalla_lai.access_token.v1';
  static const _emailKey = 'kalla_lai.remembered_email.v1';
  static const _modeKey = 'kalla_lai.app_mode.v1';

  static String? get refreshToken => kvStore.read(_refreshKey);
  static String? get accessToken => kvStore.read(_accessKey);
  static String? get rememberedEmail => kvStore.read(_emailKey);

  /// The side chosen at sign-in (`vacancy` or `hiring`). The choice is fixed
  /// after login, so it is remembered across restarts instead of being
  /// switchable from the profile.
  static String? get appMode => kvStore.read(_modeKey);

  static void saveAppMode(String mode) {
    if (mode == 'vacancy' || mode == 'hiring') kvStore.write(_modeKey, mode);
  }

  static void clearAppMode() => kvStore.remove(_modeKey);

  static void save({
    required String refreshToken,
    String? accessToken,
    String? email,
  }) {
    kvStore.write(_refreshKey, refreshToken);
    if (accessToken != null && accessToken.isNotEmpty) {
      kvStore.write(_accessKey, accessToken);
    }
    if (email != null && email.isNotEmpty) {
      kvStore.write(_emailKey, email);
    }
  }

  /// Prefill only; kept after sign-out so the email field stays convenient.
  static void saveEmail(String email) {
    if (email.trim().isNotEmpty) kvStore.write(_emailKey, email.trim());
  }

  /// Drops the session and the remembered side.
  ///
  /// Keeping `appMode` after a session ends lets one account's side leak into
  /// the next account's profile setup on a shared device.
  static void clear() {
    kvStore.remove(_refreshKey);
    kvStore.remove(_accessKey);
    kvStore.remove(_modeKey);
  }
}
