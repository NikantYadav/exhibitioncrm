import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

/// Thin wrapper over [FCheckbox]. Replaces custom
/// `GestureDetector` + `AnimatedContainer` checkbox rows.
///
/// Before: a hand-rolled tappable square with a check Icon.
/// After:
///   AppCheckbox(
///     value: _isOneDay,
///     label: 'One-day event',
///     onChanged: (v) => setState(() => _isOneDay = v),
///   )
class AppCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? label;
  final Widget? labelWidget;
  final String? description;
  final bool enabled;

  const AppCheckbox({
    super.key,
    required this.value,
    this.onChanged,
    this.label,
    this.labelWidget,
    this.description,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return FCheckbox(
      value: value,
      onChange: onChanged,
      enabled: enabled,
      label: labelWidget ?? (label != null ? Text(label!) : null),
      description: description != null ? Text(description!) : null,
    );
  }
}
