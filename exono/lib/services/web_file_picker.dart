import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// A transparent `<input type="file">` embedded directly into the Flutter
/// widget tree via [HtmlElementView]. This is the officially-supported way to
/// surface a real DOM element on Flutter web: the element is placed at the
/// correct stacking level, so it receives genuine, browser-trusted clicks and
/// its native `change` event fires reliably (unlike a detached input.click(),
/// which Flutter's canvas glass pane swallows).
///
/// Stack this over the visual "upload" affordance and size it to match.
class WebImagePickerInput extends StatefulWidget {
  /// Called with the selected image bytes, or null if the dialog was dismissed
  /// without a selection.
  final ValueChanged<Uint8List?> onPicked;

  const WebImagePickerInput({super.key, required this.onPicked});

  @override
  State<WebImagePickerInput> createState() => _WebImagePickerInputState();
}

class _WebImagePickerInputState extends State<WebImagePickerInput> {
  late final String _viewType;
  late final web.HTMLInputElement _input;

  @override
  void initState() {
    super.initState();
    _viewType = 'web-image-input-${DateTime.now().microsecondsSinceEpoch}';

    _input = web.HTMLInputElement()
      ..type = 'file'
      ..accept = 'image/*';
    // Fill the HtmlElementView box; invisible but still clickable so the user's
    // tap on the Flutter UPLOAD button beneath lands on this real input.
    _input.style
      ..width = '100%'
      ..height = '100%'
      ..margin = '0'
      ..padding = '0'
      ..border = 'none'
      ..opacity = '0'
      ..cursor = 'pointer';

    _input.onChange.listen((_) {
      final files = _input.files;
      if (files == null || files.length == 0) {
        widget.onPicked(null);
        return;
      }
      final file = files.item(0);
      if (file == null) {
        widget.onPicked(null);
        return;
      }
      final reader = web.FileReader();
      reader.onload = (web.Event _) {
        try {
          final buffer = reader.result as JSArrayBuffer;
          final bytes = buffer.toDart.asUint8List();
          // Reset so picking the same file again re-fires change.
          _input.value = '';
          widget.onPicked(bytes);
        } catch (_) {
          widget.onPicked(null);
        }
      }.toJS;
      reader.onerror = (web.Event _) {
        widget.onPicked(null);
      }.toJS;
      reader.readAsArrayBuffer(file);
    });

    ui_web.platformViewRegistry
        .registerViewFactory(_viewType, (int _) => _input);
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
