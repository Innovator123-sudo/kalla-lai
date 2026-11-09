import 'package:flutter/widgets.dart';

import 'media_picker.dart';

class WebCameraException implements Exception {
  const WebCameraException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Non-web platforms never call this (image_picker handles the native camera);
/// it exists only so the conditional import resolves everywhere.
Future<PickedMedia?> captureFromWebCamera(
  BuildContext context, {
  String initialFacingMode = 'environment',
}) async {
  throw const WebCameraException('Camera capture is only available on the web.');
}