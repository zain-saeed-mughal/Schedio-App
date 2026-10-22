import 'package:flutter/widgets.dart';

extension ResponsiveSize on BuildContext {
  double textHeight(double base, double text) =>
      base - text + MediaQuery.textScalerOf(this).scale(text);
}
