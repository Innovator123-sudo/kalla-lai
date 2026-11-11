import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kalla_lai/core/theme/kalla_lai_theme.dart';
import 'package:kalla_lai/features/auth/application/entry_journey_cubit.dart';

/// Three easy questions before sign-in. Answers are optional and are stored
/// against the account only after a successful sign-in.
class SurveyScreen extends StatefulWidget {
  const SurveyScreen({super.key});

  @override
  State<SurveyScreen> createState() => _SurveyScreenState();
}

class _SurveyScreenState extends State<SurveyScreen> {
  int _step = 0;
  String? _source;
  String? _timeline;
  String? _experience;

  static const _sources = <_SurveyOption>[
    _SurveyOption(
      value: 'FRIEND_FAMILY',
      label: 'Friend or family',
      icon: Icons.people_outline,
    ),
    _SurveyOption(
      value: 'FACEBOOK_TIKTOK',
      label: 'Facebook or TikTok',
      icon: Icons.phone_android_outlined,
    ),
    _SurveyOption(
      value: 'GOOGLE_SEARCH',
      label: 'Google search',
      icon: Icons.search,
    ),
    _SurveyOption(
      value: 'JOB_BOARD',
      label: 'Job board or newspaper',
      icon: Icons.newspaper_outlined,
    ),
    _SurveyOption(
      value: 'COMMUNITY_EVENT',
      label: 'Community event',
      icon: Icons.groups_outlined,
    ),
    _SurveyOption(
      value: 'OTHER',
      label: 'Somewhere else',
      icon: Icons.more_horiz,
    ),
  ];

  static const _timelines = <_SurveyOption>[
    _SurveyOption(
      value: 'THIS_WEEK',
      label: 'This week',
      icon: Icons.bolt_outlined,
    ),
    _SurveyOption(
      value: 'THIS_MONTH',
      label: 'This month',
      icon: Icons.calendar_month_outlined,
    ),
    _SurveyOption(
      value: 'EXPLORING',
      label: 'Just exploring',
      icon: Icons.explore_outlined,
    ),
  ];

  static const _experienceWorker = <_SurveyOption>[
    _SurveyOption(
      value: 'NEW',
      label: 'This would be my first job',
      icon: Icons.eco_outlined,
    ),
    _SurveyOption(
      value: 'SOME',
      label: '1–3 years of experience',
      icon: Icons.trending_up,
    ),
    _SurveyOption(
      value: 'EXPERIENCED',
      label: '3+ years of experience',
      icon: Icons.workspace_premium_outlined,
    ),
  ];

  static const _experienceEmployer = <_SurveyOption>[
    _SurveyOption(
      value: 'NEW',
      label: 'This is my first time hiring',
      icon: Icons.eco_outlined,
    ),
    _SurveyOption(
      value: 'SOME',
      label: 'I hire occasionally',
      icon: Icons.trending_up,
    ),
    _SurveyOption(
      value: 'EXPERIENCED',
      label: 'I hire regularly',
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

    final question = switch (_step) {
      0 => 'Where did you hear about Kalla-Lai?',
      1 => isEmployer ? 'When do you need help?' : 'When do you want to start?',
      _ =>
        isEmployer
            ? 'How often do you hire?'
            : 'How much work experience do you have?',
    };
    final helper = switch (_step) {
      0 => 'This helps us reach more people like you.',
      1 =>
        isEmployer
            ? 'A rough answer is fine — you can change it later.'
            : 'A rough answer is fine — you can change it later.',
      _ =>
        isEmployer
            ? 'No experience is needed to post a shift.'
            : 'No experience is needed to create a profile.',
    };
    final options = switch (_step) {
      0 => _sources,
      1 => _timelines,
      _ => isEmployer ? _experienceEmployer : _experienceWorker,
    };
    final selected = switch (_step) {
      0 => _source,
      1 => _timeline,
      _ => _experience,
    };

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _step > 0
            ? IconButton(
                tooltip: 'Previous question',
                onPressed: () => setState(() => _step -= 1),
                icon: const Icon(Icons.arrow_back),
              )
            : null,
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
                      3,
                      (index) => Expanded(
                        child: Container(
                          height: 5,
                          margin: EdgeInsets.only(right: index == 2 ? 0 : 7),
                          decoration: BoxDecoration(
                            color:
                                index <= _step
                                    ? KallaLaiColors.indigo
                                    : const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'QUESTION ${_step + 1} OF 3',
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
                            style: Theme.of(
                              context,
                            ).textTheme.titleLarge?.copyWith(
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
                    onPressed:
                        selected == null
                            ? null
                            : () {
                              if (_step < 2) {
                                setState(() => _step += 1);
                              } else {
                                context
                                    .read<EntryJourneyCubit>()
                                    .completeSurvey(
                                      acquisitionSource: _source!,
                                      timeline: _timeline!,
                                      experience: _experience!,
                                    );
                              }
                            },
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                    ),
                    icon: Icon(_step == 2 ? Icons.check : Icons.arrow_forward),
                    label: Text(
                      _step == 2 ? 'Finish and sign in' : 'Next question',
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
}

class _SurveyOption {
  const _SurveyOption({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;
}

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
                  color:
                      selected ? KallaLaiColors.indigo : KallaLaiColors.muted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    option.label,
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
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
