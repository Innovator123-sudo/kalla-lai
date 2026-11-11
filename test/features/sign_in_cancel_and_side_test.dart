import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kalla_lai/core/networking/api_client.dart';
import 'package:kalla_lai/features/auth/application/auth_cubit.dart';
import 'package:kalla_lai/features/auth/application/auth_gateway.dart';
import 'package:kalla_lai/features/auth/application/auth_state.dart';
import 'package:kalla_lai/features/mode/application/mode_switcher_cubit.dart';
import 'package:kalla_lai/features/shared/domain/marketplace_models.dart';

const _dualRoleUser = SessionUser(
  id: 'u1',
  email: 'both@example.com',
  fullName: 'Both Sides',
  roles: ['WORKER', 'EMPLOYER'],
);

void main() {
  group('cancelling a sign-in', () {
    test('a closed Google window returns to the form with no error', () async {
      final gateway = _FakeGateway()..google = Completer<SessionUser>();
      final cubit = AuthCubit(gateway);

      final pending = cubit.signInWithGoogle(asEmployer: true);
      expect(cubit.state.busy, isTrue);
      gateway.google.completeError(
        const ApiException('cancelled', code: googleSignInCancelledCode),
      );
      await pending;

      expect(cubit.state.busy, isFalse);
      expect(cubit.state.errorMessage, isNull);
      expect(cubit.state.status, AuthStatus.signedOut);
      await cubit.close();
    });

    test('Cancel frees the form while Google never answers', () async {
      final gateway = _FakeGateway()..google = Completer<SessionUser>();
      final cubit = AuthCubit(gateway);

      unawaited(cubit.signInWithGoogle(asEmployer: false));
      expect(cubit.state.busy, isTrue);
      cubit.cancelSignIn();

      expect(cubit.state.busy, isFalse);
      expect(cubit.state.errorMessage, isNull);
      await cubit.close();
    });

    test('a sign-in that finishes after Cancel is discarded', () async {
      final gateway = _FakeGateway()..google = Completer<SessionUser>();
      final cubit = AuthCubit(gateway);

      final pending = cubit.signInWithGoogle(asEmployer: false);
      cubit.cancelSignIn();
      gateway.google.complete(_dualRoleUser);
      await pending;

      expect(cubit.state.status, AuthStatus.signedOut);
      expect(cubit.state.user, isNull);
      expect(gateway.signOuts, 1);
      await cubit.close();
    });

    test('a real failure still shows its message', () async {
      final gateway = _FakeGateway()..google = Completer<SessionUser>();
      final cubit = AuthCubit(gateway);

      final pending = cubit.signInWithGoogle(asEmployer: false);
      gateway.google.completeError(
        const ApiException('Could not reach Firebase.', code: 'network'),
      );
      await pending;

      expect(cubit.state.errorMessage, 'Could not reach Firebase.');
      await cubit.close();
    });

    test(
      'signing out during the profile step is not undone by a late reply',
      () async {
        final gateway =
            _FakeGateway()..identity = Completer<IdentityFlowResult>();
        final cubit = AuthCubit(gateway);
        await cubit.signIn('both@example.com', 'a-long-password');
        expect(cubit.state.status, AuthStatus.signedIn);

        final pending = cubit.refreshIdentityStatus();
        expect(cubit.state.busy, isTrue);
        await cubit.signOut();
        gateway.identity!.completeError(
          const ApiException('Session expired.', code: 'UNAUTHORIZED'),
        );
        await pending;

        expect(cubit.state.status, AuthStatus.signedOut);
        expect(cubit.state.user, isNull);
        expect(cubit.state.busy, isFalse);
        expect(cubit.state.errorMessage, isNull);
        await cubit.close();
      },
    );
  });

  group('the side chosen at sign-in', () {
    test('an account with both roles keeps the chosen side', () async {
      final cubit = ModeSwitcherCubit()..select(AppMode.hiring);
      cubit.applyAccount(isWorker: true, isEmployer: true);
      expect(cubit.state, AppMode.hiring);

      cubit.select(AppMode.vacancy);
      cubit.applyAccount(isWorker: true, isEmployer: true);
      expect(cubit.state, AppMode.vacancy);
      await cubit.close();
    });

    test('an account with one role is locked to that side', () async {
      final cubit = ModeSwitcherCubit()..select(AppMode.hiring);
      cubit.applyAccount(isWorker: true, isEmployer: false);
      expect(cubit.state, AppMode.vacancy);

      cubit.applyAccount(isWorker: false, isEmployer: true);
      expect(cubit.state, AppMode.hiring);
      await cubit.close();
    });

    test(
      'the account is named after the active side, staff keep their title',
      () {
        expect(_dualRoleUser.sideLabel(hiring: true), 'Hirer');
        expect(_dualRoleUser.sideLabel(hiring: false), 'Worker');
        const admin = SessionUser(
          id: 'a',
          email: 'admin@example.com',
          fullName: 'Admin',
          roles: ['ADMIN', 'WORKER'],
        );
        expect(admin.sideLabel(hiring: true), 'Admin');
      },
    );
  });
}

class _FakeGateway implements AuthGateway {
  Completer<SessionUser> google = Completer<SessionUser>();
  Completer<IdentityFlowResult>? identity;
  int signOuts = 0;

  @override
  bool get googleSignInConfigured => true;

  @override
  Future<SessionUser?> restoreSession() async => null;

  @override
  Future<SessionUser> signIn(String email, String password) async =>
      _dualRoleUser;

  @override
  Future<SessionUser> signInWithGoogle({required bool asEmployer}) =>
      google.future;

  @override
  Future<SessionUser> signUp({
    required String email,
    required String password,
    required String fullName,
    required bool asEmployer,
    String? organization,
  }) async => _dualRoleUser;

  @override
  Future<IdentityFlowResult> completeOnboarding(Map<String, dynamic> profile) =>
      _identity();

  @override
  Future<IdentityFlowResult> startIdentityVerification() => _identity();

  @override
  Future<IdentityFlowResult> refreshIdentityStatus() => _identity();

  @override
  Future<IdentityFlowResult> submitDocumentVerification({
    required String documentType,
    required String documentImage,
    String? documentBackImage,
    required String selfieImage,
  }) => _identity();

  Future<IdentityFlowResult> _identity() =>
      identity?.future ??
      Future.value(
        const IdentityFlowResult(
          onboardingComplete: true,
          identityStatus: 'NOT_STARTED',
        ),
      );

  @override
  Future<void> signOut() async => signOuts++;
}
