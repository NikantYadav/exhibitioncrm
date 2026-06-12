import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

mixin ScreenLogger<T extends StatefulWidget> on State<T> {
  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      debugPrint('[SCREEN] ${runtimeType.toString().replaceFirst(RegExp(r'^_'), '').replaceFirst('State', '')}');
    }
  }
}
