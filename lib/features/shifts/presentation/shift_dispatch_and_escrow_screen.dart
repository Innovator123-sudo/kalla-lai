import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:kalla_lai/core/localization/app_strings.dart';
import 'package:kalla_lai/core/theme/kalla_lai_theme.dart';
import 'package:kalla_lai/core/widgets/status_pill.dart';
import 'package:kalla_lai/features/shared/domain/marketplace_models.dart';
import 'package:kalla_lai/features/shifts/application/shift_escrow_cubit.dart';

class ShiftDispatchAndEscrowScreen extends StatelessWidget {
  const ShiftDispatchAndEscrowScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ShiftEscrowCubit, ShiftWorkflowState>(
      builder: (context, workflow) {
        final entry = workflow.ledger;
        final statusLabel = _statusLabel(entry.status);
        final dispatchLabel = _dispatchLabel(workflow.dispatchStatus);
        final canDispute =
            entry.status != LedgerStatus.released &&
            entry.status != LedgerStatus.disputed;
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          children: [
            Text(
              AppStrings.of(context).text('shift_title'),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: KallaLaiColors.slate,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            const Text('Certified Electrician · Koteshwor, Kathmandu'),
            const SizedBox(height: 16),
            const _DispatchTimeline(),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Payment status',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        StatusPill(
                          label: statusLabel,
                          icon: _statusIcon(entry.status),
                          color: _statusColor(entry.status),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text('Today · 10:00–16:00 · Approximate site area'),
                    const SizedBox(height: 8),
                    const Text(
                      'Exact work address and client contact are disclosed only after an authorized confirmation.',
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Attendance status',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        StatusPill(
                          label: dispatchLabel,
                          icon: _dispatchIcon(workflow.dispatchStatus),
                          color: KallaLaiColors.indigo,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (entry.status == LedgerStatus.escrowFunded &&
                        workflow.dispatchStatus == DispatchStatus.confirmed)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed:
                              () => context.read<ShiftEscrowCubit>().onMyWay(),
                          icon: const Icon(Icons.directions_walk_outlined),
                          label: Text(AppStrings.of(context).text('on_my_way')),
                        ),
                      ),
                    if (entry.status == LedgerStatus.escrowFunded &&
                        workflow.dispatchStatus == DispatchStatus.onTheWay)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed:
                              () => context.read<ShiftEscrowCubit>().checkIn(),
                          icon: const Icon(Icons.location_on_outlined),
                          label: Text(AppStrings.of(context).text('check_in')),
                        ),
                      ),
                    if (entry.status == LedgerStatus.shiftInProgress &&
                        workflow.dispatchStatus == DispatchStatus.checkedIn)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed:
                              () =>
                                  context
                                      .read<ShiftEscrowCubit>()
                                      .completeShift(),
                          icon: const Icon(Icons.task_alt),
                          label: const Text('Submit completion for review'),
                        ),
                      ),
                    if (entry.status == LedgerStatus.pendingClientReview)
                      const _Notice(
                        icon: Icons.hourglass_top,
                        text:
                            'Completion is awaiting client review. This demo cannot release funds or change a server payment state.',
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment ledger',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _LedgerLine(
                      label: 'Amount',
                      value:
                          'NPR ${NumberFormat('#,##0').format(entry.amountNpr)}',
                    ),
                    _LedgerLine(
                      label: 'Transaction reference',
                      value: entry.transactionId,
                      mono: true,
                    ),
                    _LedgerLine(
                      label: 'Last updated',
                      value: DateFormat(
                        'd MMM yyyy · HH:mm',
                      ).format(entry.updatedAt),
                      mono: true,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Sample ledger entry only. It does not represent real funds or an escrow provider.',
                      style: TextStyle(color: KallaLaiColors.muted),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Safety & dispute support',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 7),
                    const Text(
                      'For a safety concern, no-show, or payment issue, prepare a short description and any relevant evidence for human review.',
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed:
                          canDispute ? () => _showDisputeDialog(context) : null,
                      icon: const Icon(Icons.flag_outlined),
                      label: const Text('Prepare a demo dispute'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  static String _statusLabel(LedgerStatus status) => switch (status) {
    LedgerStatus.escrowFunded => 'Escrow funded · demo',
    LedgerStatus.shiftInProgress => 'Shift in progress · demo',
    LedgerStatus.pendingClientReview => 'Pending client review · demo',
    LedgerStatus.released => 'Released',
    LedgerStatus.disputed => 'Disputed · demo',
  };

  static IconData _statusIcon(LedgerStatus status) => switch (status) {
    LedgerStatus.escrowFunded => Icons.lock_outline,
    LedgerStatus.shiftInProgress => Icons.work_history_outlined,
    LedgerStatus.pendingClientReview => Icons.hourglass_top,
    LedgerStatus.released => Icons.check_circle_outline,
    LedgerStatus.disputed => Icons.report_problem_outlined,
  };

  static Color _statusColor(LedgerStatus status) => switch (status) {
    LedgerStatus.escrowFunded => KallaLaiColors.indigo,
    LedgerStatus.shiftInProgress => KallaLaiColors.warningText,
    LedgerStatus.pendingClientReview => KallaLaiColors.warningText,
    LedgerStatus.released => KallaLaiColors.successText,
    LedgerStatus.disputed => KallaLaiColors.errorText,
  };

  static String _dispatchLabel(DispatchStatus status) => switch (status) {
    DispatchStatus.confirmed => 'Confirmed · demo',
    DispatchStatus.onTheWay => 'On my way · demo',
    DispatchStatus.checkedIn => 'Checked in · demo',
    DispatchStatus.completionSubmitted => 'Completion submitted · demo',
  };

  static IconData _dispatchIcon(DispatchStatus status) => switch (status) {
    DispatchStatus.confirmed => Icons.event_available_outlined,
    DispatchStatus.onTheWay => Icons.directions_walk_outlined,
    DispatchStatus.checkedIn => Icons.location_on_outlined,
    DispatchStatus.completionSubmitted => Icons.task_alt,
  };
}

class _DispatchTimeline extends StatelessWidget {
  const _DispatchTimeline();

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Shift preparation',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          const _TimelinePoint(
            time: '60 min before',
            title: 'On My Way check-in',
            subtitle: 'A reminder is scheduled by the production service.',
            icon: Icons.notifications_active_outlined,
          ),
          const _TimelinePoint(
            time: '30 min before',
            title: 'Preparation reminder',
            subtitle: 'Site and travel details stay behind authorization.',
            icon: Icons.route_outlined,
          ),
          const _TimelinePoint(
            time: 'At the work site',
            title: 'Geofence check-in',
            subtitle:
                'Requires location permission and server-side validation.',
            icon: Icons.my_location_outlined,
            isLast: true,
          ),
        ],
      ),
    ),
  );
}

class _TimelinePoint extends StatelessWidget {
  const _TimelinePoint({
    required this.time,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.isLast = false,
  });

  final String time;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isLast;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 28,
          child: Column(
            children: [
              Icon(icon, size: 20, color: KallaLaiColors.indigo),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 1,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: KallaLaiColors.outline,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(time, style: const TextStyle(color: KallaLaiColors.muted)),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(subtitle),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _LedgerLine extends StatelessWidget {
  const _LedgerLine({
    required this.label,
    required this.value,
    this.mono = false,
  });

  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: KallaLaiColors.muted),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontFeatures: mono ? const [FontFeature.tabularFigures()] : null,
              fontFamily: mono ? KallaLaiTypography.numeric : null,
            ),
          ),
        ),
      ],
    ),
  );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF3D6),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

Future<void> _showDisputeDialog(BuildContext context) async {
  final reasonController = TextEditingController();
  final reason = await showDialog<String>(
    context: context,
    builder:
        (dialogContext) => AlertDialog(
          title: const Text('Prepare a dispute'),
          content: TextField(
            controller: reasonController,
            maxLines: 3,
            maxLength: 300,
            decoration: const InputDecoration(
              labelText: 'Briefly describe the issue',
              alignLabelWithHint: true,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed:
                  () => Navigator.pop(dialogContext, reasonController.text),
              child: const Text('Continue'),
            ),
          ],
        ),
  );
  reasonController.dispose();
  if (!context.mounted || reason == null) return;
  if (reason.trim().isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Enter a short description first.')),
    );
    return;
  }
  context.read<ShiftEscrowCubit>().dispute();
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text(
        'Demo dispute recorded locally; support was not contacted.',
      ),
    ),
  );
}
