import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

enum AvatarKind { staff, gold, monogram, soft }

class AppAvatar extends StatelessWidget {
  final String name;
  final double size;
  final double? radius;
  final AvatarKind kind;
  final bool ring;
  final IconData? badgeIcon;

  const AppAvatar({
    super.key,
    required this.name,
    this.size = 44,
    this.radius,
    this.kind = AvatarKind.staff,
    this.ring = false,
    this.badgeIcon,
  });

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    if (kind == AvatarKind.monogram && parts.length > 1) {
      return (parts.first[0] + parts.elementAt(1)[0]).toUpperCase();
    }
    return parts.first[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(
      radius ??
          (size >= 64
              ? 16
              : size >= 56
              ? 18
              : size >= 44
              ? 14
              : 12),
    );
    final (decoration, color) = switch (kind) {
      AvatarKind.staff => (
        BoxDecoration(gradient: AppGradients.staffAvatar, borderRadius: r),
        Colors.white,
      ),
      AvatarKind.gold => (
        BoxDecoration(gradient: AppGradients.goldAvatar, borderRadius: r),
        AppColors.inkOnAmber,
      ),
      AvatarKind.monogram => (
        BoxDecoration(
          gradient: AppGradients.monogram,
          borderRadius: r,
          border: Border.all(color: AppColors.amber(0.3)),
        ),
        AppColors.amber300,
      ),
      AvatarKind.soft => (
        BoxDecoration(
          color: AppColors.amber400.withValues(alpha: 0.2),
          borderRadius: r,
          border: Border.all(color: AppColors.amber400.withValues(alpha: 0.4)),
        ),
        AppColors.amber300,
      ),
    };
    Widget avatar = Container(
      width: size,
      height: size,
      decoration: decoration,
      alignment: Alignment.center,
      child: Text(
        initials,
        style: AppText.cardTitle.copyWith(
          fontSize: size * (kind == AvatarKind.monogram ? 0.36 : 0.4),
          color: color,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
    if (ring) {
      avatar = Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: r + BorderRadius.circular(2),
          border: Border.all(
            color: AppColors.amber400.withValues(alpha: 0.4),
            width: 2,
          ),
        ),
        child: avatar,
      );
    }
    if (badgeIcon != null) {
      avatar = Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            right: -3,
            bottom: -3,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: AppColors.bgBase,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.amber(0.5)),
              ),
              child: Icon(badgeIcon, size: 11, color: AppColors.amber400),
            ),
          ),
        ],
      );
    }
    return Semantics(label: name, child: ExcludeSemantics(child: avatar));
  }
}
