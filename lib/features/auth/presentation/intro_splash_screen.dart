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
  bool _videoFailed = false;
  bool _loadingVideo = false;
  bool _soundOn = false;
  Timer? _watchdog;
  final DateTime _startedAt = DateTime.now();

  void _checkDeadline() {
    if (!_finished &&
        DateTime.now().difference(_startedAt) > const Duration(seconds: 20)) {
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
    _watchdog = Timer(const Duration(seconds: 20), _finish);
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
        ..setVolume(0) // Always start muted — browser autoplay policy requires it
        ..addListener(_handleVideoUpdate);

      await controller.play();
      if (!mounted) return;
      _loadingVideo = false;
      setState(() {});

      // Give the player 700 ms to confirm it started.
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      if (!controller.value.hasError && !controller.value.isPlaying) {
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

  void _handleVideoUpdate() {
    final controller = _controller;
    if (controller == null) return;
    if (controller.value.hasError) {
      Future<void>.delayed(const Duration(milliseconds: 900), _finish);
      return;
    }
    if (controller.value.isCompleted) _finish();
  }

  void _toggleSound() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    setState(() => _soundOn = !_soundOn);
    controller.setVolume(_soundOn ? 1.0 : 0);
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

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final hasVideo =
        controller != null && controller.value.isInitialized && !_videoFailed;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _finish,
        child: LayoutBuilder(
          builder: (context, outer) {
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

                    // Sound toggle — top right, only shown when video is playing
                    if (hasVideo)
                      Positioned(
                        top: 16,
                        right: 16,
                        child: SafeArea(
                          child: GestureDetector(
                            // Prevent tap bubbling to the full-screen skip handler
                            onTap: () {
                              _toggleSound();
                            },
                            behavior: HitTestBehavior.opaque,
                            child: FilledButton.tonalIcon(
                              onPressed: _toggleSound,
                              style: FilledButton.styleFrom(
                                backgroundColor:
                                    Colors.black.withValues(alpha: 0.55),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              icon: Icon(
                                _soundOn
                                    ? Icons.volume_up_rounded
                                    : Icons.volume_off_rounded,
                                size: 18,
                              ),
                              label: Text(
                                _soundOn ? 'Sound on' : 'Sound off',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Skip intro — bottom centre
                    Positioned(
                      bottom: 20,
                      left: 16,
                      right: 16,
                      child: SafeArea(
                        child: Center(
                          child: TextButton(
                            onPressed: _finish,
                            style: TextButton.styleFrom(
                              foregroundColor:
                                  Colors.white.withValues(alpha: 0.9),
                              backgroundColor:
                                  Colors.black.withValues(alpha: 0.35),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                            ),
                            child: const Text('Skip intro'),
                          ),
                        ),
                      ),
                    ),
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
