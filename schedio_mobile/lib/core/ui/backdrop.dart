import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class AmbientBackdrop extends StatelessWidget {
  final bool dim;
  const AmbientBackdrop({super.key, this.dim = false});

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: IgnorePointer(
      child: RepaintBoundary(
        child: Stack(
          fit: StackFit.expand,
          children: [
            const CustomPaint(painter: _AmbientPainter()),
            if (dim)
              BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                child: ColoredBox(color: AppColors.bgBase.withValues(alpha: 0.6)),
              ),
          ],
        ),
      ),
    ),
  );
}

class _AmbientPainter extends CustomPainter {
  const _AmbientPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.bgBase);

    void blob(Color color, double opacity, Rect rect, double sigma) {
      canvas.drawOval(
        rect,
        Paint()
          ..color = color.withValues(alpha: opacity)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma),
      );
    }

    blob(
      const Color(0xFF3D3028),
      0.85,
      Rect.fromLTWH(-w * 0.35, -h * 0.08, w * 0.95, h * 0.32),
      48,
    );
    blob(
      const Color(0xFF24282F),
      0.9,
      Rect.fromLTWH(w * 0.45, -h * 0.05, w * 0.8, h * 0.26),
      52,
    );
    blob(
      const Color(0xFF2E2520),
      0.75,
      Rect.fromLTWH(w * 0.1, h * 0.42, w * 0.9, h * 0.22),
      60,
    );
    blob(
      const Color(0xFF2B2F38),
      0.7,
      Rect.fromLTWH(-w * 0.25, h * 0.7, w * 0.85, h * 0.3),
      56,
    );
    blob(
      const Color(0xFF47382E),
      0.55,
      Rect.fromLTWH(w * 0.72, h * 0.3, w * 0.18, w * 0.14),
      18,
    );
    blob(
      const Color(0xFF3A2C32),
      0.5,
      Rect.fromLTWH(w * 0.06, h * 0.33, w * 0.14, w * 0.1),
      16,
    );
    blob(
      const Color(0xFF362C25),
      0.55,
      Rect.fromLTWH(w * 0.62, h * 0.83, w * 0.2, w * 0.14),
      18,
    );

    void contour(Color color, double width, double y, double amp, double phase) {
      final path = Path()..moveTo(-20, h * y);
      path.cubicTo(
        w * (0.25 + phase),
        h * (y - amp),
        w * (0.55 - phase),
        h * (y + amp),
        w + 20,
        h * (y - amp * 0.4),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round
          ..color = color,
      );
    }

    final gold = AppColors.gold.withValues(alpha: 0.2);
    final mist = AppColors.slate200.withValues(alpha: 0.11);
    final ash = const Color(0xFF7A808C).withValues(alpha: 0.25);
    contour(gold, 1.6, 0.14, 0.06, 0.04);
    contour(mist, 1.2, 0.17, 0.05, 0.08);
    contour(ash, 1.2, 0.2, 0.07, 0.02);
    contour(gold, 1.4, 0.56, 0.05, 0.1);
    contour(mist, 1.2, 0.6, 0.06, 0.05);
    contour(gold, 2, 0.88, 0.05, 0.06);
    contour(ash, 1.2, 0.92, 0.04, 0.12);

    void glow(Offset center, double radius, Color color, double opacity) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = ui.Gradient.radial(center, radius, [
            color.withValues(alpha: opacity),
            color.withValues(alpha: 0),
          ]),
      );
    }

    glow(Offset(w * 1.02, -h * 0.02), w * 0.95, AppColors.amber500, 0.13);
    glow(Offset(-w * 0.05, h * 1.0), w * 1.0, AppColors.blue500, 0.1);
  }

  @override
  bool shouldRepaint(covariant _AmbientPainter oldDelegate) => false;
}
