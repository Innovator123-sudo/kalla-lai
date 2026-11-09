import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kalla_lai/core/theme/kalla_lai_theme.dart';
import 'package:kalla_lai/features/hiring/domain/job_catalog.dart';
import 'package:kalla_lai/features/shared/domain/marketplace_models.dart';

class WorkerJobListScreen extends StatelessWidget {
  const WorkerJobListScreen({
    required this.title,
    required this.subtitle,
    required this.jobs,
    required this.emptyIcon,
    required this.emptyMessage,
    this.onRemoveSaved,
    super.key,
  });

  final String title;
  final String subtitle;
  final List<JobShift> jobs;
  final IconData emptyIcon;
  final String emptyMessage;
  final ValueChanged<JobShift>? onRemoveSaved;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(subtitle),
          ],
        ),
      ),
      Expanded(
        child:
            jobs.isEmpty
                ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(emptyIcon, size: 44, color: Colors.blueGrey),
                        const SizedBox(height: 12),
                        Text(
                          emptyMessage,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Browse jobs and save or apply to keep them here.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
                : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  itemCount: jobs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final job = jobs[index];
                    return Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFE0E7FF),
                          child: Icon(
                            jobCategoryIcon(job.category),
                            color: KallaLaiColors.indigo,
                          ),
                        ),
                        title: Text(
                          job.role,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${job.area} · ${job.shiftLabel}'),
                              const SizedBox(height: 3),
                              Text(
                                'NPR ${NumberFormat('#,##0').format(job.rateNpr)}${job.negotiable ? ' (neg.)' : ''} · ${_employmentLabel(job.employmentType)}',
                              ),
                              if (job.workingHours.isNotEmpty ||
                                  job.salaryIncrement ||
                                  job.openings > 1) ...[
                                const SizedBox(height: 5),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    if (job.workingHours.isNotEmpty)
                                      _MiniChip(
                                        icon: Icons.schedule_outlined,
                                        label: job.workingHours,
                                      ),
                                    if (job.salaryIncrement)
                                      const _MiniChip(
                                        icon: Icons.trending_up,
                                        label: 'Salary grows',
                                      ),
                                    if (job.openings > 1)
                                      _MiniChip(
                                        icon: Icons.group_outlined,
                                        label: '${job.openings} openings',
                                      ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        trailing:
                            onRemoveSaved == null
                                ? const Icon(
                                  Icons.check_circle_outline,
                                  color: Colors.green,
                                )
                                : IconButton(
                                  tooltip: 'Remove from saved jobs',
                                  onPressed: () => onRemoveSaved!(job),
                                  icon: const Icon(Icons.bookmark),
                                ),
                      ),
                    );
                  },
                ),
      ),
    ],
  );
}

String _employmentLabel(String code) => switch (code) {
  'PART_TIME' => 'Part-time',
  'CONTRACT' => 'Contract',
  'TEMPORARY' => 'Temporary',
  'INTERNSHIP' => 'Internship',
  _ => 'Full-time',
};

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: const Color(0xFFF1F5F9),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: KallaLaiColors.muted),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: KallaLaiColors.slate),
        ),
      ],
    ),
  );
}
