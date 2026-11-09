import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Intro sources in the order they should be tried.
///
/// The MP4 is the primary intro clip everywhere. The WebM is kept as a
/// fallback for Chromium builds compiled without proprietary codecs
/// (Electron / in-app preview panels) that cannot decode H.264 + AAC.
const List<String> introVideoAssets = <String>[
  'assets/videos/video_1083905.mp4',
  'assets/videos/loading.mp4',
  'assets/videos/loading.webm',
];

/// Returns the first controller that actually initialises.
///
/// Sources are tried in [introVideoAssets] order so the primary clip (the
/// MP4) always plays when it is decodable. Each source gets a short timeout
/// so a broken or unsupported codec falls through to the next one quickly
/// instead of leaving the logo on screen.
Future<VideoPlayerController> initializeIntroVideo() async {
  final disposed = <VideoPlayerController>{};

  Future<void> disposeOnce(VideoPlayerController controller) async {
    if (!disposed.add(controller)) return;
    try {
      await controller.dispose().timeout(const Duration(milliseconds: 500));
    } catch (_) {
      // Best effort: an unresponsive platform view must not block the intro.
    }
  }

  Object? lastError;
  for (final asset in introVideoAssets) {
    final controller = VideoPlayerController.asset(asset);
    try {
      // 8 s is generous enough for a cold cache over a slow connection, while
      // a genuinely broken source still falls through to the next source.
      await controller.initialize().timeout(const Duration(seconds: 8));
      return controller;
    } catch (error) {
      lastError = error;
      await disposeOnce(controller);
    }
  }

  throw StateError('No playable intro video source ($lastError)');
}

/// Clean in-app loading animation with progress indicator.
/// Does not load the intro video so background/in-app loading remains fast and lightweight.
class LoadingAnimation extends StatelessWidget {
  const LoadingAnimation({super.key, this.child});

  /// Optional foreground content rendered below or inside the indicator.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(strokeWidth: 2.5),
          if (child != null) ...[
            const SizedBox(height: 12),
            child!,
          ],
        ],
      ),
    );
  }
}
