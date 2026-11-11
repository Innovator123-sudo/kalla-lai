import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kalla_lai/core/theme/kalla_lai_theme.dart';
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
///
/// Playback starts muted, because every browser allows muted autoplay and
/// refuses an unmuted start until the visitor has interacted with the page.
/// The first tap turns the soundtrack on. If a browser refuses even the muted
/// start, the frame shows a "Tap to play" button instead of an outline that
/// never plays.
class IntroSplashScreen extends StatefulWidget {
  const IntroSplashScreen({required this.onFinished, super.key});

  final VoidCallback onFinished;

  @override
  State<IntroSplashScreen> createState() => _IntroSplashScreenState();
}

class _IntroSplashScreenState extends State<IntroSplashScreen> {
  /// How often a freshly started clip is checked, and how many checks it gets,
  /// before it counts as running.
  ///
  /// `play()` is not proof: on the web it resolves even when the browser
  /// refuses to start playback (the rejection arrives as an error *event*, not
  /// a thrown exception), and its `isPlaying` flag flips as soon as it is
  /// called. Only real movement of the clip's own position confirms that frames
  /// are being produced.
  static const Duration _progressCheckEvery = Duration(milliseconds: 250);
  static const int _progressChecks = 6;

  /// How close to the last frame counts as "the clip finished".
  static const Duration _endTolerance = Duration(milliseconds: 150);

  /// Attempts on the *same* clip before the frame asks for a tap. Retrying the
  /// clip keeps the intro identical; anything else would be a second,
  /// unintended intro.
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

  /// True once the clip is running with its soundtrack.
  bool _withSound = false;

  /// True when every automatic start was refused, which is what a browser's
  /// autoplay policy looks like from here. The frame then waits for the one
  /// tap that unlocks playback instead of sitting empty.
  bool _needsTap = false;

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
  ///
  /// [withSound] is only true once a tap has unlocked playback; every
  /// automatic attempt starts muted, because that is the one start browsers
  /// allow without a gesture.
  Future<void> _start({bool withSound = false}) async {
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

    final running = await _startAndConfirm(controller, withSound: withSound);
    if (!mounted || _finished || !identical(_controller, controller)) return;
    if (!running) {
      _retryOrGiveUp();
      return;
    }

    _starting = false;
    _attempts = 0;
    _needsTap = false;
    _withSound = withSound;
    if (mounted) setState(() {});
  }

  /// Plays [controller] and reports whether it is really running.
  ///
  /// A muted start is used unless [withSound] says a tap already unlocked the
  /// soundtrack: `setVolume(0)` also sets the element's `muted` attribute,
  /// which is exactly what autoplay policies check.
  Future<bool> _startAndConfirm(
    VideoPlayerController controller, {
    required bool withSound,
  }) async {
    try {
      await controller.setVolume(withSound ? 1.0 : 0);
      await controller.play();
    } catch (_) {
      return false;
    }

    for (var check = 0; check < _progressChecks; check++) {
      await Future<void>.delayed(_progressCheckEvery);
      if (!mounted || _finished || !identical(_controller, controller)) {
        return false;
      }
      final value = controller.value;
      if (value.hasError) return false;
      if (value.position > Duration.zero) return true;
    }
    return false;
  }

  void _retryOrGiveUp() {
    _starting = false;
    if (_finished) return;
    _attempts++;
    if (_attempts >= _maxAttempts) {
      // The clip stays on the frame and waits for the tap that unlocks
      // playback; [_hardDeadline] still hands over to the app, so nobody is
      // stranded on a still frame.
      _needsTap = true;
      if (mounted) setState(() {});
      return;
    }
    unawaited(Future<void>.delayed(_retryDelay(_attempts), () => _start()));
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
  ///
  /// On a frame that is waiting for a tap it also restarts the clip, this time
  /// with its soundtrack, because the tap itself is the gesture the browser
  /// was waiting for.
  void _unmute() {
    if (_needsTap) {
      _attempts = 0;
      _needsTap = false;
      unawaited(_start(withSound: true));
      return;
    }
    final controller = _controller;
    if (controller == null || _withSound) return;
    controller.setVolume(1.0);
    if (!controller.value.isPlaying && !controller.value.isCompleted) {
      controller.play();
    }
    setState(() => _withSound = true);
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
  ///
  /// A frame that could not start playback shows a "Tap to play" button in the
  /// same outline, so the visitor never reads an empty frame as a broken page.
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
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    FittedBox(
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
                    if (_needsTap)
                      Center(
                        child: FilledButton.icon(
                          onPressed: _unmute,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Tap to play'),
                        ),
                      ),
                  ],
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
    final showSoundHint = controller != null && !_withSound && !_needsTap;

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
              if (showSoundHint)
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 18,
                  child: Center(child: _SoundHint()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown while the clip is playing muted, which is how browsers start
/// autoplay. One tap anywhere turns the soundtrack on.
class _SoundHint extends StatelessWidget {
  const _SoundHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: KallaLaiColors.outline),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.volume_up_outlined, size: 16, color: KallaLaiColors.muted),
          SizedBox(width: 6),
          Text(
            'Tap for sound',
            style: TextStyle(
              color: KallaLaiColors.muted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
