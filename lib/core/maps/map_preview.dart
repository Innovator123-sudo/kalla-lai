/// Platform-conditional Google Maps preview.
///
/// Web builds get a real embedded map (no API key required). Native builds get
/// a compact location card. The conditional import mirrors the pattern already
/// used by `core/media/web_camera.dart`.
export 'map_preview_stub.dart'
    if (dart.library.js_interop) 'map_preview_web.dart';
