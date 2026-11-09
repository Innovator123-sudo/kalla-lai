import 'package:flutter_test/flutter_test.dart';
import 'package:kalla_lai/core/networking/api_client.dart';
import 'package:kalla_lai/features/auth/application/auth_cubit.dart';
import 'package:kalla_lai/features/auth/application/auth_gateway.dart';
import 'package:kalla_lai/features/auth/application/auth_state.dart';
import 'package:kalla_lai/features/auth/application/entry_journey_cubit.dart';
import 'package:kalla_lai/features/discovery/application/vacancy_discovery_cubit.dart';
import 'package:kalla_lai/features/hiring/application/hiring_requisition_cubit.dart';
import 'package:kalla_lai/features/mode/application/mode_switcher_cubit.dart';
import 'package:kalla_lai/features/shared/data/demo_marketplace_repository.dart';
import 'package:kalla_lai/features/shared/domain/marketplace_models.dart';
import 'package:kalla_lai/features/shifts/application/shift_escrow_cubit.dart';

void main() {
  group('Marketplace demo workflows', () {
    test('mode switcher changes between vacancy and hiring', () async {
      final cubit = ModeSwitcherCubit();

      expect(cubit.state, AppMode.vacancy);
      cubit.toggle();
      expect(cubit.state, AppMode.hiring);
      cubit.select(AppMode.vacancy);
      expect(cubit.state, AppMode.vacancy);

      await cubit.close();
    });

    test(
      'discovery loads localized sample shifts and changes radius',
      () async {
        final cubit = VacancyDiscoveryCubit(DemoMarketplaceRepository());

        await cubit.load();
        expect(cubit.state.jobs, hasLength(3));
        expect(cubit.state.jobs.first.area, 'Koteshwor, Kathmandu');
        await cubit.setDistance(2);
        expect(cubit.state.distanceKm, 2);

        await cubit.close();
      },
    );

    test(
      'hiring wizard walks questions and previews locally without a session',
      () async {
        final cubit = HiringRequisitionCubit(
          ApiClient(baseUrl: 'http://127.0.0.1:8090'),
        );

        expect(cubit.state.step, HiringStep.work);
        cubit.setArea('Patan Industrial Estate, Lalitpur');
        cubit.setShift('This weekend · flexible');
        cubit.next();
        expect(cubit.state.step, HiringStep.schedule);
        cubit.next();
        expect(cubit.state.step, HiringStep.budget);
        cubit.setRate(2400);
        cubit.next();
        expect(cubit.state.step, HiringStep.review);
        await cubit.submit();

        expect(cubit.state.submitted, isTrue);
        expect(cubit.state.localPreview, isTrue);
        expect(cubit.state.serverJobId, isNull);
        expect(cubit.state.notice, contains('Nothing was sent to the server'));

        await cubit.close();
      },
    );

    test('offline demo gateway creates a labelled local session', () async {
      const gateway = _StubAuthGateway();
      final cubit = AuthCubit(gateway);

      await cubit.signIn('worker@kallalai.demo', 'DemoPass123!');
      expect(cubit.state.status, AuthStatus.signedIn);
      expect(cubit.state.user?.email, 'worker@kallalai.demo');
      expect(cubit.state.user?.isDemoSession, isTrue);

      await cubit.signOut();
      expect(cubit.state.status, AuthStatus.signedOut);
      expect(cubit.state.user, isNull);

      await cubit.close();
    });

    test(
      'shift actions preserve distinct dispatch and payment states',
      () async {
        final cubit = ShiftEscrowCubit(
          DemoMarketplaceRepository().initialLedgerEntry(),
        );

        cubit.onMyWay();
        expect(cubit.state.dispatchStatus, DispatchStatus.onTheWay);
        expect(cubit.state.ledger.status, LedgerStatus.escrowFunded);

        cubit.checkIn();
        expect(cubit.state.dispatchStatus, DispatchStatus.checkedIn);
        expect(cubit.state.ledger.status, LedgerStatus.shiftInProgress);

        cubit.completeShift();
        expect(cubit.state.dispatchStatus, DispatchStatus.completionSubmitted);
        expect(cubit.state.ledger.status, LedgerStatus.pendingClientReview);

        cubit.dispute();
        expect(cubit.state.ledger.status, LedgerStatus.disputed);
        cubit.completeShift();
        expect(cubit.state.ledger.status, LedgerStatus.disputed);

        await cubit.close();
      },
    );

    test(
      'first-run journey keeps intent, survey and identity skip separate',
      () async {
        final cubit = EntryJourneyCubit(
          ApiClient(baseUrl: 'http://127.0.0.1:8090'),
        );

        expect(cubit.state.intent, isNull);
        expect(cubit.state.surveyComplete, isFalse);

        cubit.chooseIntent(EntryIntent.employer);
        expect(cubit.state.intent, EntryIntent.employer);
        expect(cubit.state.surveyComplete, isFalse);

        cubit.completeSurvey(
          acquisitionSource: 'FRIEND_FAMILY',
          timeline: 'THIS_WEEK',
          experience: 'SOME',
        );
        expect(cubit.state.surveyComplete, isTrue);
        expect(cubit.state.surveyJson, {
          'intent': 'EMPLOYER',
          'acquisitionSource': 'FRIEND_FAMILY',
          'timeline': 'THIS_WEEK',
          'experience': 'SOME',
        });

        cubit.skipIdentity();
        expect(cubit.state.identitySkipped, isTrue);
        cubit.resetForSignOut();
        expect(cubit.state.identitySkipped, isFalse);
        expect(cubit.state.surveyJson, isNotNull);

        cubit.changeIntent();
        expect(cubit.state.intent, isNull);
        expect(cubit.state.surveyComplete, isFalse);
        expect(cubit.state.surveyJson, isNull);

        await cubit.close();
      },
    );
  });
}

class _StubAuthGateway implements AuthGateway {
  const _StubAuthGateway();

  @override
  bool get googleSignInConfigured => false;

  @override
  Future<SessionUser?> restoreSession() async => null;

  @override
  Future<SessionUser> signIn(String email, String password) async =>
      SessionUser(
        id: 'stub',
        email: email.trim().toLowerCase(),
        fullName: 'Stub Worker',
        roles: const ['WORKER'],
        isDemoSession: true,
      );

  @override
  Future<SessionUser> signInWithGoogle({required bool asEmployer}) async =>
      throw const ApiException('Google sign-in is unavailable.');

  @override
  Future<SessionUser> signUp({
    required String email,
    required String password,
    required String fullName,
    required bool asEmployer,
    String? organization,
  }) async => SessionUser(
    id: 'stub',
    email: email.trim().toLowerCase(),
    fullName: fullName,
    roles: asEmployer ? const ['EMPLOYER'] : const ['WORKER'],
    isDemoSession: true,
  );

  @override
  Future<IdentityFlowResult> completeOnboarding(
    Map<String, dynamic> profile,
  ) async => const IdentityFlowResult(
    onboardingComplete: true,
    identityStatus: 'NOT_STARTED',
  );

  @override
  Future<IdentityFlowResult> startIdentityVerification() async =>
      const IdentityFlowResult(
        onboardingComplete: true,
        identityStatus: 'PENDING',
        sessionUrl: 'https://station.veriff.com',
      );

  @override
  Future<IdentityFlowResult> refreshIdentityStatus() async =>
      const IdentityFlowResult(
        onboardingComplete: true,
        identityStatus: 'NOT_STARTED',
      );

  @override
  Future<IdentityFlowResult> submitDocumentVerification({
    required String documentType,
    required String documentImage,
    String? documentBackImage,
    required String selfieImage,
  }) async => const IdentityFlowResult(
    onboardingComplete: true,
    identityStatus: 'VERIFIED',
    verificationMode: 'DEMO',
  );

  @override
  Future<void> signOut() async {}
}
