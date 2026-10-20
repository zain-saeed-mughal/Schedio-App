import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text.dart';
import 'app_tokens.dart';
import 'page_transitions.dart';

export 'app_colors.dart';
export 'app_text.dart';
export 'app_tokens.dart';

ThemeData schedioTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppColors.amber500,
    onPrimary: AppColors.inkOnAmber,
    primaryContainer: AppColors.amber900,
    onPrimaryContainer: AppColors.amber100,
    secondary: AppColors.amber400,
    onSecondary: AppColors.inkOnAmber,
    tertiary: AppColors.indigo400,
    onTertiary: Colors.white,
    error: AppColors.rose400,
    onError: Colors.white,
    surface: AppColors.surface,
    onSurface: Colors.white,
    onSurfaceVariant: AppColors.slate400,
    surfaceContainerLowest: AppColors.surfaceDeep,
    surfaceContainerLow: AppColors.surface,
    surfaceContainer: AppColors.cardSolid,
    surfaceContainerHigh: AppColors.modalSurface,
    surfaceContainerHighest: AppColors.slate800,
    outline: AppColors.slate700,
    outlineVariant: AppColors.slate800,
    shadow: Colors.black,
    scrim: AppColors.slate950,
    inverseSurface: AppColors.slate200,
    onInverseSurface: AppColors.slate900,
    inversePrimary: AppColors.amber700,
  );

  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: AppRadii.controlAll,
        borderSide: BorderSide(color: color, width: width),
      );

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    fontFamily: AppText.sans,
  );

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bgBase,
    canvasColor: AppColors.modalSurface,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: SchedioPageTransitions(),
        TargetPlatform.fuchsia: SchedioPageTransitions(),
        TargetPlatform.windows: SchedioPageTransitions(),
        TargetPlatform.linux: SchedioPageTransitions(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    splashColor: AppColors.amber(0.08),
    highlightColor: Colors.transparent,
    hoverColor: AppColors.white(0.03),
    dividerColor: AppColors.white(0.08),
    textTheme: base.textTheme
        .apply(
          fontFamily: AppText.sans,
          bodyColor: AppColors.slate300,
          displayColor: Colors.white,
        )
        .copyWith(
          headlineLarge: AppText.screenTitle,
          headlineMedium: AppText.screenTitle,
          headlineSmall: AppText.pageTitle,
          titleLarge: AppText.cardTitle.copyWith(fontSize: 18),
          titleMedium: AppText.cardTitle,
          titleSmall: AppText.rowTitle,
          bodyLarge: AppText.body,
          bodyMedium: AppText.body,
          bodySmall: AppText.helper,
          labelLarge: AppText.button,
          labelMedium: AppText.label,
          labelSmall: AppText.tiny,
        ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: AppColors.amber400,
      selectionColor: AppColors.amber400.withValues(alpha: 0.4),
      selectionHandleColor: AppColors.amber400,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      foregroundColor: Colors.white,
      titleTextStyle: AppText.cardTitle,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.slate950.withValues(alpha: 0.8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: AppText.body.copyWith(color: AppColors.slate500),
      labelStyle: AppText.body.copyWith(color: AppColors.slate400),
      floatingLabelStyle: AppText.label.copyWith(color: AppColors.amber300),
      helperStyle: AppText.helper,
      errorStyle: AppText.helper.copyWith(color: AppColors.rose300),
      prefixIconColor: AppColors.slate500,
      suffixIconColor: AppColors.slate400,
      border: border(AppColors.slate700.withValues(alpha: 0.8)),
      enabledBorder: border(AppColors.slate700.withValues(alpha: 0.8)),
      disabledBorder: border(AppColors.white(0.06)),
      focusedBorder: border(AppColors.amber400, 2),
      errorBorder: border(AppColors.rose500.withValues(alpha: 0.6)),
      focusedErrorBorder: border(AppColors.rose400, 2),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      textStyle: AppText.body.copyWith(color: Colors.white),
      menuStyle: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(AppColors.surface),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: AppRadii.innerAll,
            side: BorderSide(color: AppColors.white(0.1)),
          ),
        ),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      textStyle: AppText.body.copyWith(color: AppColors.slate200),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.innerAll,
        side: BorderSide(color: AppColors.white(0.1)),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? AppColors.inkOnAmber
            : AppColors.slate400,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? AppColors.amber500
            : AppColors.slate800,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? AppColors.amber500
            : AppColors.slate700,
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? AppColors.amber500
            : Colors.transparent,
      ),
      checkColor: const WidgetStatePropertyAll(AppColors.inkOnAmber),
      side: BorderSide(color: AppColors.white(0.2), width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
    ),
    radioTheme: const RadioThemeData(
      fillColor: WidgetStatePropertyAll(AppColors.amber500),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.amber400,
      linearTrackColor: AppColors.slate800,
      refreshBackgroundColor: AppColors.surface,
    ),
    dividerTheme: DividerThemeData(
      color: AppColors.white(0.06),
      thickness: 1,
      space: 1,
    ),
    iconTheme: const IconThemeData(color: AppColors.slate300, size: 22),
    listTileTheme: const ListTileThemeData(
      iconColor: AppColors.slate400,
      textColor: AppColors.slate200,
      titleTextStyle: AppText.rowTitle,
      subtitleTextStyle: AppText.helper,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.modalSurface,
      surfaceTintColor: Colors.transparent,
      barrierColor: AppColors.slate950.withValues(alpha: 0.8),
      titleTextStyle: AppText.cardTitle.copyWith(fontSize: 20),
      contentTextStyle: AppText.body,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadii.cardAll,
        side: BorderSide(color: AppColors.modalBorder),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      modalBackgroundColor: Colors.transparent,
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: AppColors.modalSurface,
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: AppColors.surface,
      headerForegroundColor: Colors.white,
      dividerColor: AppColors.modalBorder,
      todayForegroundColor: const WidgetStatePropertyAll(AppColors.amber400),
      todayBorder: const BorderSide(color: AppColors.amber400),
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadii.cardAll,
        side: BorderSide(color: AppColors.modalBorder),
      ),
    ),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: AppColors.modalSurface,
      dialBackgroundColor: AppColors.surfaceDeep,
      hourMinuteColor: WidgetStateColor.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? AppColors.amber(0.2)
            : AppColors.slate800,
      ),
      hourMinuteTextColor: WidgetStateColor.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? AppColors.amber300
            : Colors.white,
      ),
      dayPeriodColor: AppColors.amber(0.2),
      dayPeriodTextColor: AppColors.amber300,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadii.cardAll,
        side: BorderSide(color: AppColors.modalBorder),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.amber400,
        textStyle: AppText.button.copyWith(fontSize: 13),
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.controlAll),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        backgroundColor: AppColors.amber400,
        foregroundColor: AppColors.slate950,
        textStyle: AppText.button,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.controlAll),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: AppColors.slate300,
        side: const BorderSide(color: AppColors.slate700),
        textStyle: AppText.button,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.controlAll),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.cardSolid,
      contentTextStyle: AppText.body.copyWith(color: AppColors.amber300),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.innerAll,
        side: BorderSide(color: AppColors.amber(0.4)),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.smallAll,
        border: Border.all(color: AppColors.white(0.1)),
      ),
      textStyle: AppText.helper.copyWith(color: AppColors.slate200),
    ),
  );
}
