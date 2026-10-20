import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/ui/ui.dart';

class AnimatedSplash extends StatefulWidget {
  final bool ready;
  final VoidCallback onFinished;
  const AnimatedSplash({
    super.key,
    required this.ready,
    required this.onFinished,
  });

  @override
  State<AnimatedSplash> createState() => _AnimatedSplashState();
}

class _AnimatedSplashState extends State<AnimatedSplash>
    with TickerProviderStateMixin {
  late final intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2100),
  );
  late final exit = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final breathe = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  bool started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (started) return;
    started = true;
    if (AppMotion.reduced(context)) intro.duration = const Duration(milliseconds: 500);
    intro.forward().whenComplete(() {
      if (!mounted) return;
      if (AppMotion.looping(context)) breathe.repeat(reverse: true);
      maybeExit();
    });
  }

  @override
  void didUpdateWidget(covariant AnimatedSplash oldWidget) {
    super.didUpdateWidget(oldWidget);
    maybeExit();
  }

  void maybeExit() {
    if (!widget.ready || !intro.isCompleted || exit.isAnimating || exit.isCompleted) return;
    breathe.stop();
    exit.forward().whenComplete(() {
      if (mounted) widget.onFinished();
    });
  }

  @override
  void dispose() {
    intro.dispose();
    exit.dispose();
    breathe.dispose();
    super.dispose();
  }

  double phase(double t, double from, double to, [Curve curve = AppMotion.signature]) =>
      curve.transform(((t - from) / (to - from)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final mark = (size.shortestSide * 0.36).clamp(110.0, 170.0);
    return AnimatedBuilder(
      animation: Listenable.merge([intro, exit, breathe]),
      builder: (context, _) {
        final t = intro.value;
        final out = Curves.easeIn.transform(exit.value);
        final appear = phase(t, 0, 0.42);
        final pop = phase(t, 0, 0.5, Curves.elasticOut);
        final ring = phase(t, 0.18, 0.62, Curves.easeOut);
        final sweep = phase(t, 0.3, 0.72, Curves.easeInOut);
        final letters = [
          for (var i = 0; i < 7; i++) phase(t, 0.42 + i * 0.045, 0.62 + i * 0.045),
        ];
        final tagline = phase(t, 0.72, 0.95);
        final pulse = breathe.isAnimating ? Curves.easeInOut.transform(breathe.value) : 0.0;
        return IgnorePointer(
          ignoring: exit.value > 0.6,
          child: Opacity(
            opacity: 1 - out,
            child: ColoredBox(
              color: AppColors.bgBase,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const AmbientBackdrop(),
                  Center(
                    child: Transform.scale(
                      scale: 1 + out * 0.06,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: mark * 2,
                            height: mark * 1.6,
                            child: Stack(
                              alignment: Alignment.center,
                              clipBehavior: Clip.none,
                              children: [
                                Opacity(
                                  opacity: (appear * (0.55 + 0.25 * pulse)).clamp(0.0, 1.0),
                                  child: ImageFiltered(
                                    imageFilter: ui.ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                                    child: Container(
                                      width: mark * (0.9 + 0.1 * pulse),
                                      height: mark * (0.9 + 0.1 * pulse),
                                      decoration: BoxDecoration(
                                        color: AppColors.amber(0.45),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                ),
                                if (ring > 0 && ring < 1)
                                  Opacity(
                                    opacity: 0.6 * (1 - ring),
                                    child: Container(
                                      width: mark * (0.8 + 0.9 * ring),
                                      height: mark * (0.8 + 0.9 * ring),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: AppColors.amber400,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                                Opacity(
                                  opacity: appear,
                                  child: Transform.rotate(
                                    angle: (1 - appear) * -math.pi / 14,
                                    child: Transform.scale(
                                      scale: 0.55 + 0.45 * pop + 0.02 * pulse,
                                      child: _Sheen(
                                        progress: sweep,
                                        child: BrandLogo(size: mark, glow: false),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SchedioWordmark(
                            fontSize: (mark * 0.26).clamp(28.0, 40.0),
                            letterProgress: letters,
                          ),
                          const SizedBox(height: 14),
                          Opacity(
                            opacity: tagline,
                            child: BrandTagline(
                              fontSize: 11,
                              spacing: 1.5 + 2.5 * tagline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: MediaQuery.viewPaddingOf(context).bottom + 48,
                    child: Opacity(
                      opacity: tagline * (widget.ready ? 0 : 1),
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Sheen extends StatelessWidget {
  final double progress;
  final Widget child;
  const _Sheen({required this.progress, required this.child});

  @override
  Widget build(BuildContext context) {
    if (progress <= 0 || progress >= 1) return child;
    return ShaderMask(
      blendMode: BlendMode.srcATop,
      shaderCallback: (rect) {
        final x = -rect.width + rect.width * 3 * progress;
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.55),
            Colors.white.withValues(alpha: 0),
          ],
          stops: const [0.35, 0.5, 0.65],
        ).createShader(Rect.fromLTWH(x, 0, rect.width, rect.height));
      },
      child: child,
    );
  }
}
