import 'package:kalla_lai/core/networking/api_client.dart';
import 'package:kalla_lai/core/storage/session_store.dart';
import 'package:kalla_lai/features/auth/application/auth_state.dart';

class GoogleIdentityToken {
  const GoogleIdentityToken({required this.idToken});

  final String idToken;
}

class IdentityFlowResult {
  const IdentityFlowResult({
    required this.onboardingComplete,
    required this.identityStatus,
    this.sessionUrl,
    this.verificationMode = 'VERIFF',
    this.verification,
  });

  factory IdentityFlowResult.fromJson(Map<String, dynamic> json) =>
      IdentityFlowResult(
        onboardingComplete: json['onboardingComplete'] == true,
        identityStatus: json['identityStatus']?.toString() ?? 'NOT_STARTED',
        sessionUrl: json['sessionUrl']?.toString(),
        verificationMode: json['mode']?.toString() ?? 'VERIFF',
        verification:
            json['verification'] is Map<String, dynamic>
                ? json['verification'] as Map<String, dynamic>
                : null,
      );

  final bool onboardingComplete;
  final String identityStatus;
  final String? sessionUrl;

  /// 'DEMO' for the in-app document flow, 'VERIFF' for the hosted secure check.
  final String verificationMode;
  final Map<String, dynamic>? verification;
}

/// Error code for a Google sign-in the person backed out of (closed the account
/// chooser, pressed Cancel). It is not a failure and shows no error.
const String googleSignInCancelledCode = 'GOOGLE_SIGN_IN_CANCELLED';

abstract interface class GoogleIdentityProvider {
  Future<GoogleIdentityToken?> signIn();

  Future<void> signOut();
}

/// Source of truth for sign-in / registration.
///
/// The live gateway talks to the real API. The offline gateway exists only for
/// the explicitly disabled demo mode and clearly marks its sessions as demo.
abstract interface class AuthGateway {
  bool get googleSignInConfigured;

  Future<SessionUser> signIn(String email, String password);

  /// Rebuilds a session from the locally stored refresh token. Returns null
  /// when there is no saved session or it is no longer valid.
  Future<SessionUser?> restoreSession();

  Future<SessionUser> signInWithGoogle({required bool asEmployer});

  Future<SessionUser> signUp({
    required String email,
    required String password,
    required String fullName,
    required bool asEmployer,
    String? organization,
  });

  Future<IdentityFlowResult> completeOnboarding(Map<String, dynamic> profile);

  Future<IdentityFlowResult> startIdentityVerification();

  Future<IdentityFlowResult> refreshIdentityStatus();

  Future<IdentityFlowResult> submitDocumentVerification({
    required String documentType,
    required String documentImage,
    String? documentBackImage,
    required String selfieImage,
  });

  Future<void> signOut();
}

class ApiAuthGateway implements AuthGateway {
  ApiAuthGateway(this._client, {GoogleIdentityProvider? googleIdentityProvider})
    : _googleIdentityProvider = googleIdentityProvider;

  final ApiClient _client;
  final GoogleIdentityProvider? _googleIdentityProvider;
  String? _refreshToken;

  @override
  bool get googleSignInConfigured => _googleIdentityProvider != null;

  SessionUser _applySession(Map<String, dynamic> json, {String? email}) {
    _client.setAccessToken(json['accessToken']?.toString());
    _refreshToken = json['refreshToken']?.toString();
    _persist(json, email: email);
    return _mapUser(json);
  }

  /// Caches the tokens locally so the session survives a reload. The refresh
  /// token is rotated by the API on every use, so always store the newest one.
  void _persist(Map<String, dynamic> json, {String? email}) {
    final refresh = json['refreshToken']?.toString();
    if (refresh == null || refresh.isEmpty) return;
    SessionStore.save(
      refreshToken: refresh,
      accessToken: json['accessToken']?.toString(),
      email: email,
    );
  }

  @override
  Future<SessionUser?> restoreSession() async {
    final refresh = SessionStore.refreshToken;
    if (refresh == null || refresh.isEmpty) return null;
    _client.setAccessToken(SessionStore.accessToken);
    try {
      final json = await _client.postJson(
        '/v1/auth/refresh',
        body: {'refreshToken': refresh},
        timeout: const Duration(seconds: 6),
        retryOnUnauthorized: false,
      );
      _refreshToken = json['refreshToken']?.toString() ?? refresh;
      _client.setAccessToken(json['accessToken']?.toString());
      final user = _mapUser(json);
      _persist(json, email: user.email);
      return user;
    } on ApiException catch (error) {
      // Only an explicit rejection means the saved session is gone. A network
      // blip, timeout or 5xx must keep the tokens so a later reload can retry
      // instead of quietly signing the user out.
      if (error.statusCode == 401 || error.statusCode == 403) {
        _client.setAccessToken(null);
        _refreshToken = null;
        SessionStore.clear();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static SessionUser _mapUser(Map<String, dynamic> json, {bool demo = false}) {
    final user = json['user'];
    final roles = (user is Map<String, dynamic> ? user['roles'] : null);
    return SessionUser(
      id: user is Map<String, dynamic> ? '${user['id']}' : '',
      email: user is Map<String, dynamic> ? '${user['email']}' : '',
      fullName: user is Map<String, dynamic> ? '${user['fullName']}' : '',
      roles:
          roles is List
              ? roles.whereType<String>().toList(growable: false)
              : const [],
      isDemoSession: demo,
      onboardingComplete:
          user is Map<String, dynamic> && user['onboardingComplete'] == true,
      identityStatus:
          user is Map<String, dynamic>
              ? user['identityStatus']?.toString() ?? 'NOT_STARTED'
              : 'NOT_STARTED',
    );
  }

  @override
  Future<SessionUser> signIn(String email, String password) async {
    final json = await _client.postJson(
      '/v1/auth/login',
      body: {'email': email.trim(), 'password': password},
    );
    return _applySession(json);
  }

  @override
  Future<SessionUser> signInWithGoogle({required bool asEmployer}) async {
    final provider = _googleIdentityProvider;
    if (provider == null) {
      throw const ApiException(
        'Google sign-in is not configured for this app.',
        code: 'GOOGLE_SIGN_IN_UNAVAILABLE',
      );
    }
    final identity = await provider.signIn();
    if (identity == null) {
      throw const ApiException(
        'Google sign-in was cancelled.',
        code: googleSignInCancelledCode,
      );
    }
    final json = await _client.postJson(
      '/v1/auth/firebase',
      body: {
        'idToken': identity.idToken,
        'role': asEmployer ? 'EMPLOYER' : 'WORKER',
      },
    );
    return _applySession(json);
  }

  @override
  Future<SessionUser> signUp({
    required String email,
    required String password,
    required String fullName,
    required bool asEmployer,
    String? organization,
  }) async {
    final json = await _client.postJson(
      '/v1/auth/register',
      body: {
        'email': email.trim(),
        'password': password,
        'fullName': fullName.trim(),
        'role': asEmployer ? 'EMPLOYER' : 'WORKER',
        if (organization != null && organization.trim().isNotEmpty)
          'organization': organization.trim(),
        if (!asEmployer) 'publicName': fullName.trim(),
      },
    );
    return _applySession(json);
  }

  @override
  Future<void> signOut() async {
    try {
      // 204 No Content; errors are tolerated so the local session always clears.
      await _client.postJson(
        '/v1/auth/logout',
        body: _refreshToken == null ? null : {'refreshToken': _refreshToken},
      );
    } catch (_) {
      // Swallow: the device session is being discarded regardless.
    } finally {
      try {
        await _googleIdentityProvider?.signOut();
      } finally {
        _client.setAccessToken(null);
        _refreshToken = null;
        SessionStore.clear();
      }
    }
  }

  @override
  Future<IdentityFlowResult> completeOnboarding(
    Map<String, dynamic> profile,
  ) async => IdentityFlowResult.fromJson(
    await _client.postJson('/v1/verification/onboarding', body: profile),
  );

  @override
  Future<IdentityFlowResult> startIdentityVerification() async =>
      IdentityFlowResult.fromJson(
        await _client.postJson(
          '/v1/verification/sessions',
          body: const {'consent': true},
        ),
      );

  @override
  Future<IdentityFlowResult> refreshIdentityStatus() async =>
      IdentityFlowResult.fromJson(await _client.getJson('/v1/verification/me'));

  @override
  Future<IdentityFlowResult> submitDocumentVerification({
    required String documentType,
    required String documentImage,
    String? documentBackImage,
    required String selfieImage,
  }) async => IdentityFlowResult.fromJson(
    await _client.postJson(
      '/v1/verification/document',
      body: {
        'consent': true,
        'documentType': documentType,
        'documentImage': documentImage,
        if (documentBackImage != null) 'documentBackImage': documentBackImage,
        'selfieImage': selfieImage,
      },
      timeout: const Duration(seconds: 90),
    ),
  );
}

/// Demo-mode gateway. Sessions exist only in memory and are labelled as demo.
class OfflineAuthGateway implements AuthGateway {
  @override
  bool get googleSignInConfigured => false;

  @override
  Future<SessionUser?> restoreSession() async => null;

  @override
  Future<SessionUser> signIn(String email, String password) async {
    if (password.isEmpty) {
      throw const ApiException(
        'Enter a password to continue.',
        code: 'VALIDATION',
      );
    }
    final normalized = email.trim().toLowerCase();
    return SessionUser(
      id: 'demo-$normalized',
      email: normalized,
      fullName: _nameFrom(normalized),
      roles:
          normalized.contains('employer')
              ? const ['EMPLOYER']
              : const ['WORKER'],
      isDemoSession: true,
    );
  }

  @override
  Future<SessionUser> signInWithGoogle({required bool asEmployer}) async {
    throw const ApiException(
      'Google sign-in is unavailable in offline demo mode.',
      code: 'GOOGLE_SIGN_IN_UNAVAILABLE',
    );
  }

  @override
  Future<SessionUser> signUp({
    required String email,
    required String password,
    required String fullName,
    required bool asEmployer,
    String? organization,
  }) async {
    if (password.isEmpty || fullName.trim().isEmpty) {
      throw const ApiException(
        'Fill every field to continue.',
        code: 'VALIDATION',
      );
    }
    return SessionUser(
      id: 'demo-${email.trim().toLowerCase()}',
      email: email.trim().toLowerCase(),
      fullName: fullName.trim(),
      roles: asEmployer ? const ['EMPLOYER'] : const ['WORKER'],
      isDemoSession: true,
    );
  }

  @override
  Future<void> signOut() async {}

  @override
  Future<IdentityFlowResult> completeOnboarding(Map<String, dynamic> profile) =>
      _verificationUnavailable();

  @override
  Future<IdentityFlowResult> startIdentityVerification() =>
      _verificationUnavailable();

  @override
  Future<IdentityFlowResult> refreshIdentityStatus() =>
      _verificationUnavailable();

  @override
  Future<IdentityFlowResult> submitDocumentVerification({
    required String documentType,
    required String documentImage,
    String? documentBackImage,
    required String selfieImage,
  }) => _verificationUnavailable();

  Future<IdentityFlowResult> _verificationUnavailable() =>
      Future<IdentityFlowResult>.error(
        const ApiException(
          'Identity verification is not available in offline demo mode.',
          code: 'VERIFICATION_UNAVAILABLE',
        ),
      );

  String _nameFrom(String email) {
    final localPart = email.split('@').first;
    if (localPart.isEmpty) return 'Demo user';
    return localPart
        .split(RegExp(r'[._-]+'))
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }
}
