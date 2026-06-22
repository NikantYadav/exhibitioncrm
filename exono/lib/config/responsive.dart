import 'package:flutter/widgets.dart';

class Breakpoints {
  static const double narrow = 360;
  static const double tablet = 768;
}

extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;

  bool get isNarrow => screenWidth < Breakpoints.narrow;

  double get typeScale => isNarrow ? 0.92 : 1.0;

  double get gutter => isNarrow ? 16 : 20;
}
