import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'pills.dart';

const brandMarkAsset = 'assets/images/schedio-mark.png';

class BrandLogo extends StatelessWidget {
  final double size;
  final bool glow;
  const BrandLogo({super.key, this.size = 40, this.glow = true});

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Schedio',
    image: true,
    child: SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (glow)
            Container(
              width: size * 0.7,
              height: size * 0.7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.amber(0.35),
                    blurRadius: size * 0.45,
                    spreadRadius: size * 0.02,
                  ),
                ],
              ),
            ),
          Image.asset(
            brandMarkAsset,
            width: size,
            height: size,
            filterQuality: FilterQuality.high,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ],
      ),
    ),
  );
}

class SchedioWordmark extends StatelessWidget {
  final double fontSize;
  final List<double>? letterProgress;
  const SchedioWordmark({super.key, this.fontSize = 30, this.letterProgress});

  static const letters = ['S', 'C', 'H', 'E', 'D', 'I', 'O'];

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Schedio',
    child: ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < letters.length; i++)
            Builder(
              builder: (_) {
                final t = letterProgress?[i] ?? 1.0;
                return Opacity(
                  opacity: t.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(0, (1 - t) * fontSize * 0.5),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: fontSize * 0.11),
                      child: Text(
                        letters[i],
                        style: TextStyle(
                          fontFamily: AppText.sans,
                          fontSize: fontSize,
                          fontWeight: FontWeight.w700,
                          height: 1,
                          color: i == letters.length - 1
                              ? AppColors.amber500
                              : const Color(0xFFFAF7F0),
                          shadows: [
                            Shadow(
                              color: i == letters.length - 1
                                  ? AppColors.amber(0.55)
                                  : AppColors.black(0.5),
                              blurRadius: fontSize * 0.35,
                              offset: Offset(0, fontSize * 0.06),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    ),
  );
}

class BrandTagline extends StatelessWidget {
  final double fontSize;
  final double spacing;
  const BrandTagline({super.key, this.fontSize = 11, this.spacing = 4});

  @override
  Widget build(BuildContext context) => Text(
    'EVERY MOMENT, IN SYNC.',
    textAlign: TextAlign.center,
    style: TextStyle(
      fontFamily: AppText.sans,
      fontSize: fontSize,
      fontWeight: FontWeight.w500,
      letterSpacing: spacing,
      color: AppColors.slate200.withValues(alpha: 0.85),
    ),
  );
}

class BrandWordmark extends StatelessWidget {
  final String subtitle;
  final bool live;
  const BrandWordmark({super.key, required this.subtitle, this.live = true});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const BrandLogo(size: 36),
      const SizedBox(width: 10),
      Flexible(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SchedioWordmark(fontSize: 16),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (live) const LiveDot(size: 5),
                Flexible(
                  child: Text(
                    subtitle.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.monoTiny.copyWith(
                      color: AppColors.amber300.withValues(alpha: 0.9),
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  );
}

class GlassTileArt extends StatefulWidget {
  final double size;
  final IconData icon;
  final bool badge;
  final bool animate;
  const GlassTileArt({
    super.key,
    this.size = 96,
    this.icon = Icons.person_rounded,
    this.badge = true,
    this.animate = true,
  });

  @override
  State<GlassTileArt> createState() => _GlassTileArtState();
}

class _GlassTileArtState extends State<GlassTileArt>
    with SingleTickerProviderStateMixin {
  late final controller = AnimationController(
    vsync: this,
    duration: AppMotion.idleFloat,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.animate && AppMotion.looping(context)) {
      controller.repeat(reverse: true);
    } else {
      controller.stop();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final tile = s * 0.62;
    Widget layer(double dx, double dy, double opacity, {Widget? child}) =>
        Positioned(
          left: (s - tile) / 2 + dx,
          top: (s - tile) / 2 + dy,
          child: Transform.rotate(
            angle: -12 * math.pi / 180,
            child: Opacity(
              opacity: opacity,
              child: Container(
                width: tile,
                height: tile,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(tile * 0.29),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.blue500.withValues(alpha: 0.35),
                      AppColors.amber500.withValues(alpha: 0.45),
                    ],
                  ),
                  border: Border.all(color: AppColors.white(0.25)),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.black(0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(tile * 0.29),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.center,
                      colors: [AppColors.white(0.22), AppColors.white(0)],
                    ),
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        );

    final art = SizedBox(
      width: s,
      height: s,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: s * 0.22, sigmaY: s * 0.22),
              child: Center(
                child: Container(
                  width: s * 0.7,
                  height: s * 0.7,
                  decoration: BoxDecoration(
                    color: AppColors.amber(0.25),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
          layer(tile * 0.2, -tile * 0.14, 0.35),
          layer(tile * 0.1, -tile * 0.07, 0.6),
          layer(
            0,
            0,
            1,
            child: Center(
              child: Icon(
                widget.icon,
                size: tile * 0.5,
                color: AppColors.white(0.9),
                shadows: [
                  Shadow(color: AppColors.black(0.25), blurRadius: 8),
                ],
              ),
            ),
          ),
          if (widget.badge)
            Positioned(
              right: s * 0.12,
              bottom: s * 0.14,
              child: Container(
                width: s * 0.24,
                height: s * 0.24,
                decoration: BoxDecoration(
                  color: AppColors.amber400,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.bgBase, width: 2),
                  boxShadow: [
                    BoxShadow(color: AppColors.amber(0.5), blurRadius: 12),
                  ],
                ),
                child: Icon(
                  Icons.add_rounded,
                  size: s * 0.16,
                  color: AppColors.inkOnAmber,
                ),
              ),
            ),
        ],
      ),
    );

    return ExcludeSemantics(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: controller,
          child: art,
          builder: (_, child) => Transform.translate(
            offset: Offset(
              0,
              -4 + 8 * Curves.easeInOut.transform(controller.value),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
