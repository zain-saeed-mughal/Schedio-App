import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppRadii {
  AppRadii._();

  static const double hero = 24;
  static const double card = 24;
  static const double modal = 24;
  static const double sheetTop = 28;
  static const double control = 12;
  static const double small = 8;
  static const double inner = 16;
  static const double slot = 10.4;
  static const double barTop = 28;

  static const heroAll = BorderRadius.all(Radius.circular(hero));
  static const cardAll = BorderRadius.all(Radius.circular(card));
  static const controlAll = BorderRadius.all(Radius.circular(control));
  static const smallAll = BorderRadius.all(Radius.circular(small));
  static const innerAll = BorderRadius.all(Radius.circular(inner));
  static const slotAll = BorderRadius.all(Radius.circular(slot));
  static const pill = BorderRadius.all(Radius.circular(999));
}

class AppSpace {
  AppSpace._();

  static const double gutter = 16;
  static const double cardPad = 20;
  static const double gap = 16;
  static const double row = 12;
  static const double maxContent = 640;
  static const double maxBar = 560;
  static const double topBar = 64;
  static const double bottomBar = 74;
}

class AppMotion {
  AppMotion._();

  static const signature = Cubic(0.16, 1, 0.3, 1);
  static const pulseCurve = Cubic(0.4, 0, 0.6, 1);
  static const pingCurve = Cubic(0, 0, 0.2, 1);

  static const cardPress = Duration(milliseconds: 250);
  static const buttonPress = Duration(milliseconds: 200);
  static const pill = Duration(milliseconds: 190);
  static const iconTile = Duration(milliseconds: 300);
  static const rotate = Duration(milliseconds: 300);
  static const popoverIn = Duration(milliseconds: 150);
  static const popoverOut = Duration(milliseconds: 100);
  static const scrimIn = Duration(milliseconds: 200);
  static const scrimOut = Duration(milliseconds: 150);
  static const toastIn = Duration(milliseconds: 300);
  static const toastOut = Duration(milliseconds: 200);
  static const toastDwell = Duration(milliseconds: 3500);
  static const pulse = Duration(milliseconds: 2000);
  static const ping = Duration(milliseconds: 1000);
  static const copyRevert = Duration(milliseconds: 2500);
  static const drag = Duration(milliseconds: 200);
  static const segment = Duration(milliseconds: 260);
  static const shimmer = Duration(milliseconds: 1400);
  static const listItem = Duration(milliseconds: 280);
  static const listStagger = Duration(milliseconds: 40);
  static const int listStaggerCap = 8;
  static const page = Duration(milliseconds: 320);
  static const pageOut = Duration(milliseconds: 220);
  static const reducedFade = Duration(milliseconds: 120);
  static const idleFloat = Duration(milliseconds: 3200);
  static const navColor = Duration(milliseconds: 200);
  static const navRise = Duration(milliseconds: 220);
  static const navFall = Duration(milliseconds: 180);
  static const fabGlow = Duration(milliseconds: 520);
  static const fabBounce = Duration(milliseconds: 480);
  static const barHide = Duration(milliseconds: 220);
  static const poll = Duration(seconds: 30);
  static const debounce = Duration(milliseconds: 300);

  static bool ambient = true;

  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  static bool looping(BuildContext context) => ambient && !reduced(context);
}

class AppShadows {
  AppShadows._();

  static final panel = [
    BoxShadow(
      color: AppColors.black(0.6),
      offset: const Offset(0, 16),
      blurRadius: 36,
      spreadRadius: -8,
    ),
  ];

  static final card = [
    BoxShadow(
      color: AppColors.black(0.5),
      offset: const Offset(0, 10),
      blurRadius: 28,
      spreadRadius: -6,
    ),
  ];

  static final cardLifted = [
    BoxShadow(
      color: AppColors.black(0.7),
      offset: const Offset(0, 18),
      blurRadius: 36,
      spreadRadius: -10,
    ),
    BoxShadow(
      color: AppColors.amber(0.15),
      blurRadius: 20,
      spreadRadius: -4,
    ),
  ];

  static final amberButton = [
    BoxShadow(
      color: AppColors.amber(0.35),
      offset: const Offset(0, 6),
      blurRadius: 18,
      spreadRadius: -2,
    ),
  ];

  static final amberButtonLifted = [
    BoxShadow(
      color: AppColors.amber(0.55),
      offset: const Offset(0, 8),
      blurRadius: 24,
      spreadRadius: -2,
    ),
  ];

  static final selectedPill = [
    BoxShadow(
      color: AppColors.amber(0.45),
      offset: const Offset(0, 4),
      blurRadius: 14,
    ),
  ];

  static final dateCard = [
    BoxShadow(
      color: AppColors.amber(0.4),
      offset: const Offset(0, 6),
      blurRadius: 18,
    ),
  ];

  static final segment = [
    BoxShadow(
      color: AppColors.amber(0.25),
      offset: const Offset(0, 4),
      blurRadius: 12,
    ),
  ];

  static final modal = [
    BoxShadow(
      color: AppColors.black(0.6),
      offset: const Offset(0, 25),
      blurRadius: 50,
      spreadRadius: -12,
    ),
  ];

  static final liveDot = [
    BoxShadow(color: AppColors.amber500, blurRadius: 6),
  ];
}

class AppBlur {
  AppBlur._();

  static const double panel = 24;
  static const double card = 18;
  static const double bar = 40;
  static const double nav = 24;
  static const double scrim = 4;
}
