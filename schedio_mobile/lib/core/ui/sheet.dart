import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'buttons.dart';

Future<T?> showAppSheet<T>(
  BuildContext context, {
  required String title,
  String? subtitle,
  required WidgetBuilder builder,
  List<Widget> Function(BuildContext)? actions,
  bool scrollable = true,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.transparent,
  barrierColor: AppColors.slate950.withValues(alpha: 0.8),
  sheetAnimationStyle: AnimationStyle(
    duration: AppMotion.page,
    reverseDuration: AppMotion.scrimOut,
    curve: AppMotion.signature,
  ),
  builder: (c) => AppSheet(
    title: title,
    subtitle: subtitle,
    actions: actions?.call(c) ?? const [],
    scrollable: scrollable,
    child: builder(c),
  ),
);

class AppSheet extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget> actions;
  final bool scrollable;
  const AppSheet({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.actions = const [],
    this.scrollable = true,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final safe = MediaQuery.viewPaddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpace.maxContent),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.modalSurface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadii.sheetTop),
              ),
              border: Border.all(color: AppColors.modalBorder),
              boxShadow: AppShadows.modal,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.white(0.2),
                      borderRadius: AppRadii.pill,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 14, 12, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: AppText.cardTitle.copyWith(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 4),
                              Text(subtitle!, style: AppText.helper),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: AppColors.slate400,
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: scrollable
                      ? SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(
                            24,
                            8,
                            24,
                            actions.isEmpty ? 24 + safe : 16,
                          ),
                          child: child,
                        )
                      : Padding(
                          padding: EdgeInsets.fromLTRB(
                            24,
                            8,
                            24,
                            actions.isEmpty ? 24 + safe : 16,
                          ),
                          child: child,
                        ),
                ),
                if (actions.isNotEmpty)
                  Container(
                    padding: EdgeInsets.fromLTRB(24, 14, 24, 14 + safe),
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: AppColors.slate800),
                      ),
                    ),
                    child: Row(
                      children: [
                        for (var i = 0; i < actions.length; i++) ...[
                          if (i > 0) const SizedBox(width: 12),
                          Expanded(flex: i == actions.length - 1 ? 3 : 2, child: actions[i]),
                        ],
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
}

Future<bool> confirm(
  BuildContext context,
  String title, {
  String message = 'This change will also appear in your Schedio workspace.',
  String confirmLabel = 'Confirm',
  bool destructive = false,
}) async =>
    await showAppSheet<bool>(
      context,
      title: title,
      builder: (_) => Text(message, style: AppText.body),
      actions: (c) => [
        AppButton(
          label: 'Keep',
          variant: ButtonVariant.secondary,
          onPressed: () => Navigator.pop(c, false),
        ),
        AppButton(
          label: confirmLabel,
          variant: destructive ? ButtonVariant.danger : ButtonVariant.amber,
          haptic: destructive ? HapticKind.error : HapticKind.medium,
          onPressed: () => Navigator.pop(c, true),
        ),
      ],
    ) ??
    false;

Future<T?> showFormSheet<T>(
  BuildContext context, {
  required String title,
  String? subtitle,
  List<String> initial = const [''],
  required Widget Function(BuildContext, List<TextEditingController>) builder,
  required List<Widget> Function(BuildContext, List<TextEditingController>) actions,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.transparent,
  barrierColor: AppColors.slate950.withValues(alpha: 0.8),
  sheetAnimationStyle: AnimationStyle(
    duration: AppMotion.page,
    reverseDuration: AppMotion.scrimOut,
    curve: AppMotion.signature,
  ),
  builder: (_) => _ControllerScope(
    initial: initial,
    builder: (c, controllers) => AppSheet(
      title: title,
      subtitle: subtitle,
      actions: actions(c, controllers),
      child: builder(c, controllers),
    ),
  ),
);

class _ControllerScope extends StatefulWidget {
  final List<String> initial;
  final Widget Function(BuildContext, List<TextEditingController>) builder;
  const _ControllerScope({required this.initial, required this.builder});

  @override
  State<_ControllerScope> createState() => _ControllerScopeState();
}

class _ControllerScopeState extends State<_ControllerScope> {
  late final controllers = [
    for (final text in widget.initial) TextEditingController(text: text),
  ];

  @override
  void dispose() {
    for (final c in controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, controllers);
}
