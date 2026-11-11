import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kalla_lai/core/theme/kalla_lai_theme.dart';
import 'package:kalla_lai/features/auth/application/entry_journey_cubit.dart';

/// The short first-run questionnaire, in the spirit of the questions a
/// marketplace like Fiverr asks before you create an account: a progress bar,
/// one question per screen, bigger tap targets, and a final review.
///
/// Answers are optional and are stored against the account only after a
/// successful sign-in, so every step can be skipped.
class SurveyScreen extends StatefulWidget {
  const SurveyScreen({super.key});

  @override
  State<SurveyScreen> createState() => _SurveyScreenState();
}

class _SurveyScreenState extends State<SurveyScreen> {
  /// Three questions, then one review step.
  static const int _questionCount = 3;
  static const int _lastStep = _questionCount;

  int _step = 0;
  String? _source;
  String? _timeline;
  String? _experience;

  static const _sources = <_SurveyOption>[
    _SurveyOption(
      value: 'FRIEND_FAMILY',
      label: 'Friend or family',
      subtitle: 'Someone I know told me about it',
      icon: Icons.people_outline,
    ),
    _SurveyOption(
      value: 'FACEBOOK_TIKTOK',
      label: 'Facebook or TikTok',
      subtitle: 'A post, an ad or a short video',
      icon: Icons.phone_android_outlined,
    ),
    _SurveyOption(
      value: 'GOOGLE_SEARCH',
      label: 'Google search',
      subtitle: 'I found it while searching online',
      icon: Icons.search,
    ),
    _SurveyOption(
      value: 'JOB_BOARD',
      label: 'Job board or newspaper',
      subtitle: 'A listing, an advert or a classified',
      icon: Icons.newspaper_outlined,
    ),
    _SurveyOption(
      value: 'COMMUNITY_EVENT',
      label: 'Community event',
      subtitle: 'A fair, an office or a local event',
      icon: Icons.groups_outlined,
    ),
    _SurveyOption(
      value: 'OTHER',
      label: 'Somewhere else',
      subtitle: 'None of these fit',
      icon: Icons.more_horiz,
    ),
  ];

  static const _timelines = <_SurveyOption>[
    _SurveyOption(
      value: 'THIS_WEEK',
      label: 'This week',
      subtitle: 'In the next few days',
      icon: Icons.bolt_outlined,
    ),
    _SurveyOption(
      value: 'THIS_MONTH',
      label: 'This month',
      subtitle: 'Sometime in the next few weeks',
      icon: Icons.calendar_month_outlined,
    ),
    _SurveyOption(
      value: 'EXPLORING',
      label: 'Just exploring',
      subtitle: 'I am only looking around for now',
      icon: Icons.explore_outlined,
    ),
  ];

  static const _experienceWorker = <_SurveyOption>[
    _SurveyOption(
      value: 'NEW',
      label: 'This would be my first job',
      subtitle: 'I have not been paid for this work yet',
      icon: Icons.eco_outlined,
    ),
    _SurveyOption(
      value: 'SOME',
      label: '1-3 years of experience',
      subtitle: 'I have done this kind of work before',
      icon: Icons.trending_up,
    ),
    _SurveyOption(
      value: 'EXPERIENCED',
      label: '3+ years of experience',
      subtitle: 'This has been my work for years',
      icon: Icons.workspace_premium_outlined,
    ),
  ];

  static const _experienceEmployer = <_SurveyOption>[
    _SurveyOption(
      value: 'NEW',
      label: 'This is my first time hiring',
      subtitle: 'I have never hired anyone before',
      icon: Icons.eco_outlined,
    ),
    _SurveyOption(
      value: 'SOME',
      label: 'I hire occasionally',
      subtitle: 'A few short jobs each year',
      icon: Icons.trending_up,
    ),
    _SurveyOption(
      value: 'EXPERIENCED',
      label: 'I hire regularly',
      subtitle: 'Hiring help is part of my week',
      icon: Icons.workspace_premium_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final intent =
        context.select<EntryJourneyCubit, EntryIntent?>(
          (cubit) => cubit.state.intent,
        ) ??
        EntryIntent.worker;
    final isEmployer = intent == EntryIntent.employer;
    final isReview = _step == _lastStep;
    final experienceOptions =
        isEmployer ? _experienceEmployer : _experienceWorker;

    final question = switch (_step) {
      0 => 'Where did you hear about Kalla-Lai?',
      1 => isEmployer ? 'When do you need help?' : 'When do you want to start?',
      2 =>
        isEmployer
            ? 'How often do you hire?'
            : 'How much work experience do you have?',
      _ => 'Does this look right?',
    };
    final helper = switch (_step) {
      0 => 'This helps us reach more people like you.',
      1 => 'A rough answer is fine, and you can change it later.',
      2 =>
        isEmployer
            ? 'No experience is needed to post a shift.'
            : 'No experience is needed to create a profile.',
      _ => 'You can edit any answer, or change it later in settings.',
    };
    final options = switch (_step) {
      0 => _sources,
      1 => _timelines,
      2 => experienceOptions,
      _ => const <_SurveyOption>[],
    };
    final selected = switch (_step) {
      0 => _source,
      1 => _timeline,
      2 => _experience,
      _ => null,
    };
    // The review step is only reached once every question is answered.
    final canContinue = isReview || selected != null;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip:
              _step == 0 ? 'Back to the first choice' : 'Previous question',
          onPressed:
              _step == 0
                  ? () => context.read<EntryJourneyCubit>().changeIntent()
                  : () => setState(() => _step -= 1),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: List.generate(
                      _lastStep + 1,
                      (index) => Expanded(
                        child: Container(
                          height: 5,
                          margin: EdgeInsets.only(
                            right: index == _lastStep ? 0 : 7,
                          ),
                          decoration: BoxDecoration(
                            color:
                                index <= _step
                                    ? KallaLaiColors.indigo
                                    : KallaLaiColors.outline,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isReview
                        ? 'REVIEW YOUR ANSWERS'
                        : 'QUESTION ${_step + 1} OF $_questionCount',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: KallaLaiColors.muted,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            question,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: KallaLaiColors.slate,
                                  fontWeight: FontWeight.w800,
                                  height: 1.25,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            helper,
                            style: const TextStyle(color: KallaLaiColors.muted),
                          ),
                          const SizedBox(height: 18),
                          if (isReview) ...[
                            _AnswerRow(
                              icon: Icons.campaign_outlined,
                              question: 'Where did you hear about us?',
                              answer: _labelFor(_sources, _source),
                              onEdit: () => setState(() => _step = 0),
                            ),
                            _AnswerRow(
                              icon: Icons.schedule_outlined,
                              question:
                                  isEmployer
                                      ? 'When do you need help?'
                                      : 'When do you want to start?',
                              answer: _labelFor(_timelines, _timeline),
                              onEdit: () => setState(() => _step = 1),
                            ),
                            _AnswerRow(
                              icon: Icons.workspace_premium_outlined,
                              question:
                                  isEmployer
                                      ? 'How often do you hire?'
                                      : 'Work experience',
                              answer: _labelFor(experienceOptions, _experience),
                              onEdit: () => setState(() => _step = 2),
                              isLast: true,
                            ),
                          ] else
                            for (final option in options)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _SurveyOptionTile(
                                  option: option,
                                  selected: selected == option.value,
                                  onTap:
                                      () => setState(() {
                                        switch (_step) {
                                          case 0:
                                            _source = option.value;
                                            break;
                                          case 1:
                                            _timeline = option.value;
                                            break;
                                          default:
                                            _experience = option.value;
                                        }
                                      }),
                                ),
                              ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: canContinue ? _continue : null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                    ),
                    icon: Icon(isReview ? Icons.check : Icons.arrow_forward),
                    label: Text(
                      isReview ? 'Create my account' : 'Next question',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed:
                        () => context.read<EntryJourneyCubit>().skipSurvey(),
                    child: const Text('Skip the questions'),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Answers are saved with your account after sign-in and are used only to improve Kalla-Lai. You can skip them.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: KallaLaiColors.muted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Moves to the next question, and on the review step saves the answers.
  void _continue() {
    if (_step < _lastStep) {
      setState(() => _step += 1);
      return;
    }
    final source = _source;
    final timeline = _timeline;
    final experience = _experience;
    if (source == null || timeline == null || experience == null) return;
    context.read<EntryJourneyCubit>().completeSurvey(
      acquisitionSource: source,
      timeline: timeline,
      experience: experience,
    );
  }

  /// Human label for a stored answer value, used by the review step.
  static String _labelFor(List<_SurveyOption> options, String? value) {
    for (final option in options) {
      if (option.value == value) return option.label;
    }
    return 'Not answered';
  }
}

class _SurveyOption {
  const _SurveyOption({
    required this.value,
    required this.label,
    required this.subtitle,
    required this.icon,
  });

  final String value;
  final String label;
  final String subtitle;
  final IconData icon;
}

/// One tappable answer: icon, title, a one-line explanation and a clear
/// selected state, the way a marketplace onboarding screen lists its choices.
class _SurveyOptionTile extends StatelessWidget {
  const _SurveyOptionTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _SurveyOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: option.label,
      hint: option.subtitle,
      child: Material(
        color:
            selected
                ? KallaLaiColors.indigo.withValues(alpha: 0.06)
                : Colors.white,
        borderRadius: BorderRadius.circular(KallaLaiRadii.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(KallaLaiRadii.md),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(KallaLaiRadii.md),
              border: Border.all(
                color:
                    selected ? KallaLaiColors.indigo : KallaLaiColors.outline,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  option.icon,
                  color: selected ? KallaLaiColors.indigo : KallaLaiColors.muted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option.label,
                        style: TextStyle(
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        option.subtitle,
                        style: const TextStyle(
                          color: KallaLaiColors.muted,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  selected ? Icons.check_circle : Icons.circle_outlined,
                  size: 20,
                  color:
                      selected
                          ? KallaLaiColors.indigo
                          : const Color(0xFFCBD5E1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One line of the review step: what was asked, the answer that was given, and
/// a way back to that question.
class _AnswerRow extends StatelessWidget {
  const _AnswerRow({
    required this.icon,
    required this.question,
    required this.answer,
    required this.onEdit,
    this.isLast = false,
  });

  final IconData icon;
  final String question;
  final String answer;
  final VoidCallback onEdit;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: KallaLaiColors.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  question,
                  style: const TextStyle(
                    color: KallaLaiColors.muted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  answer,
                  style: const TextStyle(
                    color: KallaLaiColors.slate,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onEdit,
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 36),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text('Edit'),
          ),
        ],
      ),
    );
  }
}
