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
  final String? labelText;
  final String? hintText;
  final TextCapitalization textCapitalization;
  /// Strips the field's border/fill/content padding so it reads as plain
  /// editable text — for inline edit-in-place rows already inside a card
  /// (e.g. a list row that supplies its own background/border).
  final bool bare;

  /// Value text style for [bare] mode (the typed/value text). Defaults to the
  /// theme's foreground at the default field size. Pass to match a design's
  /// value prominence (e.g. `context.theme.typography.lg`).
  final TextStyle? bareTextStyle;

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
    this.labelText,
    this.hintText,
    this.textCapitalization = TextCapitalization.none,
    this.bare = false,
    this.bareTextStyle,
  });

  @override
  Widget build(BuildContext context) {
    final control = FTextFieldControl.managed(
      controller: controller,
      onChange: onChanged != null ? (val) => onChanged!(val.text) : null,
    );

    final resolvedLabel = labelText ?? label;
    final resolvedHint = hintText ?? hint;

    return FTextField(
      autofocus: autofocus,
      control: control,
      style: bare
          ? FTextFieldStyleDelta.delta(
              border: FVariantsValueDelta.delta([
                FVariantValueDeltaOperation.all(InputBorder.none),
              ]),
              // base must be null (not transparent) so InputDecorator's
              // `filled` resolves false and draws no container at all.
              color: FVariantsValueDelta.delta([
                FVariantValueDeltaOperation.all(null),
              ]),
              contentPadding:
                  EdgeInsetsGeometryDelta.value(EdgeInsets.zero),
              contentTextStyle: bareTextStyle != null
                  ? FVariantsDelta.delta([
                      FVariantOperation.all(
                        TextStyleDelta.value(bareTextStyle!),
                      ),
                    ])
                  : null,
              hintTextStyle: bareTextStyle != null
                  ? FVariantsDelta.delta([
                      FVariantOperation.all(
                        TextStyleDelta.value(
                          bareTextStyle!.copyWith(
                            color: context.theme.colors.mutedForeground,
                          ),
                        ),
                      ),
                    ])
                  : null,
            )
          : const FTextFieldStyleDelta.context(),
      label: resolvedLabel != null ? Text(resolvedLabel) : null,
      hint: resolvedHint,
      textCapitalization: textCapitalization,
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
