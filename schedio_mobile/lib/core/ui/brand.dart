import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'pills.dart';

class BrandLogo extends StatelessWidget {
  final double size;
  const BrandLogo({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Schedio',
    image: true,
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: [
          BoxShadow(
            color: AppColors.amber(0.45),
            blurRadius: size * 0.4,
            spreadRadius: -size * 0.12,
            offset: Offset(0, size * 0.08),
          ),
        ],
      ),
      child: CustomPaint(painter: _LogoPainter()),
    ),
  );
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 44;
    canvas.save();
    canvas.scale(s);
    canvas.translate(-2, -2);
    final rect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(2, 2, 44, 44),
      const Radius.circular(12),
    );
    canvas.drawRRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          const Offset(48, 48),
          const [Color(0xFF262A34), Color(0xFF14171E), Color(0xFF0B0D11)],
          const [0, 0.5, 1],
        ),
    );
    canvas.drawCircle(
      const Offset(20, 18),
      14,
      Paint()..color = AppColors.amber500.withValues(alpha: 0.16),
    );
    canvas.drawRRect(
      rect.deflate(0.65),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..shader = ui.Gradient.linear(
          Offset.zero,
          const Offset(48, 48),
          [
            const Color(0xFFFDE68A).withValues(alpha: 0.9),
            const Color(0xFFF59E0B).withValues(alpha: 0.6),
            Colors.white.withValues(alpha: 0.1),
            const Color(0xFFB45309).withValues(alpha: 0.4),
          ],
          const [0, 0.35, 0.65, 1],
        ),
    );
    final ribbon = Path()
      ..moveTo(34, 15.2)
      ..cubicTo(34, 12.3, 31.2, 11, 26.5, 11)
      ..lineTo(19, 11)
      ..cubicTo(14.8, 11, 12.5, 13.5, 12.5, 17.2)
      ..cubicTo(12.5, 20.8, 15.2, 22.5, 20, 23.8)
      ..lineTo(24.8, 25.1)
      ..cubicTo(28.5, 26.1, 30.5, 27.6, 30.5, 30.6)
      ..cubicTo(30.5, 34, 27.8, 35.8, 23.5, 35.8)
      ..lineTo(15.5, 35.8)
      ..cubicTo(12.8, 35.8, 11.2, 34.2, 10.8, 32.2);
    canvas.drawPath(
      ribbon,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..shader = ui.Gradient.linear(
          const Offset(12, 10),
          const Offset(36, 38),
          const [
            Color(0xFFFFFDF5),
            Color(0xFFFDE68A),
            Color(0xFFF59E0B),
            Color(0xFFD97706),
          ],
          const [0, 0.3, 0.7, 1],
        ),
    );
    canvas.drawCircle(
      const Offset(34, 15.2),
      2.2,
      Paint()..color = const Color(0xFFFFFDF5),
    );
    canvas.drawCircle(
      const Offset(10.8, 32.2),
      2.2,
      Paint()..color = AppColors.amber400,
    );
    canvas.drawCircle(
      const Offset(22.4, 24.4),
      1.6,
      Paint()..color = const Color(0xFFFFFBEB),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LogoPainter oldDelegate) => false;
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
            Text(
              'Schedio',
              style: AppText.cardTitle.copyWith(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                height: 1.1,
              ),
            ),
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
