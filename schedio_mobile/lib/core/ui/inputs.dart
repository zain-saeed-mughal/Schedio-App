import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import 'buttons.dart';

class FieldLabel extends StatelessWidget {
  final String text;
  final bool required;
  final Color? color;
  final IconData? icon;
  const FieldLabel(
    this.text, {
    super.key,
    this.required = false,
    this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 2),
    child: Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: color ?? AppColors.slate300),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text.rich(
            TextSpan(
              text: text.toUpperCase(),
              children: [
                if (required)
                  const TextSpan(
                    text: ' *',
                    style: TextStyle(color: AppColors.rose400),
                  ),
              ],
            ),
            style: AppText.label.copyWith(color: color ?? AppColors.slate300),
          ),
        ),
      ],
    ),
  );
}

class AppField extends StatelessWidget {
  final String label;
  final TextEditingController? controller;
  final String? hint;
  final bool required;
  final bool highlighted;
  final bool obscure;
  final int maxLines;
  final int? maxLength;
  final bool enabled;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final Widget? suffix;
  final IconData? prefixIcon;
  final Color? prefixColor;
  final Color? labelColor;
  final String? helper;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final EdgeInsetsGeometry padding;

  const AppField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.required = false,
    this.highlighted = false,
    this.obscure = false,
    this.maxLines = 1,
    this.maxLength,
    this.enabled = true,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.suffix,
    this.prefixIcon,
    this.prefixColor,
    this.labelColor,
    this.helper,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.inputFormatters,
    this.padding = const EdgeInsets.only(bottom: 16),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).inputDecorationTheme;
    final highlightBorder = OutlineInputBorder(
      borderRadius: AppRadii.controlAll,
      borderSide: BorderSide(color: AppColors.amber(0.4)),
    );
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FieldLabel(
            label,
            required: required,
            color: labelColor ?? (highlighted ? AppColors.amber300 : null),
          ),
          TextFormField(
            controller: controller,
            obscureText: obscure,
            maxLines: obscure ? 1 : maxLines,
            maxLength: maxLength,
            enabled: enabled,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            autofillHints: autofillHints,
            inputFormatters: inputFormatters,
            style: AppText.body.copyWith(color: Colors.white),
            onChanged: onChanged,
            onFieldSubmitted: onSubmitted,
            decoration: InputDecoration(
              hintText: hint,
              helperText: helper,
              helperMaxLines: 2,
              suffixIcon: suffix,
              prefixIcon: prefixIcon == null
                  ? null
                  : Icon(prefixIcon, size: 18, color: prefixColor),
              enabledBorder: highlighted ? highlightBorder : theme.enabledBorder,
            ),
            validator: validator,
          ),
        ],
      ),
    );
  }
}

class AppSearchField extends StatefulWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback? onFilter;
  final bool filterActive;
  final String initial;
  const AppSearchField({
    super.key,
    required this.onChanged,
    this.hint = 'Search',
    this.onFilter,
    this.filterActive = false,
    this.initial = '',
  });

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  late final controller = TextEditingController(text: widget.initial);
  Timer? debounce;

  @override
  void dispose() {
    debounce?.cancel();
    controller.dispose();
    super.dispose();
  }

  void changed(String value) {
    debounce?.cancel();
    debounce = Timer(AppMotion.debounce, () => widget.onChanged(value.trim()));
  }

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: TextField(
          controller: controller,
          onChanged: changed,
          onSubmitted: (v) {
            debounce?.cancel();
            widget.onChanged(v.trim());
          },
          textInputAction: TextInputAction.search,
          style: AppText.body.copyWith(color: Colors.white),
          decoration: InputDecoration(
            hintText: widget.hint,
            fillColor: AppColors.surfaceDeep.withValues(alpha: 0.8),
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppRadii.controlAll,
              borderSide: BorderSide(color: AppColors.white(0.1)),
            ),
            suffixIcon: ValueListenableBuilder(
              valueListenable: controller,
              builder: (_, value, _) => value.text.isEmpty
                  ? const SizedBox.shrink()
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        controller.clear();
                        debounce?.cancel();
                        widget.onChanged('');
                      },
                    ),
            ),
          ),
        ),
      ),
      if (widget.onFilter != null) ...[
        const SizedBox(width: 10),
        GlassIconButton(
          icon: Icons.tune_rounded,
          tooltip: 'Filters',
          round: true,
          iconColor: widget.filterActive ? AppColors.amber400 : null,
          onPressed: widget.onFilter,
        ),
      ],
    ],
  );
}

class AppDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final FormFieldValidator<T>? validator;
  final bool required;
  final Color? labelColor;
  final EdgeInsetsGeometry padding;

  const AppDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.validator,
    this.required = false,
    this.labelColor,
    this.padding = const EdgeInsets.only(bottom: 16),
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FieldLabel(label, required: required, color: labelColor),
        DropdownButtonFormField<T>(
          initialValue: value,
          items: items,
          onChanged: onChanged,
          validator: validator,
          isExpanded: true,
          dropdownColor: AppColors.surface,
          borderRadius: AppRadii.innerAll,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.slate400,
          ),
          style: AppText.body.copyWith(color: Colors.white),
          decoration: InputDecoration(hintText: label),
        ),
      ],
    ),
  );
}

class SwitchRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final IconData? icon;
  final EdgeInsetsGeometry margin;
  const SwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.icon,
    this.margin = const EdgeInsets.only(bottom: 10),
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: margin,
    child: Semantics(
      toggled: value,
      label: title,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onChanged == null
            ? null
            : () {
                haptic(HapticKind.selection);
                onChanged!(!value);
              },
        child: AnimatedContainer(
          duration: AppMotion.buttonPress,
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          decoration: BoxDecoration(
            color: value ? AppColors.amber(0.06) : AppColors.white(0.03),
            borderRadius: AppRadii.innerAll,
            border: Border.all(
              color: value ? AppColors.amber(0.3) : AppColors.white(0.06),
            ),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 20,
                  color: value ? AppColors.amber400 : AppColors.slate400,
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.rowTitle.copyWith(fontSize: 13)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: AppText.helper),
                    ],
                  ],
                ),
              ),
              ExcludeSemantics(
                child: Switch(value: value, onChanged: onChanged),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class CheckRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget? leading;
  const CheckRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.leading,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    checked: value,
    label: title,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        haptic(HapticKind.selection);
        onChanged(!value);
      },
      child: AnimatedContainer(
        duration: AppMotion.buttonPress,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: value ? AppColors.amber(0.06) : AppColors.white(0.03),
          borderRadius: AppRadii.controlAll,
          border: Border.all(
            color: value ? AppColors.amber(0.3) : AppColors.white(0.06),
          ),
        ),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppText.rowTitle.copyWith(fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null)
                    Text(subtitle!, style: AppText.monoTiny),
                ],
              ),
            ),
            ExcludeSemantics(
              child: Checkbox(value: value, onChanged: (v) => onChanged(v == true)),
            ),
          ],
        ),
      ),
    ),
  );
}

class PickerTile extends StatelessWidget {
  final String label;
  final String value;
  final String? meta;
  final IconData icon;
  final VoidCallback? onTap;
  final bool placeholder;
  final bool required;
  const PickerTile({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.meta,
    this.icon = Icons.schedule_rounded,
    this.placeholder = false,
    this.required = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FieldLabel(label, required: required),
        Semantics(
          button: true,
          label: '$label, $value',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap == null
                ? null
                : () {
                    haptic(HapticKind.selection);
                    onTap!();
                  },
            child: Container(
              constraints: const BoxConstraints(minHeight: 50),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.slate950.withValues(alpha: 0.8),
                borderRadius: AppRadii.controlAll,
                border: Border.all(
                  color: AppColors.slate700.withValues(alpha: 0.8),
                ),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: AppColors.amber400),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          value,
                          style: AppText.body.copyWith(
                            color: placeholder
                                ? AppColors.slate500
                                : Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (meta != null)
                          Text(meta!, style: AppText.monoTiny),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.slate500,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
