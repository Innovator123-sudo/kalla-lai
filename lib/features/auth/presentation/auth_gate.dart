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
                final workerNeedsIdentity =
                    !user.isDemoSession &&
                    user.isWorker &&
                    user.identityStatus != 'VERIFIED' &&
                    !journey.identitySkipped;
                if (workerNeedsIdentity) {
                  return const IdentityOnboardingScreen();
                }
                return const MainShellScreen();
              }

              // Proceed directly to the sign-in / registration screen. Role
              // choice (Worker vs Employer/Hirer) is confirmed only once during
              // account creation or Google sign-in.
              return const LoginScreen();
            },
          );
        },
      ),
    );
  }
}
