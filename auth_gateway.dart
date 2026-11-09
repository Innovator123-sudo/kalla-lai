import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kalla_lai/core/networking/api_client.dart';
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
  });

  factory IdentityFlowResult.fromJson(Map<String, dynamic> json) =>
      IdentityFlowResult(
        onboardingComplete: json['onboardingComplete'] == true,
        identityStatus: json['identityStatus']?.toString() ?? 'NOT_STARTED',
        sessionUrl: json['sessionUrl']?.toString(),
      );

  final bool onboardingComplete;
  final String identityStatus;
  final String? sessionUrl;
}

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
    _client.setAccessToken(json['accessToken']?.toString());
    _refreshToken = json['refreshToken']?.toString();
    return _mapUser(json);
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
        code: 'GOOGLE_SIGN_IN_CANCELLED',
      );
    }
    final json = await _client.postJson(
      '/v1/auth/firebase',
      body: {
        'idToken': identity.idToken,
        'role': asEmployer ? 'EMPLOYER' : 'WORKER',
      },
    );
    _client.setAccessToken(json['accessToken']?.toString());
    _refreshToken = json['refreshToken']?.toString();
    return _mapUser(json);
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
    _client.setAccessToken(json['accessToken']?.toString());
    _refreshToken = json['refreshToken']?.toString();
    return _mapUser(json);
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
}

/// Demo-mode gateway. Sessions exist only in memory and are labelled as demo.
class OfflineAuthGateway implements AuthGateway {
  @override
  bool get googleSignInConfigured => false;

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

class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._gateway) : super(const AuthState());

  final AuthGateway _gateway;

  Future<void> signIn(String email, String password) async {
    if (email.trim().isEmpty || password.isEmpty) {
      emit(
        state.copyWith(
          clearError: true,
          errorMessage: 'Enter your email and password.',
        ),
      );
      return;
    }
    await _run(() => _gateway.signIn(email, password));
  }

  Future<void> signInWithGoogle({required bool asEmployer}) async {
    await _run(() => _gateway.signInWithGoogle(asEmployer: asEmployer));
  }

  bool get googleSignInConfigured => _gateway.googleSignInConfigured;

  Future<void> completeOnboarding(Map<String, dynamic> profile) async {
    await _runIdentity(() => _gateway.completeOnboarding(profile));
  }

  Future<IdentityFlowResult?> startIdentityVerification() =>
      _runIdentity(_gateway.startIdentityVerification);

  Future<void> refreshIdentityStatus() async {
    await _runIdentity(_gateway.refreshIdentityStatus);
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    required bool asEmployer,
    String? organization,
  }) async {
    if (email.trim().isEmpty || password.isEmpty || fullName.trim().isEmpty) {
      emit(
        state.copyWith(
          clearError: true,
          errorMessage: 'Enter your name, email and a password.',
        ),
      );
      return;
    }
    if (password.length < 10) {
      emit(
        state.copyWith(
          clearError: true,
          errorMessage: 'Passwords need at least 10 characters.',
        ),
      );
      return;
    }
    await _run(
      () => _gateway.signUp(
        email: email,
        password: password,
        fullName: fullName,
        asEmployer: asEmployer,
        organization: organization,
      ),
    );
  }

  Future<void> signOut() async {
    await _gateway.signOut();
    if (isClosed) return;
    emit(const AuthState());
  }

  Future<void> _run(Future<SessionUser> Function() action) async {
    emit(state.copyWith(busy: true, clearError: true));

    try {
      final user = await action();
      if (isClosed) return;

      emit(AuthState(status: AuthStatus.signedIn, user: user));
    } on ApiException catch (error) {
      if (isClosed) return;

      emit(state.copyWith(busy: false, errorMessage: error.message));
    } catch (_) {
      if (isClosed) return;

      emit(
        state.copyWith(
          busy: false,
          errorMessage: 'Sign-in failed unexpectedly. Please try again.',
        ),
      );
    }
  }

  Future<IdentityFlowResult?> _runIdentity(
    Future<IdentityFlowResult> Function() action,
  ) async {
    final user = state.user;
    if (user == null) return null;

    emit(state.copyWith(busy: true, clearError: true));

    try {
      final result = await action();
      if (isClosed) return result;

      emit(
        state.copyWith(
          user: user.copyWith(
            onboardingComplete: result.onboardingComplete,
            identityStatus: result.identityStatus,
          ),
          busy: false,
          clearError: true,
        ),
      );

      return result;
    } on ApiException catch (error) {
      if (isClosed) return null;

      emit(state.copyWith(busy: false, errorMessage: error.message));
    } catch (_) {
      if (isClosed) return null;

      emit(
        state.copyWith(
          busy: false,
          errorMessage:
              'Could not update verification status. Please try again.',
        ),
      );
    }

    return null;
  }
}
