import 'package:kalla_lai/features/shared/domain/marketplace_models.dart';

/// Read model used by the discovery experience.
///
/// Live and demo implementations exist so the same cubit can run against the
/// real API or offline sample data without the UI knowing the difference.
abstract interface class MarketplaceRepository {
  /// Whether the data shown comes from the live API.
  bool get isLive;

  /// Jobs within [radiusKm] of [origin] (the worker's true location when
  /// granted, otherwise their approximate base area).
  Future<List<JobShift>> nearbyJobs({double radiusKm = 5, GeoPoint? origin});
}
