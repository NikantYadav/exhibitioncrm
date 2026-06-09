import 'dart:typed_data';

import 'package:flutter/widgets.dart';

/// Non-web stub. The widget is never shown on non-web platforms (callers gate
/// on kIsWeb), so it renders nothing.
class WebImagePickerInput extends StatelessWidget {
  final ValueChanged<Uint8List?> onPicked;

  const WebImagePickerInput({super.key, required this.onPicked});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
