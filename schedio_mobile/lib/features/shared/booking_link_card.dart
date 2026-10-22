import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/widgets.dart';

class BookingLinkCard extends StatefulWidget {
  final String url;
  final VoidCallback? onView;
  const BookingLinkCard({super.key, required this.url, this.onView});

  @override
  State<BookingLinkCard> createState() => _BookingLinkCardState();
}

class _BookingLinkCardState extends State<BookingLinkCard> {
  bool copied = false;
  Timer? revert;

  @override
  void dispose() {
    revert?.cancel();
    super.dispose();
  }

  Future<void> copy() async {
    await Clipboard.setData(ClipboardData(text: widget.url));
    revert?.cancel();
    setState(() => copied = true);
    revert = Timer(AppMotion.copyRevert, () {
      if (mounted) setState(() => copied = false);
    });
  }

  Future<void> share() async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: widget.url,
          sharePositionOrigin: const Rect.fromLTWH(24, 24, 1, 1),
        ),
      );
    } catch (e) {
      if (mounted) showToast(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      borderRadius: AppRadii.innerAll,
      gradient: AppGradients.banner,
      border: Border.all(color: AppColors.amber(0.25)),
    ),
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const IconTile(icon: Icons.link_rounded, size: 36, iconSize: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Public Booking Link',
                style: AppText.rowTitle.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            const StatusPill(
              text: 'Live & Shareable',
              tint: Tint.success,
              dot: true,
            ),
          ],
        ),
        const SizedBox(height: 12),
        InsetWell(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Text(
            widget.url,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.monoData.copyWith(color: AppColors.amber300, fontSize: 11.5),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: AnimatedSwitcher(
                duration: AppMotion.buttonPress,
                child: AppButton(
                  key: ValueKey(copied),
                  label: copied ? 'Copied to Clipboard!' : 'Copy Link',
                  icon: copied ? Icons.check_rounded : Icons.copy_rounded,
                  variant: copied ? ButtonVariant.tinted : ButtonVariant.glass,
                  size: ButtonSize.sm,
                  expand: true,
                  onPressed: copy,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GlassIconButton(
              icon: Icons.ios_share_rounded,
              tooltip: 'Share link',
              size: 36,
              onPressed: share,
            ),
            if (widget.onView != null) ...[
              const SizedBox(width: 4),
              AppButton(
                label: 'View Page',
                variant: ButtonVariant.tinted,
                size: ButtonSize.sm,
                trailingIcon: Icons.arrow_outward_rounded,
                onPressed: widget.onView,
              ),
            ],
          ],
        ),
      ],
    ),
  );
}
