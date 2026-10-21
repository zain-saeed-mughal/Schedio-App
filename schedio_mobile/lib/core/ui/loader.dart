import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'brand.dart';

class SchedioLoadingIndicator extends StatefulWidget {
  final double size;
  final bool isLoading;
  final String? semanticsLabel;

  const SchedioLoadingIndicator({
    super.key,
    this.size = 70,
    this.isLoading = true,
    this.semanticsLabel = 'Loading',
  });

  static const cycle = Duration(milliseconds: 2000);

  @override
  State<SchedioLoadingIndicator> createState() => _SchedioLoadingIndicatorState();
}

class _SchedioLoadingIndicatorState extends State<SchedioLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final controller = AnimationController(vsync: this, duration: SchedioLoadingIndicator.cycle);
  bool animate = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    sync();
  }

  @override
  void didUpdateWidget(covariant SchedioLoadingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isLoading != widget.isLoading) sync();
  }

  void sync() {
    animate = widget.isLoading && AppMotion.looping(context);
    if (animate) {
      if (!controller.isAnimating) controller.repeat();
    } else {
      controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isLoading) return const SizedBox.shrink();
    final size = widget.size;
    final logoSize = size * 0.72;
    final logo = Image.asset(
      brandMarkAsset,
      width: logoSize,
      height: logoSize,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      excludeFromSemantics: true,
    );
    return Semantics(
      label: widget.semanticsLabel,
      liveRegion: true,
      child: RepaintBoundary(
        child: SizedBox.square(
          dimension: size,
          child: animate
              ? ClipRect(
                  child: AnimatedBuilder(
                    animation: controller,
                    builder: (context, _) => _Frame(
                      t: controller.value,
                      size: size,
                      logoSize: logoSize,
                      logo: logo,
                    ),
                  ),
                )
              : Center(child: logo),
        ),
      ),
    );
  }
}

double _interval(double t, double begin, double end, [Curve curve = Curves.linear]) =>
    curve.transform(((t - begin) / (end - begin)).clamp(0.0, 1.0));

const _crack = [
  Offset(0.50, 0.04),
  Offset(0.47, 0.17),
  Offset(0.535, 0.30),
  Offset(0.475, 0.43),
  Offset(0.53, 0.56),
  Offset(0.465, 0.69),
  Offset(0.525, 0.82),
  Offset(0.49, 0.97),
];

class _Frame extends StatelessWidget {
  final double t;
  final double size;
  final double logoSize;
  final Widget logo;
  const _Frame({required this.t, required this.size, required this.logoSize, required this.logo});

  @override
  Widget build(BuildContext context) {
    final split = _interval(t, 0.40, 0.85, Curves.easeOutCubic);
    final fragmentsFade = 1 - _interval(t, 0.46, 0.76, Curves.easeIn);
    final reveal = _interval(t, 0.40, 0.66, Curves.easeOut);
    final settle = _interval(t, 0.40, 0.95, Curves.easeOutBack);
    final pulse = math.sin(_interval(t, 0.85, 1.0) * math.pi);
    final broken = t >= 0.40;
    final dx = size * 0.20 * split;
    final dy = size * 0.035 * split;
    final angle = 0.17 * split;

    Widget piece(bool left) => Transform(
      alignment: Alignment.center,
      transform: Matrix4.translationValues(left ? -dx : dx, dy, 0)
        ..rotateZ(left ? -angle : angle)
        ..scaleByDouble(1 - 0.12 * split, 1 - 0.12 * split, 1, 1),
      child: Opacity(
        opacity: fragmentsFade,
        child: ClipPath(clipper: _HalfClipper(left), child: logo),
      ),
    );

    return Stack(
      alignment: Alignment.center,
      children: [
        if (broken)
          Opacity(
            opacity: reveal,
            child: Transform.scale(scale: 0.84 + 0.16 * settle + 0.02 * pulse, child: logo),
          ),
        if (!broken) logo else ...[piece(true), piece(false)],
        IgnorePointer(
          child: CustomPaint(
            size: Size.square(size),
            painter: _CrackPainter(t: t, logoSize: logoSize),
          ),
        ),
      ],
    );
  }
}

class _HalfClipper extends CustomClipper<Path> {
  final bool left;
  const _HalfClipper(this.left);

  @override
  Path getClip(Size size) {
    final points = [for (final p in _crack) Offset(p.dx * size.width, p.dy * size.height)];
    final path = Path();
    if (left) {
      path
        ..moveTo(0, 0)
        ..lineTo(points.first.dx, 0);
      for (final p in points) {
        path.lineTo(p.dx, p.dy);
      }
      path
        ..lineTo(points.last.dx, size.height)
        ..lineTo(0, size.height);
    } else {
      path
        ..moveTo(size.width, 0)
        ..lineTo(points.first.dx, 0);
      for (final p in points) {
        path.lineTo(p.dx, p.dy);
      }
      path
        ..lineTo(points.last.dx, size.height)
        ..lineTo(size.width, size.height);
    }
    return path..close();
  }

  @override
  bool shouldReclip(covariant _HalfClipper oldClipper) => oldClipper.left != left;
}

class _Particle {
  final double along, angle, speed, radius, spin;
  final bool shard;
  const _Particle(this.along, this.angle, this.speed, this.radius, this.spin, this.shard);
}

final _particles = () {
  final random = math.Random(7);
  return List.generate(16, (i) {
    final side = i.isEven ? 0.0 : math.pi;
    return _Particle(
      0.1 + random.nextDouble() * 0.8,
      side + (random.nextDouble() - 0.5) * 1.6,
      0.35 + random.nextDouble() * 0.55,
      0.010 + random.nextDouble() * 0.016,
      (random.nextDouble() - 0.5) * 6,
      i % 4 == 0,
    );
  });
}();

class _CrackPainter extends CustomPainter {
  final double t;
  final double logoSize;
  const _CrackPainter({required this.t, required this.logoSize});

  Offset _point(Size size, Offset normalized) {
    final origin = (size.width - logoSize) / 2;
    return Offset(origin + normalized.dx * logoSize, origin + normalized.dy * logoSize);
  }

  Offset _along(Size size, double f) {
    final scaled = f * (_crack.length - 1);
    final i = scaled.floor().clamp(0, _crack.length - 2);
    final local = scaled - i;
    return Offset.lerp(_point(size, _crack[i]), _point(size, _crack[i + 1]), local)!;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final grow = _interval(t, 0.15, 0.40, Curves.easeInOut);
    final glowFade = 1 - _interval(t, 0.38, 0.50, Curves.easeOut);
    if (grow > 0 && glowFade > 0) {
      final path = Path()..moveTo(_point(size, _crack.first).dx, _point(size, _crack.first).dy);
      final reach = grow * (_crack.length - 1);
      for (var i = 1; i < _crack.length; i++) {
        if (i <= reach) {
          final p = _point(size, _crack[i]);
          path.lineTo(p.dx, p.dy);
        } else {
          final tip = _along(size, reach / (_crack.length - 1));
          path.lineTo(tip.dx, tip.dy);
          break;
        }
      }
      final stroke = logoSize * 0.022;
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke * 4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = AppColors.amber500.withValues(alpha: 0.45 * glowFade)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, stroke * 2.2),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..shader = ui.Gradient.linear(
            _point(size, _crack.first),
            _point(size, _crack.last),
            [
              const Color(0xFFFFFDF5).withValues(alpha: glowFade),
              AppColors.amber200.withValues(alpha: glowFade),
              AppColors.amber400.withValues(alpha: glowFade),
            ],
            const [0, 0.5, 1],
          ),
      );
      if (grow < 1) {
        final tip = _along(size, grow);
        canvas.drawCircle(
          tip,
          stroke * 1.6,
          Paint()
            ..color = const Color(0xFFFFFDF5).withValues(alpha: 0.9)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, stroke),
        );
      }
    }

    final burst = _interval(t, 0.38, 0.85);
    if (burst <= 0 || burst >= 1) return;
    final travel = Curves.easeOutCubic.transform(burst);
    final fade = 1 - Curves.easeIn.transform(burst);
    for (final p in _particles) {
      final start = _along(size, p.along);
      final distance = logoSize * 0.42 * p.speed * travel;
      final position = start +
          Offset(math.cos(p.angle) * distance, math.sin(p.angle) * distance + logoSize * 0.06 * burst * burst);
      final radius = logoSize * p.radius * (1 - 0.4 * burst);
      final paint = Paint()
        ..color = Color.lerp(AppColors.amber200, AppColors.amber500, p.along)!.withValues(alpha: fade);
      if (p.shard) {
        canvas.save();
        canvas.translate(position.dx, position.dy);
        canvas.rotate(p.spin * burst);
        final s = radius * 2.2;
        canvas.drawPath(
          Path()
            ..moveTo(0, -s)
            ..lineTo(s * 0.7, s * 0.6)
            ..lineTo(-s * 0.6, s * 0.4)
            ..close(),
          paint,
        );
        canvas.restore();
      } else {
        canvas.drawCircle(
          position,
          radius * 2.4,
          Paint()
            ..color = AppColors.amber500.withValues(alpha: 0.25 * fade)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 1.5),
        );
        canvas.drawCircle(position, radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CrackPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.logoSize != logoSize;
}
