import 'package:kalla_lai/core/networking/api_client.dart';
import 'package:kalla_lai/features/shared/data/marketplace_repository.dart';
import 'package:kalla_lai/features/shared/domain/marketplace_models.dart';

/// Read-only marketplace repository backed by the Kalla-Lai API.
///
/// Discovery is a public endpoint, so no session is required. Coordinates are
/// deliberately coarse in the response; the exact address is released only
/// after an offer is accepted.
class ApiMarketplaceRepository implements MarketplaceRepository {
  ApiMarketplaceRepository(
    this._client, {
    this.origin = const GeoPoint(27.6895, 85.3436),
  });

  final ApiClient _client;

  /// Approximate fallback base area (Baneshwor, Kathmandu) used until the
  /// user grants device location.
  final GeoPoint origin;

  @override
  bool get isLive => true;

  @override
  Future<List<JobShift>> nearbyJobs({
    double radiusKm = 5,
    GeoPoint? origin,
  }) async {
    final center = origin ?? this.origin;
    final response = await _client.getJson(
      '/v1/discovery/jobs',
      query: {
        'lat': center.latitude.toStringAsFixed(4),
        'lng': center.longitude.toStringAsFixed(4),
        'radiusKm': radiusKm.clamp(1, 100).ceil().toString(),
        'limit': '50',
      },
    );
    final items = response['items'];
    if (items is! List) return const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(_toJobShift)
        .toList(growable: false);
  }

  JobShift _toJobShift(Map<String, dynamic> json) {
    final employer = json['employer'];
    return JobShift(
      id: json['id']?.toString() ?? '',
      role: json['role']?.toString() ?? 'Untitled role',
      location: _point(json),
      area: json['area']?.toString() ?? 'Kathmandu Valley',
      rateNpr: (json['rateNpr'] as num?)?.round() ?? 0,
      shiftLabel: _scheduleLabel(
        json['workMode']?.toString(),
        DateTime.tryParse(json['publishedAt']?.toString() ?? ''),
      ),
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0,
      employerVerified:
          employer is Map<String, dynamic> && employer['verified'] == true,
      description: json['description']?.toString() ?? '',
      skills:
          (json['requiredSkills'] as List?)
              ?.whereType<String>()
              .map(_humanize)
              .toList(growable: false) ??
          const [],
      category: json['category']?.toString() ?? '',
      contactPhone: json['contactPhone']?.toString() ?? '',
      workingHours: json['workingHours']?.toString() ?? '',
      employmentType: json['employmentType']?.toString() ?? 'FULL_TIME',
      openings: (json['openings'] as num?)?.round() ?? 1,
      salaryIncrement: json['salaryIncrement'] == true,
      incrementNote: json['incrementNote']?.toString() ?? '',
      compensationType: json['compensationType']?.toString() ?? 'DAILY',
      negotiable: json['negotiable'] != false,
    );
  }

  GeoPoint _point(Map<String, dynamic> json) {
    final latitude = (json['latitude'] as num?)?.toDouble();
    final longitude = (json['longitude'] as num?)?.toDouble();
    if (latitude == null || longitude == null) return origin;
    return GeoPoint(latitude, longitude);
  }

  String _scheduleLabel(String? workMode, DateTime? publishedAt) {
    final mode = switch (workMode) {
      'REMOTE' => 'Remote',
      'HYBRID' => 'Hybrid',
      _ => 'On-site',
    };
    if (publishedAt == null) return '$mode · schedule set in offer';
    return '$mode · posted ${_relative(publishedAt)}';
  }

  String _relative(DateTime time) {
    final difference = DateTime.now().toUtc().difference(time.toUtc());
    if (difference.inMinutes < 1) return 'just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    if (difference.inDays < 30) return '${difference.inDays}d ago';
    return 'over a month ago';
  }

  String _humanize(String slug) => slug
      .split('-')
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .join(' ');
}
