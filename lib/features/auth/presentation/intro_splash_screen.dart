import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kalla_lai/core/widgets/loading_animation.dart'
    show initializeIntroVideo;
import 'package:video_player/video_player.dart';

/// Plays the intro clip once, centred on a white page inside a thin black
/// frame, then hands over to [onFinished].
///
/// The clip *is* the intro: this screen never swaps it for a different
/// animation, and never cuts it short on a value it cannot trust.
/// `video_player` derives `isCompleted` from `position == duration`, which is
/// also true for the first moments of a freshly created player (both are
/// zero), so the clip's own end position is compared instead.
class IntroSplashScreen extends StatefulWidget {
  const IntroSplashScreen({required this.onFinished, super.key});

  final VoidCallback onFinished;

  @override
  State<IntroSplashScreen> createState() => _IntroSplashScreenState();
}

class _IntroSplashScreenState extends State<IntroSplashScreen> {
  /// How long a freshly started clip gets to prove it is running.
  static const Duration _startTimeout = Duration(milliseconds: 1500);

  /// How close to the last frame counts as "the clip finished".
  static const Duration _endTolerance = Duration(milliseconds: 150);

  /// Attempts on the *same* clip before the app takes over. Retrying the clip
  /// keeps the intro identical; anything else would be a second, unintended
  /// intro.
  static const int _maxAttempts = 6;

  /// Growing pause before each retry (index 0 is the pause after attempt 1).
  ///
  /// A start most often fails because of a momentary network or CDN hiccup, so
  /// backing off for a few seconds brings the clip up instead of skipping the
  /// intro. The last entry repeats for any remaining attempt, and
  /// [_hardDeadline] remains the absolute backstop.
  static const List<Duration> _retryDelays = <Duration>[
    Duration(milliseconds: 400),
    Duration(milliseconds: 700),
    Duration(milliseconds: 1000),
    Duration(milliseconds: 1500),
    Duration(milliseconds: 2000),
  ];

  /// Absolute backstop, so nothing here can strand the visitor on the intro.
  static const Duration _hardDeadline = Duration(seconds: 20);

  /// Frame shape used before the clip's first frame reaches the screen. It
  /// mirrors the shipped asset (`assets/videos/video_1083905.mp4`, which is
  /// 768x1344 portrait) so the black outline never jumps.
  static const Size _fallbackVideoSize = Size(768, 1344);

  VideoPlayerController? _controller;
  bool _finished = false;
  bool _starting = false;
  int _attempts = 0;
  Timer? _watchdog;

  @override
  void initState() {
    super.initState();
    _watchdog = Timer(_hardDeadline, _finish);
    unawaited(_start());
  }

  /// Starts the clip, retrying the same source when a start cannot be
  /// confirmed. Each attempt replaces the previous player, so a browser that
  /// killed the first one still gets the identical intro.
  Future<void> _start() async {
    if (_finished || _starting) return;
    _starting = true;
    _detachController();
    if (mounted) setState(() {});

    VideoPlayerController? controller;
    try {
      controller = await initializeIntroVideo();
    } catch (_) {
      controller = null;
    }
    if (!mounted || _finished) {
      await controller?.dispose();
      return;
    }
    if (controller == null) {
      _retryOrGiveUp();
      return;
    }

    _controller = controller;
    controller
      ..setLooping(false)
      ..addListener(_handleVideoUpdate);
    if (mounted) setState(() {});

    await _play(controller);
    if (!mounted || _finished || !identical(_controller, controller)) return;

    await Future<void>.delayed(_startTimeout);
    if (!mounted || _finished || !identical(_controller, controller)) return;

    // Confirmed only when the clip is genuinely running. `isPlaying` alone is
    // enough to know the browser accepted the play() call, and a position that
    // already moved proves frames are being produced.
    final value = controller.value;
    if (value.isPlaying || value.position > Duration.zero) {
      _starting = false;
      _attempts = 0;
      if (mounted) setState(() {});
      return;
    }
    _retryOrGiveUp();
  }

  Future<void> _play(VideoPlayerController controller) async {
    try {
      // Preferred path: the intro clip starts with its soundtrack.
      await controller.setVolume(1.0);
      await controller.play();
    } catch (_) {
      // Browsers refuse unmuted autoplay until the visitor interacts, so fall
      // back to muted playback and let the first tap or key press unmute it
      // (the GestureDetector below and web/index.html both do that). Unmuting
      // here instead would make Chrome pause the clip again and the intro
      // would look like it failed to start.
      try {
        await controller.setVolume(0);
        await controller.play();
      } catch (_) {}
    }
  }

  void _retryOrGiveUp() {
    _starting = false;
    if (_finished) return;
    _attempts++;
    if (_attempts >= _maxAttempts) {
      // Every attempt failed. Hand over to the app rather than showing some
      // other animation: the intro must only ever be the clip.
      _finish();
      return;
    }
    unawaited(Future<void>.delayed(_retryDelay(_attempts), _start));
  }

  /// Pause to take before attempt number [attempt] (1-based).
  static Duration _retryDelay(int attempt) {
    final index = attempt - 1;
    if (index >= _retryDelays.length) return _retryDelays.last;
    return _retryDelays[index];
  }

  void _handleVideoUpdate() {
    final controller = _controller;
    if (controller == null) return;
    final value = controller.value;
    if (value.hasError) {
      // Restart the same clip instead of ending the intro on the error: a
      // player that dies must not turn into a different intro or an early
      // jump into the app.
      unawaited(Future<void>.microtask(() => _restartAfterError(controller)));
      return;
    }
    final duration = value.duration;
    // `isCompleted` is `position == duration`, which is also true before the
    // clip has any metadata (both zero). Finishing on that is what skipped
    // the intro on a reload, so require real progress towards a real end.
    if (duration <= Duration.zero || value.position <= Duration.zero) return;
    if (value.isCompleted) {
      _finish();
      return;
    }
    if (duration - value.position <= _endTolerance) _finish();
  }

  /// Restarts the clip after its player died.
  ///
  /// [controller] is the player that reported the error, so a late callback
  /// from a player that has already been replaced cannot restart the intro on
  /// top of the clip that replaced it.
  void _restartAfterError(VideoPlayerController controller) {
    if (_finished || !identical(_controller, controller)) return;
    _detachController();
    _retryOrGiveUp();
  }

  void _detachController() {
    final controller = _controller;
    _controller = null;
    if (controller == null) return;
    controller
      ..removeListener(_handleVideoUpdate)
      ..dispose();
  }

  /// The first tap anywhere is the browser's cue to unlock sound.
  void _unmute() {
    final controller = _controller;
    if (controller == null) return;
    controller.setVolume(1.0);
    if (!controller.value.isPlaying && !controller.value.isCompleted) {
      controller.play();
    }
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    _watchdog?.cancel();
    widget.onFinished();
  }

  @override
  void dispose() {
    _watchdog?.cancel();
    _finished = true;
    _detachController();
    super.dispose();
  }

  /// Centres the clip on the white page inside a thin black frame.
  ///
  /// The frame keeps the clip's own aspect ratio and is held away from the
  /// page edges, so the clip's white borders no longer sit mid-screen where
  /// they read as a stray "dividing line" across the page.
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
                    child: controller == null
                        ? const SizedBox.shrink()
                        : VideoPlayer(controller),
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
          child: _buildFrame(videoSize: videoSize),
        ),
      ),
    );
  }
}
