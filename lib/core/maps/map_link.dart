import 'dart:math' as math;

/// Pure-Dart helpers for Google Maps links.
///
/// The app accepts either a Google Maps share link or a raw `lat, lng` pin.
/// Nothing here trusts the raw string: [directionsUri] always returns a URI on
/// an allowlisted Google host, so a pasted `https://evil.example/...` can never
/// be launched from a button.
abstract final class MapLink {
  /// Hosts a pasted Maps link must use to be opened directly.
  static const allowedHosts = <String>{
    'maps.app.goo.gl',
    'goo.gl',
    'maps.google.com',
    'www.google.com',
    'google.com',
  };

  static const _directionsBase = 'https://www.google.com/maps/dir/';
  static const _searchBase = 'https://www.google.com/maps/search/';
  static const _embedBase = 'https://maps.google.com/maps';

  /// Extracts coordinates from a share link or a raw `27.7172, 85.3240` pin.
  /// Returns null for short links such as `maps.app.goo.gl/...` which need a
  /// redirect to resolve.
  static ({double latitude, double longitude})? coordinates(String input) {
    final text = input.trim();
    if (text.isEmpty) return null;

    // Plain coordinates: "27.7172, 85.3240".
    final plain = RegExp(
      r'^\s*(-?\d{1,3}(?:\.\d+)?)\s*,\s*(-?\d{1,3}(?:\.\d+)?)\s*$',
    ).firstMatch(text);
    if (plain != null) return _pair(plain.group(1), plain.group(2));

    // Links: @lat,lng  /  ?q=lat,lng  /  ?ll=lat,lng  /  /@lat,lng
    final embedded = RegExp(
      r'(?:@|[?&](?:q|ll|daddr|destination)=)(-?\d{1,3}(?:\.\d+)?)\s*,\s*(-?\d{1,3}(?:\.\d+)?)',
    ).firstMatch(text);
    if (embedded != null) return _pair(embedded.group(1), embedded.group(2));

    // Maps "place" URLs sometimes end with /@lat,lng or contain !3dlat!4dlng.
    final place = RegExp(
      r'!3d(-?\d{1,3}(?:\.\d+)?)!4d(-?\d{1,3}(?:\.\d+)?)',
    ).firstMatch(text);
    if (place != null) return _pair(place.group(1), place.group(2));
    return null;
  }

  static ({double latitude, double longitude})? _pair(String? lat, String? lng) {
    final latitude = double.tryParse(lat ?? '');
    final longitude = double.tryParse(lng ?? '');
    if (latitude == null || longitude == null) return null;
    if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
      return null;
    }
    return (latitude: latitude, longitude: longitude);
  }

  /// True when the trimmed input is a usable Google Maps link or a raw pin.
  static bool isValid(String input) {
    final text = input.trim();
    if (text.isEmpty) return false;
    if (coordinates(text) != null) return true;
    final uri = Uri.tryParse(text);
    if (uri == null || uri.scheme != 'https') return false;
    final host = uri.host.toLowerCase();
    return allowedHosts.any((allowed) => host == allowed || host.endsWith('.$allowed'));
  }

  /// A safe, always-Google URL for the "Directions" action.
  static Uri directionsUri({
    required String link,
    double? latitude,
    double? longitude,
    required String area,
  }) {
    final trimmed = link.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri != null &&
        uri.scheme == 'https' &&
        allowedHosts.contains(uri.host.toLowerCase())) {
      return uri;
    }
    final lat = latitude;
    final lng = longitude;
    if (lat != null && lng != null) {
      return Uri.parse('$_directionsBase?api=1&destination=$lat,$lng');
    }
    final query = area.trim().isEmpty ? 'Kathmandu' : area.trim();
    return Uri.parse('$_searchBase?api=1&query=${Uri.encodeComponent(query)}');
  }

  /// The keyless Google Maps embed URL used by the in-app preview.
  static String embedUrl({
    required String link,
    double? latitude,
    double? longitude,
    required String area,
  }) {
    final coords = coordinates(link);
    final lat = latitude ?? coords?.latitude;
    final lng = longitude ?? coords?.longitude;
    final query = (lat != null && lng != null)
        ? '$lat,$lng'
        : Uri.encodeComponent(area.trim().isEmpty ? 'Kathmandu' : area.trim());
    return '$_embedBase?q=$query&z=15&output=embed';
  }

  /// Human-readable pin used in the hirer wizard and worker job detail.
  static String pinLabel(double? latitude, double? longitude) {
    if (latitude == null || longitude == null) return '';
    return '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
  }

  /// Kept for callers that want to display a "straight-line" hint without a
  /// network request. Uses the standard Haversine formula.
  static double distanceKm(
    double fromLat,
    double fromLng,
    double toLat,
    double toLng,
  ) {
    double rad(double deg) => deg * math.pi / 180;
    final dLat = rad(toLat - fromLat);
    final dLng = rad(toLng - fromLng);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(rad(fromLat)) *
            math.cos(rad(toLat)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return 6371.0 * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }
}
