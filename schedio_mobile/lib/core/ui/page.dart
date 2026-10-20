import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'backdrop.dart';
import 'buttons.dart';

class ShellChrome extends InheritedWidget {
  const ShellChrome({super.key, required super.child});

  static bool inShell(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ShellChrome>() != null;

  @override
  bool updateShouldNotify(ShellChrome oldWidget) => false;
}

EdgeInsets pageInsets(
  BuildContext context, {
  double top = 12,
  double bottom = 24,
  double horizontal = AppSpace.gutter,
}) {
  final view = MediaQuery.viewPaddingOf(context);
  final width = MediaQuery.sizeOf(context).width;
  final side = width > AppSpace.maxContent + 2 * horizontal
      ? (width - AppSpace.maxContent) / 2
      : (width >= 420 ? 20.0 : horizontal);
  return EdgeInsets.fromLTRB(
    side,
    topChrome(context) + top,
    side,
    view.bottom +
        bottom +
        (ShellChrome.inShell(context) ? AppSpace.bottomBar + 28 : 0),
  );
}

double topChrome(BuildContext context) =>
    MediaQuery.viewPaddingOf(context).top + AppSpace.topBar;

class GlassBar extends StatelessWidget {
  final Widget child;
  final bool top;
  const GlassBar({super.key, required this.child, this.top = true});

  @override
  Widget build(BuildContext context) => ClipRect(
    child: BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: AppBlur.bar, sigmaY: AppBlur.bar),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.85),
          border: Border(
            bottom: top
                ? BorderSide(color: AppColors.white(0.08))
                : BorderSide.none,
            top: top ? BorderSide.none : BorderSide(color: AppColors.white(0.08)),
          ),
        ),
        child: child,
      ),
    ),
  );
}

class GlassTopBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? leading;
  final Widget title;
  final List<Widget> actions;
  const GlassTopBar({
    super.key,
    required this.title,
    this.leading,
    this.actions = const [],
  });

  @override
  Size get preferredSize => const Size.fromHeight(AppSpace.topBar);

  @override
  Widget build(BuildContext context) => GlassBar(
    child: SafeArea(
      bottom: false,
      child: SizedBox(
        height: AppSpace.topBar,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 10)],
              Expanded(child: title),
              for (final a in actions) ...[const SizedBox(width: 6), a],
            ],
          ),
        ),
      ),
    ),
  );
}

class BackChip extends StatelessWidget {
  final VoidCallback? onPressed;
  const BackChip({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) => GlassIconButton(
    icon: Icons.arrow_back_rounded,
    tooltip: 'Back',
    onPressed: onPressed ?? () => Navigator.maybePop(context),
  );
}

class GlassPage extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget body;
  final List<Widget> actions;
  final Widget? bottomBar;
  final bool showBack;
  final bool dim;
  final Widget? floating;

  const GlassPage({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.actions = const [],
    this.bottomBar,
    this.showBack = true,
    this.dim = false,
    this.floating,
  });

  @override
  Widget build(BuildContext context) {
    final canPop = showBack && (ModalRoute.of(context)?.canPop ?? false);
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: GlassTopBar(
        leading: canPop ? const BackChip() : null,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.rowTitle.copyWith(fontWeight: FontWeight.w800),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.monoTiny.copyWith(color: AppColors.slate400),
              ),
          ],
        ),
        actions: actions,
      ),
      floatingActionButton: floating,
      bottomNavigationBar: bottomBar == null ? null : StickyActionBar(child: bottomBar!),
      body: Stack(
        children: [
          AmbientBackdrop(dim: dim),
          Positioned.fill(child: body),
        ],
      ),
    );
  }
}

class StickyActionBar extends StatelessWidget {
  final Widget child;
  const StickyActionBar({super.key, required this.child});

  @override
  Widget build(BuildContext context) => GlassBar(
    top: false,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSpace.maxContent),
            child: child,
          ),
        ),
      ),
    ),
  );
}

class TabPage extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget> actions;
  const TabPage({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    if (ShellChrome.inShell(context)) {
      return Material(type: MaterialType.transparency, child: child);
    }
    return GlassPage(title: title, actions: actions, body: child);
  }
}

class ScreenHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? chip;
  const ScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.chip,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (chip != null) ...[chip!, const SizedBox(height: 10)],
              Text(title, style: AppText.pageTitle),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: AppText.helper.copyWith(fontSize: 13)),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
      ],
    ),
  );
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final Widget? trailing;
  final bool dot;
  const SectionHeader({
    super.key,
    required this.title,
    this.action,
    this.onAction,
    this.trailing,
    this.dot = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 12),
    child: Row(
      children: [
        if (dot) ...[
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppColors.amber400,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            title,
            style: AppText.cardTitle.copyWith(fontSize: 17),
          ),
        ),
        ?trailing,
        if (action != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(action!)),
      ],
    ),
  );
}

class Centered extends StatelessWidget {
  final Widget child;
  const Centered({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: AppSpace.maxContent),
      child: child,
    ),
  );
}
