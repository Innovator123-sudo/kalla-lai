import 'dart:convert';
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import 'media_picker.dart';

class WebCameraException implements Exception {
  const WebCameraException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Opens a live webcam preview and returns the captured frame. Returns null if
/// the user cancels; throws [WebCameraException] when no camera is available so
/// the caller can fall back to the file picker. [initialFacingMode] is
/// 'environment' (rear lens, best for documents) or 'user' (front lens/selfie);
/// the user can switch lenses while the screen is open.
Future<PickedMedia?> captureFromWebCamera(
  BuildContext context, {
  String initialFacingMode = 'environment',
}) async {
  final result = await Navigator.of(context).push<Object?>(
    MaterialPageRoute(
      builder: (_) => _WebCameraScreen(initialFacingMode: initialFacingMode),
    ),
  );
  if (result is PickedMedia) return result;
  if (result == 'fallback') {
    throw const WebCameraException(
      'No camera is available. Upload a photo instead.',
    );
  }
  return null;
}

class _WebCameraScreen extends StatefulWidget {
  const _WebCameraScreen({required this.initialFacingMode});

  final String initialFacingMode;

  @override
  State<_WebCameraScreen> createState() => _WebCameraScreenState();
}

class _WebCameraScreenState extends State<_WebCameraScreen> {
  static int _counter = 0;

  late final String _viewType;
  late final web.HTMLVideoElement _video;
  late String _facingMode;
  web.MediaStream? _stream;
  bool _starting = true;
  bool _ready = false;
  bool _capturing = false;
  bool _switching = false;
  String? _error;

  bool get _isFront => _facingMode == 'user';

  @override
  void initState() {
    super.initState();
    _facingMode = widget.initialFacingMode;
    _viewType = 'kalla-webcam-${_counter++}';
    _video = web.document.createElement('video') as web.HTMLVideoElement;
    _video.autoplay = true;
    _video.muted = true;
    _video.setAttribute('playsinline', 'true');
    _video.style.width = '100%';
    _video.style.height = '100%';
    _video.style.objectFit = 'cover';
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => _video,
    );
    _start();
  }

  Future<void> _start() async {
    try {
      final stream = await web.window.navigator.mediaDevices
          .getUserMedia(
            web.MediaStreamConstraints(
              video: web.MediaTrackConstraints(facingMode: _facingMode.toJS),
              audio: false.toJS,
            ),
          )
          .toDart;
      _stream = stream;
      _video.srcObject = stream;
      _video.style.transform = _isFront ? 'scaleX(-1)' : 'none';
      await _video.play().toDart;
      if (!mounted) {
        _stopTracks();
        return;
      }
      setState(() {
        _starting = false;
        _switching = false;
        _ready = true;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _switching = false;
        _error =
            'Could not open the ${_isFront ? 'front' : 'rear'} camera. Allow camera '
            'access in your browser, switch lens, or upload a photo instead.';
      });
    }
  }

  Future<void> _switchCamera() async {
    if (_switching || _capturing) return;
    setState(() {
      _switching = true;
      _starting = true;
      _ready = false;
      _error = null;
      _facingMode = _isFront ? 'environment' : 'user';
    });
    _stopTracks();
    await _start();
  }

  Future<void> _capture() async {
    if (!_ready || _capturing) return;
    setState(() => _capturing = true);
    try {
      final canvas =
          web.document.createElement('canvas') as web.HTMLCanvasElement;
      final sourceWidth = _video.videoWidth > 0 ? _video.videoWidth : 640;
      final sourceHeight = _video.videoHeight > 0 ? _video.videoHeight : 480;
      const maxSide = 1600;
      final scale = math.min(
        1.0,
        maxSide / math.max(sourceWidth, sourceHeight),
      );
      canvas.width = (sourceWidth * scale).round();
      canvas.height = (sourceHeight * scale).round();
      final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;
      ctx.drawImage(_video, 0, 0, canvas.width, canvas.height);
      final dataUrl = canvas.toDataURL('image/jpeg', 0.85.toJS);
      final bytes = base64Decode(dataUrl.split(',').last);
      if (!mounted) return;
      Navigator.of(context).pop(
        PickedMedia(
          bytes: bytes,
          mimeType: 'image/jpeg',
          fileName: 'camera-photo.jpg',
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _capturing = false;
        _error = 'Could not capture the photo. Please try again.';
      });
    }
  }

  void _stopTracks() {
    final stream = _stream;
    if (stream == null) return;
    for (final track in stream.getTracks().toDart) {
      track.stop();
    }
    _stream = null;
  }

  @override
  void dispose() {
    _stopTracks();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isFront ? 'Front camera' : 'Rear camera'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Switch front/back camera',
            onPressed: _switching || _capturing ? null : _switchCamera,
            icon: const Icon(Icons.cameraswitch_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(20),
              shrinkWrap: true,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: 3 / 4,
                    child: ColoredBox(
                      color: Colors.black,
                      child: _error != null
                          ? const Center(
                              child: Icon(
                                Icons.videocam_off_outlined,
                                color: Colors.white54,
                                size: 48,
                              ),
                            )
                          : HtmlElementView(viewType: _viewType),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_starting)
                  const Center(child: CircularProgressIndicator())
                else if (_error != null) ...[
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _switchCamera,
                    icon: const Icon(Icons.cameraswitch_outlined),
                    label: Text(_isFront ? 'Try rear camera' : 'Try front camera'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop('fallback'),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Upload a photo instead'),
                  ),
                ] else ...[
                  FilledButton.icon(
                    onPressed: _capturing ? null : _capture,
                    icon: const Icon(Icons.photo_camera),
                    label: Text(_capturing ? 'Capturing…' : 'Capture photo'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _switching || _capturing ? null : _switchCamera,
                    icon: const Icon(Icons.cameraswitch_outlined),
                    label: Text(
                      _isFront ? 'Switch to rear camera' : 'Switch to front camera',
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}