import 'package:geolocator/geolocator.dart';

class DeviceLocationException implements Exception {
  const DeviceLocationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Reads the device's true position, asking for permission when needed.
/// Throws [DeviceLocationException] with a user-readable reason on failure.
Future<Position> getCurrentDevicePosition() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw const DeviceLocationException(
      'Location services are off. Turn them on to see your true location.',
    );
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    throw const DeviceLocationException(
      'Location permission was denied. Allow location for this site in your browser settings, then try again.',
    );
  }
  try {
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
  } catch (_) {
    throw const DeviceLocationException(
      'Could not read your location. Check the site permission and try again.',
    );
  }
}
