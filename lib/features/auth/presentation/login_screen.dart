import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kalla_lai/core/config/app_config.dart';
import 'package:kalla_lai/core/storage/session_store.dart';
import 'package:kalla_lai/core/localization/app_strings.dart';
import 'package:kalla_lai/core/theme/kalla_lai_theme.dart';
import 'package:kalla_lai/core/widgets/demo_banner.dart';
import 'package:kalla_lai/core/widgets/loading_animation.dart';
import 'package:kalla_lai/features/auth/application/auth_cubit.dart';
import 'package:kalla_lai/features/auth/application/auth_state.dart';
import 'package:kalla_lai/features/auth/application/entry_journey_cubit.dart';
import 'package:kalla_lai/features/settings/presentation/settings_screen.dart';

/// Sign-in / create-account menu.
///
/// Easy-by-design: one screen, big tap targets, demo accounts that fill
/// themselves, and a single honest error line that always comes from either
/// local validation or the API.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'settings_login',
        tooltip: 'Settings',
        onPressed: () => openSettings(context),
        child: const Icon(Icons.settings_outlined),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: const _LoginCard(),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginCard extends StatefulWidget {
  const _LoginCard();

  @override
  State<_LoginCard> createState() => _LoginCardState();
}

class _LoginCardState extends State<_LoginCard> {
  final _email = TextEditingController(
    text: SessionStore.rememberedEmail ?? '',
  );
  final _password = TextEditingController();
  final _fullName = TextEditingController();
  final _organization = TextEditingController();
  bool _createMode = false;
  late bool _asEmployer;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _asEmployer =
        context.read<EntryJourneyCubit>().state.intent == EntryIntent.employer;
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _fullName.dispose();
    _organization.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    final cubit = context.read<AuthCubit>();
    SessionStore.saveEmail(_email.text);
    if (_createMode) {
      cubit.signUp(
        email: _email.text,
        password: _password.text,
        fullName: _fullName.text,
        asEmployer: _asEmployer,
        organization: _organization.text,
      );
    } else {
      cubit.signIn(_email.text, _password.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final journey = context.watch<EntryJourneyCubit>().state;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 28),
        Image.asset(
          'assets/images/kalla_lai_logo.png',
          height: 100,
          fit: BoxFit.contain,
          semanticLabel: 'कल्ला-लाई',
        ),
        const SizedBox(height: 8),
        Text(strings.text('login_subtitle'), textAlign: TextAlign.center),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: BlocBuilder<AuthCubit, AuthState>(
              builder: (context, auth) {
                final googleSignInConfigured = true;
                return Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SegmentedButton<bool>(
                          segments: [
                            ButtonSegment(
                              value: false,
                              icon: const Icon(Icons.login),
                              label: Text(strings.text('signin')),
                            ),
                            ButtonSegment(
                              value: true,
                              icon: const Icon(Icons.person_add_alt_1_outlined),
                              label: Text(strings.text('create_account')),
                            ),
                          ],
                          selected: {_createMode},
                          onSelectionChanged:
                              (selection) =>
                                  setState(() => _createMode = selection.first),
                        ),
                        const SizedBox(height: 18),
                        if (_createMode) ...[
                          TextFormField(
                            controller: _fullName,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Full name',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            strings.text('account_type'),
                            style: const TextStyle(color: KallaLaiColors.muted),
                          ),
                          const SizedBox(height: 6),
                          SegmentedButton<bool>(
                            segments: [
                              ButtonSegment(
                                value: false,
                                icon: const Icon(Icons.engineering_outlined),
                                label: Text(strings.text('role_worker')),
                              ),
                              ButtonSegment(
                                value: true,
                                icon: const Icon(
                                  Icons.business_center_outlined,
                                ),
                                label: Text(strings.text('role_employer')),
                              ),
                            ],
                            selected: {_asEmployer},
                            onSelectionChanged:
                                (selection) => setState(
                                  () => _asEmployer = selection.first,
                                ),
                          ),
                          if (_asEmployer) ...[
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _organization,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Organization (optional)',
                                prefixIcon: Icon(Icons.apartment_outlined),
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                        ],
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Email or ID',
                            prefixIcon: Icon(Icons.alternate_email),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _password,
                          obscureText: _obscure,
                          autofillHints: const [AutofillHints.password],
                          onFieldSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            labelText: strings.text('password'),
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              tooltip:
                                  _obscure ? 'Show password' : 'Hide password',
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed:
                                  () => setState(() => _obscure = !_obscure),
                            ),
                          ),
                        ),
                        if (auth.errorMessage != null) ...[
                          const SizedBox(height: 12),
                          Semantics(
                            liveRegion: true,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFDE8E8),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    color: KallaLaiColors.crimson,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      auth.errorMessage!,
                                      style: const TextStyle(
                                        color: KallaLaiColors.crimson,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: auth.busy ? null : _submit,
                          icon:
                              auth.busy
                                  ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : Icon(
                                    _createMode
                                        ? Icons.person_add_alt_1
                                        : Icons.login,
                                  ),
                          label: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              _createMode
                                  ? strings.text('create_btn')
                                  : strings.text('signin_btn'),
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (!_createMode && googleSignInConfigured) ...[
                          Text(
                            strings.text('google_account_type'),
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 8),
                          SegmentedButton<bool>(
                            showSelectedIcon: false,
                            segments: [
                              ButtonSegment(
                                value: false,
                                icon: const Icon(Icons.engineering_outlined),
                                label: Text(strings.text('role_worker')),
                              ),
                              ButtonSegment(
                                value: true,
                                icon: const Icon(
                                  Icons.business_center_outlined,
                                ),
                                label: Text(strings.text('role_employer')),
                              ),
                            ],
                            selected: {_asEmployer},
                            onSelectionChanged:
                                (selection) => setState(
                                  () => _asEmployer = selection.first,
                                ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        OutlinedButton.icon(
                          onPressed:
                              !auth.busy && googleSignInConfigured
                                  ? () => context
                                      .read<AuthCubit>()
                                      .signInWithGoogle(asEmployer: _asEmployer)
                                  : null,
                          icon: const Icon(Icons.account_circle_outlined),
                          label: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Text(strings.text('google_sign_in')),
                          ),
                        ),
                      ],
                    ),
                    if (auth.busy)
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            color: Colors.white.withValues(alpha: 0.88),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const CircularProgressIndicator(strokeWidth: 2.5),
                                  const SizedBox(height: 14),
                                  Text(
                                    _createMode
                                        ? 'Creating your account…'
                                        : 'Signing in…',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: KallaLaiColors.slate,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Shows the choice made before the survey and offers a one-tap way back.
class _PathBanner extends StatelessWidget {
  const _PathBanner({required this.intent, required this.onChange});

  final EntryIntent intent;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: KallaLaiColors.indigo.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KallaLaiColors.indigo.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(
            intent == EntryIntent.employer
                ? Icons.business_center_outlined
                : Icons.engineering_outlined,
            size: 20,
            color: KallaLaiColors.indigo,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              intent == EntryIntent.employer
                  ? 'Hiring path · post work'
                  : 'Worker path · verify before applying',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: KallaLaiColors.indigo,
                fontSize: 13,
              ),
            ),
          ),
          TextButton(onPressed: onChange, child: const Text('Change')),
        ],
      ),
    );
  }
}
