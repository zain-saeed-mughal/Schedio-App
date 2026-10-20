import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'buttons.dart';

enum PillSize { sm, md, lg }

class StatusPill extends StatelessWidget {
  final String text;
  final Tint tint;
  final PillSize size;
  final IconData? icon;
  final bool dot;
  final bool uppercase;

  const StatusPill({
    super.key,
    required this.text,
    this.tint = Tint.neutral,
    this.size = PillSize.sm,
    this.icon,
    this.dot = false,
    this.uppercase = false,
  });

  factory StatusPill.status(String status, {PillSize size = PillSize.sm}) =>
      StatusPill(
        text: status.replaceAll('_', ' '),
        tint: statusTint(status),
        size: size,
        dot: true,
      );

  @override
  Widget build(BuildContext context) {
    final neutral = identical(tint, Tint.neutral);
    final fontSize = switch (size) {
      PillSize.sm => 10.0,
      PillSize.md => 12.0,
      PillSize.lg => 14.0,
    };
    final padding = switch (size) {
      PillSize.sm => const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      PillSize.md => const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      PillSize.lg => const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    };
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: neutral ? AppColors.slate800.withValues(alpha: 0.8) : tint.fill,
        borderRadius: AppRadii.pill,
        border: Border.all(
          color: neutral
              ? AppColors.slate700.withValues(alpha: 0.6)
              : tint.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: neutral ? AppColors.slate400 : tint.text,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
          ],
          if (icon != null) ...[
            Icon(icon, size: fontSize + 2, color: tint.text),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              uppercase ? text.toUpperCase() : text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.tiny.copyWith(
                fontSize: fontSize,
                color: tint.text,
                letterSpacing: uppercase ? 0.5 : 0.1,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Tint statusTint(String status) => switch (status) {
  'scheduled' || 'approved' || 'completed' || 'accepted' || 'active' =>
    Tint.success,
  'cancelled' || 'rejected' || 'declined' || 'deadend' || 'high' ||
  'urgent' => Tint.danger,
  'pending' || 'tentative' || 'medium' || 'review' || 'discovery' ||
  'unread' => Tint.warning,
  'in_progress' || 'rescheduled' || 'paperwork_onboarding' => Tint.info,
  'onboarded' => Tint.success,
  _ => Tint.neutral,
};

Tint meetingStatusTint(String status) => switch (status) {
  'scheduled' => Tint.success,
  'cancelled' => Tint.danger,
  _ => Tint.neutral,
};

Tint priorityTint(String priority) => switch (priority) {
  'high' || 'urgent' => Tint.danger,
  'medium' => Tint.warning,
  _ => Tint.neutral,
};

Tint taskStatusTint(String status) => switch (status) {
  'completed' => Tint.success,
  'in_progress' => Tint.info,
  'cancelled' => Tint.danger,
  'review' => Tint.purple,
  _ => Tint.neutral,
};

class RoleChip extends StatelessWidget {
  final String role;
  const RoleChip({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    final text = role == 'client'
        ? 'Client Partner'
        : role == 'developer'
        ? 'Platform Developer'
        : role
              .split('_')
              .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
              .join(' ');
    if (role == 'super_admin' || role == 'developer') {
      return StatusPill(
        text: text,
        tint: Tint(AppColors.amber400, AppColors.amber300),
        size: PillSize.sm,
      );
    }
    if (role == 'client') {
      return StatusPill(text: text, tint: Tint.success);
    }
    return Text(
      text,
      style: AppText.monoTiny.copyWith(color: AppColors.slate400),
    );
  }
}

class ReminderChip extends StatelessWidget {
  final int minutes;
  const ReminderChip({super.key, required this.minutes});

  @override
  Widget build(BuildContext context) => StatusPill(
    text: minutes >= 1440 ? '1d Alert' : '${minutes}m Alert',
    tint: Tint.warning,
    icon: Icons.notifications_active_outlined,
  );
}

class LiveDot extends StatefulWidget {
  final double size;
  final Color color;
  final bool ping;
  const LiveDot({
    super.key,
    this.size = 7,
    this.color = AppColors.amber400,
    this.ping = true,
  });

  @override
  State<LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<LiveDot> with TickerProviderStateMixin {
  late final pulse = AnimationController(vsync: this, duration: AppMotion.pulse);
  late final ping = AnimationController(vsync: this, duration: AppMotion.ping);
  bool reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    reduced = !AppMotion.looping(context);
    if (reduced) {
      pulse.stop();
      ping.stop();
    } else {
      pulse.repeat(reverse: true);
      if (widget.ping) ping.repeat();
    }
  }

  @override
  void dispose() {
    pulse.dispose();
    ping.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final dot = Container(
      width: s,
      height: s,
      decoration: BoxDecoration(
        color: widget.color,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: widget.color, blurRadius: 6)],
      ),
    );
    if (reduced) return SizedBox(width: s * 2, height: s * 2, child: Center(child: dot));
    return SizedBox(
      width: s * 2,
      height: s * 2,
      child: RepaintBoundary(
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (widget.ping)
              AnimatedBuilder(
                animation: ping,
                builder: (_, _) {
                  final t = AppMotion.pingCurve.transform(ping.value);
                  return Opacity(
                    opacity: 0.75 * (1 - t),
                    child: Transform.scale(
                      scale: 1 + t,
                      child: Container(
                        width: s,
                        height: s,
                        decoration: BoxDecoration(
                          color: widget.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  );
                },
              ),
            FadeTransition(
              opacity: Tween(begin: 1.0, end: 0.5).animate(
                CurvedAnimation(parent: pulse, curve: AppMotion.pulseCurve),
              ),
              child: dot,
            ),
          ],
        ),
      ),
    );
  }
}

class FilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;
  final Color? dot;
  const FilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
    this.dot,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: GestureDetector(
      onTap: () {
        haptic(HapticKind.selection);
        onTap();
      },
      child: AnimatedContainer(
        duration: AppMotion.pill,
        curve: Curves.easeInOut,
        constraints: const BoxConstraints(minHeight: 36),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.amber400 : AppColors.white(0.035),
          borderRadius: AppRadii.pill,
          border: Border.all(
            color: selected ? AppColors.amber400 : AppColors.white(0.12),
          ),
          boxShadow: selected ? AppShadows.segment : const [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dot != null) ...[
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: AppText.helper.copyWith(
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? AppColors.slate950 : AppColors.slate300,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.slate950.withValues(alpha: 0.2)
                      : AppColors.slate800,
                  borderRadius: AppRadii.pill,
                ),
                child: Text(
                  '$count',
                  style: AppText.monoTiny.copyWith(
                    color: selected ? AppColors.slate950 : AppColors.slate400,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class SlotPill extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  const SlotPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<SlotPill> createState() => _SlotPillState();
}

class _SlotPillState extends State<SlotPill> {
  bool pressed = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.selected;
    return Semantics(
      button: true,
      selected: s,
      child: GestureDetector(
        onTapDown: widget.onTap == null ? null : (_) => setState(() => pressed = true),
        onTapUp: widget.onTap == null ? null : (_) => setState(() => pressed = false),
        onTapCancel: widget.onTap == null ? null : () => setState(() => pressed = false),
        onTap: widget.onTap == null
            ? null
            : () {
                haptic(HapticKind.selection);
                widget.onTap!();
              },
        child: AnimatedContainer(
          duration: AppMotion.pill,
          curve: Curves.easeInOut,
          transform: Matrix4.translationValues(0, pressed && !s ? -1 : 0, 0),
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: s
                ? AppColors.amber500
                : pressed
                ? AppColors.amber(0.1)
                : AppColors.white(0.035),
            borderRadius: AppRadii.slotAll,
            border: Border.all(
              color: s || pressed ? AppColors.amber500 : AppColors.white(0.14),
            ),
            boxShadow: s ? AppShadows.selectedPill : const [],
          ),
          child: Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.fade,
            softWrap: false,
            style: AppText.helper.copyWith(
              fontWeight: s ? FontWeight.w800 : FontWeight.w600,
              color: s
                  ? AppColors.inkOnAmberAlt
                  : pressed
                  ? AppColors.amber100
                  : AppColors.slate300,
            ),
          ),
        ),
      ),
    );
  }
}

class DateCard extends StatelessWidget {
  final String weekday;
  final String day;
  final bool selected;
  final bool today;
  final VoidCallback onTap;
  const DateCard({
    super.key,
    required this.weekday,
    required this.day,
    required this.selected,
    required this.onTap,
    this.today = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF0B0D10) : Colors.white;
    return Semantics(
      button: true,
      selected: selected,
      label: '$weekday $day',
      child: GestureDetector(
        onTap: () {
          haptic(HapticKind.selection);
          onTap();
        },
        child: AnimatedContainer(
          duration: AppMotion.pill,
          curve: Curves.easeInOut,
          constraints: const BoxConstraints(minWidth: 56),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.amber500 : AppColors.white(0.035),
            borderRadius: AppRadii.controlAll,
            border: Border.all(
              color: selected
                  ? AppColors.amber500
                  : today
                  ? AppColors.amber(0.5)
                  : AppColors.white(0.1),
            ),
            boxShadow: selected ? AppShadows.dateCard : const [],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                weekday.toUpperCase(),
                style: AppText.tiny.copyWith(
                  fontSize: 10,
                  color: (selected
                          ? color
                          : today
                          ? AppColors.amber400
                          : AppColors.slate400)
                      .withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                day,
                style: AppText.cardTitle.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SegmentProgress extends StatelessWidget {
  final int step;
  const SegmentProgress({super.key, required this.step});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 0; i < 4; i++) ...[
        if (i > 0) const SizedBox(width: 4),
        Expanded(
          child: Container(
            height: 5,
            decoration: BoxDecoration(
              color: i < step
                  ? StageStyle.progressColors[i]
                  : AppColors.slate800,
              borderRadius: AppRadii.pill,
              boxShadow: i < step
                  ? [
                      BoxShadow(
                        color: StageStyle.progressColors[i].withValues(
                          alpha: 0.5,
                        ),
                        blurRadius: 6,
                      ),
                    ]
                  : null,
            ),
          ),
        ),
      ],
    ],
  );
}
