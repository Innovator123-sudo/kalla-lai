import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';

import 'web_camera.dart';

class PickedMedia {
  const PickedMedia({
    required this.bytes,
    required this.mimeType,
    required this.fileName,
  });

  final Uint8List bytes;
  final String mimeType;
  final String fileName;

  String get dataUrl => 'data:$mimeType;base64,${base64Encode(bytes)}';
  int get sizeBytes => bytes.length;
}

class MediaPickException implements Exception {
  const MediaPickException(this.message);
  final String message;
  @override
  String toString() => message;
}

String _mimeFromName(String name, String fallback) {
  final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
  return switch (ext) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    'heic' => 'image/heic',
    'mp4' => 'video/mp4',
    'webm' => 'video/webm',
    'mov' => 'video/quicktime',
    'pdf' => 'application/pdf',
    'doc' => 'application/msword',
    'docx' =>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    _ => fallback,
  };
}

/// Picks a document/selfie photo from the gallery or camera. Returns null when
/// the user cancels. On web, [fromCamera] opens a live webcam capture screen
/// (desktop browsers have no native camera picker); if no camera is available
/// it falls back to the file picker. Pass [context] to enable the web camera.
Future<PickedMedia?> pickImage({
  required bool fromCamera,
  BuildContext? context,
  String cameraFacingMode = 'environment',
}) async {
  if (fromCamera && kIsWeb && context != null) {
    try {
      return await captureFromWebCamera(
        context,
        initialFacingMode: cameraFacingMode,
      );
    } on WebCameraException {
      // No camera or permission denied — fall through to the file picker.
    }
  }
  try {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: (fromCamera && !kIsWeb) ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    final mime =
        file.mimeType ?? _mimeFromName(file.name, 'image/jpeg');
    return PickedMedia(bytes: bytes, mimeType: mime, fileName: file.name);
  } catch (error) {
    throw MediaPickException(
      fromCamera
          ? 'Could not open the camera. Try uploading from your gallery instead.'
          : 'Could not open the gallery. Please try again.',
    );
  }
}

Future<PickedMedia?> _pickFile({
  required List<String> extensions,
  required String fallbackMime,
}) async {
  try {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      throw const MediaPickException('The selected file could not be read.');
    }
    return PickedMedia(
      bytes: bytes,
      mimeType: _mimeFromName(file.name, fallbackMime),
      fileName: file.name,
    );
  } on MediaPickException {
    rethrow;
  } catch (_) {
    throw const MediaPickException('Could not open the file picker. Please try again.');
  }
}

/// Picks a CV (PDF or Word document).
Future<PickedMedia?> pickCv() => _pickFile(
  extensions: ['pdf', 'doc', 'docx'],
  fallbackMime: 'application/pdf',
);

/// Picks a short promo video.
Future<PickedMedia?> pickVideo() => _pickFile(
  extensions: ['mp4', 'webm', 'mov'],
  fallbackMime: 'video/mp4',
);