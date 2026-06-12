import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

/// Thin wrapper over [FTextField] that preserves existing call-sites unchanged.
class AppInput extends StatelessWidget {
  final String? label;
  final String? hint;
  final String? error;
  final String? helperText;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool readOnly;
  final bool enabled;
  final int? maxLines;
  final int? minLines;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final String? Function(String?)? validator;
  final bool autofocus;

  const AppInput({
    super.key,
    this.label,
    this.hint,
    this.error,
    this.helperText,
    this.controller,
    this.keyboardType,
    this.obscureText = false,
    this.readOnly = false,
    this.enabled = true,
    this.maxLines = 1,
    this.minLines,
    this.prefixIcon,
    this.suffixIcon,
    this.onChanged,
    this.onTap,
    this.focusNode,
    this.textInputAction,
    this.onSubmitted,
    this.validator,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final control = FTextFieldControl.managed(
      controller: controller,
      onChange: onChanged != null ? (val) => onChanged!(val.text) : null,
    );

    return FTextField(
      autofocus: autofocus,
      control: control,
      label: label != null ? Text(label!) : null,
      hint: hint,
      description: helperText != null ? Text(helperText!) : null,
      error: error != null ? Text(error!) : null,
      keyboardType: keyboardType,
      obscureText: obscureText,
      readOnly: readOnly,
      enabled: enabled,
      maxLines: obscureText ? 1 : maxLines,
      minLines: minLines,
      focusNode: focusNode,
      textInputAction: textInputAction,
      onSubmit: onSubmitted,
      onTap: onTap,
      prefixBuilder: prefixIcon != null
          ? (ctx, _, variants) => Padding(
                padding: const EdgeInsets.only(left: 12, right: 4),
                child: prefixIcon!,
              )
          : null,
      suffixBuilder: suffixIcon != null
          ? (ctx, _, variants) => Padding(
                padding: const EdgeInsets.only(left: 4, right: 12),
                child: suffixIcon!,
              )
          : null,
    );
  }
}
