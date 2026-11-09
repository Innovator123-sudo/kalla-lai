import 'package:equatable/equatable.dart';
import 'package:kalla_lai/features/shared/domain/marketplace_models.dart';

class DiscoveryState extends Equatable {
  const DiscoveryState({
    this.isLoading = false,
    this.jobs = const [],
    this.distanceKm = 5,
    this.isLive = false,
    this.errorMessage,
    this.userLocation,
    this.locationAccuracyM,
    this.locating = false,
    this.locationError,
  });

  final bool isLoading;
  final List<JobShift> jobs;
  final int distanceKm;
  final bool isLive;
  final String? errorMessage;

  /// True device location once the user grants permission. Null means the
  /// map is showing approximate areas around the default base area.
  final GeoPoint? userLocation;
  final double? locationAccuracyM;
  final bool locating;
  final String? locationError;

  DiscoveryState copyWith({
    bool? isLoading,
    List<JobShift>? jobs,
    int? distanceKm,
    bool? isLive,
    String? errorMessage,
    bool clearError = false,
    GeoPoint? userLocation,
    double? locationAccuracyM,
    bool? locating,
    String? locationError,
    bool clearLocationError = false,
  }) {
    return DiscoveryState(
      isLoading: isLoading ?? this.isLoading,
      jobs: jobs ?? this.jobs,
      distanceKm: distanceKm ?? this.distanceKm,
      isLive: isLive ?? this.isLive,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      userLocation: userLocation ?? this.userLocation,
      locationAccuracyM: locationAccuracyM ?? this.locationAccuracyM,
      locating: locating ?? this.locating,
      locationError:
          clearLocationError ? null : locationError ?? this.locationError,
    );
  }

  @override
  List<Object?> get props => [
    isLoading,
    jobs,
    distanceKm,
    isLive,
    errorMessage,
    userLocation,
    locationAccuracyM,
    locating,
    locationError,
  ];
}
