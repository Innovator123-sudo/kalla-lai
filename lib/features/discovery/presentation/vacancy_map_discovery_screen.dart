import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as maps;
import 'package:intl/intl.dart';
import 'package:kalla_lai/core/config/app_config.dart';
import 'package:kalla_lai/core/localization/app_strings.dart';
import 'package:kalla_lai/core/maps/map_link.dart';
import 'package:kalla_lai/core/theme/kalla_lai_theme.dart';
import 'package:kalla_lai/core/widgets/loading_animation.dart';
import 'package:kalla_lai/core/widgets/status_pill.dart';
import 'package:kalla_lai/features/discovery/application/discovery_state.dart';
import 'package:kalla_lai/features/discovery/application/vacancy_discovery_cubit.dart';
import 'package:kalla_lai/features/shared/domain/marketplace_models.dart';
import 'package:url_launcher/url_launcher.dart';

class VacancyMapDiscoveryScreen extends StatelessWidget {
  const VacancyMapDiscoveryScreen({
    required this.savedJobIds,
    required this.onToggleSaved,
    required this.onApply,
    required this.canApply,
    required this.onVerificationRequired,
    super.key,
  });

  final Set<String> savedJobIds;
  final ValueChanged<JobShift> onToggleSaved;
  final ValueChanged<JobShift> onApply;

  /// False for a live worker whose identity is not VERIFIED. Browsing and
  /// saving stay available; only applications are blocked.
  final bool canApply;
  final VoidCallback onVerificationRequired;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return BlocListener<VacancyDiscoveryCubit, DiscoveryState>(
      listenWhen:
          (previous, current) =>
              previous.locationError != current.locationError &&
              current.locationError != null,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(state.locationError!)));
      },
      child: BlocBuilder<VacancyDiscoveryCubit, DiscoveryState>(
        builder: (context, state) {
          final visibleJobs =
              state.jobs
                  .where((job) => job.distanceKm <= state.distanceKm)
                  .toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.text('nearby'),
                      style: Theme.of(
                        context,
                      ).textTheme.headlineSmall?.copyWith(
                        color: KallaLaiColors.slate,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      state.userLocation != null
                          ? 'Your true location · ${state.isLive ? 'Live listings' : 'Sample data'}'
                          : state.isLive
                          ? 'Kathmandu Valley · Live listings'
                          : 'Koteshwor, Kathmandu · Sample data',
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              onPressed:
                                  state.locating
                                      ? null
                                      : () => context
                                          .read<VacancyDiscoveryCubit>()
                                          .useTrueLocation(),
                              icon:
                                  state.locating
                                      ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                      : Icon(
                                        state.userLocation != null
                                            ? Icons.my_location
                                            : Icons.location_searching,
                                        size: 18,
                                      ),
                              label: Text(
                                state.locating
                                    ? 'Locating…'
                                    : state.userLocation != null
                                    ? 'True location on'
                                    : 'Use my true location',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.outlined(
                          tooltip: 'Refresh jobs',
                          onPressed:
                              state.isLoading
                                  ? null
                                  : () => context
                                      .read<VacancyDiscoveryCubit>()
                                      .load(),
                          icon: const Icon(Icons.refresh, size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          '${strings.text('distance')}:',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 8),
                        for (final distance in [2, 5, 15])
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text('$distance km'),
                              selected: state.distanceKm == distance,
                              onSelected:
                                  (_) => context
                                      .read<VacancyDiscoveryCubit>()
                                      .setDistance(distance),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.padded,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!canApply)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                    decoration: BoxDecoration(
                      color: KallaLaiColors.warningText.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: KallaLaiColors.warningText.withValues(
                          alpha: 0.25,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.verified_user_outlined,
                          size: 20,
                          color: KallaLaiColors.warningText,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Verify your identity to apply. Browsing and saving stay open.',
                            style: TextStyle(fontSize: 13, height: 1.35),
                          ),
                        ),
                        TextButton(
                          onPressed: onVerificationRequired,
                          child: const Text('Verify'),
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child:
                    state.isLoading
                        ? const LoadingAnimation()
                        : state.errorMessage != null
                        ? _DiscoveryError(
                          message: state.errorMessage!,
                          onRetry:
                              () =>
                                  context.read<VacancyDiscoveryCubit>().load(),
                        )
                        : visibleJobs.isEmpty
                        ? _DiscoveryEmpty(isLive: state.isLive)
                        : _MapAndJobSheet(
                          jobs: visibleJobs,
                          distanceKm: state.distanceKm,
                          userLocation: state.userLocation,
                          savedJobIds: savedJobIds,
                          onToggleSaved: onToggleSaved,
                          onApply: onApply,
                          canApply: canApply,
                          onVerificationRequired: onVerificationRequired,
                        ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DiscoveryError extends StatelessWidget {
  const _DiscoveryError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 36),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    ),
  );
}

class _DiscoveryEmpty extends StatelessWidget {
  const _DiscoveryEmpty({required this.isLive});

  final bool isLive;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.work_outline, size: 40),
          const SizedBox(height: 12),
          Text(
            isLive
                ? 'No open shifts in this area yet. Try a wider search radius.'
                : 'No sample shifts in this area yet. Try a wider distance.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class _MapAndJobSheet extends StatelessWidget {
  const _MapAndJobSheet({
    required this.jobs,
    required this.distanceKm,
    required this.userLocation,
    required this.savedJobIds,
    required this.onToggleSaved,
    required this.onApply,
    required this.canApply,
    required this.onVerificationRequired,
  });

  final List<JobShift> jobs;
  final int distanceKm;
  final GeoPoint? userLocation;
  final Set<String> savedJobIds;
  final ValueChanged<JobShift> onToggleSaved;
  final ValueChanged<JobShift> onApply;
  final bool canApply;
  final VoidCallback onVerificationRequired;

  void _openJob(BuildContext context, JobShift job) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder:
          (sheetContext) => _JobDetailsSheet(
            job: job,
            isSaved: savedJobIds.contains(job.id),
            onToggleSaved: () => onToggleSaved(job),
            onApply: () => onApply(job),
            canApply: canApply,
            onVerificationRequired: () {
              Navigator.of(sheetContext).pop();
              onVerificationRequired();
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final first = jobs.first;
    final center = userLocation ?? first.location;
    const canUseMap = AppConfig.mapsConfigured && !kIsWeb;
    return Stack(
      children: [
        Positioned.fill(
          child:
              canUseMap
                  ? maps.GoogleMap(
                    initialCameraPosition: maps.CameraPosition(
                      target: maps.LatLng(center.latitude, center.longitude),
                      zoom: 12.5,
                    ),
                    myLocationEnabled: userLocation != null,
                    myLocationButtonEnabled: false,
                    markers: {
                      for (final job in jobs)
                        maps.Marker(
                          markerId: maps.MarkerId(job.id),
                          position: maps.LatLng(
                            job.location.latitude,
                            job.location.longitude,
                          ),
                          infoWindow: maps.InfoWindow(
                            title: job.role,
                            snippet: 'NPR ${job.rateNpr} / shift',
                          ),
                          onTap: () => _openJob(context, job),
                        ),
                    },
                    circles: {
                      maps.Circle(
                        circleId: const maps.CircleId('search-radius'),
                        center: maps.LatLng(center.latitude, center.longitude),
                        fillColor: KallaLaiColors.indigo.withValues(
                          alpha: 0.08,
                        ),
                        strokeColor: KallaLaiColors.indigo.withValues(
                          alpha: 0.38,
                        ),
                        strokeWidth: 1,
                        radius: distanceKm * 1000.0,
                      ),
                    },
                  )
                  : _SchematicMap(
                    jobs: jobs,
                    distanceKm: distanceKm,
                    showUserLocation: userLocation != null,
                    onTap: (job) => _openJob(context, job),
                  ),
        ),
        Positioned(
          top: 14,
          right: 14,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(color: Color(0x22000000), blurRadius: 10),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    userLocation != null
                        ? Icons.my_location
                        : Icons.near_me_outlined,
                    size: 16,
                    color:
                        userLocation != null
                            ? KallaLaiColors.successText
                            : null,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    userLocation != null
                        ? 'True location'
                        : 'Approximate areas',
                  ),
                ],
              ),
            ),
          ),
        ),
        DraggableScrollableSheet(
          initialChildSize: 0.40,
          minChildSize: 0.25,
          maxChildSize: 0.82,
          builder:
              (context, controller) => Container(
                decoration: const BoxDecoration(
                  color: KallaLaiColors.canvas,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(color: Color(0x22000000), blurRadius: 14),
                  ],
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${jobs.length} nearby opportunities',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          TextButton.icon(
                            onPressed:
                                () => context
                                    .read<VacancyDiscoveryCubit>()
                                    .load(),
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Refresh'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        controller: controller,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                        itemCount: jobs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder:
                            (context, index) => _JobListTile(
                              job: jobs[index],
                              isSaved: savedJobIds.contains(jobs[index].id),
                              onToggleSaved: () => onToggleSaved(jobs[index]),
                              onTap: () => _openJob(context, jobs[index]),
                            ),
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

class _JobListTile extends StatelessWidget {
  const _JobListTile({
    required this.job,
    required this.isSaved,
    required this.onToggleSaved,
    required this.onTap,
  });

  final JobShift job;
  final bool isSaved;
  final VoidCallback onToggleSaved;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: onTap,
                      child: Text(
                        job.role,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: isSaved ? 'Remove saved job' : 'Save job',
                    onPressed: onToggleSaved,
                    icon: Icon(
                      isSaved ? Icons.bookmark : Icons.bookmark_border,
                    ),
                  ),
                  Text(
                    'NPR ${NumberFormat('#,##0').format(job.rateNpr)}',
                    style: const TextStyle(
                      fontFeatures: [FontFeature.tabularFigures()],
                      fontFamily: KallaLaiTypography.numeric,
                      fontWeight: FontWeight.w800,
                      color: KallaLaiColors.indigo,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Text('${job.area} · ${job.distanceKm.toStringAsFixed(1)} km'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.schedule, size: 16, color: Colors.blueGrey[700]),
                  const SizedBox(width: 5),
                  Expanded(child: Text(job.shiftLabel)),
                  if (job.employerVerified)
                    StatusPill(
                      label: AppStrings.of(context).text('verified_employer'),
                      icon: Icons.verified_outlined,
                      color: KallaLaiColors.successText,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JobDetailsSheet extends StatefulWidget {
  const _JobDetailsSheet({
    required this.job,
    required this.isSaved,
    required this.onToggleSaved,
    required this.onApply,
    required this.canApply,
    required this.onVerificationRequired,
  });

  final JobShift job;
  final bool isSaved;
  final VoidCallback onToggleSaved;
  final VoidCallback onApply;
  final bool canApply;
  final VoidCallback onVerificationRequired;

  @override
  State<_JobDetailsSheet> createState() => _JobDetailsSheetState();
}

class _JobDetailsSheetState extends State<_JobDetailsSheet> {
  late double _offer = widget.job.rateNpr.toDouble();
  late bool _isSaved = widget.isSaved;

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        22,
        18,
        22,
        22 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              job.role,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: KallaLaiColors.slate,
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  setState(() => _isSaved = !_isSaved);
                  widget.onToggleSaved();
                },
                icon: Icon(_isSaved ? Icons.bookmark : Icons.bookmark_border),
                label: Text(_isSaved ? 'Saved' : 'Save job'),
              ),
            ),
            if (job.employerVerified)
              const StatusPill(
                label: 'Verified employer · प्रमाणित',
                icon: Icons.verified_outlined,
                color: KallaLaiColors.green,
              ),
            const SizedBox(height: 16),
            _DetailLine(icon: Icons.location_on_outlined, text: job.area),
            _DetailLine(icon: Icons.schedule, text: job.shiftLabel),
            const _DetailLine(
              icon: Icons.radar,
              text: 'Approximate work area · exact address after confirmation',
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                String targetUrl;
                if (job.googleMapsLink.trim().isNotEmpty) {
                  targetUrl = job.googleMapsLink.trim();
                } else {
                  final urlMatch = RegExp(r'https?://[^\s]+(?:google\.com/maps|maps\.app\.goo\.gl)[^\s]*').firstMatch(job.description);
                  if (urlMatch != null) {
                    targetUrl = urlMatch.group(0)!;
                  } else if (job.location.latitude != 0 && job.location.longitude != 0) {
                    targetUrl = 'https://www.google.com/maps/dir/?api=1&destination=${job.location.latitude},${job.location.longitude}';
                  } else {
                    targetUrl = 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(job.area)}';
                  }
                }
                launchUrl(Uri.parse(targetUrl), mode: LaunchMode.externalApplication);
              },
              icon: const Icon(Icons.directions_outlined),
              label: const Text('Open directions in Google Maps'),
            ),
            const SizedBox(height: 12),
            Text(job.description),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final skill in job.skills)
                  Chip(
                    avatar: const Icon(Icons.check_circle_outline, size: 16),
                    label: Text(skill),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Your proposed rate · NPR ${_offer.round()}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                fontFeatures: [FontFeature.tabularFigures()],
                fontFamily: KallaLaiTypography.numeric,
              ),
            ),
            Slider(
              value: _offer,
              min: (job.rateNpr * 0.7).roundToDouble(),
              max: (job.rateNpr * 1.5).roundToDouble(),
              divisions: 16,
              label: 'NPR ${_offer.round()}',
              onChanged: (value) => setState(() => _offer = value),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                    widget.canApply
                        ? () {
                          final messenger = ScaffoldMessenger.of(context);
                          final amount = _offer.round();
                          widget.onApply();
                          Navigator.of(context).pop();
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                'Saved to your Applied list in this demo. NPR $amount was not sent to the employer.',
                              ),
                            ),
                          );
                        }
                        : widget.onVerificationRequired,
                icon: Icon(
                  widget.canApply
                      ? Icons.send_outlined
                      : Icons.verified_user_outlined,
                ),
                label: Text(
                  widget.canApply
                      ? 'Apply / propose rate'
                      : 'Verify identity to apply',
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.canApply
                  ? 'A verified profile is required before a real application can be submitted.'
                  : 'Applying is locked until your identity check is approved. You can still save this job.',
              style: const TextStyle(color: KallaLaiColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Icon(icon, size: 19, color: KallaLaiColors.indigo),
        const SizedBox(width: 9),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

class _SchematicMap extends StatelessWidget {
  const _SchematicMap({
    required this.jobs,
    required this.distanceKm,
    required this.showUserLocation,
    required this.onTap,
  });

  final List<JobShift> jobs;
  final int distanceKm;
  final bool showUserLocation;
  final ValueChanged<JobShift> onTap;

  static const _positions = [
    Alignment(-0.55, -0.15),
    Alignment(0.35, 0.03),
    Alignment(0.7, -0.65),
  ];

  @override
  Widget build(BuildContext context) {
    final ringDiameter = switch (distanceKm) {
      2 => 80.0,
      5 => 140.0,
      _ => 220.0,
    };
    return Stack(
      fit: StackFit.expand,
      children: [
        const CustomPaint(painter: _SchematicMapPainter()),
        Align(
          alignment: const Alignment(0.02, 0.12),
          child: Container(
            width: ringDiameter,
            height: ringDiameter,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: KallaLaiColors.indigo.withValues(alpha: 0.08),
              border: Border.all(
                color: KallaLaiColors.indigo.withValues(alpha: 0.38),
              ),
            ),
          ),
        ),
        if (showUserLocation)
          Align(
            alignment: const Alignment(0.02, 0.12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF1A73E8),
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: const [
                      BoxShadow(color: Color(0x331A73E8), blurRadius: 8),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'You',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A73E8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        for (var index = 0; index < jobs.length; index++)
          Align(
            alignment: _positions[index % _positions.length],
            child: Semantics(
              button: true,
              label: '${jobs[index].role}, NPR ${jobs[index].rateNpr}',
              child: Material(
                color: KallaLaiColors.indigo,
                shape: const CircleBorder(),
                elevation: 3,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => onTap(jobs[index]),
                  child: Padding(
                    padding: const EdgeInsets.all(11),
                    child: Text(
                      'रू ${jobs[index].rateNpr}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontFeatures: [FontFeature.tabularFigures()],
                        fontFamily: KallaLaiTypography.numeric,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        const Positioned(
          left: 18,
          top: 18,
          child: Text(
            'KATHMANDU VALLEY · SCHEMATIC',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: KallaLaiColors.muted,
            ),
          ),
        ),
      ],
    );
  }
}

class _SchematicMapPainter extends CustomPainter {
  const _SchematicMapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()..color = const Color(0xFFE9F0EA);
    canvas.drawRect(Offset.zero & size, background);
    final parkPaint = Paint()..color = const Color(0xFFD8E8D6);
    final park =
        Path()
          ..moveTo(size.width * 0.02, size.height * 0.24)
          ..quadraticBezierTo(
            size.width * 0.24,
            size.height * 0.12,
            size.width * 0.41,
            size.height * 0.32,
          )
          ..lineTo(size.width * 0.28, size.height * 0.64)
          ..lineTo(size.width * 0.03, size.height * 0.57)
          ..close();
    canvas.drawPath(park, parkPaint);
    final roadPaint =
        Paint()
          ..color = Colors.white
          ..strokeWidth = 12
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
    final roads = [
      Path()
        ..moveTo(-20, size.height * 0.78)
        ..cubicTo(
          size.width * 0.25,
          size.height * 0.64,
          size.width * 0.65,
          size.height * 0.88,
          size.width + 20,
          size.height * 0.54,
        ),
      Path()
        ..moveTo(size.width * 0.7, -20)
        ..cubicTo(
          size.width * 0.55,
          size.height * 0.26,
          size.width * 0.72,
          size.height * 0.64,
          size.width * 0.52,
          size.height + 20,
        ),
      Path()
        ..moveTo(-20, size.height * 0.18)
        ..quadraticBezierTo(
          size.width * 0.45,
          size.height * 0.41,
          size.width + 20,
          size.height * 0.26,
        ),
    ];
    for (final road in roads) {
      canvas.drawPath(road, roadPaint);
      canvas.drawPath(
        road,
        Paint()
          ..color = const Color(0xFFD7DEE4)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke,
      );
    }
    final blockPaint = Paint()..color = const Color(0xFFE1E7E8);
    for (var row = 0; row < 4; row++) {
      for (var column = 0; column < 5; column++) {
        final rect = Rect.fromLTWH(
          size.width * (0.08 + column * 0.19),
          size.height * (0.08 + row * 0.22),
          size.width * 0.08,
          size.height * 0.07,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(4)),
          blockPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_SchematicMapPainter oldDelegate) => false;
}
