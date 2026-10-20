import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const bgBase = Color(0xFF15181D);
  static const surface = Color(0xFF16191E);
  static const surfaceDeep = Color(0xFF111317);
  static const columnBg = Color(0xFF121418);
  static const cardSolid = Color(0xFF181B20);
  static const panelSplit = Color(0xFF181B22);
  static const inkOnAmber = Color(0xFF0B0D11);
  static const inkOnAmberAlt = Color(0xFF090B0E);
  static const modalSurface = Color(0xFF0F172A);
  static const modalBorder = Color(0xFF1E293B);

  static const glassPanel = Color.fromRGBO(22, 26, 32, 0.78);
  static const glassCard = Color.fromRGBO(25, 29, 36, 0.65);
  static const glassCardFlat = Color(0xFF1A1E25);

  static const amber100 = Color(0xFFFEF3C7);
  static const amber200 = Color(0xFFFDE68A);
  static const amber300 = Color(0xFFFCD34D);
  static const amber400 = Color(0xFFFBBF24);
  static const amber500 = Color(0xFFF59E0B);
  static const amber600 = Color(0xFFD97706);
  static const amber700 = Color(0xFFB45309);
  static const amber800 = Color(0xFF92400E);
  static const amber900 = Color(0xFF78350F);
  static const amber950 = Color(0xFF451A03);
  static const orange500 = Color(0xFFF97316);
  static const gold = Color(0xFFC8A168);

  static const slate50 = Color(0xFFF8FAFC);
  static const slate200 = Color(0xFFE2E8F0);
  static const slate300 = Color(0xFFCBD5E1);
  static const slate400 = Color(0xFF94A3B8);
  static const slate500 = Color(0xFF64748B);
  static const slate600 = Color(0xFF475569);
  static const slate700 = Color(0xFF334155);
  static const slate800 = Color(0xFF1E293B);
  static const slate900 = Color(0xFF0F172A);
  static const slate950 = Color(0xFF020617);
  static const calendarDay = Color(0xFF717D91);

  static const emerald300 = Color(0xFF6EE7B7);
  static const emerald400 = Color(0xFF34D399);
  static const emerald500 = Color(0xFF10B981);
  static const emerald600 = Color(0xFF059669);
  static const emerald950 = Color(0xFF022C22);
  static const rose200 = Color(0xFFFECDD3);
  static const rose300 = Color(0xFFFDA4AF);
  static const rose400 = Color(0xFFFB7185);
  static const rose500 = Color(0xFFF43F5E);
  static const rose600 = Color(0xFFE11D48);
  static const rose700 = Color(0xFFBE123C);
  static const rose950 = Color(0xFF4C0519);
  static const sky300 = Color(0xFF7DD3FC);
  static const sky400 = Color(0xFF38BDF8);
  static const sky500 = Color(0xFF0EA5E9);
  static const indigo300 = Color(0xFFA5B4FC);
  static const indigo400 = Color(0xFF818CF8);
  static const indigo500 = Color(0xFF6366F1);
  static const purple300 = Color(0xFFD8B4FE);
  static const purple500 = Color(0xFFA855F7);
  static const purple600 = Color(0xFF9333EA);
  static const blue500 = Color(0xFF3B82F6);
  static const cyan300 = Color(0xFF67E8F9);
  static const cyan500 = Color(0xFF06B6D4);
  static const eventClientText = Color(0xFFE9D5FF);

  static const eventInternal = indigo500;
  static const eventClient = purple500;
  static const eventCompany = blue500;

  static Color white(double opacity) => Colors.white.withValues(alpha: opacity);
  static Color black(double opacity) => Colors.black.withValues(alpha: opacity);
  static Color amber(double opacity) => amber500.withValues(alpha: opacity);
}

class AppGradients {
  AppGradients._();

  static const amberButton = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.amber500, AppColors.amber600],
  );

  static const amberButtonPressed = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.amber400, AppColors.amber500],
  );

  static const fab = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.amber400, AppColors.amber500, AppColors.amber600],
  );

  static const staffAvatar = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.indigo500, AppColors.purple600],
  );

  static const goldAvatar = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.amber400, AppColors.amber600],
  );

  static final monogram = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      AppColors.amber400.withValues(alpha: 0.2),
      AppColors.amber600.withValues(alpha: 0.3),
    ],
  );

  static const glassSheen = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color.fromRGBO(255, 255, 255, 0.035),
      Color.fromRGBO(255, 255, 255, 0.005),
    ],
  );

  static final banner = LinearGradient(
    colors: [AppColors.amber500.withValues(alpha: 0.1), Colors.transparent],
  );

  static LinearGradient tile(Color base, Color neighbor) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [base.withValues(alpha: 0.2), neighbor.withValues(alpha: 0.2)],
  );
}

class Tint {
  final Color base, text;
  const Tint(this.base, this.text);

  Color get fill => base.withValues(alpha: 0.15);
  Color get border => base.withValues(alpha: 0.3);

  static const neutral = Tint(AppColors.slate500, AppColors.slate300);
  static const success = Tint(AppColors.emerald500, AppColors.emerald300);
  static const danger = Tint(AppColors.rose500, AppColors.rose300);
  static const info = Tint(AppColors.sky500, AppColors.sky300);
  static const indigo = Tint(AppColors.indigo500, AppColors.indigo300);
  static const purple = Tint(AppColors.purple500, AppColors.purple300);
  static const warning = Tint(AppColors.amber500, AppColors.amber300);
  static const cyan = Tint(AppColors.cyan500, AppColors.cyan300);
}

class StageStyle {
  final String key, label;
  final Color background, text, border, dot;
  final int step;
  const StageStyle(
    this.key,
    this.label,
    this.background,
    this.text,
    this.border,
    this.dot,
    this.step,
  );

  static const all = [
    StageStyle(
      'discovery',
      'Discovery',
      Color(0xFF6A2B07),
      Color(0xFFFEF3C7),
      Color(0xFF92400E),
      Color(0xFFF59E0B),
      1,
    ),
    StageStyle(
      'scheduled',
      'Scheduled',
      Color(0xFFBAE6FD),
      Color(0xFF0369A1),
      Color(0xFF7DD3FC),
      Color(0xFF0EA5E9),
      2,
    ),
    StageStyle(
      'paperwork_onboarding',
      'Paperwork/onboarding',
      Color(0xFF1D4ED8),
      Color(0xFFFFFFFF),
      Color(0xFF3B82F6),
      Color(0xFF93C5FD),
      3,
    ),
    StageStyle(
      'onboarded',
      'Onboarded',
      Color(0xFF166534),
      Color(0xFFECFDF5),
      Color(0xFF22C55E),
      Color(0xFF34D399),
      4,
    ),
    StageStyle(
      'deadend',
      'Deadend',
      Color(0xFFB91C1C),
      Color(0xFFFFFFFF),
      Color(0xFFEF4444),
      Color(0xFFFB7185),
      0,
    ),
    StageStyle(
      'pause',
      'Pause',
      Color(0xFFE2E8F0),
      Color(0xFF1E293B),
      Color(0xFFCBD5E1),
      Color(0xFF94A3B8),
      0,
    ),
  ];

  static StageStyle of(String key) =>
      all.firstWhere((s) => s.key == key, orElse: () => all.first);

  static const progressColors = [
    AppColors.amber400,
    AppColors.sky400,
    AppColors.indigo400,
    AppColors.emerald400,
  ];
}
