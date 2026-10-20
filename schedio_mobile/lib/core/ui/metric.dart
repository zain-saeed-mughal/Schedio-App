import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'glass.dart';

class MetricCard extends StatefulWidget {
  final String title;
  final String value;
  final String caption;
  final IconData icon;
  final Tint tint;
  final Color neighbor;
  final VoidCallback? onTap;
  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.caption,
    required this.icon,
    this.tint = Tint.warning,
    this.neighbor = AppColors.orange500,
    this.onTap,
  });

  @override
  State<MetricCard> createState() => _MetricCardState();
}

class _MetricCardState extends State<MetricCard> {
  bool pressed = false;

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => setState(() => pressed = true),
    onPointerUp: (_) => setState(() => pressed = false),
    onPointerCancel: (_) => setState(() => pressed = false),
    child: GlassCard(
      onTap: widget.onTap,
      padding: const EdgeInsets.all(16),
      semanticLabel: '${widget.title}: ${widget.value}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  widget.title.toUpperCase(),
                  maxLines: 2,
                  style: AppText.label.copyWith(
                    color: AppColors.slate400,
                    fontSize: 10.5,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AnimatedScale(
                scale: pressed ? 1.1 : 1,
                duration: AppMotion.iconTile,
                curve: Curves.easeOut,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: AppRadii.innerAll,
                    gradient: AppGradients.tile(widget.tint.base, widget.neighbor),
                    border: Border.all(color: widget.tint.border),
                  ),
                  child: Icon(widget.icon, size: 21, color: widget.tint.text),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(widget.value, style: AppText.metric),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: widget.tint.text.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.helper.copyWith(
                    fontSize: 11,
                    color: widget.tint.text,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final String? secondary;
  final IconData? icon;
  final bool accent;
  const InfoTile({
    super.key,
    required this.label,
    required this.value,
    this.secondary,
    this.icon,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) => InsetWell(
    padding: const EdgeInsets.all(10),
    fill: AppColors.slate950.withValues(alpha: 0.7),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: AppColors.slate500),
              const SizedBox(width: 5),
            ],
            Expanded(
              child: Text(
                label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.tiny,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            if (accent) ...[
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.amber400,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.rowTitle.copyWith(
                  fontSize: 13,
                  color: accent ? AppColors.amber300 : AppColors.slate300,
                  fontWeight: accent ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        if (secondary != null && secondary!.isNotEmpty)
          Text(
            secondary!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.helper.copyWith(fontSize: 11),
          ),
      ],
    ),
  );
}

class DetailRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Tint tint;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool selectable;
  const DetailRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.tint = Tint.warning,
    this.trailing,
    this.onTap,
    this.selectable = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: PressableRow(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          IconTile(icon: icon, tint: tint),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                selectable
                    ? SelectableText(title, style: AppText.rowTitle)
                    : Text(title, style: AppText.rowTitle),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: AppText.helper),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    ),
  );
}

class StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool accent;
  const StatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.slate950.withValues(alpha: 0.6),
      borderRadius: AppRadii.innerAll,
      border: Border.all(color: AppColors.white(0.06)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.slate400),
        const SizedBox(height: 8),
        Text(
          label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.tiny,
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            if (accent) ...[
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.amber400,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
            ],
            Expanded(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.rowTitle.copyWith(
                  fontSize: 12.5,
                  color: accent ? AppColors.amber300 : Colors.white,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class LabeledBlock extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  const LabeledBlock({
    super.key,
    required this.label,
    required this.value,
    this.icon,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: AppColors.amber400),
              const SizedBox(width: 6),
            ],
            Text(label.toUpperCase(), style: AppText.label),
          ],
        ),
        const SizedBox(height: 6),
        SelectableText(value, style: AppText.body),
      ],
    ),
  );
}
