import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../core/ui/ui.dart';

const fabGlyphColor = Colors.white;

class NavDestination {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final int badge;
  const NavDestination(this.label, this.icon, this.activeIcon, {this.badge = 0});
}

class NotchedNavBar extends StatelessWidget {
  final List<NavDestination> items;
  final int current;
  final ValueChanged<int> onSelect;
  final VoidCallback onFab;
  final bool fabOpen;
  final bool hidden;

  const NotchedNavBar({
    super.key,
    required this.items,
    required this.current,
    required this.onSelect,
    required this.onFab,
    required this.fabOpen,
    this.hidden = false,
  }) : assert(items.length == 4);

  static const double fabSize = 60;
  static const double fabRise = 28;

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.viewPaddingOf(context).bottom;
    final height = AppSpace.bottomBar + safe;
    return AnimatedSlide(
      offset: hidden ? const Offset(0, 1.4) : Offset.zero,
      duration: AppMotion.barHide,
      curve: Curves.easeOut,
      child: RepaintBoundary(
        child: Align(
          alignment: Alignment.bottomCenter,
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSpace.maxBar),
            child: SizedBox(
              height: height + fabRise,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: height,
                    child: const CustomPaint(painter: _BarShadowPainter()),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: height,
                    child: ClipPath(
                      clipper: _NotchClipper(),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(
                          sigmaX: AppBlur.nav,
                          sigmaY: AppBlur.nav,
                        ),
                        child: CustomPaint(
                          painter: NotchedBarPainter(
                            fill: AppColors.surface.withValues(alpha: 0.94),
                            border: AppColors.white(0.08),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: safe,
                    height: AppSpace.bottomBar,
                    child: Row(
                      children: [
                        for (var i = 0; i < 4; i++) ...[
                          if (i == 2) const Expanded(child: SizedBox()),
                          Expanded(
                            child: _NavItem(
                              item: items[i],
                              active: i == current,
                              onTap: () => onSelect(i),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: CenterFab(open: fabOpen, onTap: onFab),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class NotchedBarPainter extends CustomPainter {
  NotchedBarPainter({required this.fill, required this.border});

  final Color fill;
  final Color border;

  static Path buildPath(Size size) {
    const corner = 28.0;
    const depth = 38.0;
    const half = 64.0;
    final cx = size.width / 2;

    return Path()
      ..moveTo(0, corner)
      ..quadraticBezierTo(0, 0, corner, 0)
      ..lineTo(cx - half, 0)
      ..cubicTo(cx - 40, 0, cx - 38, depth, cx, depth)
      ..cubicTo(cx + 38, depth, cx + 40, 0, cx + half, 0)
      ..lineTo(size.width - corner, 0)
      ..quadraticBezierTo(size.width, 0, size.width, corner)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = buildPath(size);
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = border,
    );
  }

  @override
  bool shouldRepaint(covariant NotchedBarPainter oldDelegate) =>
      oldDelegate.fill != fill || oldDelegate.border != border;
}

class _BarShadowPainter extends CustomPainter {
  const _BarShadowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = NotchedBarPainter.buildPath(size);
    canvas.drawShadow(path.shift(const Offset(0, -8)), AppColors.black(0.45), 16, false);
  }

  @override
  bool shouldRepaint(covariant _BarShadowPainter oldDelegate) => false;
}

class _NotchClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => NotchedBarPainter.buildPath(size);

  @override
  bool shouldReclip(covariant _NotchClipper oldClipper) => false;
}

class _NavItem extends StatefulWidget {
  final NavDestination item;
  final bool active;
  final VoidCallback onTap;
  const _NavItem({
    required this.item,
    required this.active,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> with SingleTickerProviderStateMixin {
  late final controller = AnimationController(
    vsync: this,
    duration: AppMotion.navRise,
    reverseDuration: AppMotion.navFall,
    value: widget.active ? 1 : 0,
  );

  static final scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1, end: 1.12), weight: 60),
    TweenSequenceItem(tween: Tween(begin: 1.12, end: 1.08), weight: 40),
  ]);

  @override
  void didUpdateWidget(covariant _NavItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active != oldWidget.active) {
      if (AppMotion.reduced(context)) {
        controller.value = widget.active ? 1 : 0;
      } else if (widget.active) {
        controller.forward();
      } else {
        controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Semantics(
      button: true,
      selected: widget.active,
      label: item.badge > 0 ? '${item.label}, ${item.badge} new' : item.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          haptic(HapticKind.light);
          widget.onTap();
        },
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final v = controller.value;
            final rise = Curves.easeOutCubic.transform(v);
            final color = Color.lerp(AppColors.slate400, AppColors.amber400, v)!;
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Transform.translate(
                  offset: Offset(0, -4 * rise),
                  child: Transform.scale(
                    scale: controller.status == AnimationStatus.reverse
                        ? 1 + 0.08 * v
                        : scale.transform(v),
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        if (v > 0)
                          Opacity(
                            opacity: v,
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.amber(0.3),
                                    blurRadius: 12,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        Icon(
                          widget.active ? item.activeIcon : item.icon,
                          size: 24,
                          color: color,
                        ),
                        if (item.badge > 0)
                          Positioned(
                            top: -6,
                            right: -10,
                            child: CountBadge(
                              count: item.badge,
                              ring: AppColors.surface,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 15,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      item.label,
                      style: AppText.tiny.copyWith(
                        fontSize: 11,
                        letterSpacing: 0.1,
                        color: color,
                        fontWeight: widget.active ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class CenterFab extends StatefulWidget {
  final bool open;
  final VoidCallback onTap;
  const CenterFab({super.key, required this.open, required this.onTap});

  @override
  State<CenterFab> createState() => _CenterFabState();
}

class _CenterFabState extends State<CenterFab> with TickerProviderStateMixin {
  late final bounce = AnimationController.unbounded(vsync: this, value: 1);
  late final rings = AnimationController(vsync: this, duration: AppMotion.fabGlow + const Duration(milliseconds: 120));
  bool holding = false;

  static const spring = SpringDescription(mass: 1, stiffness: 420, damping: 14);

  @override
  void dispose() {
    bounce.dispose();
    rings.dispose();
    super.dispose();
  }

  void down() {
    setState(() => holding = true);
    if (AppMotion.reduced(context)) return;
    bounce.animateTo(0.88, duration: const Duration(milliseconds: 90), curve: Curves.easeOut);
  }

  void release() {
    setState(() => holding = false);
    if (AppMotion.reduced(context)) {
      bounce.value = 1;
      return;
    }
    bounce.animateWith(SpringSimulation(spring, bounce.value, 1, 0));
  }

  @override
  Widget build(BuildContext context) {
    const size = NotchedNavBar.fabSize;
    final reduced = AppMotion.reduced(context);
    return Semantics(
      button: true,
      label: 'Quick actions',
      expanded: widget.open,
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: (_) => down(),
        onTapCancel: release,
        onTapUp: (_) => release(),
        onTap: () {
          haptic(HapticKind.medium);
          if (!reduced) rings.forward(from: 0);
          widget.onTap();
        },
        child: SizedBox(
          width: 140,
          height: size + 16,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              if (!reduced)
                AnimatedBuilder(
                  animation: rings,
                  builder: (_, _) => Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      for (final delay in [0.0, 120.0])
                        Builder(
                          builder: (_) {
                            final total = rings.duration!.inMilliseconds.toDouble();
                            final t = ((rings.value * total - delay) / AppMotion.fabGlow.inMilliseconds)
                                .clamp(0.0, 1.0);
                            if (t <= 0 || t >= 1) return const SizedBox(width: size, height: size);
                            final e = Curves.easeOut.transform(t);
                            final r = 32 + (68 - 32) * e;
                            return SizedBox(
                              width: size,
                              height: size,
                              child: OverflowBox(
                                maxWidth: r * 2,
                                maxHeight: r * 2,
                                child: Container(
                                  width: r * 2,
                                  height: r * 2,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.amber400.withValues(alpha: 0.45 * (1 - e)),
                                      width: 2,
                                    ),
                                    color: AppColors.amber400.withValues(alpha: 0.12 * (1 - e)),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              AnimatedBuilder(
                animation: bounce,
                builder: (_, child) => Transform.scale(scale: bounce.value, child: child),
                child: AnimatedContainer(
                  duration: AppMotion.buttonPress,
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppGradients.fab,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.amber(holding ? 0.35 : 0.45),
                        blurRadius: holding ? 32 : 24,
                        spreadRadius: holding ? 6 : 0,
                      ),
                      BoxShadow(
                        color: AppColors.black(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.center,
                        colors: [AppColors.white(0.18), AppColors.white(0)],
                      ),
                    ),
                    child: AnimatedRotation(
                      turns: widget.open ? 0.25 : 0,
                      duration: reduced ? Duration.zero : AppMotion.rotate,
                      curve: Curves.easeOut,
                      child: Icon(
                        Icons.grid_view_rounded,
                        size: 26,
                        color: fabGlyphColor,
                        shadows: [Shadow(color: AppColors.black(0.25), blurRadius: 6)],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
