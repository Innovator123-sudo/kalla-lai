import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kalla_lai/core/networking/api_client.dart';
import 'package:kalla_lai/features/auth/application/auth_gateway.dart';
import 'package:kalla_lai/features/auth/application/auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._gateway) : super(const AuthState());

  final AuthGateway _gateway;

  /// Silently rebuilds the previous session from local storage. Called after
  /// the first frame so a slow or blocked API can never stop the app loading.
  Future<void> restoreSession() async {
    try {
      final user = await _gateway.restoreSession();
      if (isClosed || user == null) return;
      emit(AuthState(status: AuthStatus.signedIn, user: user));
    } catch (_) {
      // A stale or revoked session simply leaves the user signed out.
    }
  }

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

  Future<IdentityFlowResult?> loadIdentityStatus() =>
      _runIdentity(_gateway.refreshIdentityStatus);

  Future<IdentityFlowResult?> submitDocumentVerification({
    required String documentType,
    required String documentImage,
    String? documentBackImage,
    required String selfieImage,
  }) => _runIdentity(
    () => _gateway.submitDocumentVerification(
      documentType: documentType,
      documentImage: documentImage,
      documentBackImage: documentBackImage,
      selfieImage: selfieImage,
    ),
  );

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
