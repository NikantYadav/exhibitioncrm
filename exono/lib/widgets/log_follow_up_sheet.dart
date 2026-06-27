import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import 'app_button.dart';
import 'app_checkbox.dart';
import 'app_feedback.dart';
import 'app_input.dart';
import 'app_select.dart';

/// Result of the Log Follow-Up sheet.
class LogFollowUpResult {
  final String note;
  final String channel; // 'email' | 'call' | 'manual'
  final String mode;     // free-text mode label when channel == 'manual'
  final bool emailUsed;  // true if the user confirmed they sent the drafted email

  const LogFollowUpResult({
    required this.note,
    required this.channel,
    required this.mode,
    required this.emailUsed,
  });
}

/// Opens the shared "Log Follow-Up" bottom sheet and returns the entered data,
/// or null if dismissed. [hasDraftEmail] gates the "I sent our email" checkbox —
/// pass false on screens with no drafted email (e.g. the global Follow-Ups list).
Future<LogFollowUpResult?> showLogFollowUpSheet({
  required BuildContext context,
  required String name,
  bool hasDraftEmail = false,
}) async {
  final noteCtrl = TextEditingController();
  final modeCtrl = TextEditingController();
  LogFollowUpResult? result;
  await showAppSheet<void>(
    context: context,
    // Keyboard inset is handled centrally by showAppSheet — do not re-add it.
    builder: (ctx) => _LogFollowUpSheet(
      name: name,
      noteCtrl: noteCtrl,
      modeCtrl: modeCtrl,
      hasDraftEmail: hasDraftEmail,
      onSubmit: (r) {
        result = r;
        Navigator.of(ctx).pop();
      },
    ),
  );
  // Defer disposal one frame: the sheet's exit animation is still running when
  // the await returns, so the FTextField (and its managed control) is briefly
  // still mounted and depends on these controllers. Synchronous disposal throws
  // `_dependents.isEmpty is not true`.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    noteCtrl.dispose();
    modeCtrl.dispose();
  });
  return result;
}

class _LogFollowUpSheet extends StatefulWidget {
  final String name;
  final TextEditingController noteCtrl;
  final TextEditingController modeCtrl;
  final bool hasDraftEmail;
  final ValueChanged<LogFollowUpResult> onSubmit;

  const _LogFollowUpSheet({
    required this.name,
    required this.noteCtrl,
    required this.modeCtrl,
    required this.hasDraftEmail,
    required this.onSubmit,
  });

  @override
  State<_LogFollowUpSheet> createState() => _LogFollowUpSheetState();
}

class _LogFollowUpSheetState extends State<_LogFollowUpSheet> {
  String _channel = 'email';
  bool _emailUsed = false;

  @override
  Widget build(BuildContext context) {
    final isManual = _channel == 'manual';
    final isEmail = _channel == 'email';
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.theme.colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Log Follow-Up',
              style: context.theme.typography.xl.copyWith(
                fontWeight: FontWeight.w700,
                color: context.theme.colors.foreground,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Recording follow-up with ${widget.name}',
              style: context.theme.typography.sm.copyWith(color: context.theme.colors.mutedForeground),
            ),
            const SizedBox(height: 20),
            Text(
              'CHANNEL',
              style: context.theme.typography.xs.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  color: context.theme.colors.mutedForeground),
            ),
            const SizedBox(height: 6),
            AppSelect<String>(
              value: _channel,
              sheetTitle: 'Channel',
              items: const {'Email': 'email', 'Call': 'call', 'Manual': 'manual'},
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _channel = v;
                  if (v != 'email') _emailUsed = false;
                });
              },
            ),
            // Manual: capture the specific mode of interaction.
            if (isManual) ...[
              const SizedBox(height: 14),
              _SheetField(
                label: 'Mode of interaction',
                hint: 'e.g. Coffee Chat, LinkedIn, Meeting…',
                controller: widget.modeCtrl,
              ),
            ],
            // Email: offer to attach the drafted email we generated.
            if (isEmail && widget.hasDraftEmail) ...[
              const SizedBox(height: 14),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _emailUsed = !_emailUsed),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppCheckbox(
                      value: _emailUsed,
                      onChanged: (v) => setState(() => _emailUsed = v),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'I sent the email drafted above. Save it to this contact.',
                          style: context.theme.typography.sm.copyWith(
                              color: context.theme.colors.foreground, height: 1.35),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            _SheetField(
              label: 'Notes (optional)',
              hint: 'What did you discuss? Any commitments made?',
              controller: widget.noteCtrl,
              maxLines: 4,
            ),
            const SizedBox(height: 8),
            Text(
              'Sharing context helps our AI personalise future suggestions.',
              style: context.theme.typography.xs.copyWith(color: context.theme.colors.mutedForeground, height: 1.4),
            ),
            const SizedBox(height: 20),
            AppButton(
              label: 'CONFIRM FOLLOW-UP',
              onPressed: () => widget.onSubmit(LogFollowUpResult(
                note: widget.noteCtrl.text.trim(),
                channel: _channel,
                mode: widget.modeCtrl.text.trim(),
                emailUsed: _emailUsed,
              )),
              fullWidth: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final int maxLines;

  const _SheetField({
    required this.label,
    required this.hint,
    required this.controller,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: context.theme.typography.xs.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              color: context.theme.colors.mutedForeground),
        ),
        const SizedBox(height: 6),
        AppInput(
          controller: controller,
          maxLines: maxLines,
          hint: hint,
        ),
      ],
    );
  }
}
