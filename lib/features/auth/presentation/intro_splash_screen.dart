import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kalla_lai/core/widgets/loading_animation.dart'
    show initializeIntroVideo;
import 'package:video_player/video_player.dart';

/// Plays the intro clip once, centred on a white page inside a thin black
/// frame, then hands over to [onFinished].
class IntroSplashScreen extends StatefulWidget {
  const IntroSplashScreen({required this.onFinished, super.key});

  final VoidCallback onFinished;

  @override
  State<IntroSplashScreen> createState() => _IntroSplashScreenState();
}

class _IntroSplashScreenState extends State<IntroSplashScreen> {
  static const Duration _hardDeadline = Duration(seconds: 12);
  static const Size _fallbackVideoSize = Size(768, 1344);

  VideoPlayerController? _controller;
  bool _finished = false;
  bool _muted = false;
  Timer? _watchdog;

  @override
  void initState() {
    super.initState();
    _watchdog = Timer(_hardDeadline, _finish);
    unawaited(_loadAndPlay());
  }

  Future<void> _loadAndPlay() async {
    try {
      final controller = await initializeIntroVideo();
      if (!mounted || _finished) {
        await controller.dispose();
        return;
      }
      _controller = controller;
      controller
        ..setLooping(false)
        ..addListener(_handleVideoUpdate);
      if (mounted) setState(() {});

      // Preferred: start with sound.
      try {
        await controller.setVolume(1.0);
        await controller.play();
        _muted = false;
      } catch (_) {
        // Fall back to muted autoplay allowed by all browsers.
        try {
          await controller.setVolume(0);
          await controller.play();
          _muted = true;
        } catch (_) {}
      }
      if (mounted) setState(() {});
    } catch (_) {
      // If video asset cannot load, proceed to the next screen.
      _finish();
    }
  }

  void _handleVideoUpdate() {
    final controller = _controller;
    if (controller == null || _finished) return;
    final value = controller.value;
    if (value.hasError) {
      _finish();
      return;
    }
    final duration = value.duration;
    if (duration > Duration.zero && value.position >= duration - const Duration(milliseconds: 200)) {
      _finish();
      return;
    }
    if (value.isCompleted) {
      _finish();
    }
  }

  void _unmute() {
    final controller = _controller;
    if (controller == null) return;
    controller.setVolume(1.0);
    _muted = false;
    if (!controller.value.isPlaying && !controller.value.isCompleted) {
      controller.play();
    }
    if (mounted) setState(() {});
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    _watchdog?.cancel();
    _controller?.removeListener(_handleVideoUpdate);
    widget.onFinished();
  }

  @override
  void dispose() {
    _watchdog?.cancel();
    _finished = true;
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      controller.removeListener(_handleVideoUpdate);
      controller.dispose();
    }
    super.dispose();
  }

  Widget _buildFrame({Size? videoSize}) {
    final size = (videoSize == null || videoSize.isEmpty)
        ? _fallbackVideoSize
        : videoSize;
    final controller = _controller;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 740),
          child: AspectRatio(
            aspectRatio: size.width / size.height,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.black, width: 2),
              ),
              child: ClipRect(
                child: FittedBox(
                  fit: BoxFit.contain,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: size.width,
                    height: size.height,
                    child: controller != null && controller.value.isInitialized
                        ? VideoPlayer(controller)
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    Size? videoSize;
    if (controller != null && controller.value.isInitialized) {
      videoSize = controller.value.size;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _unmute,
        child: Container(
          color: Colors.white,
          width: double.infinity,
          height: double.infinity,
          child: Stack(
            children: [
              _buildFrame(videoSize: videoSize),
              if (_muted && controller != null && controller.value.isPlaying)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 18,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.volume_up_outlined, size: 16, color: Colors.black54),
                          SizedBox(width: 6),
                          Text(
                            'Tap anywhere for sound',
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
