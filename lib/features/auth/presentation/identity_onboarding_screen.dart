import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kalla_lai/core/theme/kalla_lai_theme.dart';
import 'package:kalla_lai/features/auth/application/auth_cubit.dart';
import 'package:kalla_lai/features/auth/application/auth_state.dart';
import 'package:kalla_lai/features/auth/application/entry_journey_cubit.dart';
import 'package:kalla_lai/features/auth/presentation/document_verification_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class IdentityOnboardingScreen extends StatefulWidget {
  const IdentityOnboardingScreen({super.key});

  @override
  State<IdentityOnboardingScreen> createState() =>
      _IdentityOnboardingScreenState();
}

class _IdentityOnboardingScreenState extends State<IdentityOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _area = TextEditingController();
  final _education = TextEditingController();
  final _skills = TextEditingController();
  final _organization = TextEditingController();
  final _hiringSummary = TextEditingController();
  int _profileStep = 0;
  bool _consentGiven = false;
  String _verificationMode = 'VERIFF';

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthCubit>().state.user;
    _name.text = user?.fullName ?? '';
    if (user != null && user.onboardingComplete) {
      _loadVerificationMode();
    }
  }

  Future<void> _loadVerificationMode() async {
    final result = await context.read<AuthCubit>().loadIdentityStatus();
    if (!mounted || result == null) return;
    setState(() => _verificationMode = result.verificationMode);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _area.dispose();
    _education.dispose();
    _skills.dispose();
    _organization.dispose();
    _hiringSummary.dispose();
    super.dispose();
  }

  Future<void> _continueProfile(AuthCubit cubit, SessionUser user) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    if (_profileStep == 0) {
      setState(() => _profileStep = 1);
      return;
    }

    final profile = <String, dynamic>{
      'fullName': _name.text.trim(),
      'phone': _phone.text.trim(),
      if (user.isWorker)
        'worker': {
          'baseArea': _area.text.trim(),
          'education': _education.text.trim(),
          'skillsSummary': _skills.text.trim(),
        },
      if (user.isEmployer)
        'employer': {
          'organization': _organization.text.trim(),
          'worksiteArea': _area.text.trim(),
          'hiringSummary': _hiringSummary.text.trim(),
        },
    };
    await cubit.completeOnboarding(profile);
  }

  void _skipIdentity() {
    context.read<EntryJourneyCubit>().skipIdentity();
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop();
  }

  Future<void> _startVerification(AuthCubit cubit) async {
    if (!_consentGiven) return;

    // Demo mode runs the in-app Nepali document + selfie flow. Production
    // launches the hosted Veriff secure check below.
    if (_verificationMode == 'DEMO') {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const DocumentVerificationScreen(),
        ),
      );
      if (mounted) await cubit.refreshIdentityStatus();
      return;
    }

    final result = await cubit.startIdentityVerification();
    if (!mounted || result?.sessionUrl == null) return;

    final sessionUri = Uri.tryParse(result!.sessionUrl!);
    if (sessionUri == null ||
        sessionUri.scheme != 'https' ||
        !(sessionUri.host == 'veriff.com' ||
            sessionUri.host.endsWith('.veriff.com'))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The verification link was invalid.')),
      );
      return;
    }

    try {
      final launched = await launchUrl(
        sessionUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open the secure verification flow.'),
          ),
        );
      } else if (launched && mounted) {
        await cubit.refreshIdentityStatus();
      }
    } on Exception {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open the secure verification flow.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authCubit = context.read<AuthCubit>();
    final user = context.select<AuthCubit, SessionUser?>(
      (cubit) => cubit.state.user,
    );
    if (user == null) return const SizedBox.shrink();
    final auth = context.watch<AuthCubit>().state;
    final onboardingComplete = user.onboardingComplete;

    return Scaffold(
      appBar: AppBar(
        title: Text(onboardingComplete ? 'Identity check' : 'Your profile'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: auth.busy ? null : authCubit.signOut,
            icon: const Icon(Icons.logout),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        bottom: !onboardingComplete,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Form(
              key: _formKey,
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                children: [
                  _heading(user, onboardingComplete),
                  const SizedBox(height: 22),
                  if (onboardingComplete) ...[
                    _stepProgress(2),
                    const SizedBox(height: 20),
                    _buildVerification(user, authCubit, auth),
                    if (user.identityStatus != 'VERIFIED') ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: auth.busy ? null : _skipIdentity,
                        icon: const Icon(Icons.arrow_forward),
                        label: Text(
                          Navigator.of(context).canPop()
                              ? 'Close · verify later'
                              : 'Skip for now · verify later',
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'You can still browse and save jobs. Applying for a job stays locked until your identity is verified.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: KallaLaiColors.muted,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ] else ...[
                    _stepProgress(_profileStep),
                    const SizedBox(height: 20),
                    _profileCard(user),
                  ],
                  if (auth.errorMessage != null) ...[
                    const SizedBox(height: 14),
                    _errorNotice(auth.errorMessage!),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar:
          onboardingComplete
              ? null
              : SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: const Border(
                      top: BorderSide(color: KallaLaiColors.outline),
                    ),
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Row(
                      children: [
                        if (_profileStep > 0) ...[
                          OutlinedButton(
                            onPressed:
                                auth.busy
                                    ? null
                                    : () {
                                      FocusScope.of(context).unfocus();
                                      setState(() => _profileStep = 0);
                                    },
                            child: const Text('Back'),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: FilledButton(
                            onPressed:
                                auth.busy
                                    ? null
                                    : () => _continueProfile(authCubit, user),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                            ),
                            child:
                                auth.busy
                                    ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : Text(
                                      _profileStep == 0
                                          ? 'Continue'
                                          : 'Save and verify',
                                    ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
    );
  }

  Widget _heading(SessionUser user, bool onboardingComplete) {
    final title =
        onboardingComplete
            ? _verificationHeading(user.identityStatus)
            : _profileStep == 0
            ? 'Let’s get to know you'
            : user.isEmployer
            ? 'Tell us about your work'
            : 'Showcase your skills';
    final subtitle =
        onboardingComplete
            ? 'Verify it’s you to apply for jobs. You can skip this and verify later from your profile.'
            : _profileStep == 0
            ? 'A few quick details help make your account yours.'
            : user.isEmployer
            ? 'Help workers understand your organization and the roles you hire for.'
            : 'Tell employers where you work and what you can do.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: KallaLaiColors.indigo.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            onboardingComplete
                ? Icons.shield_outlined
                : user.isEmployer
                ? Icons.business_center_outlined
                : Icons.person_outline,
            color: KallaLaiColors.indigo,
            size: 28,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: KallaLaiColors.slate,
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: KallaLaiColors.muted,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  String _verificationHeading(String status) => switch (status) {
    'PENDING' => 'Verification in progress',
    'NEEDS_ACTION' => 'One more step needed',
    'REJECTED' => 'Let’s try verification again',
    _ => 'Verify it’s really you',
  };

  Widget _stepProgress(int currentStep) {
    const labels = ['Your details', 'About your work', 'Identity check'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(labels.length, (index) {
            final complete = index < currentStep;
            final active = index == currentStep;
            return Expanded(
              child: Container(
                height: 4,
                margin: EdgeInsets.only(
                  right: index == labels.length - 1 ? 0 : 6,
                ),
                decoration: BoxDecoration(
                  color:
                      complete || active
                          ? KallaLaiColors.indigo
                          : KallaLaiColors.outline,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 10),
        Text(
          'STEP ${currentStep + 1} OF ${labels.length}  ·  ${labels[currentStep]}',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: KallaLaiColors.muted,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _profileCard(SessionUser user) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KallaLaiRadii.lg),
        side: const BorderSide(color: KallaLaiColors.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children:
              _profileStep == 0
                  ? [
                    Center(
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 36,
                                backgroundColor: KallaLaiColors.indigo
                                    .withValues(alpha: 0.1),
                                child: const Icon(
                                  Icons.person_outline,
                                  size: 36,
                                  color: KallaLaiColors.indigo,
                                ),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: KallaLaiColors.indigo,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Padding(
                                    padding: EdgeInsets.all(5),
                                    child: Icon(
                                      Icons.add_a_photo_outlined,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Profile photo',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Photo upload will be available when secure image storage is configured.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: KallaLaiColors.muted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    _field(
                      _name,
                      'Full name',
                      icon: Icons.badge_outlined,
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 14),
                    _field(
                      _phone,
                      'Phone number',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      minLength: 6,
                    ),
                  ]
                  : [
                    _sectionLabel(
                      user.isEmployer
                          ? 'Hiring location'
                          : 'Where are you based?',
                      Icons.location_on_outlined,
                    ),
                    const SizedBox(height: 8),
                    _field(
                      _area,
                      user.isEmployer ? 'Worksite area / city' : 'Area / city',
                      icon: Icons.map_outlined,
                    ),
                    const SizedBox(height: 20),
                    if (user.isEmployer) ...[
                      _sectionLabel('Organization', Icons.apartment_outlined),
                      const SizedBox(height: 8),
                      _field(
                        _organization,
                        'Business or organization name',
                        icon: Icons.business_outlined,
                      ),
                      const SizedBox(height: 14),
                      _field(
                        _hiringSummary,
                        'What kind of workers do you hire?',
                        icon: Icons.groups_outlined,
                        maxLines: 4,
                      ),
                    ] else ...[
                      _sectionLabel(
                        'Education and trade',
                        Icons.workspace_premium_outlined,
                      ),
                      const SizedBox(height: 8),
                      _field(
                        _education,
                        'Education or trade qualification',
                        icon: Icons.school_outlined,
                      ),
                      const SizedBox(height: 14),
                      _field(
                        _skills,
                        'Skills and experience',
                        icon: Icons.handyman_outlined,
                        maxLines: 4,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      'Share your area or city only. Avoid adding your private home address.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: KallaLaiColors.muted,
                      ),
                    ),
                  ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label, IconData icon) => Row(
    children: [
      Icon(icon, size: 18, color: KallaLaiColors.indigo),
      const SizedBox(width: 8),
      Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    ],
  );

  Widget _buildVerification(SessionUser user, AuthCubit cubit, AuthState auth) {
    final status = user.identityStatus;
    final pending = status == 'PENDING';
    final statusColor = switch (status) {
      'PENDING' => KallaLaiColors.warningText,
      'VERIFIED' => KallaLaiColors.successText,
      'REJECTED' => KallaLaiColors.errorText,
      _ => KallaLaiColors.indigo,
    };
    final statusIcon = switch (status) {
      'PENDING' => Icons.hourglass_top_rounded,
      'VERIFIED' => Icons.check_circle_outline,
      'REJECTED' => Icons.error_outline,
      _ => Icons.shield_outlined,
    };

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KallaLaiRadii.lg),
        side: const BorderSide(color: KallaLaiColors.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(KallaLaiRadii.md),
              ),
              child: Row(
                children: [
                  Icon(statusIcon, color: statusColor, size: 26),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _verificationHeading(status),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _verificationStep(
              icon: Icons.document_scanner_outlined,
              title: 'Scan your ID',
              subtitle:
                  _verificationMode == 'DEMO'
                      ? 'Choose a Nepali document and upload it from gallery or camera.'
                      : 'Veriff reads supported documents securely.',
            ),
            _verificationStep(
              icon: Icons.face_retouching_natural_outlined,
              title: 'Confirm it’s you',
              subtitle: 'A live selfie helps check face match and liveness.',
            ),
            _verificationStep(
              icon: Icons.verified_user_outlined,
              title: 'Get approved to apply',
              subtitle:
                  'An approved decision unlocks applications. Browsing and saving stay open.',
              isLast: true,
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              _verificationMode == 'DEMO'
                  ? 'Upload a supported Nepali ID and a selfie. Kalla-Lai runs the OCR and face-match check and stores the decision, not your biometric media.'
                  : 'Your ID images and face video are handled in Veriff’s secure flow. Kalla-Lai stores the verification decision, not your biometric media.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: KallaLaiColors.muted,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
            if (pending) ...[
              FilledButton.tonalIcon(
                onPressed: auth.busy ? null : cubit.refreshIdentityStatus,
                icon: const Icon(Icons.refresh),
                label:
                    auth.busy
                        ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Text('Refresh status'),
              ),
              const SizedBox(height: 8),
              _consentTile(auth.busy),
              OutlinedButton(
                onPressed:
                    auth.busy || !_consentGiven
                        ? null
                        : () => _startVerification(cubit),
                child: const Text('Restart verification'),
              ),
            ] else ...[
              _consentTile(auth.busy),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed:
                    auth.busy || !_consentGiven
                        ? null
                        : () => _startVerification(cubit),
                icon: const Icon(Icons.lock_outline),
                label:
                    auth.busy
                        ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Text('Continue to secure check'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _verificationStep({
    required IconData icon,
    required String title,
    required String subtitle,
    bool isLast = false,
  }) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 42,
        child: Column(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: KallaLaiColors.indigo.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: KallaLaiColors.indigo, size: 21),
            ),
            if (!isLast)
              Container(width: 1, height: 24, color: KallaLaiColors.outline),
          ],
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: KallaLaiColors.muted,
                  height: 1.4,
                ),
              ),
              if (!isLast) const SizedBox(height: 14),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _consentTile(bool busy) => CheckboxListTile(
    value: _consentGiven,
    contentPadding: EdgeInsets.zero,
    controlAffinity: ListTileControlAffinity.leading,
    onChanged:
        busy ? null : (value) => setState(() => _consentGiven = value ?? false),
    title: Text(
      _verificationMode == 'DEMO'
          ? 'I agree to Kalla-Lai processing my ID and selfie for identity, face-match and liveness checks.'
          : 'I agree to Veriff processing my ID and selfie/video for identity, face-match and liveness checks.',
    ),
    subtitle: const Text(
      'Kalla-Lai receives the verification result, not the raw biometric media.',
    ),
  );

  Widget _errorNotice(String message) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFFEF2F2),
      borderRadius: BorderRadius.circular(KallaLaiRadii.sm),
      border: Border.all(color: const Color(0xFFFECACA)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.error_outline, color: KallaLaiColors.errorText),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: KallaLaiColors.errorText),
          ),
        ),
      ],
    ),
  );

  Widget _field(
    TextEditingController controller,
    String label, {
    required IconData icon,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.sentences,
    int maxLines = 1,
    int minLength = 2,
  }) => TextFormField(
    controller: controller,
    keyboardType: keyboardType,
    textCapitalization: textCapitalization,
    maxLines: maxLines,
    textInputAction:
        maxLines > 1 ? TextInputAction.newline : TextInputAction.next,
    validator:
        (value) =>
            (value == null || value.trim().length < minLength)
                ? 'Please enter a valid $label.'
                : null,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      alignLabelWithHint: maxLines > 1,
    ),
  );
}
