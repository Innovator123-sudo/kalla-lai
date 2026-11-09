import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kalla_lai/core/config/supabase_config.dart';
import 'package:kalla_lai/core/networking/api_client.dart';
import 'package:kalla_lai/core/theme/kalla_lai_theme.dart';

import '../application/admin_cubit.dart';
import '../application/admin_models.dart';
import '../application/admin_state.dart';

/// Entry point: scopes its own cubit to the console so no other screen pays
/// the startup cost of loading the directory.
class AdminPeopleScreen extends StatelessWidget {
  const AdminPeopleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          AdminCubit(RepositoryProvider.of<ApiClient>(context, listen: false))
            ..load(),
      child: const AdminPeopleView(),
    );
  }
}

class AdminPeopleView extends StatefulWidget {
  const AdminPeopleView({super.key});

  @override
  State<AdminPeopleView> createState() => _AdminPeopleViewState();
}

class _AdminPeopleViewState extends State<AdminPeopleView> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: context.read<AdminCubit>().state.query,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KallaLaiColors.canvas,
      appBar: AppBar(title: const Text('Admin console')),
      body: BlocConsumer<AdminCubit, AdminPeopleState>(
        listener: (context, state) {
          final error = state.errorMessage;
          // Fetch failures already show the retry card; only surface the
          // snackbar for failures that happen while normal content is visible
          // (e.g. a save failed).
          if (error != null && state.status != AdminLoadStatus.error) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(error),
                  backgroundColor: Colors.red.shade700,
                ),
              );
          }
        },
        builder: (context, state) {
          return Column(
            children: [
              _Toolbar(searchController: _searchController),
              Expanded(child: _buildList(context, state)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildList(BuildContext context, AdminPeopleState state) {
    if (state.status == AdminLoadStatus.loading && state.people.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.status == AdminLoadStatus.error) {
      return _ErrorCard(cubit: context.read<AdminCubit>());
    }
    if (state.people.isEmpty) {
      return const _EmptyState();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxCardWidth = constraints.maxWidth.clamp(0, 760).toDouble();
        return RefreshIndicator(
          onRefresh: () => context.read<AdminCubit>().refresh(),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            itemCount: state.people.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final person = state.people[index];
              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxCardWidth),
                  child: _PersonCard(person: person),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.searchController});

  final TextEditingController searchController;

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<AdminCubit>();
    return Material(
      color: KallaLaiColors.surface,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: searchController,
              onChanged: cubit.onQueryChanged,
              decoration: InputDecoration(
                hintText: 'Search by name or email',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(KallaLaiRadii.sm),
                ),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: adminRoleFilters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final role = adminRoleFilters[index];
                  return FilterChip(
                    label: Text(roleFilterLabel(role)),
                    selected: cubit.state.roleFilter == role,
                    showCheckmark: false,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 10),
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => cubit.selectRoleFilter(role),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            _BackendChip(settings: cubit.state.supabase),
          ],
        ),
      ),
    );
  }
}

/// Shows whether profile edits are being written to Supabase or the local dev
/// engine, so an administrator never mistakes demo data for live records.
class _BackendChip extends StatelessWidget {
  const _BackendChip({required this.settings});

  final SupabaseSettings settings;

  @override
  Widget build(BuildContext context) {
    final onSupabase = settings.usesSupabase;
    final color = onSupabase
        ? KallaLaiColors.successText
        : KallaLaiColors.muted;
    final detail = settings.projectRef == null ? '' : ' · ${settings.projectRef}';
    return Row(
      children: [
        Icon(
          onSupabase ? Icons.cloud_done_outlined : Icons.storage_outlined,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            onSupabase
                ? 'Backend: Supabase$detail · publishable key active'
                : settings.configurationWarning ??
                    'Backend: ${settings.backendLabel} — set SUPABASE_DB_URL in server/.env to use Supabase',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.cubit});

  final AdminCubit cubit;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(KallaLaiSpace.lg),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(KallaLaiSpace.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_off,
                  size: 40,
                  color: KallaLaiColors.crimson,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Could not load people',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'The admin list needs the Kalla-Lai API running. Check the '
                  'connection, then try again.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: cubit.load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.group_off_outlined,
            size: 48,
            color: KallaLaiColors.muted,
          ),
          const SizedBox(height: 12),
          const Text('No people match this filter'),
          const SizedBox(height: 4),
          Text(
            'Try clearing the search box or the role filter.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({required this.person});

  final AdminPerson person;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final saving = context.select<AdminCubit, bool>(
      (cubit) => cubit.state.savingIds.contains(person.id),
    );
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KallaLaiRadii.sm),
        side: const BorderSide(color: KallaLaiColors.outline),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(KallaLaiRadii.sm),
        onTap: saving ? null : () => _openEditor(context),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: KallaLaiColors.indigo.withValues(alpha: 0.12),
                foregroundColor: KallaLaiColors.indigo,
                child: Text(
                  person.fullName.isEmpty
                      ? '?'
                      : person.fullName.characters.first.toUpperCase(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      person.fullName.isEmpty ? '(no name yet)' : person.fullName,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      person.email,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: KallaLaiColors.muted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final role in person.roles)
                          _MiniChip(
                            label: role,
                            color: person.isStaff
                                ? KallaLaiColors.indigo
                                : KallaLaiColors.muted,
                          ),
                        if (person.status != 'ACTIVE')
                          const _MiniChip(
                            label: 'Suspended',
                            color: KallaLaiColors.crimson,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    DefaultTextStyle(
                      style: theme.textTheme.bodySmall!.copyWith(
                        color: KallaLaiColors.muted,
                      ),
                      child: Wrap(
                        spacing: 14,
                        runSpacing: 4,
                        children: [
                          Text(
                            'Identity: ${identityStatusLabel(person.identityStatus)}',
                          ),
                          if (person.workerProfile?.verificationStatus != null)
                            Text('Worker: ${workerStatusLabel(person.workerProfile!.verificationStatus!)}'),
                          if (person.employerProfile?.trustStatus != null)
                            Text('Trust: ${person.employerProfile!.trustStatus!}'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              saving
                  ? const SizedBox(
                      width: 26,
                      height: 26,
                      child: Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : IconButton(
                      tooltip: 'Edit profile',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _openEditor(context),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openEditor(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AdminPersonEditorSheet(person: person, cubit: context.read<AdminCubit>()),
    );
  }
}

String workerStatusLabel(String status) => switch (status) {
  'UNVERIFIED' => 'Unverified',
  'PENDING' => 'Pending',
  'VERIFIED' => 'Verified',
  'REJECTED' => 'Rejected',
  _ => status,
};

/// One compact colored chip on a person card.
class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// The editor sheet: account fields, roles, and both profile sheets.
class AdminPersonEditorSheet extends StatefulWidget {
  const AdminPersonEditorSheet({super.key, required this.person, required this.cubit});

  final AdminPerson person;
  final AdminCubit cubit;

  @override
  State<AdminPersonEditorSheet> createState() => _AdminPersonEditorSheetState();
}

class _AdminPersonEditorSheetState extends State<AdminPersonEditorSheet> {
  late final AdminPerson _person = widget.person;
  late final AdminWorkerProfile _workerDefaults =
      _person.workerProfile ?? const AdminWorkerProfile();
  late final AdminEmployerProfile _employerDefaults =
      _person.employerProfile ?? const AdminEmployerProfile();

  late final TextEditingController _fullName;
  late final TextEditingController _phone;
  late final TextEditingController _publicName;
  late final TextEditingController _baseArea;
  late final TextEditingController _minRate;
  late final TextEditingController _availability;
  late final TextEditingController _tagline;
  late final TextEditingController _bio;
  late final TextEditingController _displayName;
  late final TextEditingController _organization;

  late String _status;
  late String _identityStatus;
  late Set<String> _roles;
  late bool _rateNegotiable;
  late String _verificationStatus;
  late String _trustStatus;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _fullName = TextEditingController(text: _person.fullName);
    _phone = TextEditingController(text: _person.phone);
    final worker = _workerDefaults;
    _publicName = TextEditingController(text: worker.publicName ?? '');
    _baseArea = TextEditingController(text: worker.baseArea ?? '');
    _minRate = TextEditingController(text: worker.minRateNpr?.toString() ?? '');
    _availability = TextEditingController(text: worker.availability ?? '');
    _tagline = TextEditingController(text: worker.tagline ?? '');
    _bio = TextEditingController(text: worker.bio ?? '');
    final employer = _employerDefaults;
    _displayName = TextEditingController(text: employer.displayName ?? '');
    _organization = TextEditingController(text: employer.organization ?? '');
    _status = _person.status == 'SUSPENDED' ? 'SUSPENDED' : 'ACTIVE';
    _identityStatus = _person.identityStatus;
    _roles = _person.roles.toSet();
    _rateNegotiable = worker.rateNegotiable ?? true;
    _verificationStatus = worker.verificationStatus ?? 'UNVERIFIED';
    _trustStatus = employer.trustStatus ?? 'UNVERIFIED';
  }

  @override
  void dispose() {
    for (final controller in [
      _fullName,
      _phone,
      _publicName,
      _baseArea,
      _minRate,
      _availability,
      _tagline,
      _bio,
      _displayName,
      _organization,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.9,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text('Edit profile'),
            actions: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TextButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Save'),
                ),
              ),
              IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          primary: false,
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            children: [
              _HeaderCard(person: _person),
              _SectionCard(
                icon: Icons.manage_accounts_outlined,
                title: 'Account',
                children: [
                  _LabeledField(
                    label: 'Full name',
                    controller: _fullName,
                    maxLength: 120,
                  ),
                  _LabeledField(
                    label: 'Phone',
                    controller: _phone,
                    maxLength: 40,
                    keyboardType: TextInputType.phone,
                  ),
                  _LabeledDropdown(
                    label: 'Account status',
                    value: _status,
                    values: const ['ACTIVE', 'SUSPENDED'],
                    formatLabel: personStatusLabel,
                    onChanged: (value) =>
                        setState(() => _status = value ?? _status),
                  ),
                  _LabeledDropdown(
                    label: 'Identity check',
                    value: _identityStatus,
                    values: const [
                      'NOT_STARTED',
                      'PENDING',
                      'NEEDS_ACTION',
                      'VERIFIED',
                      'REJECTED',
                    ],
                    formatLabel: identityStatusLabel,
                    onChanged: (value) =>
                        setState(() => _identityStatus = value ?? _identityStatus),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Roles',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final role in adminRoles)
                        FilterChip(
                          label: Text(role),
                          selected: _roles.contains(role),
                          onSelected: (selected) => setState(
                            () => selected
                                ? _roles.add(role)
                                : _roles.remove(role),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              _SectionCard(
                icon: Icons.engineering_outlined,
                title: 'Worker profile',
                subtitle: _person.workerProfile == null
                    ? 'No worker sheet yet — create one or just save your edits.'
                    : null,
                children: [
                  if (_person.workerProfile == null)
                    _ProfileAction(
                      label: 'Create worker profile',
                      icon: Icons.add,
                      saving: _saving,
                      onCreate: () => _configureProfile('worker'),
                    )
                  else
                    _ProfileAction(
                      label: 'Remove worker profile',
                      icon: Icons.delete_outline,
                      saving: _saving,
                      destructive: true,
                      onCreate: () => _removeProfile('worker'),
                    ),
                  _LabeledField(
                    label: 'Public name',
                    controller: _publicName,
                    maxLength: 120,
                  ),
                  _LabeledField(
                    label: 'Base area',
                    controller: _baseArea,
                    maxLength: 160,
                    hint: 'e.g. Koteshwor, Kathmandu',
                  ),
                  _LabeledField(
                    label: 'Minimum rate (NPR per shift)',
                    controller: _minRate,
                    keyboardType: TextInputType.number,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Rate negotiable'),
                    value: _rateNegotiable,
                    onChanged: (value) =>
                        setState(() => _rateNegotiable = value),
                  ),
                  _LabeledField(
                    label: 'Availability',
                    controller: _availability,
                    maxLength: 500,
                    hint: 'Days or hours the worker is free',
                  ),
                  _LabeledField(
                    label: 'Tagline',
                    controller: _tagline,
                    maxLength: 160,
                  ),
                  _LabeledField(
                    label: 'Bio',
                    controller: _bio,
                    maxLength: 2000,
                    maxLines: 4,
                  ),
                  _LabeledDropdown(
                    label: 'Verification status',
                    value: _verificationStatus,
                    values: const ['UNVERIFIED', 'PENDING', 'VERIFIED', 'REJECTED'],
                    formatLabel: workerStatusLabel,
                    onChanged: (value) =>
                        setState(() => _verificationStatus = value ?? _verificationStatus),
                  ),
                ],
              ),
              _SectionCard(
                icon: Icons.business_center_outlined,
                title: 'Employer profile',
                subtitle: _person.employerProfile == null
                    ? 'No hirer sheet yet — create one or just save your edits.'
                    : null,
                children: [
                  if (_person.employerProfile == null)
                    _ProfileAction(
                      label: 'Create hirer profile',
                      icon: Icons.add,
                      saving: _saving,
                      onCreate: () => _configureProfile('employer'),
                    )
                  else
                    _ProfileAction(
                      label: 'Remove hirer profile',
                      icon: Icons.delete_outline,
                      saving: _saving,
                      destructive: true,
                      onCreate: () => _removeProfile('employer'),
                    ),
                  _LabeledField(
                    label: 'Display name',
                    controller: _displayName,
                    maxLength: 160,
                  ),
                  _LabeledField(
                    label: 'Organization',
                    controller: _organization,
                    maxLength: 160,
                  ),
                  _LabeledDropdown(
                    label: 'Trust status',
                    value: _trustStatus,
                    values: const ['UNVERIFIED', 'VERIFIED', 'SUSPENDED'],
                    formatLabel: (value) => switch (value) {
                      'UNVERIFIED' => 'Unverified',
                      'VERIFIED' => 'Verified',
                      _ => 'Suspended',
                    },
                    onChanged: (value) =>
                        setState(() => _trustStatus = value ?? _trustStatus),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final patch = _buildPatch();
    if (patch.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Nothing changed yet.')));
      return;
    }
    setState(() => _saving = true);
    final saved = await widget.cubit.savePerson(_person.id, patch);
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Saved ${_person.fullName.isEmpty ? _person.email : _person.fullName}'),
            backgroundColor: Colors.green.shade700,
          ),
        );
    }
  }

  Future<void> _configureProfile(String kind) => _runProfileAction(
    () => widget.cubit.configureProfile(_person.id, kind),
    'created',
  );

  Future<void> _removeProfile(String kind) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove profile?'),
        content: Text(
          'This deletes the ${kind == 'worker' ? 'worker' : 'hirer'} sheet '
          'for this account. It can be created again later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _runProfileAction(
      () => widget.cubit.removeProfile(_person.id, kind),
      'removed',
    );
  }

  Future<void> _runProfileAction(
    Future<bool> Function() action,
    String verb,
  ) async {
    setState(() => _saving = true);
    final saved = await action();
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Profile $verb'),
            backgroundColor: Colors.green.shade700,
          ),
        );
    }
  }

  /// Only sends fields that actually changed, so untouched sections are never
  /// overwritten by accident.
  Map<String, dynamic> _buildPatch() {
    final user = <String, dynamic>{};
    final fullName = _fullName.text.trim();
    if (fullName.isNotEmpty && fullName != _person.fullName) {
      user['fullName'] = fullName;
    }
    final phone = _phone.text.trim();
    if (phone != _person.phone) user['phone'] = phone;
    if (_status != _person.status) user['status'] = _status;
    if (_identityStatus != _person.identityStatus) {
      user['identityStatus'] = _identityStatus;
    }
    final roles = [
      for (final role in adminRoles)
        if (_roles.contains(role)) role,
    ];
    // Compare as sets: the API returns roles in no guaranteed order.
    final rolesChanged =
        roles.length != _person.roles.length ||
        !roles.every(_person.roles.contains);
    if (rolesChanged) user['roles'] = roles;

    final patch = <String, dynamic>{};
    if (user.isNotEmpty) patch['user'] = user;
    final worker = _diffWorker();
    if (worker != null) patch['workerProfile'] = worker;
    final employer = _diffEmployer();
    if (employer != null) patch['employerProfile'] = employer;
    return patch;
  }

  Map<String, dynamic>? _diffWorker() {
    final patch = <String, dynamic>{};
    final source = _workerDefaults;
    final publicName = _publicName.text.trim();
    // A blank public name keeps the existing value (or falls back to the
    // account's full name when creating a fresh sheet).
    final effectivePublicName =
        publicName.isEmpty ? source.publicName ?? _person.fullName : publicName;
    if (effectivePublicName != source.publicName) {
      patch['publicName'] = effectivePublicName;
    }
    final baseArea = _baseArea.text.trim();
    if (baseArea != (source.baseArea ?? '')) patch['baseArea'] = baseArea;
    final rate = int.tryParse(_minRate.text.trim());
    if (rate != null && rate != source.minRateNpr) patch['minRateNpr'] = rate;
    if (_rateNegotiable != (source.rateNegotiable ?? true)) {
      patch['rateNegotiable'] = _rateNegotiable;
    }
    final availability = _availability.text.trim();
    if (availability != (source.availability ?? '')) {
      patch['availability'] = availability;
    }
    final tagline = _tagline.text.trim();
    if (tagline != (source.tagline ?? '')) patch['tagline'] = tagline;
    final bio = _bio.text.trim();
    if (bio != (source.bio ?? '')) patch['bio'] = bio;
    if (_verificationStatus != (source.verificationStatus ?? 'UNVERIFIED')) {
      patch['verificationStatus'] = _verificationStatus;
    }
    return patch.isEmpty ? null : patch;
  }

  Map<String, dynamic>? _diffEmployer() {
    final patch = <String, dynamic>{};
    final source = _employerDefaults;
    final displayName = _displayName.text.trim();
    final effectiveName =
        displayName.isEmpty ? source.displayName ?? _person.fullName : displayName;
    if (effectiveName != source.displayName) {
      patch['displayName'] = effectiveName;
    }
    final organization = _organization.text.trim();
    if (organization != (source.organization ?? '')) {
      patch['organization'] = organization;
    }
    if (_trustStatus != (source.trustStatus ?? 'UNVERIFIED')) {
      patch['trustStatus'] = _trustStatus;
    }
    return patch.isEmpty ? null : patch;
  }
}

/// Read-only account facts at the top of the editor.
class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.person});

  final AdminPerson person;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: KallaLaiColors.indigo.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(KallaLaiRadii.sm),
      ),
      child: Row(
        children: [
          const Icon(Icons.badge_outlined, color: KallaLaiColors.indigo),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  person.email,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  'Joined ${person.createdAt.isEmpty ? '—' : _prettyDate(person.createdAt)} · '
                  'Onboarding: ${person.onboardingComplete ? 'complete' : 'in progress'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: KallaLaiColors.muted,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _prettyDate(String iso) {
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return iso;
    final month = switch (parsed.month) {
      1 => 'Jan',
      2 => 'Feb',
      3 => 'Mar',
      4 => 'Apr',
      5 => 'May',
      6 => 'Jun',
      7 => 'Jul',
      8 => 'Aug',
      9 => 'Sep',
      10 => 'Oct',
      11 => 'Nov',
      _ => 'Dec',
    };
    return '${parsed.year}-$month-${parsed.day.toString().padLeft(2, '0')}';
  }
}

/// Create / remove control shown at the top of each profile sheet section.
class _ProfileAction extends StatelessWidget {
  const _ProfileAction({
    required this.label,
    required this.icon,
    required this.saving,
    required this.onCreate,
    this.destructive = false,
  });

  final String label;
  final IconData icon;
  final bool saving;
  final VoidCallback onCreate;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? KallaLaiColors.crimson : KallaLaiColors.indigo;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: destructive
            ? TextButton.icon(
              onPressed: saving ? null : onCreate,
              icon: Icon(icon, size: 16),
              label: Text(label),
              style: TextButton.styleFrom(foregroundColor: color),
            )
            : OutlinedButton.icon(
              onPressed: saving ? null : onCreate,
              icon: Icon(icon, size: 18),
              label: Text(label),
              style: OutlinedButton.styleFrom(foregroundColor: color),
            ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.children,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KallaLaiRadii.sm),
        side: const BorderSide(color: KallaLaiColors.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: KallaLaiColors.indigo),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: KallaLaiColors.warningText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.controller,
    this.maxLines = 1,
    this.maxLength,
    this.hint,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final int maxLines;
  final int? maxLength;
  final String? hint;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        maxLength: maxLength,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(KallaLaiRadii.sm),
          ),
          counterText: '',
          isDense: true,
        ),
      ),
    );
  }
}

class _LabeledDropdown extends StatelessWidget {
  const _LabeledDropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
    required this.formatLabel,
  });

  final String label;
  final String value;
  final List<String> values;
  final String Function(String) formatLabel;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(KallaLaiRadii.sm),
          ),
          isDense: true,
        ),
        items: [
          for (final item in values)
            DropdownMenuItem<String>(
              value: item,
              child: Text(formatLabel(item)),
            ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}
