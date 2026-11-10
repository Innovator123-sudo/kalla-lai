import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:kalla_lai/core/localization/app_strings.dart';
import 'package:kalla_lai/core/maps/map_link.dart';
import 'package:kalla_lai/core/maps/map_preview.dart';
import 'package:kalla_lai/core/theme/kalla_lai_theme.dart';
import 'package:kalla_lai/core/widgets/loading_animation.dart';
import 'package:kalla_lai/features/discovery/application/vacancy_discovery_cubit.dart';
import 'package:kalla_lai/features/hiring/application/hiring_requisition_cubit.dart';
import 'package:kalla_lai/features/hiring/domain/job_catalog.dart';
import 'package:kalla_lai/features/hiring/presentation/job_type_picker_screen.dart';
import 'package:kalla_lai/features/mode/application/mode_switcher_cubit.dart';
import 'package:kalla_lai/features/shared/domain/marketplace_models.dart';

/// Question-style requisition wizard: one plain question per step, big tap
/// targets, and an honest ending that states exactly where the data went.
class HiringRequisitionWizardScreen extends StatelessWidget {
  const HiringRequisitionWizardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<HiringRequisitionCubit, HiringWizardState>(
      listenWhen:
          (previous, current) =>
              previous.errorMessage != current.errorMessage ||
              previous.serverDraft != current.serverDraft ||
              previous.serverJobId != current.serverJobId,
      listener: (context, state) {
        // A job only enters worker discovery after it is PUBLISHED. Refresh
        // the shared discovery cubit immediately so switching to the worker
        // side shows the new job without restarting the app.
        if (state.submitted && state.serverJobId != null && !state.serverDraft) {
          context.read<VacancyDiscoveryCubit>().load();
        }
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                backgroundColor: KallaLaiColors.crimson,
              ),
            );
        }
      },
      builder: (context, state) {
        if (state.submitted) {
          return _SubmittedView(state: state);
        }
        if (state.submitting) {
          return const LoadingAnimation(
            child: Center(
              child: Text(
                'Posting your work…',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: KallaLaiColors.slate,
                ),
              ),
            ),
          );
        }
        return SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            children: [
              Text(
                AppStrings.of(context).text('hiring_title'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: KallaLaiColors.slate,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                AppStrings.of(context).text('hiring_intro'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              Text(
                AppStrings.of(context)
                    .text('hiring_progress')
                    .replaceAll('{step}', '${state.step.index + 1}'),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: KallaLaiColors.indigo,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              _WizardProgress(step: state.step.index),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: _WizardStepContent(state: state),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  if (state.step != HiringStep.work) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            state.submitting
                                ? null
                                : () =>
                                    context
                                        .read<HiringRequisitionCubit>()
                                        .previous(),
                        child: const Text('Back'),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed:
                          state.submitting
                              ? null
                              : () =>
                                  context.read<HiringRequisitionCubit>().next(),
                      icon:
                          state.submitting
                              ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Icon(Icons.arrow_forward),
                      label: Text(
                        state.step == HiringStep.review
                            ? 'Confirm & send'
                            : 'Continue',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed:
                    state.submitting
                        ? null
                        : () =>
                            context
                                .read<HiringRequisitionCubit>()
                                .submitLocalPreview(),
                icon: const Icon(Icons.preview_outlined, size: 18),
                label: const Text('Skip server · preview locally'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WizardStepContent extends StatelessWidget {
  const _WizardStepContent({required this.state});

  final HiringWizardState state;

  static const _employmentTypes = {
    'FULL_TIME': 'Full-time',
    'PART_TIME': 'Part-time',
    'CONTRACT': 'Contract',
    'TEMPORARY': 'Temporary',
    'INTERNSHIP': 'Internship',
  };

  static const _compensationTypes = {
    'HOURLY': 'Hourly',
    'DAILY': 'Daily',
    'PROJECT': 'Project',
    'MILESTONE': 'Milestone',
  };

  static String _unit(String type) => switch (type) {
    'HOURLY' => 'hour',
    'PROJECT' => 'project',
    'MILESTONE' => 'milestone',
    _ => 'shift',
  };

  Future<void> _pickJobType(
    BuildContext context,
    HiringRequisitionCubit cubit,
  ) async {
    final selection = await Navigator.of(context).push<JobTypeSelection>(
      MaterialPageRoute(
        builder: (_) => JobTypePickerScreen(initialTitle: state.role),
      ),
    );
    if (selection != null) {
      cubit.setJobType(selection.title, selection.category);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<HiringRequisitionCubit>();
    switch (state.step) {
      case HiringStep.work:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _QuestionHeading(
              number: '01',
              question: 'What kind of work do you need?',
            ),
            const SizedBox(height: 16),
            Material(
              color: KallaLaiColors.indigo.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _pickJobType(context, cubit),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: KallaLaiColors.indigo.withValues(alpha: 0.12),
                        child: Icon(jobCategoryIcon(state.category), color: KallaLaiColors.indigo),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(state.role, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                            const SizedBox(height: 2),
                            Text('${state.category} · tap to change', style: const TextStyle(color: KallaLaiColors.muted, fontSize: 12)),
                          ],
                        ),
                      ),
                      const Icon(Icons.expand_more, color: KallaLaiColors.muted),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pick from $jobTypeCount job types, or search and type your own.',
              style: const TextStyle(color: KallaLaiColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 14),
            TextFormField(
              initialValue: state.contactPhone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Contact phone number',
                hintText: 'e.g. 98XXXXXXXX',
                prefixIcon: Icon(Icons.phone_outlined),
                helperText: 'Shown to workers who want to reach you about this job.',
              ),
              onChanged: cubit.setContactPhone,
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: state.details,
              maxLines: 3,
              maxLength: 4000,
              decoration: const InputDecoration(
                labelText: 'Anything else workers should know?',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.notes_outlined),
              ),
              onChanged: cubit.setDetails,
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: state.companyInfo,
              maxLines: 2,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: 'About your company (optional)',
                hintText: 'e.g. We are a growing construction firm with 10+ ongoing projects',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.business_outlined),
                helperText: 'Shown to workers so they know who they are working for.',
              ),
              onChanged: cubit.setCompanyInfo,
            ),
          ],
        );
      case HiringStep.schedule:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _QuestionHeading(
              number: '02',
              question: 'Where & when is the work?',
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: state.area,
              decoration: const InputDecoration(
                labelText: 'Location (area, not exact address)',
                hintText: 'e.g. Kathmandu · Baneshwor',
                prefixIcon: Icon(Icons.location_on_outlined),
                helperText: 'Keep the exact address private until a shift is confirmed.',
              ),
              onChanged: cubit.setArea,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: state.locating ? null : cubit.useMyLocation,
              icon: state.locating
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location),
              label: Text(state.hasTrueLocation ? 'True location captured' : 'Use my true location'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: state.googleMapsLink,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: 'Google Maps link or pin (optional)',
                hintText: 'https://maps.app.goo.gl/… or 27.7172, 85.3240',
                prefixIcon: const Icon(Icons.map_outlined),
                helperText:
                    'Workers get a directions button for this exact location.',
                errorText: state.hasInvalidMapsLink
                    ? 'Use a Google Maps link or a coordinate pin.'
                    : null,
              ),
              onChanged: cubit.setGoogleMapsLink,
            ),
            if (state.googleMapsLink.trim().isNotEmpty || state.hasTrueLocation) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 200,
                width: double.infinity,
                child: buildMapPreview(
                  link: state.googleMapsLink,
                  latitude: state.latitude,
                  longitude: state.longitude,
                  area: state.area,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: cubit.openDirections,
                  icon: const Icon(Icons.directions_outlined),
                  label: const Text('Open directions in Google Maps'),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Saved with the job: ${MapLink.pinLabel(state.latitude, state.longitude).isEmpty ? state.area.trim() : MapLink.pinLabel(state.latitude, state.longitude)}',
                style: const TextStyle(color: KallaLaiColors.muted, fontSize: 12),
              ),
            ],
            const SizedBox(height: 14),
            TextFormField(
              initialValue: state.workingHours,
              decoration: const InputDecoration(
                labelText: 'Working hours',
                hintText: 'e.g. 8 hrs/day · Sun–Fri, 9am–5pm',
                prefixIcon: Icon(Icons.schedule_outlined),
              ),
              onChanged: cubit.setWorkingHours,
            ),
            const SizedBox(height: 16),
            const Text('Employment type', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in _employmentTypes.entries)
                  ChoiceChip(
                    label: Text(entry.value),
                    selected: state.employmentType == entry.key,
                    onSelected: (_) => cubit.setEmploymentType(entry.key),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(child: Text('Workers needed', style: TextStyle(fontWeight: FontWeight.w700))),
                IconButton.filledTonal(
                  onPressed: state.openings <= 1 ? null : () => cubit.setOpenings(state.openings - 1),
                  icon: const Icon(Icons.remove),
                ),
                SizedBox(width: 40, child: Text('${state.openings}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                IconButton.filledTonal(
                  onPressed: () => cubit.setOpenings(state.openings + 1),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('Shift window', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final shift in _shifts)
                  ChoiceChip(
                    label: Text(shift),
                    selected: state.shiftLabel == shift,
                    onSelected: (_) => cubit.setShift(shift),
                  ),
              ],
            ),
          ],
        );
      case HiringStep.budget:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _QuestionHeading(number: '03', question: 'Pay & salary'),
            const SizedBox(height: 8),
            Text(
              'NPR ${NumberFormat('#,##0').format(state.rateNpr)} / ${_unit(state.compensationType)}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
                fontFamily: KallaLaiTypography.numeric,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: '${state.rateNpr}',
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Price (NPR)',
                prefixIcon: Icon(Icons.payments_outlined),
                isDense: true,
              ),
              onChanged: (value) => cubit.setRate(int.tryParse(value.trim()) ?? state.rateNpr),
            ),
            Slider(
              min: 0,
              max: 10000,
              divisions: 100,
              value: state.rateNpr.toDouble().clamp(0, 10000),
              label: 'NPR ${state.rateNpr}',
              onChanged: (value) => cubit.setRate(value.round()),
            ),
            const Text('Paid per', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in _compensationTypes.entries)
                  ChoiceChip(
                    label: Text(entry.value),
                    selected: state.compensationType == entry.key,
                    onSelected: (_) => cubit.setCompensationType(entry.key),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Price is negotiable'),
              value: state.negotiable,
              onChanged: cubit.setNegotiable,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Salary increases over time'),
              subtitle: const Text('Pay rises with performance or tenure.'),
              value: state.salaryIncrement,
              onChanged: cubit.setSalaryIncrement,
            ),
            if (state.salaryIncrement)
              TextFormField(
                initialValue: state.incrementNote,
                decoration: const InputDecoration(
                  labelText: 'How does it increase? (optional)',
                  hintText: 'e.g. +10% after 3 months',
                  prefixIcon: Icon(Icons.trending_up),
                  isDense: true,
                ),
                onChanged: cubit.setIncrementNote,
              ),
            const SizedBox(height: 8),
            const Text(
              'Visible to workers up front. Server rules control any real payment.',
              style: TextStyle(color: KallaLaiColors.muted),
            ),
          ],
        );
      case HiringStep.review:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _QuestionHeading(number: '04', question: 'Review & confirm'),
            const SizedBox(height: 16),
            _SummaryLine(label: 'Job', value: state.role),
            _SummaryLine(label: 'Category', value: state.category),
            _SummaryLine(label: 'Location', value: state.area),
            if (state.googleMapsLink.isNotEmpty)
              _SummaryLine(label: 'Google Maps', value: state.googleMapsLink),
            if (state.hasTrueLocation)
              const _SummaryLine(label: 'GPS pin', value: 'Location captured'),
            if (state.workingHours.trim().isNotEmpty)
              _SummaryLine(label: 'Hours', value: state.workingHours.trim()),
            _SummaryLine(label: 'Type', value: _employmentTypes[state.employmentType] ?? state.employmentType),
            _SummaryLine(label: 'Openings', value: '${state.openings} worker(s)'),
            _SummaryLine(label: 'When', value: state.shiftLabel),
            _SummaryLine(
              label: 'Pay',
              value: 'NPR ${NumberFormat('#,##0').format(state.rateNpr)} / ${_unit(state.compensationType)}${state.negotiable ? ' · negotiable' : ''}',
            ),
            _SummaryLine(
              label: 'Salary growth',
              value: state.salaryIncrement
                  ? 'Yes${state.incrementNote.trim().isEmpty ? '' : ' · ${state.incrementNote.trim()}'}'
                  : 'No increase',
            ),
            if (state.contactPhone.trim().isNotEmpty)
              _SummaryLine(label: 'Phone', value: state.contactPhone.trim()),
            if (state.companyInfo.trim().isNotEmpty)
              _SummaryLine(label: 'Company', value: state.companyInfo.trim()),
            if (state.details.trim().isNotEmpty)
              _SummaryLine(label: 'Notes', value: state.details.trim()),
            const SizedBox(height: 12),
            const Text(
              'With an employer account the job is created and published immediately so workers can find it. Without one it stays a local preview. No worker is reserved and no funds move.',
              style: TextStyle(color: KallaLaiColors.muted),
            ),
          ],
        );
    }
  }

  static const _shifts = [
    'Today · 10:00–16:00',
    'Tomorrow · 08:00–14:00',
    'Tomorrow · 10:00–16:00',
    'This weekend · flexible',
  ];
}

class _QuestionHeading extends StatelessWidget {
  const _QuestionHeading({required this.number, required this.question});

  final String number;
  final String question;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        number,
        style: const TextStyle(
          color: KallaLaiColors.indigo,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              question,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    ],
  );
}

class _WizardProgress extends StatelessWidget {
  const _WizardProgress({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) => Row(
    children: List.generate(
      4,
      (index) => Expanded(
        child: Container(
          height: 5,
          margin: EdgeInsets.only(right: index == 3 ? 0 : 7),
          decoration: BoxDecoration(
            color:
                index <= step ? KallaLaiColors.indigo : const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    ),
  );
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 84,
          child: Text(
            label,
            style: const TextStyle(color: KallaLaiColors.muted),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class _SubmittedView extends StatelessWidget {
  const _SubmittedView({required this.state});

  final HiringWizardState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<HiringRequisitionCubit>();
    final wentToServer = state.serverJobId != null;
    final published = wentToServer && !state.serverDraft;
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              published
                  ? Icons.cloud_done_outlined
                  : wentToServer
                      ? Icons.pending_actions_outlined
                      : Icons.preview_outlined,
              size: 52,
              color: published
                  ? KallaLaiColors.indigo
                  : wentToServer
                      ? KallaLaiColors.warningText
                      : KallaLaiColors.muted,
            ),
            const SizedBox(height: 16),
            Text(
              published
                  ? 'Shift published live!'
                  : wentToServer
                      ? 'Saved as a draft — not visible yet'
                      : 'Local preview ready',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              state.notice ??
                  (published
                      ? '${state.role} is now live! Workers nearby can find and apply for this shift immediately.'
                      : '${state.role} · kept on this device only. Nothing was sent to the server.'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: () => cubit.startAnother(),
                  icon: const Icon(Icons.add),
                  label: const Text('Post another'),
                ),
                if (wentToServer && state.serverDraft)
                  OutlinedButton.icon(
                    onPressed: state.submitting ? null : cubit.retryPublish,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry publishing'),
                  ),
                if (published)
                  OutlinedButton.icon(
                    onPressed: () {
                      // Switching the cubit directly bypasses the shell's
                      // segmented-button handler, so refresh discovery here.
                      context.read<VacancyDiscoveryCubit>().load();
                      context.read<ModeSwitcherCubit>().select(AppMode.vacancy);
                      cubit.startAnother();
                    },
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('View on map'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
