import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'buttons.dart';

class Segment<T> {
  final T value;
  final String label;
  final int? count;
  final IconData? icon;
  const Segment(this.value, this.label, {this.count, this.icon});
}

class SegmentedTabs<T> extends StatelessWidget {
  final List<Segment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;
  final bool compact;

  const SegmentedTabs({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final index = segments
        .indexWhere((s) => s.value == selected)
        .clamp(0, segments.length - 1);
    final height = compact ? 38.0 : 44.0;
    return Container(
      height: height + 8,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.slate950.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.white(0.1)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth / segments.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: AppMotion.reduced(context)
                    ? Duration.zero
                    : AppMotion.segment,
                curve: AppMotion.signature,
                left: width * index,
                top: 0,
                bottom: 0,
                width: width,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.amber400,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: AppShadows.segment,
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < segments.length; i++)
                    Expanded(
                      child: _SegmentLabel(
                        segment: segments[i],
                        active: i == index,
                        compact: compact,
                        onTap: () {
                          if (segments[i].value != selected) {
                            haptic(HapticKind.selection);
                            onChanged(segments[i].value);
                          }
                        },
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SegmentLabel<T> extends StatelessWidget {
  final Segment<T> segment;
  final bool active;
  final bool compact;
  final VoidCallback onTap;
  const _SegmentLabel({
    required this.segment,
    required this.active,
    required this.compact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.slate950 : AppColors.slate400;
    return Semantics(
      button: true,
      selected: active,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (segment.icon != null) ...[
                    Icon(segment.icon, size: 15, color: color),
                    const SizedBox(width: 5),
                  ],
                  AnimatedDefaultTextStyle(
                    duration: AppMotion.segment,
                    style: AppText.helper.copyWith(
                      fontSize: compact ? 12 : 13,
                      color: color,
                      fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                    ),
                    child: Text(segment.label),
                  ),
                  if (segment.count != null) ...[
                    const SizedBox(width: 6),
                    AnimatedContainer(
                      duration: AppMotion.segment,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: active
                            ? AppColors.slate950.withValues(alpha: 0.2)
                            : AppColors.slate800,
                        borderRadius: AppRadii.pill,
                      ),
                      child: Text(
                        '${segment.count}',
                        style: AppText.monoTiny.copyWith(color: color),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
