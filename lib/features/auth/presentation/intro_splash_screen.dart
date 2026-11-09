import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kalla_lai/core/widgets/loading_animation.dart'
    show initializeIntroVideo;
import 'package:video_player/video_player.dart';

class IntroSplashScreen extends StatefulWidget {
  const IntroSplashScreen({required this.onFinished, super.key});

  final VoidCallback onFinished;

  @override
  State<IntroSplashScreen> createState() => _IntroSplashScreenState();
}

class _IntroSplashScreenState extends State<IntroSplashScreen>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _controller;
  bool _finished = false;
  bool _soundBlocked = false;
  bool _videoFailed = false;
  bool _loadingVideo = false;
  Timer? _watchdog;
  Timer? _autoFinishTimer;
  final DateTime _startedAt = DateTime.now();

  void _checkDeadline() {
    if (!_finished &&
        DateTime.now().difference(_startedAt) > const Duration(seconds: 16)) {
      _finish();
    }
  }

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  @override
  void initState() {
    super.initState();
    _pulse
      ..addListener(_checkDeadline)
      ..repeat(reverse: true);
    _watchdog = Timer(const Duration(seconds: 16), _finish);
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    if (_loadingVideo) return;
    _loadingVideo = true;
    _videoFailed = false;
    final previous = _controller;
    _controller = null;
    if (previous != null) {
      previous
        ..removeListener(_handleVideoUpdate)
        ..dispose();
    }
    if (mounted) setState(() {});
    try {
      final controller = await initializeIntroVideo();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      _controller = controller;
      controller
        ..setLooping(false)
        ..addListener(_handleVideoUpdate);
      // Start muted: browsers commonly reject autoplay with audio, while muted
      // playback is permitted. Sound can be enabled with the visible Sound
      // button or a tap after playback has started.
      await controller.setVolume(0);
      _soundBlocked = true;
      await controller.play();
      if (!mounted) return;
      _loadingVideo = false;
      setState(() {});

      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      if (!controller.value.hasError && !controller.value.isPlaying) {
        // Some browsers defer the first play() until a gesture. Keep the
        // fallback controls visible so the user can explicitly retry/skip.
        _videoFailed = true;
        _loadingVideo = false;
        setState(() {});
      }
    } catch (_) {
      if (!mounted) return;
      _loadingVideo = false;
      _videoFailed = true;
      setState(() {});
    }
  }

  Future<void> _enableSound() async {
    final controller = _controller;
    if (controller == null) return;
    try {
      await controller.setVolume(1.0);
      if (!controller.value.hasError && !controller.value.isPlaying) {
        await controller.play();
      }
      if (mounted) setState(() => _soundBlocked = false);
    } catch (_) {
      // Sound stays off; the intro continues either way.
    }
  }

  void _scheduleAutoFinish({required Duration after}) {
    _autoFinishTimer?.cancel();
    _autoFinishTimer = Timer(after, _finish);
  }

  void _handleVideoUpdate() {
    final controller = _controller;
    if (controller == null) return;
    if (controller.value.hasError) {
      _scheduleAutoFinish(after: const Duration(milliseconds: 900));
      return;
    }
    if (controller.value.isCompleted) _finish();
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    _watchdog?.cancel();
    _autoFinishTimer?.cancel();
    widget.onFinished();
  }

  @override
  void dispose() {
    _watchdog?.cancel();
    _autoFinishTimer?.cancel();
    _finished = true;
    _pulse.dispose();
    final controller = _controller;
    if (controller != null) {
      controller
        ..removeListener(_handleVideoUpdate)
        ..dispose();
    }
    super.dispose();
  }

  Widget _buildVideo(VideoPlayerController controller) {
    return ClipRect(
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: controller.value.size.width,
            height: controller.value.size.height,
            child: VideoPlayer(controller),
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackLogo(double logoWidth) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1.04).animate(
              CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: logoWidth, maxHeight: 180),
              child: Image(
                image: const AssetImage('assets/images/kalla_lai_logo.png'),
                fit: BoxFit.contain,
                width: logoWidth,
                semanticLabel: 'कल्ला-लाई',
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (_loadingVideo)
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (_videoFailed) ...[
            const Text('The intro video could not start.'),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _initializeVideo,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry video'),
            ),
          ],
          TextButton(onPressed: _finish, child: const Text('Skip intro')),
        ],
      ),
    );
  }

  Widget _buildSoundButton() {
    return Positioned(
      left: 12,
      bottom: 12,
      child: OutlinedButton.icon(
        onPressed: _enableSound,
        icon: const Icon(Icons.volume_up_outlined, size: 20),
        label: const Text('Sound'),
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.85),
          foregroundColor: Theme.of(context).colorScheme.primary,
          side: const BorderSide(color: Color(0xFFCBD5E1)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          minimumSize: const Size(0, 40),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final hasVideo =
        controller != null && controller.value.isInitialized && !_videoFailed;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (_soundBlocked) {
            _enableSound();
            return;
          }
          _finish();
        },
        child: LayoutBuilder(
          builder: (context, outer) {
            // Fill the whole viewport. The clip is a portrait 9:16 video drawn
            // with BoxFit.cover, so it reaches every edge instead of sitting
            // inside letterbox bands. On wide windows it is cropped to a
            // centred portrait band, which keeps the logo full height.
            final maxW = math.max(0.0, outer.maxWidth);
            final maxH = math.max(0.0, outer.maxHeight);
            final height = maxH;
            final width = math.min(maxW, height * 9 / 16);
            final logoWidth = math.max(80.0, math.min(width - 48, 320.0));

            return Center(
              child: SizedBox(
                width: width,
                height: height,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (hasVideo)
                      _buildVideo(controller)
                    else
                      _buildFallbackLogo(logoWidth),
                    if (_soundBlocked && hasVideo) _buildSoundButton(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
