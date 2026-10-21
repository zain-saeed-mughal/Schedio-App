import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'buttons.dart';
import 'loader.dart';

OverlayEntry? _activeToast;

void showToast(BuildContext context, String message, {bool error = false}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  _activeToast?.remove();
  _activeToast = null;
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _Toast(
      message: message,
      error: error,
      onDone: () {
        if (_activeToast == entry) _activeToast = null;
        if (entry.mounted) entry.remove();
      },
    ),
  );
  _activeToast = entry;
  overlay.insert(entry);
}

class _Toast extends StatefulWidget {
  final String message;
  final bool error;
  final VoidCallback onDone;
  const _Toast({
    required this.message,
    required this.error,
    required this.onDone,
  });

  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with SingleTickerProviderStateMixin {
  late final controller = AnimationController(
    vsync: this,
    duration: AppMotion.toastIn,
    reverseDuration: AppMotion.toastOut,
  );
  Timer? timer;

  @override
  void initState() {
    super.initState();
    controller.forward();
    timer = Timer(AppMotion.toastDwell, dismiss);
  }

  Future<void> dismiss() async {
    timer?.cancel();
    if (!mounted) return;
    await controller.reverse();
    widget.onDone();
  }

  @override
  void dispose() {
    timer?.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.error;
    final bottom = MediaQuery.viewPaddingOf(context).bottom + 108;
    final curve = CurvedAnimation(
      parent: controller,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
    return Positioned(
      left: 16,
      right: 16,
      bottom: bottom,
      child: SafeArea(
        top: false,
        child: AnimatedBuilder(
          animation: curve,
          builder: (_, child) => Opacity(
            opacity: curve.value,
            child: Transform.translate(
              offset: Offset(0, 16 * (1 - curve.value)),
              child: Transform.scale(
                scale: 0.95 + 0.05 * curve.value,
                child: child,
              ),
            ),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Material(
                type: MaterialType.transparency,
                child: Semantics(
                  liveRegion: true,
                  child: ClipRRect(
                    borderRadius: AppRadii.innerAll,
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
                        decoration: BoxDecoration(
                          color: e
                              ? AppColors.rose950.withValues(alpha: 0.95)
                              : AppColors.cardSolid.withValues(alpha: 0.95),
                          borderRadius: AppRadii.innerAll,
                          border: Border.all(
                            color: e
                                ? AppColors.rose500.withValues(alpha: 0.4)
                                : AppColors.amber(0.4),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: e
                                  ? AppColors.rose500.withValues(alpha: 0.2)
                                  : AppColors.amber(0.2),
                              blurRadius: 24,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: e
                                    ? AppColors.rose500.withValues(alpha: 0.2)
                                    : AppColors.amber400.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                e
                                    ? Icons.error_outline_rounded
                                    : Icons.check_rounded,
                                size: 16,
                                color: e
                                    ? AppColors.rose300
                                    : AppColors.amber400,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                widget.message,
                                style: AppText.body.copyWith(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: e
                                      ? AppColors.rose200
                                      : AppColors.amber300,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Dismiss',
                              onPressed: dismiss,
                              icon: Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: e
                                    ? AppColors.rose300
                                    : AppColors.slate400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum BannerKind { success, error, info, warning }

class InlineBanner extends StatelessWidget {
  final String message;
  final BannerKind kind;
  final String? title;
  final Widget? trailing;
  final Widget? footer;
  const InlineBanner({
    super.key,
    required this.message,
    this.kind = BannerKind.error,
    this.title,
    this.trailing,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final (fill, border, text, icon) = switch (kind) {
      BannerKind.success => (
        AppColors.emerald950.withValues(alpha: 0.65),
        AppColors.emerald500.withValues(alpha: 0.35),
        AppColors.emerald300,
        Icons.check_circle_outline_rounded,
      ),
      BannerKind.error => (
        AppColors.rose950.withValues(alpha: 0.6),
        AppColors.rose500.withValues(alpha: 0.4),
        AppColors.rose300,
        Icons.warning_amber_rounded,
      ),
      BannerKind.info => (
        AppColors.sky500.withValues(alpha: 0.1),
        AppColors.sky500.withValues(alpha: 0.3),
        AppColors.sky300,
        Icons.info_outline_rounded,
      ),
      BannerKind.warning => (
        AppColors.amber950.withValues(alpha: 0.4),
        AppColors.amber(0.3),
        AppColors.amber300,
        Icons.lightbulb_outline_rounded,
      ),
    };
    return Semantics(
      liveRegion: kind == BannerKind.error,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: AppRadii.innerAll,
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 20, color: text),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (title != null) ...[
                        Text(
                          title!,
                          style: AppText.rowTitle.copyWith(color: text),
                        ),
                        const SizedBox(height: 2),
                      ],
                      Text(
                        message,
                        style: AppText.body.copyWith(
                          fontSize: 13,
                          color: title == null ? text : text.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
            if (footer != null) ...[const SizedBox(height: 12), footer!],
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String title, message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _DashedBorderPainter(),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: AppColors.white(0.02),
        borderRadius: AppRadii.innerAll,
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.white(0.05),
              borderRadius: AppRadii.innerAll,
            ),
            child: Icon(icon, size: 26, color: AppColors.slate400),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppText.rowTitle.copyWith(color: AppColors.slate200),
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: AppText.helper,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 18),
            AppButton(
              label: actionLabel!,
              onPressed: onAction,
              icon: Icons.add_rounded,
              rotateIcon: true,
            ),
          ],
        ],
      ),
    ),
  );
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(AppRadii.inner),
    );
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppColors.white(0.1);
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 6), paint);
        d += 11;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) => false;
}

class Shimmer extends StatefulWidget {
  final Widget child;
  const Shimmer({super.key, required this.child});

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final controller = AnimationController(
    vsync: this,
    duration: AppMotion.shimmer,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!AppMotion.looping(context)) {
      controller.stop();
    } else {
      controller.repeat();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    child: widget.child,
    builder: (_, child) => ShaderMask(
      blendMode: BlendMode.srcATop,
      shaderCallback: (rect) {
        final dx = rect.width * (controller.value * 2 - 0.5);
        return LinearGradient(
          colors: [
            AppColors.white(0.04),
            AppColors.white(0.09),
            AppColors.white(0.04),
          ],
          stops: const [0, 0.5, 1],
        ).createShader(Rect.fromLTWH(dx - rect.width / 2, 0, rect.width, rect.height));
      },
      child: child,
    ),
  );
}

class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 14,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: AppColors.white(0.06),
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

class SkeletonList extends StatelessWidget {
  final int count;
  final EdgeInsetsGeometry padding;
  const SkeletonList({
    super.key,
    this.count = 5,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading',
    child: Shimmer(
      child: ListView.separated(
        padding: padding,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: count,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) => Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white(0.03),
            borderRadius: AppRadii.innerAll,
            border: Border.all(color: AppColors.white(0.06)),
          ),
          child: Row(
            children: [
              const SkeletonBox(width: 44, height: 44, radius: 14),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: i.isEven ? 160 : 120, height: 14),
                    const SizedBox(height: 8),
                    const SkeletonBox(width: 90, height: 10),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class StaggeredEntrance extends StatefulWidget {
  final int index;
  final Widget child;
  const StaggeredEntrance({super.key, required this.index, required this.child});

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  late final controller = AnimationController(
    vsync: this,
    duration: AppMotion.listItem,
  );
  Timer? timer;
  bool started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (started) return;
    started = true;
    if (AppMotion.reduced(context) ||
        widget.index >= AppMotion.listStaggerCap * 2) {
      controller.value = 1;
      return;
    }
    final i = widget.index.clamp(0, AppMotion.listStaggerCap);
    timer = Timer(AppMotion.listStagger * i, () {
      if (mounted) controller.forward();
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: controller, curve: AppMotion.signature);
    return AnimatedBuilder(
      animation: curve,
      child: widget.child,
      builder: (_, child) => Opacity(
        opacity: curve.value,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - curve.value)),
          child: child,
        ),
      ),
    );
  }
}

class AppRefresh extends StatefulWidget {
  final Future<void> Function() onRefresh;
  final Widget child;
  final double edgeOffset;
  const AppRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
    this.edgeOffset = 0,
  });

  @override
  State<AppRefresh> createState() => _AppRefreshState();
}

class _AppRefreshState extends State<AppRefresh> {
  RefreshIndicatorStatus? status;

  bool get visible =>
      status == RefreshIndicatorStatus.armed ||
      status == RefreshIndicatorStatus.snap ||
      status == RefreshIndicatorStatus.refresh;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      RefreshIndicator.noSpinner(
        onStatusChange: (value) {
          if (mounted && value != status) setState(() => status = value);
        },
        onRefresh: () async {
          try {
            await widget.onRefresh();
          } catch (_) {}
        },
        child: widget.child,
      ),
      Positioned(
        top: widget.edgeOffset + 8,
        left: 0,
        right: 0,
        child: IgnorePointer(
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: AppMotion.popoverIn,
            child: Center(child: SchedioLoadingIndicator(isLoading: visible)),
          ),
        ),
      ),
    ],
  );
}
