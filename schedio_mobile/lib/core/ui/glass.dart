import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';

enum GlassTone { card, panel }

class GlassCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius radius;
  final GlassTone tone;
  final bool blur;
  final bool accentEdge;
  final bool sweep;
  final bool flare;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? borderColor;
  final Color? fill;
  final String? semanticLabel;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpace.cardPad),
    this.radius = AppRadii.cardAll,
    this.tone = GlassTone.card,
    this.blur = false,
    this.accentEdge = false,
    this.sweep = false,
    this.flare = false,
    this.onTap,
    this.onLongPress,
    this.borderColor,
    this.fill,
    this.semanticLabel,
  });

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard> {
  bool pressed = false;

  void setPressed(bool value) {
    if (widget.onTap == null && widget.onLongPress == null) return;
    if (pressed != value) setState(() => pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final panel = widget.tone == GlassTone.panel;
    final baseFill =
        widget.fill ??
        (widget.blur
            ? (panel ? AppColors.glassPanel : AppColors.glassCard)
            : AppColors.glassCardFlat.withValues(alpha: panel ? 0.92 : 0.86));
    final baseBorder =
        widget.borderColor ?? AppColors.white(panel ? 0.09 : 0.08);
    final interactive = widget.onTap != null || widget.onLongPress != null;

    Widget surface(double t) {
      final border = Color.lerp(baseBorder, AppColors.amber(0.4), t)!;
      final shadows = t > 0.01
          ? [
              for (var i = 0; i < AppShadows.cardLifted.length; i++)
                BoxShadow.lerp(
                  i < AppShadows.card.length
                      ? AppShadows.card[i]
                      : AppShadows.cardLifted[i].copyWith(
                          color: Colors.transparent,
                        ),
                  AppShadows.cardLifted[i],
                  t,
                )!,
            ]
          : (panel ? AppShadows.panel : AppShadows.card);
      Widget body = DecoratedBox(
        decoration: BoxDecoration(
          color: baseFill,
          borderRadius: widget.radius,
          border: Border.all(color: border),
          gradient: null,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: widget.radius,
            gradient: AppGradients.glassSheen,
          ),
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 24,
                right: 24,
                child: Container(height: 1, color: AppColors.white(0.06)),
              ),
              if (widget.accentEdge) ...[
                Positioned(
                  left: -60,
                  top: -60,
                  child: IgnorePointer(
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [AppColors.amber(0.18), AppColors.amber(0)],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 14,
                  bottom: 14,
                  child: Container(
                    width: 3.5,
                    decoration: BoxDecoration(
                      borderRadius: AppRadii.pill,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [AppColors.amber500, AppColors.amber(0)],
                      ),
                    ),
                  ),
                ),
              ],
              if (widget.sweep)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(painter: _SweepPainter()),
                  ),
                ),
              Padding(padding: widget.padding, child: widget.child),
            ],
          ),
        ),
      );
      body = ClipRRect(borderRadius: widget.radius, child: body);
      if (widget.blur) {
        body = ClipRRect(
          borderRadius: widget.radius,
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(
              sigmaX: panel ? AppBlur.panel : AppBlur.card,
              sigmaY: panel ? AppBlur.panel : AppBlur.card,
            ),
            child: body,
          ),
        );
      }
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: widget.radius,
          boxShadow: shadows,
        ),
        child: body,
      );
    }

    Widget content = interactive
        ? TweenAnimationBuilder<double>(
            tween: Tween(end: pressed ? 1 : 0),
            duration: AppMotion.reduced(context)
                ? Duration.zero
                : AppMotion.cardPress,
            curve: AppMotion.signature,
            builder: (context, t, _) => Transform.translate(
              offset: Offset(0, -2 * t),
              child: Transform.scale(scale: 1 - 0.015 * t, child: surface(t)),
            ),
          )
        : surface(0);

    if (widget.flare) {
      content = Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -34,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                  child: Container(
                    width: 190,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.amber(0.2),
                      borderRadius: AppRadii.pill,
                    ),
                  ),
                ),
              ),
            ),
          ),
          content,
        ],
      );
    }

    if (!interactive) return RepaintBoundary(child: content);

    return RepaintBoundary(
      child: Semantics(
        button: widget.onTap != null,
        label: widget.semanticLabel,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setPressed(true),
          onTapUp: (_) => setPressed(false),
          onTapCancel: () => setPressed(false),
          onTap: widget.onTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  widget.onTap!();
                },
          onLongPress: widget.onLongPress,
          child: content,
        ),
      ),
    );
  }
}

class _SweepPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(size.width * 0.45, 0, size.width * 0.55, size.height);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          rect.topLeft,
          rect.bottomRight,
          [
            Colors.transparent,
            AppColors.blue500.withValues(alpha: 0.14),
            AppColors.amber500.withValues(alpha: 0.08),
          ],
          [0, 0.6, 1],
        ),
    );
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = AppColors.gold.withValues(alpha: 0.16);
    for (var i = 0; i < 3; i++) {
      final y = size.height * (0.25 + i * 0.22);
      canvas.drawPath(
        Path()
          ..moveTo(size.width * 0.5, y + 12)
          ..cubicTo(
            size.width * 0.68,
            y - 18,
            size.width * 0.82,
            y + 26,
            size.width + 4,
            y - 6,
          ),
        line,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SweepPainter oldDelegate) => false;
}

class InsetWell extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius radius;
  final Color? fill;
  final Color? border;
  const InsetWell({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.radius = AppRadii.controlAll,
    this.fill,
    this.border,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: fill ?? AppColors.slate950.withValues(alpha: 0.6),
      borderRadius: radius,
      border: Border.all(color: border ?? AppColors.white(0.05)),
    ),
    child: child,
  );
}

class PressableRow extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? fill;
  final Color? border;
  final BorderRadius radius;
  const PressableRow({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.fill,
    this.border,
    this.radius = AppRadii.innerAll,
  });

  @override
  State<PressableRow> createState() => _PressableRowState();
}

class _PressableRowState extends State<PressableRow> {
  bool pressed = false;

  @override
  Widget build(BuildContext context) {
    final fill = widget.fill ?? AppColors.white(pressed ? 0.05 : 0.03);
    final border =
        widget.border ??
        (pressed ? AppColors.amber400.withValues(alpha: 0.3) : AppColors.white(0.06));
    return Semantics(
      button: widget.onTap != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.onTap == null ? null : (_) => setState(() => pressed = true),
        onTapUp: widget.onTap == null ? null : (_) => setState(() => pressed = false),
        onTapCancel: widget.onTap == null ? null : () => setState(() => pressed = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppMotion.buttonPress,
          curve: Curves.easeOut,
          padding: widget.padding,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: widget.radius,
            border: Border.all(color: border),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class IconTile extends StatelessWidget {
  final IconData icon;
  final Tint tint;
  final double size;
  final double iconSize;
  final BorderRadius radius;
  const IconTile({
    super.key,
    required this.icon,
    this.tint = Tint.warning,
    this.size = 40,
    this.iconSize = 20,
    this.radius = AppRadii.controlAll,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      borderRadius: radius,
      color: tint.fill,
      border: Border.all(color: tint.border),
    ),
    child: Icon(icon, size: iconSize, color: tint.text),
  );
}
