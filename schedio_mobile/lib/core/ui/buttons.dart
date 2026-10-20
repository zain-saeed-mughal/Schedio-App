import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';

enum ButtonVariant {
  amber,
  solid,
  secondary,
  outline,
  ghost,
  tinted,
  glass,
  success,
  danger,
  dangerSolid,
}

enum ButtonSize { sm, md, lg }

class AppButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final ButtonSize size;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool expand;
  final bool busy;
  final bool rotateIcon;
  final Color? iconColor;
  final HapticKind haptic;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = ButtonVariant.amber,
    this.size = ButtonSize.md,
    this.icon,
    this.trailingIcon,
    this.expand = false,
    this.busy = false,
    this.rotateIcon = false,
    this.iconColor,
    this.haptic = HapticKind.selection,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

enum HapticKind { none, selection, light, medium, error }

void haptic(HapticKind kind) {
  switch (kind) {
    case HapticKind.none:
      break;
    case HapticKind.selection:
      HapticFeedback.selectionClick();
    case HapticKind.light:
      HapticFeedback.lightImpact();
    case HapticKind.medium:
      HapticFeedback.mediumImpact();
    case HapticKind.error:
      HapticFeedback.vibrate();
  }
}

class _ButtonLook {
  final Gradient? gradient;
  final Gradient? pressedGradient;
  final Color? fill;
  final Color? pressedFill;
  final Color border;
  final Color text;
  final List<BoxShadow> shadow;
  final List<BoxShadow> pressedShadow;
  const _ButtonLook({
    this.gradient,
    this.pressedGradient,
    this.fill,
    this.pressedFill,
    this.border = Colors.transparent,
    required this.text,
    this.shadow = const [],
    this.pressedShadow = const [],
  });
}

class _AppButtonState extends State<AppButton> {
  bool pressed = false;

  _ButtonLook get look => switch (widget.variant) {
    ButtonVariant.amber => _ButtonLook(
      gradient: AppGradients.amberButton,
      pressedGradient: AppGradients.amberButtonPressed,
      text: AppColors.inkOnAmber,
      shadow: AppShadows.amberButton,
      pressedShadow: AppShadows.amberButtonLifted,
    ),
    ButtonVariant.solid => _ButtonLook(
      fill: AppColors.amber400,
      pressedFill: AppColors.amber300,
      text: AppColors.slate950,
      shadow: [
        BoxShadow(
          color: AppColors.amber(0.25),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    ButtonVariant.secondary => const _ButtonLook(
      fill: AppColors.slate800,
      pressedFill: AppColors.slate700,
      border: AppColors.slate700,
      text: AppColors.slate200,
    ),
    ButtonVariant.outline => _ButtonLook(
      fill: Colors.transparent,
      pressedFill: AppColors.white(0.04),
      border: AppColors.slate700,
      text: AppColors.slate300,
    ),
    ButtonVariant.ghost => _ButtonLook(
      fill: Colors.transparent,
      pressedFill: AppColors.white(0.04),
      text: AppColors.slate400,
    ),
    ButtonVariant.tinted => _ButtonLook(
      fill: AppColors.amber400.withValues(alpha: 0.1),
      pressedFill: AppColors.amber400.withValues(alpha: 0.18),
      border: AppColors.amber400.withValues(alpha: 0.3),
      text: AppColors.amber300,
    ),
    ButtonVariant.glass => _ButtonLook(
      fill: AppColors.white(0.04),
      pressedFill: AppColors.white(0.08),
      border: AppColors.white(0.1),
      text: AppColors.slate200,
    ),
    ButtonVariant.success => _ButtonLook(
      fill: AppColors.emerald600,
      pressedFill: AppColors.emerald500,
      text: Colors.white,
      shadow: [
        BoxShadow(
          color: AppColors.emerald600.withValues(alpha: 0.2),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    ButtonVariant.danger => _ButtonLook(
      fill: AppColors.rose950.withValues(alpha: 0.6),
      pressedFill: AppColors.rose950.withValues(alpha: 0.85),
      border: AppColors.rose700.withValues(alpha: 0.5),
      text: AppColors.rose300,
    ),
    ButtonVariant.dangerSolid => const _ButtonLook(
      fill: AppColors.rose600,
      pressedFill: AppColors.rose500,
      text: Colors.white,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final l = look;
    final enabled = widget.onPressed != null && !widget.busy;
    final reduced = AppMotion.reduced(context);
    final height = switch (widget.size) {
      ButtonSize.sm => 36.0,
      ButtonSize.md => 48.0,
      ButtonSize.lg => 52.0,
    };
    final fontSize = switch (widget.size) {
      ButtonSize.sm => 12.0,
      ButtonSize.md => 14.0,
      ButtonSize.lg => 15.0,
    };
    final radius = widget.size == ButtonSize.sm
        ? AppRadii.smallAll
        : AppRadii.controlAll;
    final iconSize = widget.size == ButtonSize.sm ? 16.0 : 18.0;
    final active = pressed && enabled;

    final textStyle = AppText.button.copyWith(
      fontSize: fontSize,
      color: l.text,
      fontWeight: widget.variant == ButtonVariant.amber
          ? FontWeight.w800
          : FontWeight.w700,
    );

    Widget? leading;
    if (widget.busy) {
      leading = SizedBox(
        width: iconSize - 2,
        height: iconSize - 2,
        child: CircularProgressIndicator(strokeWidth: 2, color: l.text),
      );
    } else if (widget.icon != null) {
      leading = Icon(
        widget.icon,
        size: iconSize,
        color: widget.iconColor ?? l.text,
      );
      if (widget.rotateIcon) {
        leading = AnimatedRotation(
          turns: active ? 0.25 : 0,
          duration: reduced ? Duration.zero : AppMotion.rotate,
          curve: Curves.easeOut,
          child: leading,
        );
      }
    }

    final content = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (leading != null) ...[leading, const SizedBox(width: 8)],
        Flexible(
          child: Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textStyle,
          ),
        ),
        if (widget.trailingIcon != null) ...[
          const SizedBox(width: 8),
          Icon(widget.trailingIcon, size: iconSize, color: l.text),
        ],
      ],
    );

    final button = AnimatedScale(
      scale: active ? 0.98 : 1,
      duration: reduced ? Duration.zero : AppMotion.buttonPress,
      curve: AppMotion.signature,
      child: AnimatedContainer(
        duration: reduced ? Duration.zero : AppMotion.buttonPress,
        curve: AppMotion.signature,
        constraints: BoxConstraints(minHeight: height, minWidth: 44),
        padding: EdgeInsets.symmetric(
          horizontal: widget.size == ButtonSize.sm ? 12 : 18,
        ),
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: active ? (l.pressedGradient ?? l.gradient) : l.gradient,
          color: l.gradient != null
              ? null
              : (active ? (l.pressedFill ?? l.fill) : l.fill),
          border: Border.all(color: l.border),
          boxShadow: enabled ? (active ? l.pressedShadow.isEmpty ? l.shadow : l.pressedShadow : l.shadow) : const [],
        ),
        child: content,
      ),
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled || widget.busy ? 1 : 0.5,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (_) => setState(() => pressed = true) : null,
          onTapUp: enabled ? (_) => setState(() => pressed = false) : null,
          onTapCancel: enabled ? () => setState(() => pressed = false) : null,
          onTap: enabled
              ? () {
                  haptic(widget.haptic);
                  widget.onPressed!();
                }
              : null,
          child: button,
        ),
      ),
    );
  }
}

class GlassIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final double size;
  final bool round;
  final int badge;
  final Color? iconColor;
  final bool pulseBadge;

  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.size = 44,
    this.round = false,
    this.badge = 0,
    this.iconColor,
    this.pulseBadge = true,
  });

  @override
  State<GlassIconButton> createState() => _GlassIconButtonState();
}

class _GlassIconButtonState extends State<GlassIconButton> {
  bool pressed = false;

  @override
  Widget build(BuildContext context) {
    final shape = widget.round
        ? BorderRadius.circular(widget.size)
        : AppRadii.controlAll;
    return Tooltip(
      message: widget.tooltip,
      child: Semantics(
        button: true,
        label: widget.tooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => pressed = true),
          onTapUp: (_) => setState(() => pressed = false),
          onTapCancel: () => setState(() => pressed = false),
          onTap: widget.onPressed == null
              ? null
              : () {
                  haptic(HapticKind.light);
                  widget.onPressed!();
                },
          child: SizedBox(
            width: math.max(widget.size, 44),
            height: math.max(widget.size, 44),
            child: Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: AppMotion.buttonPress,
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      color: AppColors.white(pressed ? 0.08 : 0.04),
                      borderRadius: shape,
                      border: Border.all(
                        color: pressed
                            ? AppColors.amber(0.5)
                            : AppColors.white(0.1),
                      ),
                    ),
                    child: Icon(
                      widget.icon,
                      size: widget.size * 0.45,
                      color: widget.iconColor ??
                          (pressed ? AppColors.amber400 : AppColors.slate200),
                    ),
                  ),
                  if (widget.badge > 0)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: CountBadge(
                        count: widget.badge,
                        pulse: widget.pulseBadge,
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

class CountBadge extends StatefulWidget {
  final int count;
  final bool pulse;
  final Color ring;
  const CountBadge({
    super.key,
    required this.count,
    this.pulse = false,
    this.ring = AppColors.bgBase,
  });

  @override
  State<CountBadge> createState() => _CountBadgeState();
}

class _CountBadgeState extends State<CountBadge>
    with SingleTickerProviderStateMixin {
  late final controller = AnimationController(
    vsync: this,
    duration: AppMotion.pulse,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.pulse && AppMotion.looping(context)) {
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
    final text = widget.count > 99 ? '99+' : '${widget.count}';
    final badge = Container(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: AppColors.amber400,
        borderRadius: AppRadii.pill,
        border: Border.all(color: widget.ring, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: AppText.tiny.copyWith(
          color: AppColors.inkOnAmber,
          letterSpacing: 0,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
    if (!widget.pulse) return badge;
    return FadeTransition(
      opacity: Tween(begin: 1.0, end: 0.6).animate(
        CurvedAnimation(parent: controller, curve: AppMotion.pulseCurve),
      ),
      child: badge,
    );
  }
}
