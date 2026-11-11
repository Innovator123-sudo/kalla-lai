import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kalla_lai/core/media/user_gesture.dart';
import 'package:kalla_lai/core/widgets/loading_animation.dart'
    show initializeIntroVideo;
import 'package:video_player/video_player.dart';

/// Plays the intro clip once, then hands over to [onFinished].
///
/// The clip is asked to play with sound as soon as it loads. Browsers refuse
/// sound until the visitor has interacted with the page, so when that happens
/// the clip keeps playing silently and sound comes on at the first tap, click
/// or key press. Nothing is shown to the visitor either way.
class IntroSplashScreen extends StatefulWidget {
  const IntroSplashScreen({required this.onFinished, super.key});

  final VoidCallback onFinished;

  /// The clip's own background colour, so the page shows no edge around it.
  static const Color backdrop = Color(0xFFEFEDEA);

  @override
  State<IntroSplashScreen> createState() => _IntroSplashScreenState();
}

class _IntroSplashScreenState extends State<IntroSplashScreen> {
  static const Duration _loadDeadline = Duration(seconds: 12);
  static const Duration _playbackGrace = Duration(seconds: 4);
  static const Duration _soundVerdictWindow = Duration(milliseconds: 600);
  static const Size _fallbackVideoSize = Size(768, 1344);

  VideoPlayerController? _controller;
  bool _finished = false;
  bool _awaitingSoundVerdict = false;
  Timer? _watchdog;
  Timer? _soundVerdict;
  void Function()? _stopGestureListener;

  @override
  void initState() {
    super.initState();
    _watchdog = Timer(_loadDeadline, _finish);
    _stopGestureListener = onUserGesture(_requestSound);
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
      controller.addListener(_handleVideoUpdate);
      _watchdog?.cancel();
      _watchdog = Timer(controller.value.duration + _playbackGrace, _finish);
      setState(() {});

      // A silent start is allowed everywhere, so the clip always plays.
      await controller.setLooping(false);
      await controller.setVolume(0);
      await controller.play();
      _requestSound();
    } catch (_) {
      // If video asset cannot load, proceed to the next screen.
      _finish();
    }
  }

  /// Switches sound on. A browser that does not allow it yet pauses the clip,
  /// which [_handleVideoUpdate] turns back into silent playback.
  void _requestSound() {
    final controller = _controller;
    if (controller == null || _finished) return;
    final value = controller.value;
    if (!value.isPlaying || value.volume > 0) return;
    _awaitingSoundVerdict = true;
    _soundVerdict?.cancel();
    _soundVerdict = Timer(_soundVerdictWindow, () {
      _awaitingSoundVerdict = false;
      _stopListeningForGestures();
    });
    unawaited(controller.setVolume(1.0));
  }

  void _resumeSilently(VideoPlayerController controller) {
    _awaitingSoundVerdict = false;
    _soundVerdict?.cancel();
    unawaited(controller.setVolume(0).then((_) => controller.play()));
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
    if (duration > Duration.zero &&
        value.position >= duration - const Duration(milliseconds: 200)) {
      _finish();
      return;
    }
    if (value.isCompleted) {
      _finish();
      return;
    }
    if (_awaitingSoundVerdict && !value.isPlaying) {
      _resumeSilently(controller);
    }
  }

  void _stopListeningForGestures() {
    _stopGestureListener?.call();
    _stopGestureListener = null;
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    _watchdog?.cancel();
    _soundVerdict?.cancel();
    _stopListeningForGestures();
    _controller?.removeListener(_handleVideoUpdate);
    widget.onFinished();
  }

  @override
  void dispose() {
    _watchdog?.cancel();
    _soundVerdict?.cancel();
    _stopListeningForGestures();
    _finished = true;
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      controller.removeListener(_handleVideoUpdate);
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final ready = controller != null && controller.value.isInitialized;
    final reported = ready ? controller.value.size : Size.zero;
    final size = reported.isEmpty ? _fallbackVideoSize : reported;

    return Scaffold(
      backgroundColor: IntroSplashScreen.backdrop,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 740),
          child: AspectRatio(
            aspectRatio: size.width / size.height,
            child: ready ? VideoPlayer(controller) : const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
