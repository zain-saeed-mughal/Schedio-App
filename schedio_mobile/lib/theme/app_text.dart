import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppText {
  AppText._();

  static const sans = 'Plus Jakarta Sans';
  static const mono = 'JetBrains Mono';
  static const monoFallback = [
    'monospace',
    'Menlo',
    'Roboto Mono',
    'SF Mono',
    'Courier New',
  ];

  static const hero = TextStyle(
    fontFamily: sans,
    fontSize: 34,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.85,
    height: 1.1,
    color: AppColors.amber400,
  );

  static const screenTitle = TextStyle(
    fontFamily: sans,
    fontSize: 26,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.65,
    height: 1.15,
    color: Colors.white,
  );

  static const pageTitle = TextStyle(
    fontFamily: sans,
    fontSize: 22,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.55,
    height: 1.2,
    color: Colors.white,
  );

  static const cardTitle = TextStyle(
    fontFamily: sans,
    fontSize: 16,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.16,
    height: 1.25,
    color: Colors.white,
  );

  static const rowTitle = TextStyle(
    fontFamily: sans,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 1.3,
    color: Colors.white,
  );

  static const metric = TextStyle(
    fontFamily: sans,
    fontSize: 28,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.7,
    height: 1.1,
    color: Colors.white,
  );

  static const body = TextStyle(
    fontFamily: sans,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.5,
    color: AppColors.slate300,
  );

  static const helper = TextStyle(
    fontFamily: sans,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.45,
    color: AppColors.slate400,
  );

  static const label = TextStyle(
    fontFamily: sans,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.55,
    height: 1.3,
    color: AppColors.slate300,
  );

  static const tiny = TextStyle(
    fontFamily: sans,
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
    height: 1.3,
    color: AppColors.slate500,
  );

  static const button = TextStyle(
    fontFamily: sans,
    fontSize: 14,
    fontWeight: FontWeight.w800,
    height: 1.2,
  );

  static const monoData = TextStyle(
    fontFamily: mono,
    fontFamilyFallback: monoFallback,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: AppColors.amber400,
  );

  static const monoMuted = TextStyle(
    fontFamily: mono,
    fontFamilyFallback: monoFallback,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: AppColors.slate400,
  );

  static const monoTiny = TextStyle(
    fontFamily: mono,
    fontFamilyFallback: monoFallback,
    fontSize: 10,
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: AppColors.slate500,
  );
}
