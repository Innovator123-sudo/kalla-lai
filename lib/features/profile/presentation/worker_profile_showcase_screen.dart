import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kalla_lai/core/localization/app_strings.dart';
import 'package:kalla_lai/core/localization/locale_cubit.dart';
import 'package:kalla_lai/core/location/device_location.dart';
import 'package:kalla_lai/core/media/media_picker.dart';
import 'package:kalla_lai/core/networking/api_client.dart';
import 'package:kalla_lai/core/theme/kalla_lai_theme.dart';
import 'package:kalla_lai/core/widgets/loading_animation.dart';
import 'package:kalla_lai/core/widgets/status_pill.dart';
import 'package:kalla_lai/features/auth/application/auth_cubit.dart';
import 'package:kalla_lai/features/auth/presentation/identity_onboarding_screen.dart';
import 'package:kalla_lai/features/profile/application/profile_cubit.dart';
import 'package:url_launcher/url_launcher.dart';

class WorkerProfileShowcaseScreen extends StatelessWidget {
  const WorkerProfileShowcaseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthCubit>().state.user;
    final canEdit =
        user != null &&
        !user.isDemoSession &&
        (user.isWorker || user.isEmployer || user.isStaff);
    return BlocProvider(
      create: (context) => ProfileCubit(context.read<ApiClient>()),
      child: _ProfileBody(canEdit: canEdit),
    );
  }
}

class _ProfileBody extends StatefulWidget {
  const _ProfileBody({required this.canEdit});

  final bool canEdit;

  @override
  State<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends State<_ProfileBody> {
  @override
  void initState() {
    super.initState();
    if (widget.canEdit) context.read<ProfileCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final localeCubit = context.read<LocaleCubit>();
    final user = context.watch<AuthCubit>().state.user;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        Text(
          strings.text('profile_title'),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: KallaLaiColors.slate,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 16),
        const _AccountCard(),
        const _IdentityCard(),
        const SizedBox(height: 14),
        if (widget.canEdit)
          BlocConsumer<ProfileCubit, ProfileState>(
            listenWhen:
                (previous, current) =>
                    previous.errorMessage != current.errorMessage ||
                    previous.savedMessage != current.savedMessage,
            listener: (context, state) {
              final message = state.errorMessage ?? state.savedMessage;
              if (message == null) return;
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text(message),
                    backgroundColor:
                        state.errorMessage != null
                            ? KallaLaiColors.errorText
                            : KallaLaiColors.successText,
                  ),
                );
            },
            builder: (context, state) {
              if (state.loading) {
                return const SizedBox(height: 220, child: LoadingAnimation());
              }
              if (!state.loaded) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.errorMessage ?? 'Could not load your profile.',
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => context.read<ProfileCubit>().load(),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                );
              }
              // Build a list of profile editors relevant to this account.
              // Workers see the worker editor, employers see the employer
              // editor, and staff see whichever profile sheets they have
              // (or a prompt to create one).
              final editors = <Widget>[];
              if (user?.isWorker == true || (user?.isStaff == true && state.worker != null)) {
                editors.add(_WorkerProfileEditor(state: state));
              }
              if (user?.isEmployer == true || (user?.isStaff == true && state.employer != null)) {
                editors.add(_EmployerProfileEditor(state: state));
              }
              if (editors.isEmpty && user?.isStaff == true) {
                editors.add(
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.badge_outlined, color: KallaLaiColors.indigo),
                              const SizedBox(width: 8),
                              Text(
                                'Staff profile',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'No worker or employer profile yet. Use the admin console '
                            'to configure profiles for any account, or save a worker/'
                            'employer profile below to create your own.',
                            style: TextStyle(color: KallaLaiColors.muted),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 10,
                            children: [
                              FilledButton.tonalIcon(
                                onPressed: () => context.read<ProfileCubit>().saveWorker(
                                  {'publicName': user?.fullName ?? 'Admin'},
                                ),
                                icon: const Icon(Icons.engineering_outlined),
                                label: const Text('Create worker profile'),
                              ),
                              FilledButton.tonalIcon(
                                onPressed: () => context.read<ProfileCubit>().saveEmployer(
                                  {'displayName': user?.fullName ?? 'Admin'},
                                ),
                                icon: const Icon(Icons.business_center_outlined),
                                label: const Text('Create hirer profile'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
              if (editors.isEmpty) {
                return const SizedBox.shrink();
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: editors,
              );
            },
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      user?.isDemoSession == true
                          ? 'Profile editing is available after signing in to the live server. This offline demo session is read-only.'
                          : 'Profile editing is available for worker, employer, and admin accounts.',
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.text('language'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                RadioGroup<Locale>(
                  groupValue: Localizations.localeOf(context),
                  onChanged: (value) {
                    if (value != null) localeCubit.select(value);
                  },
                  child: Column(
                    children: [
                      RadioListTile<Locale>(
                        contentPadding: EdgeInsets.zero,
                        title: Text(strings.text('english')),
                        value: const Locale('en'),
                      ),
                      RadioListTile<Locale>(
                        contentPadding: EdgeInsets.zero,
                        title: Text(strings.text('nepali')),
                        value: const Locale('ne'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _WorkerProfileEditor extends StatefulWidget {
  const _WorkerProfileEditor({required this.state});

  final ProfileState state;

  @override
  State<_WorkerProfileEditor> createState() => _WorkerProfileEditorState();
}

class _WorkerProfileEditorState extends State<_WorkerProfileEditor> {
  static const _categoryOptions = [
    'Electrical', 'Plumbing', 'Carpentry', 'Painting', 'Cleaning', 'Cooking',
    'Driving', 'Delivery', 'Construction', 'Gardening', 'Tailoring',
    'Beauty & Salon', 'Security', 'Event Help', 'Tech & IT', 'Tutoring',
    'Photography', 'Moving & Lifting',
  ];
  static const _languageOptions = [
    'Nepali', 'English', 'Hindi', 'Maithili', 'Bhojpuri', 'Tamang',
    'Newari', 'Gurung', 'Magar', 'Urdu',
  ];
  static const _categoryIcons = <String, IconData>{
    'Electrical': Icons.electrical_services_outlined,
    'Plumbing': Icons.plumbing_outlined,
    'Carpentry': Icons.carpenter_outlined,
    'Painting': Icons.format_paint_outlined,
    'Cleaning': Icons.cleaning_services_outlined,
    'Cooking': Icons.restaurant_outlined,
    'Driving': Icons.directions_car_outlined,
    'Delivery': Icons.delivery_dining_outlined,
    'Construction': Icons.construction_outlined,
    'Gardening': Icons.yard_outlined,
    'Tailoring': Icons.content_cut_outlined,
    'Beauty & Salon': Icons.face_retouching_natural_outlined,
    'Security': Icons.security_outlined,
    'Event Help': Icons.celebration_outlined,
    'Tech & IT': Icons.computer_outlined,
    'Tutoring': Icons.school_outlined,
    'Photography': Icons.photo_camera_outlined,
    'Moving & Lifting': Icons.local_shipping_outlined,
  };

  late final TextEditingController _publicName;
  late final TextEditingController _baseArea;
  late final TextEditingController _minRate;
  late final TextEditingController _availability;
  late final TextEditingController _bio;
  late final TextEditingController _skillName;
  late final TextEditingController _tagline;
  late final TextEditingController _portfolioUrl;
  late bool _rateNegotiable;
  double? _latitude;
  double? _longitude;
  bool _locating = false;
  late Set<String> _categories;
  late Set<String> _languages;
  late List<String> _portfolioUrls;
  String _promoVideoUrl = '';
  String _promoVideoName = '';
  String _cvUrl = '';
  String _cvName = '';
  bool _uploadingVideo = false;
  bool _uploadingCv = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.state.worker ?? const WorkerProfile();
    _publicName = TextEditingController(text: profile.publicName);
    _baseArea = TextEditingController(text: profile.baseArea);
    _minRate = TextEditingController(
      text: profile.minRateNpr > 0 ? '${profile.minRateNpr}' : '',
    );
    _availability = TextEditingController(text: profile.availability);
    _bio = TextEditingController(text: profile.bio);
    _skillName = TextEditingController();
    _tagline = TextEditingController(text: profile.tagline);
    _portfolioUrl = TextEditingController();
    _rateNegotiable = profile.rateNegotiable;
    _latitude = profile.latitude;
    _longitude = profile.longitude;
    _categories = {...profile.categories};
    _languages = {...profile.languages};
    _portfolioUrls = [...profile.portfolioUrls];
    _promoVideoUrl = profile.promoVideoUrl;
    _cvUrl = profile.cvUrl;
  }

  @override
  void dispose() {
    _publicName.dispose();
    _baseArea.dispose();
    _minRate.dispose();
    _availability.dispose();
    _bio.dispose();
    _skillName.dispose();
    _tagline.dispose();
    _portfolioUrl.dispose();
    super.dispose();
  }

  Future<void> _uploadPromoVideo() async {
    if (_uploadingVideo) return;
    try {
      final media = await pickVideo();
      if (!mounted || media == null) return;
      setState(() => _uploadingVideo = true);
      final url = await context.read<ProfileCubit>().uploadMedia(
        kind: 'PROMO_VIDEO',
        fileName: media.fileName,
        mimeType: media.mimeType,
        bytes: media.bytes,
      );
      if (!mounted) return;
      setState(() {
        _uploadingVideo = false;
        if (url != null) {
          _promoVideoUrl = url;
          _promoVideoName = media.fileName;
        }
      });
    } on MediaPickException catch (error) {
      if (!mounted) return;
      setState(() => _uploadingVideo = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _uploadCv() async {
    if (_uploadingCv) return;
    try {
      final media = await pickCv();
      if (!mounted || media == null) return;
      setState(() => _uploadingCv = true);
      final url = await context.read<ProfileCubit>().uploadMedia(
        kind: 'CV',
        fileName: media.fileName,
        mimeType: media.mimeType,
        bytes: media.bytes,
      );
      if (!mounted) return;
      setState(() {
        _uploadingCv = false;
        if (url != null) {
          _cvUrl = url;
          _cvName = media.fileName;
        }
      });
    } on MediaPickException catch (error) {
      if (!mounted) return;
      setState(() => _uploadingCv = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  void _addPortfolio() {
    final url = _portfolioUrl.text.trim();
    if (url.length < 4 || _portfolioUrls.contains(url)) return;
    setState(() {
      _portfolioUrls = [..._portfolioUrls, url];
      _portfolioUrl.clear();
    });
  }

  Future<void> _openUrl(String url) async {
    final base = context.read<ApiClient>().baseUrl.trim();
    final String absolute;
    if (url.startsWith('http')) {
      absolute = url;
    } else if (url.startsWith('/')) {
      absolute = base.isEmpty ? Uri.base.resolve(url).toString() : '$base$url';
    } else {
      absolute = 'https://$url';
    }
    final uri = Uri.tryParse(absolute);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _editorHeading(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(color: KallaLaiColors.muted, fontSize: 12),
        ),
      ],
    );
  }

  Widget _mediaCard({
    required IconData icon,
    required String emptyLabel,
    required String fileName,
    required String url,
    required bool busy,
    required String buttonLabel,
    required Future<void> Function() onUpload,
    required VoidCallback onRemove,
  }) {
    final hasFile = url.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: KallaLaiColors.indigo.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KallaLaiColors.indigo.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, color: KallaLaiColors.indigo),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasFile ? (fileName.isEmpty ? url : fileName) : emptyLabel,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color:
                        hasFile ? KallaLaiColors.slate : KallaLaiColors.muted,
                  ),
                ),
                if (hasFile) ...[
                  const SizedBox(height: 2),
                  const Text(
                    'Uploaded · tap Preview to open',
                    style: TextStyle(
                      color: KallaLaiColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (busy)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (hasFile) ...[
            IconButton.outlined(
              onPressed: () => _openUrl(url),
              tooltip: 'Preview',
              icon: const Icon(Icons.open_in_new, size: 20),
            ),
            const SizedBox(width: 4),
            IconButton.outlined(
              onPressed: onRemove,
              tooltip: 'Remove',
              icon: const Icon(Icons.delete_outline, size: 20),
            ),
          ] else
            OutlinedButton.icon(
              onPressed: onUpload,
              icon: const Icon(Icons.upload_outlined, size: 18),
              label: Text(buttonLabel),
            ),
        ],
      ),
    );
  }

  Future<void> _useMyLocation() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final position = await getCurrentDevicePosition();
      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'True location captured. Save to update your base pin.',
          ),
        ),
      );
    } on DeviceLocationException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read your location.')),
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _save() {
    final name = _publicName.text.trim();
    if (name.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Public name needs at least 2 characters.'),
        ),
      );
      return;
    }
    context.read<ProfileCubit>().saveWorker({
      'publicName': name,
      'baseArea': _baseArea.text.trim(),
      if (_latitude != null) 'latitude': _latitude,
      if (_longitude != null) 'longitude': _longitude,
      'minRateNpr': int.tryParse(_minRate.text.trim()) ?? 0,
      'rateNegotiable': _rateNegotiable,
      'availability': _availability.text.trim(),
      'bio': _bio.text.trim(),
      'tagline': _tagline.text.trim(),
      'languages': _languages.toList(),
      'categories': _categories.toList(),
      'promoVideoUrl': _promoVideoUrl,
      'cvUrl': _cvUrl,
      'portfolioUrls': _portfolioUrls,
    });
  }

  void _addSkill() {
    final name = _skillName.text.trim();
    if (name.length < 2) return;
    context.read<ProfileCubit>().addSkill(name);
    _skillName.clear();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.edit_outlined, color: KallaLaiColors.indigo),
                const SizedBox(width: 8),
                Text(
                  'My worker profile',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'This is how employers see you on vacancies. Only you can edit it.',
              style: TextStyle(color: KallaLaiColors.muted),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _publicName,
              decoration: const InputDecoration(
                labelText: 'Public name',
                hintText: 'Name shown on your applications',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _baseArea,
              decoration: const InputDecoration(
                labelText: 'Base area',
                hintText: 'e.g. Kathmandu · Baneshwor',
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _locating ? null : _useMyLocation,
              icon:
                  _locating
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.my_location),
              label: Text(_locating ? 'Locating…' : 'Use my true location'),
            ),
            if (_latitude != null && _longitude != null) ...[
              const SizedBox(height: 6),
              Text(
                'Pin: ${_latitude!.toStringAsFixed(5)}, '
                '${_longitude!.toStringAsFixed(5)}',
                style: const TextStyle(
                  color: KallaLaiColors.muted,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _minRate,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Minimum rate (NPR / shift)',
                hintText: 'e.g. 1500',
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Rate is negotiable'),
              value: _rateNegotiable,
              onChanged: (value) => setState(() => _rateNegotiable = value),
            ),
            TextField(
              controller: _availability,
              decoration: const InputDecoration(
                labelText: 'Availability',
                hintText: 'e.g. Weekday mornings, weekends anytime',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bio,
              maxLines: 3,
              maxLength: 2000,
              decoration: const InputDecoration(
                labelText: 'About me',
                hintText: 'Experience, strengths, the work you want',
              ),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _tagline,
              maxLength: 160,
              decoration: const InputDecoration(
                labelText: 'Professional tagline',
                hintText: 'e.g. Licensed electrician · 6 years · fast & tidy',
              ),
            ),
            const SizedBox(height: 12),
            _editorHeading('What work do you do?', 'Tick all the fields that apply.'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final category in _categoryOptions)
                  FilterChip(
                    avatar: Icon(
                      _categoryIcons[category] ?? Icons.work_outline,
                      size: 18,
                    ),
                    label: Text(category),
                    selected: _categories.contains(category),
                    onSelected: (selected) => setState(() {
                      if (selected) {
                        _categories.add(category);
                      } else {
                        _categories.remove(category);
                      }
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _editorHeading('Languages you speak', 'Helps employers match with you.'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final language in _languageOptions)
                  FilterChip(
                    label: Text(language),
                    selected: _languages.contains(language),
                    onSelected: (selected) => setState(() {
                      if (selected) {
                        _languages.add(language);
                      } else {
                        _languages.remove(language);
                      }
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _editorHeading('Promo video', 'A short clip introduces you to employers.'),
            const SizedBox(height: 8),
            _mediaCard(
              icon: Icons.smart_display_outlined,
              emptyLabel: 'No promo video yet',
              fileName: _promoVideoName,
              url: _promoVideoUrl,
              busy: _uploadingVideo,
              buttonLabel: 'Upload video',
              onUpload: _uploadPromoVideo,
              onRemove: () => setState(() {
                _promoVideoUrl = '';
                _promoVideoName = '';
              }),
            ),
            const SizedBox(height: 16),
            _editorHeading('CV / résumé', 'Upload a PDF or Word document.'),
            const SizedBox(height: 8),
            _mediaCard(
              icon: Icons.description_outlined,
              emptyLabel: 'No CV uploaded yet',
              fileName: _cvName,
              url: _cvUrl,
              busy: _uploadingCv,
              buttonLabel: 'Upload CV',
              onUpload: _uploadCv,
              onRemove: () => setState(() {
                _cvUrl = '';
                _cvName = '';
              }),
            ),
            const SizedBox(height: 16),
            _editorHeading('Portfolio links', 'Add links to your work (optional).'),
            const SizedBox(height: 8),
            if (_portfolioUrls.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final url in _portfolioUrls)
                    InputChip(
                      label: Text(url, overflow: TextOverflow.ellipsis),
                      onPressed: () => _openUrl(url),
                      onDeleted: () => setState(() {
                        _portfolioUrls = _portfolioUrls.where((u) => u != url).toList();
                      }),
                    ),
                ],
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _portfolioUrl,
                    decoration: const InputDecoration(
                      hintText: 'https://your-work.example.com',
                      isDense: true,
                    ),
                    onSubmitted: (_) => _addPortfolio(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _addPortfolio,
                  icon: const Icon(Icons.add_link),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Skills',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            if (state.skills.isEmpty)
              const Text(
                'No skills yet — add your first one below.',
                style: TextStyle(color: KallaLaiColors.muted),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final skill in state.skills)
                    Chip(
                      label: Text(skill.name),
                      onDeleted:
                          state.saving
                              ? null
                              : () => context.read<ProfileCubit>().removeSkill(
                                skill.slug,
                              ),
                    ),
                ],
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _skillName,
                    decoration: const InputDecoration(
                      hintText: 'Add a skill, e.g. Wiring',
                      isDense: true,
                    ),
                    onSubmitted: (_) => _addSkill(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: state.saving ? null : _addSkill,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: state.saving ? null : _save,
                icon:
                    state.saving
                        ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.save_outlined),
                label: Text(state.saving ? 'Saving…' : 'Save profile'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmployerProfileEditor extends StatefulWidget {
  const _EmployerProfileEditor({required this.state});

  final ProfileState state;

  @override
  State<_EmployerProfileEditor> createState() => _EmployerProfileEditorState();
}

class _EmployerProfileEditorState extends State<_EmployerProfileEditor> {
  static const _industryOptions = [
    'Construction', 'Manufacturing', 'Hospitality', 'Retail', 'Agriculture',
    'Transport & Logistics', 'Healthcare', 'Education', 'IT & Software',
    'Real Estate', 'Cleaning Services', 'Security', 'Event Management',
    'Food & Beverage', 'Textile & Garment', 'Automotive', 'Beauty & Wellness',
    'Domestic Help',
  ];
  static const _languageOptions = [
    'Nepali', 'English', 'Hindi', 'Maithili', 'Bhojpuri', 'Tamang',
    'Newari', 'Gurung', 'Magar', 'Urdu',
  ];

  late final TextEditingController _displayName;
  late final TextEditingController _organization;
  late final TextEditingController _bio;
  late final TextEditingController _tagline;
  late final TextEditingController _baseArea;
  late final TextEditingController _contactPhone;
  late final TextEditingController _websiteUrl;
  late final TextEditingController _portfolioUrl;
  double? _latitude;
  double? _longitude;
  bool _locating = false;
  late Set<String> _categories;
  late Set<String> _languages;
  late List<String> _portfolioUrls;
  String _profilePictureUrl = '';
  bool _uploadingPicture = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.state.employer ?? const EmployerProfile();
    _displayName = TextEditingController(text: profile.displayName);
    _organization = TextEditingController(text: profile.organization);
    _bio = TextEditingController(text: profile.bio);
    _tagline = TextEditingController(text: profile.tagline);
    _baseArea = TextEditingController(text: profile.baseArea);
    _contactPhone = TextEditingController(text: profile.contactPhone);
    _websiteUrl = TextEditingController(text: profile.websiteUrl);
    _portfolioUrl = TextEditingController();
    _latitude = profile.latitude;
    _longitude = profile.longitude;
    _categories = {...profile.categories};
    _languages = {...profile.languages};
    _portfolioUrls = [...profile.portfolioUrls];
    _profilePictureUrl = profile.profilePictureUrl;
  }

  @override
  void dispose() {
    _displayName.dispose();
    _organization.dispose();
    _bio.dispose();
    _tagline.dispose();
    _baseArea.dispose();
    _contactPhone.dispose();
    _websiteUrl.dispose();
    _portfolioUrl.dispose();
    super.dispose();
  }

  Widget _editorHeading(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(color: KallaLaiColors.muted, fontSize: 12),
        ),
      ],
    );
  }

  Future<void> _uploadProfilePicture() async {
    if (_uploadingPicture) return;
    try {
      final media = await pickImage(fromCamera: false, context: context);
      if (!mounted || media == null) return;
      setState(() => _uploadingPicture = true);
      final url = await context.read<ProfileCubit>().uploadMedia(
        kind: 'IMAGE',
        fileName: media.fileName,
        mimeType: media.mimeType,
        bytes: media.bytes,
      );
      if (!mounted) return;
      setState(() {
        _uploadingPicture = false;
        if (url != null) _profilePictureUrl = url;
      });
    } on MediaPickException catch (error) {
      if (!mounted) return;
      setState(() => _uploadingPicture = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _useMyLocation() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final position = await getCurrentDevicePosition();
      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('True location captured. Save to update your base pin.'),
        ),
      );
    } on DeviceLocationException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read your location.')),
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _addPortfolio() {
    final url = _portfolioUrl.text.trim();
    if (url.length < 4 || _portfolioUrls.contains(url)) return;
    setState(() {
      _portfolioUrls = [..._portfolioUrls, url];
      _portfolioUrl.clear();
    });
  }

  Future<void> _openUrl(String url) async {
    final base = context.read<ApiClient>().baseUrl.trim();
    final String absolute;
    if (url.startsWith('http')) {
      absolute = url;
    } else if (url.startsWith('/')) {
      absolute = base.isEmpty ? Uri.base.resolve(url).toString() : '$base$url';
    } else {
      absolute = 'https://$url';
    }
    final uri = Uri.tryParse(absolute);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _buildProfilePicture() {
    final hasPicture = _profilePictureUrl.isNotEmpty;
    final base = context.read<ApiClient>().baseUrl.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _editorHeading('Profile picture', 'A photo helps workers recognise and trust you.'),
        const SizedBox(height: 12),
        Center(
          child: GestureDetector(
            onTap: _uploadingPicture ? null : _uploadProfilePicture,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: KallaLaiColors.indigo.withValues(alpha: 0.08),
                border: Border.all(
                  color: KallaLaiColors.indigo.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: _uploadingPicture
                  ? const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : hasPicture
                      ? ClipOval(
                          child: Image.network(
                            base.isEmpty
                                ? Uri.base.resolve(_profilePictureUrl).toString()
                                : '$base$_profilePictureUrl',
                            fit: BoxFit.cover,
                            width: 110,
                            height: 110,
                            errorBuilder: (_, __, ___) => _picturePlaceholder(),
                          ),
                        )
                      : _picturePlaceholder(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasPicture) ...[
                TextButton.icon(
                  onPressed: _uploadingPicture ? null : _uploadProfilePicture,
                  icon: const Icon(Icons.swap_horiz, size: 18),
                  label: const Text('Change photo'),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: () => setState(() => _profilePictureUrl = ''),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Remove'),
                ),
              ] else
                TextButton.icon(
                  onPressed: _uploadingPicture ? null : _uploadProfilePicture,
                  icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                  label: const Text('Upload photo'),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _picturePlaceholder() {
    final name = _displayName.text.trim();
    return Center(
      child: Text(
        name.isEmpty ? '?' : name[0].toUpperCase(),
        style: const TextStyle(
          color: KallaLaiColors.indigo,
          fontWeight: FontWeight.w800,
          fontSize: 40,
        ),
      ),
    );
  }

  void _save() {
    final name = _displayName.text.trim();
    if (name.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Display name needs at least 2 characters.'),
        ),
      );
      return;
    }
    context.read<ProfileCubit>().saveEmployer({
      'displayName': name,
      'organization': _organization.text.trim(),
      'profilePictureUrl': _profilePictureUrl,
      'bio': _bio.text.trim(),
      'tagline': _tagline.text.trim(),
      'baseArea': _baseArea.text.trim(),
      if (_latitude != null) 'latitude': _latitude,
      if (_longitude != null) 'longitude': _longitude,
      'contactPhone': _contactPhone.text.trim(),
      'websiteUrl': _websiteUrl.text.trim(),
      'categories': _categories.toList(),
      'languages': _languages.toList(),
      'portfolioUrls': _portfolioUrls,
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final trust = state.employer?.trustStatus ?? 'UNVERIFIED';
    final verified = trust == 'VERIFIED';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.business_center_outlined, color: KallaLaiColors.indigo),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'My hirer profile',
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'This is how workers see you on your job posts. Make it impressive.',
              style: TextStyle(color: KallaLaiColors.muted),
            ),
            const SizedBox(height: 12),
            StatusPill(
              label:
                  verified
                      ? 'Trusted employer · verified'
                      : 'Trust check pending',
              icon: verified ? Icons.verified_outlined : Icons.shield_outlined,
              color:
                  verified
                      ? KallaLaiColors.successText
                      : KallaLaiColors.warningText,
            ),
            const SizedBox(height: 20),

            // Profile picture
            _buildProfilePicture(),
            const SizedBox(height: 20),

            // Display name
            TextField(
              controller: _displayName,
              decoration: const InputDecoration(
                labelText: 'Display name',
                hintText: 'Name shown on your job posts',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),

            // Organization
            TextField(
              controller: _organization,
              decoration: const InputDecoration(
                labelText: 'Organization',
                hintText: 'Business or team name (optional)',
                prefixIcon: Icon(Icons.business_outlined),
              ),
            ),
            const SizedBox(height: 12),

            // Tagline
            TextField(
              controller: _tagline,
              maxLength: 160,
              decoration: const InputDecoration(
                labelText: 'Tagline',
                hintText: 'e.g. Growing construction company · Kathmandu',
                prefixIcon: Icon(Icons.short_text_outlined),
              ),
            ),
            const SizedBox(height: 12),

            // Bio / About
            TextField(
              controller: _bio,
              maxLines: 4,
              maxLength: 2000,
              decoration: const InputDecoration(
                labelText: 'About the organization',
                hintText: 'Tell workers about your business, values, and the kind of work you offer',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.article_outlined),
              ),
            ),
            const SizedBox(height: 12),

            // Contact phone
            TextField(
              controller: _contactPhone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Contact phone',
                hintText: 'e.g. 98XXXXXXXX',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 12),

            // Website
            TextField(
              controller: _websiteUrl,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Website (optional)',
                hintText: 'https://your-company.example.com',
                prefixIcon: Icon(Icons.language_outlined),
              ),
            ),
            const SizedBox(height: 16),

            // Location
            _editorHeading('Location', 'Where is your business based?'),
            const SizedBox(height: 8),
            TextField(
              controller: _baseArea,
              decoration: const InputDecoration(
                labelText: 'Base area',
                hintText: 'e.g. Kathmandu · Baneshwor',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _locating ? null : _useMyLocation,
              icon:
                  _locating
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.my_location),
              label: Text(_locating ? 'Locating…' : 'Use my true location'),
            ),
            if (_latitude != null && _longitude != null) ...[
              const SizedBox(height: 6),
              Text(
                'Pin: ${_latitude!.toStringAsFixed(5)}, '
                '${_longitude!.toStringAsFixed(5)}',
                style: const TextStyle(
                  color: KallaLaiColors.muted,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 16),

            // Industries / categories
            _editorHeading('Industries you hire for', 'Tick all the fields that apply.'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final category in _industryOptions)
                  FilterChip(
                    label: Text(category),
                    selected: _categories.contains(category),
                    onSelected: (selected) => setState(() {
                      if (selected) {
                        _categories.add(category);
                      } else {
                        _categories.remove(category);
                      }
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Languages
            _editorHeading('Languages you work in', 'Helps workers communicate with you.'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final language in _languageOptions)
                  FilterChip(
                    label: Text(language),
                    selected: _languages.contains(language),
                    onSelected: (selected) => setState(() {
                      if (selected) {
                        _languages.add(language);
                      } else {
                        _languages.remove(language);
                      }
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Portfolio links
            _editorHeading('Portfolio links', 'Add links to your past projects or company page (optional).'),
            const SizedBox(height: 8),
            if (_portfolioUrls.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final url in _portfolioUrls)
                    InputChip(
                      label: Text(url, overflow: TextOverflow.ellipsis),
                      onPressed: () => _openUrl(url),
                      onDeleted: () => setState(() {
                        _portfolioUrls = _portfolioUrls.where((u) => u != url).toList();
                      }),
                    ),
                ],
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _portfolioUrl,
                    decoration: const InputDecoration(
                      hintText: 'https://your-project.example.com',
                      isDense: true,
                    ),
                    onSubmitted: (_) => _addPortfolio(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _addPortfolio,
                  icon: const Icon(Icons.add_link),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Save button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: state.saving ? null : _save,
                icon:
                    state.saving
                        ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.save_outlined),
                label: Text(state.saving ? 'Saving…' : 'Save profile'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Signed-in session card. Everything here comes from the real API session
/// (or an explicitly labelled offline demo session) — never invented.
class _AccountCard extends StatelessWidget {
  const _AccountCard();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthCubit>().state;
    final user = auth.user;
    if (user == null) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFFE0E7FF),
                  child: Text(
                    user.fullName.isEmpty
                        ? '?'
                        : user.fullName[0].toUpperCase(),
                    style: const TextStyle(
                      color: KallaLaiColors.indigo,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fullName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        user.email,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: KallaLaiColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  avatar: const Icon(Icons.badge_outlined, size: 18),
                  label: Text(user.roleLabel),
                ),
                StatusPill(
                  label:
                      user.isDemoSession
                          ? 'Demo session · offline, not a server login'
                          : 'Signed in · live API session',
                  icon:
                      user.isDemoSession
                          ? Icons.cloud_off_outlined
                          : Icons.verified_outlined,
                  color:
                      user.isDemoSession
                          ? KallaLaiColors.warningText
                          : KallaLaiColors.indigo,
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => context.read<AuthCubit>().signOut(),
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Real identity state for the signed-in worker. Applications stay locked in
/// the UI and on the API until this says VERIFIED.
class _IdentityCard extends StatelessWidget {
  const _IdentityCard();

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthCubit>().state.user;
    if (user == null || user.isDemoSession || !user.isWorker) {
      return const SizedBox.shrink();
    }
    final status = user.identityStatus;
    final verified = status == 'VERIFIED';
    final color = switch (status) {
      'VERIFIED' => KallaLaiColors.successText,
      'PENDING' => KallaLaiColors.warningText,
      'REJECTED' => KallaLaiColors.errorText,
      'NEEDS_ACTION' => KallaLaiColors.warningText,
      _ => KallaLaiColors.indigo,
    };
    final icon = switch (status) {
      'VERIFIED' => Icons.verified_outlined,
      'PENDING' => Icons.hourglass_top_rounded,
      'REJECTED' => Icons.error_outline,
      _ => Icons.shield_outlined,
    };
    final label = switch (status) {
      'VERIFIED' => 'Verified · can apply',
      'PENDING' => 'Pending · cannot apply',
      'NEEDS_ACTION' => 'Action needed · cannot apply',
      'REJECTED' => 'Not approved · cannot apply',
      _ => 'Not verified · cannot apply',
    };
    final description = switch (status) {
      'VERIFIED' => 'Your identity check is approved. You can apply for jobs.',
      'PENDING' =>
        'Your identity check is being reviewed. You can browse and save, but applications stay locked until it is approved.',
      'NEEDS_ACTION' =>
        'The verification provider needs another step. Open the check to continue.',
      'REJECTED' =>
        'Verification was not approved. You can try again; applications stay locked until it passes.',
      _ =>
        'Verify your identity to apply for jobs. Browsing and saving are always open.',
    };

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Identity check',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              StatusPill(label: label, icon: icon, color: color),
              const SizedBox(height: 10),
              Text(description),
              if (!verified) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed:
                      () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const IdentityOnboardingScreen(),
                        ),
                      ),
                  icon: const Icon(Icons.shield_outlined),
                  label: Text(
                    status == 'PENDING'
                        ? 'Check verification status'
                        : 'Verify my identity',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
