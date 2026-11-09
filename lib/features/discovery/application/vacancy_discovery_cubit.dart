import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kalla_lai/core/location/device_location.dart';
import 'package:kalla_lai/core/networking/api_client.dart';
import 'package:kalla_lai/features/discovery/application/discovery_state.dart';
import 'package:kalla_lai/features/shared/data/marketplace_repository.dart';
import 'package:kalla_lai/features/shared/domain/marketplace_models.dart';

class VacancyDiscoveryCubit extends Cubit<DiscoveryState> {
  VacancyDiscoveryCubit(this._repository)
    : super(DiscoveryState(isLive: _repository.isLive));

  final MarketplaceRepository _repository;

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final jobs = await _repository.nearbyJobs(
        radiusKm: state.distanceKm.toDouble(),
        origin: state.userLocation,
      );
      if (isClosed) return;
      emit(state.copyWith(isLoading: false, jobs: jobs));
    } on ApiException catch (error) {
      if (isClosed) return;
      emit(state.copyWith(isLoading: false, errorMessage: error.message));
    } catch (_) {
      if (isClosed) return;
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'Something went wrong while loading shifts.',
        ),
      );
    }
  }

  Future<void> setDistance(int distanceKm) async {
    emit(state.copyWith(distanceKm: distanceKm));
    await load();
  }

  /// Ask for location permission and re-center discovery on the device's
  /// true position instead of the approximate default area.
  Future<void> useTrueLocation() async {
    if (state.locating) return;
    emit(state.copyWith(locating: true, clearLocationError: true));
    try {
      final position = await getCurrentDevicePosition();
      if (isClosed) return;
      emit(
        state.copyWith(
          locating: false,
          userLocation: GeoPoint(position.latitude, position.longitude),
          locationAccuracyM: position.accuracy,
        ),
      );
      await load();
    } on DeviceLocationException catch (error) {
      if (isClosed) return;
      emit(state.copyWith(locating: false, locationError: error.message));
    } catch (_) {
      if (isClosed) return;
      emit(
        state.copyWith(
          locating: false,
          locationError:
              'Could not read your location. Check the site permission and try again.',
        ),
      );
    }
  }
}
