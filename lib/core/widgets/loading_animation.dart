import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Intro sources in the order they should be tried.
///
/// The MP4 is the primary intro clip everywhere. The WebM is kept as a
/// fallback for Chromium builds compiled without proprietary codecs
/// (Electron / in-app preview panels) that cannot decode H.264 + AAC.
const List<String> introVideoAssets = <String>[
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

/// Full-surface loading animation backed by the looping intro clip.
/// Falls back to the standard Material progress indicator when no video
/// source can be decoded, so a slow or unsupported codec never traps the UI.
class LoadingAnimation extends StatefulWidget {
  const LoadingAnimation({super.key, this.child});

  /// Optional foreground content rendered above the animation.
  final Widget? child;

  @override
  State<LoadingAnimation> createState() => _LoadingAnimationState();
}

class _LoadingAnimationState extends State<LoadingAnimation> {
  VideoPlayerController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    initializeIntroVideo()
        .then((controller) async {
          if (!mounted) {
            await controller.dispose();
            return;
          }
          _controller = controller;
          await controller.setVolume(0);
          await controller.setLooping(true);
          await controller.play();
          if (mounted) setState(() {});
        })
        .catchError((Object _) {
          if (!mounted) return;
          setState(() => _failed = true);
        });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_failed || controller == null || !controller.value.isInitialized) {
      return SizedBox.expand(
        child: widget.child ??
            const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            ),
      );
    }

    return SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRect(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: controller.value.size.width,
                height: controller.value.size.height,
                child: VideoPlayer(controller),
              ),
            ),
          ),
          if (widget.child != null) Positioned.fill(child: widget.child!),
        ],
      ),
    );
  }
}
