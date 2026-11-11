import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kalla_lai/core/localization/app_strings.dart';
import 'package:kalla_lai/core/theme/kalla_lai_theme.dart';
import 'package:kalla_lai/features/admin/presentation/admin_people_screen.dart';
import 'package:kalla_lai/features/auth/application/auth_cubit.dart';
import 'package:kalla_lai/features/auth/application/auth_state.dart';
import 'package:kalla_lai/features/auth/presentation/identity_onboarding_screen.dart';
import 'package:kalla_lai/features/discovery/application/vacancy_discovery_cubit.dart';
import 'package:kalla_lai/features/discovery/presentation/vacancy_map_discovery_screen.dart';
import 'package:kalla_lai/features/hiring/presentation/hiring_requisition_wizard_screen.dart';
import 'package:kalla_lai/features/mode/application/mode_switcher_cubit.dart';
import 'package:kalla_lai/features/profile/presentation/worker_profile_showcase_screen.dart';
import 'package:kalla_lai/features/settings/presentation/settings_screen.dart';
import 'package:kalla_lai/features/shared/domain/marketplace_models.dart';
import 'package:kalla_lai/features/shifts/presentation/shift_dispatch_and_escrow_screen.dart';
import 'package:kalla_lai/features/home/presentation/worker_job_list_screen.dart';

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _selectedIndex = 0;
  final Map<String, JobShift> _savedJobsById = {};
  final Map<String, JobShift> _appliedJobsById = {};

  @override
  void initState() {
    super.initState();
    // Do not force ModeSwitcherCubit to a specific mode. Respect the user's active choice.
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final user = context.select<AuthCubit, SessionUser?>(
      (cubit) => cubit.state.user,
    );
    final canApply =
        user != null &&
        (user.isDemoSession || user.identityStatus == 'VERIFIED');
    return BlocBuilder<ModeSwitcherCubit, AppMode>(
      builder: (context, selectedMode) {
        // The side is chosen during sign-in and never changes afterwards. The
        // API still enforces EMPLOYER / WORKER on every protected endpoint.
        // Staff-only accounts (no worker or employer role) get the admin layout.
        final isStaffOnly =
            user?.isStaff == true &&
            !user!.isWorker &&
            !user.isEmployer;
        final mode = isStaffOnly ? AppMode.vacancy : selectedMode;
        final isJobSearch = mode == AppMode.vacancy;
        final savedJobs = _savedJobsById.values.toList(growable: false);
        final appliedJobs = _appliedJobsById.values.toList(growable: false);

        // Staff-only users get a dedicated admin layout: the admin console
        // is the primary tab, their profile is the secondary tab. They can
        // still browse the marketplace through the mode switcher if they
        // also have a worker or employer role.
        final labels =
            isStaffOnly
                ? const ['Admin', 'Profile']
                : isJobSearch
                    ? const ['Home', 'Saved', 'Applied', 'Profile']
                    : [
                      strings.text('post_work'),
                      strings.text('shift'),
                      strings.text('profile'),
                    ];
        final icons =
            isStaffOnly
                ? const [
                  Icons.admin_panel_settings_outlined,
                  Icons.person_outline,
                ]
                : isJobSearch
                    ? const [
                      Icons.home_outlined,
                      Icons.bookmark_border,
                      Icons.assignment_turned_in_outlined,
                      Icons.person_outline,
                    ]
                    : const [
                      Icons.post_add_outlined,
                      Icons.work_history_outlined,
                      Icons.person_outline,
                    ];
        final pages =
            isStaffOnly
                ? const [
                  AdminPeopleScreen(),
                  WorkerProfileShowcaseScreen(),
                ]
                : isJobSearch
                    ? [
                      VacancyMapDiscoveryScreen(
                        savedJobIds: _savedJobsById.keys.toSet(),
                        onToggleSaved: _toggleSavedJob,
                        onApply: _recordApplication,
                        canApply: canApply,
                        onVerificationRequired: _openIdentityVerification,
                      ),
                      WorkerJobListScreen(
                        title: 'Saved jobs',
                        subtitle: 'Jobs you bookmark will be easy to find here.',
                        jobs: savedJobs,
                        emptyIcon: Icons.bookmark_border,
                        emptyMessage: 'No saved jobs yet',
                        onRemoveSaved: _toggleSavedJob,
                      ),
                      WorkerJobListScreen(
                        title: 'Applied jobs',
                        subtitle: 'Keep track of jobs you have applied to.',
                        jobs: appliedJobs,
                        emptyIcon: Icons.assignment_turned_in_outlined,
                        emptyMessage: 'No applications yet',
                      ),
                      const WorkerProfileShowcaseScreen(),
                    ]
                    : const [
                      HiringRequisitionWizardScreen(),
                      ShiftDispatchAndEscrowScreen(),
                      WorkerProfileShowcaseScreen(),
                    ];
        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'कल्ला-लाई',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            actions: [
              if (user != null)
                PopupMenuButton<_AccountAction>(
                  tooltip: strings.text('account_menu'),
                  onSelected: (action) {
                    if (action == _AccountAction.signOut) {
                      context.read<AuthCubit>().signOut();
                    } else if (action == _AccountAction.verifyIdentity) {
                      _openIdentityVerification();
                    } else if (action == _AccountAction.adminConsole) {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const AdminPeopleScreen(),
                        ),
                      );
                    } else if (action == _AccountAction.settings) {
                      openSettings(context);
                    }
                  },
                  itemBuilder:
                      (context) => [
                        PopupMenuItem<_AccountAction>(
                          enabled: false,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.fullName,
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                user.email,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user.isDemoSession
                                    ? '${user.roleLabel} · ${strings.text('demo_session')}'
                                    : user.roleLabel,
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                              if (user.isWorker)
                                Text(
                                  user.identityStatus == 'VERIFIED'
                                      ? 'Identity verified'
                                      : 'Identity: ${_identityLabel(user.identityStatus)}',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.labelSmall?.copyWith(
                                    color:
                                        user.identityStatus == 'VERIFIED'
                                            ? KallaLaiColors.successText
                                            : KallaLaiColors.warningText,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        if (user.isStaff) ...[
                          const PopupMenuItem<_AccountAction>(
                            value: _AccountAction.adminConsole,
                            child: Row(
                              children: [
                                Icon(Icons.admin_panel_settings_outlined),
                                SizedBox(width: 12),
                                Text('Admin console'),
                              ],
                            ),
                          ),
                          const PopupMenuDivider(),
                        ],
                        if (user.isWorker &&
                            !user.isDemoSession &&
                            user.identityStatus != 'VERIFIED') ...[
                          const PopupMenuItem<_AccountAction>(
                            value: _AccountAction.verifyIdentity,
                            child: Row(
                              children: [
                                Icon(Icons.verified_user_outlined),
                                SizedBox(width: 12),
                                Text('Verify identity'),
                              ],
                            ),
                          ),
                          const PopupMenuDivider(),
                        ],
                        const PopupMenuItem<_AccountAction>(
                          value: _AccountAction.settings,
                          child: Row(
                            children: [
                              Icon(Icons.settings_outlined),
                              SizedBox(width: 12),
                              Text('Settings'),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        PopupMenuItem<_AccountAction>(
                          value: _AccountAction.signOut,
                          child: Row(
                            children: [
                              const Icon(Icons.logout),
                              const SizedBox(width: 12),
                              Text(strings.text('sign_out')),
                            ],
                          ),
                        ),
                      ],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: CircleAvatar(
                      radius: 17,
                      child: Text(
                        user.fullName.isEmpty
                            ? '?'
                            : user.fullName.characters.first.toUpperCase(),
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: IconButton(
                  tooltip: 'About कल्ला-लाई',
                  onPressed:
                      () => showAboutDialog(
                        context: context,
                        applicationName: 'कल्ला-लाई · Kalla-Lai',
                        applicationVersion: '0.1.0',
                        children: const [
                          Text(
                            'Jobs are published to the live API and appear in vacancy search after a refresh. Identity verification is processed in-app. Payments and escrow settlement are still modelled only, not real money transfers.',
                          ),
                        ],
                      ),
                  icon: const Icon(Icons.info_outline),
                ),
              ),
            ],
            bottom: isStaffOnly
                ? PreferredSize(
                    preferredSize: const Size.fromHeight(54),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: KallaLaiColors.indigo.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.admin_panel_settings_outlined,
                              size: 18,
                              color: KallaLaiColors.indigo,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Admin account · manage people and profiles',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: KallaLaiColors.indigo,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : null,
          ),
          body: pages[_selectedIndex],
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected:
                (index) => setState(() => _selectedIndex = index),
            destinations: [
              for (var index = 0; index < labels.length; index++)
                NavigationDestination(
                  icon: Icon(icons[index]),
                  label: labels[index],
                ),
            ],
          ),
        );
      },
    );
  }

  void _toggleSavedJob(JobShift job) {
    setState(() {
      if (_savedJobsById.remove(job.id) == null) {
        _savedJobsById[job.id] = job;
      }
    });
  }

  void _recordApplication(JobShift job) {
    final user = context.read<AuthCubit>().state.user;
    if (user != null &&
        !user.isDemoSession &&
        user.identityStatus != 'VERIFIED') {
      _openIdentityVerification();
      return;
    }
    setState(() => _appliedJobsById[job.id] = job);
  }

  void _openIdentityVerification() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const IdentityOnboardingScreen()),
    );
  }
}

String _identityLabel(String status) => switch (status) {
  'PENDING' => 'Pending review',
  'NEEDS_ACTION' => 'Needs action',
  'REJECTED' => 'Not approved',
  'VERIFIED' => 'Verified',
  _ => 'Not started',
};

enum _AccountAction { verifyIdentity, adminConsole, settings, signOut }
