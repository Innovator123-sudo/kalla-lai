import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kalla_lai/features/auth/application/auth_cubit.dart';
import 'package:kalla_lai/features/auth/application/auth_state.dart';
import 'package:kalla_lai/features/auth/application/entry_journey_cubit.dart';
import 'package:kalla_lai/features/auth/presentation/identity_onboarding_screen.dart';
import 'package:kalla_lai/features/auth/presentation/intent_selection_screen.dart';
import 'package:kalla_lai/features/auth/presentation/intro_splash_screen.dart';
import 'package:kalla_lai/features/auth/presentation/login_screen.dart';
import 'package:kalla_lai/features/auth/presentation/survey_screen.dart';
import 'package:kalla_lai/features/home/presentation/main_shell_screen.dart';
import 'package:kalla_lai/features/mode/application/mode_switcher_cubit.dart';
import 'package:kalla_lai/features/shared/domain/marketplace_models.dart';

/// Runs the first-launch journey:
/// intro video → worker/employer choice → optional survey → sign-in →
/// profile + identity check → home.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _introFinished = false;

  @override
  Widget build(BuildContext context) {
    if (!_introFinished) {
      return IntroSplashScreen(
        onFinished: () {
          if (mounted) setState(() => _introFinished = true);
        },
      );
    }
    return BlocListener<AuthCubit, AuthState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, auth) {
        final journey = context.read<EntryJourneyCubit>();
        if (auth.status == AuthStatus.signedIn) {
          journey.syncSurvey();
          final user = auth.user;
          if (user != null) {
            // The side is chosen at sign-in. Accounts with a single role are
            // locked to it; dual-role accounts keep the login choice.
            context.read<ModeSwitcherCubit>().applyAccount(
              isWorker: user.isWorker,
              isEmployer: user.isEmployer,
            );
          }
        } else {
          journey.resetForSignOut();
        }
      },
      child: BlocBuilder<EntryJourneyCubit, EntryJourneyState>(
        builder: (context, journey) {
          return BlocBuilder<AuthCubit, AuthState>(
            builder: (context, auth) {
              if (auth.status == AuthStatus.signedIn) {
                final user = auth.user;
                if (user == null) return const LoginScreen();

                final gatedAccount =
                    !user.isDemoSession && (user.isWorker || user.isEmployer);
                if (gatedAccount && !user.onboardingComplete) {
                  return const IdentityOnboardingScreen();
                }

                // Workers can choose "Skip for now" and browse the app, but
                // the API still refuses applications until identity is
                // VERIFIED. Employers can verify from their profile later.
                final isHiring =
                    context.watch<ModeSwitcherCubit>().state == AppMode.hiring;
                final workerNeedsIdentity =
                    !user.isDemoSession &&
                    !isHiring &&
                    user.identityStatus != 'VERIFIED' &&
                    !journey.identitySkipped;
                if (workerNeedsIdentity) {
                  return const IdentityOnboardingScreen();
                }
                return const MainShellScreen();
              }

              // First-run journey: the intro clip has already played, so the
              // visitor picks a path, answers the short questions, and then
              // signs in. Platform staff can reach the sign-in menu without
              // answering them, and the answers are optional for everyone.
              if (journey.staffLogin) return const LoginScreen();
              if (journey.intent == null) {
                return const IntentSelectionScreen();
              }
              if (!journey.surveyComplete) return const SurveyScreen();
              return const LoginScreen();
            },
          );
        },
      ),
    );
  }
}
