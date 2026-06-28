import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import 'app_button.dart';
import 'app_card.dart';
import 'app_input.dart';
import 'app_section_label.dart';

/// Editable list of free-form "additional details" (label/value pairs) used
/// when creating or editing a contact. Pre-fills from an existing
/// `scanned_details` map and serializes back to a `{snake_case_label: value}`
/// map via [controller].
///
/// Add / edit / remove rows are handled internally. Read the current map with
/// `controller.toMap()` at save time.
class AdditionalDetailsEditor extends StatefulWidget {
  final AdditionalDetailsController controller;
  const AdditionalDetailsEditor({super.key, required this.controller});

  @override
  State<AdditionalDetailsEditor> createState() => _AdditionalDetailsEditorState();
}

class _AdditionalDetailsEditorState extends State<AdditionalDetailsEditor> {
  AdditionalDetailsController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _c._attach(() { if (mounted) setState(() {}); });
  }

  @override
  void dispose() {
    _c._detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AppSectionLabel('Additional Details'),
            const Spacer(),
            AppButton(
              variant: ButtonVariant.outline,
              size: ButtonSize.sm,
              onPressed: () => setState(_c.addField),
              prefixIcon: const Icon(Icons.add, size: 14),
              label: 'Add',
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_c.fields.isEmpty)
          Text(
            'No additional details yet. Tap Add to include extra fields.',
            style: theme.typography.sm.copyWith(color: theme.colors.mutedForeground),
          )
        else
          AppCard(
            radius: 20,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < _c.fields.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  _row(_c.fields[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _row(DetailField field) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: AppInput(label: 'Label', controller: field.labelCtrl),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: AppInput(label: 'Value', controller: field.valueCtrl),
        ),
        const SizedBox(width: 4),
        Padding(
          padding: const EdgeInsets.only(top: 20),
          child: AppButton(
            variant: ButtonVariant.ghost,
            size: ButtonSize.sm,
            onPressed: () => setState(() => _c.removeField(field)),
            child: Icon(Icons.remove_circle_outline, size: 20, color: context.theme.colors.error),
          ),
        ),
      ],
    );
  }
}

/// Owns the list of editable detail fields. Create one in the host screen's
/// state, optionally seed it with [AdditionalDetailsController.fromMap], and
/// call [dispose] in the screen's dispose.
class AdditionalDetailsController {
  final List<DetailField> fields = [];
  VoidCallback? _notify;

  AdditionalDetailsController();

  /// Seeds the controller from an existing `scanned_details` map.
  void setFromMap(Map<String, dynamic>? map) {
    for (final f in fields) { f.dispose(); }
    fields.clear();
    if (map != null) {
      map.forEach((key, value) {
        fields.add(DetailField(label: _humanize(key.toString()), value: value?.toString() ?? ''));
      });
    }
    _notify?.call();
  }

  void addField() => fields.add(DetailField());

  void removeField(DetailField field) {
    fields.remove(field);
    field.dispose();
  }

  /// Serializes to `{snake_case_label: value}`, skipping rows with empty labels.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};
    for (final f in fields) {
      final label = f.labelCtrl.text.trim();
      if (label.isEmpty) continue;
      final key = label.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
      map[key] = f.valueCtrl.text.trim();
    }
    return map;
  }

  void clear() {
    for (final f in fields) { f.dispose(); }
    fields.clear();
    _notify?.call();
  }

  void dispose() {
    for (final f in fields) { f.dispose(); }
    fields.clear();
    _notify = null;
  }

  void _attach(VoidCallback notify) => _notify = notify;
  void _detach() => _notify = null;

  static String _humanize(String key) => key
      .replaceAll('_', ' ')
      .split(' ')
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');
}

class DetailField {
  final TextEditingController labelCtrl;
  final TextEditingController valueCtrl;
  DetailField({String label = '', String value = ''})
      : labelCtrl = TextEditingController(text: label),
        valueCtrl = TextEditingController(text: value);

  void dispose() {
    labelCtrl.dispose();
    valueCtrl.dispose();
  }
}
