import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

import '../config/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/app_card.dart';
import '../widgets/app_input.dart';
import '../widgets/app_section_label.dart';
import '../utils/screen_logger.dart';

Future<bool> showLogInteractionSheet(
  BuildContext context, {
  String? contactId,
  String? initialMode,
  VoidCallback? onSaved,
}) async {
  if (contactId == null || contactId.isEmpty) {
    showFToast(
      context: context,
      title: const Text('No contact linked — interaction cannot be saved.'),
      variant: FToastVariant.destructive,
    );
    return false;
  }
  final saved = await showFSheet<bool>(
    context: context,
    side: FLayout.btt,
    builder: (_) => _LogInteractionSheet(contactId: contactId, initialMode: initialMode),
  );
  if (saved == true) {
    onSaved?.call();
    return true;
  }
  return false;
}

// ── Sheet ──────────────────────────────────────────────────────────────────────

class _LogInteractionSheet extends StatefulWidget {
  final String contactId;
  final String? initialMode;
  const _LogInteractionSheet({required this.contactId, this.initialMode});

  @override
  State<_LogInteractionSheet> createState() => _LogInteractionSheetState();
}

class _LogInteractionSheetState extends State<_LogInteractionSheet> with ScreenLogger {
  ExonoColors get _c => AppTheme.colorsOf(context);

  late final TextEditingController _modeController;
  final _notesController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  // ── Voice recording ──────────────────────────────────────────────────────────
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _isVoiceMode = false;
  Duration _recDuration = Duration.zero;
  Timer? _recTimer;
  String? _recordingPath;
  double _amplitude = 0.0;
  StreamSubscription<Amplitude>? _ampSub;

  @override
  void initState() {
    super.initState();
    _modeController = TextEditingController(text: widget.initialMode ?? '');
  }

  @override
  void dispose() {
    _modeController.dispose();
    _notesController.dispose();
    _recTimer?.cancel();
    _ampSub?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  // ── Voice ──────────────────────────────────────────────────────────────────

  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      if (mounted) {
        showFToast(
          context: context,
          title: const Text('Microphone permission required'),
          variant: FToastVariant.destructive,
        );
      }
      return;
    }

    final dir = await getTemporaryDirectory();
    _recordingPath = '${dir.path}/voice_note_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000, sampleRate: 16000),
      path: _recordingPath!,
    );

    _ampSub = _recorder.onAmplitudeChanged(const Duration(milliseconds: 100)).listen((amp) {
      if (mounted) setState(() => _amplitude = ((amp.current + 60) / 60).clamp(0.0, 1.0));
    });

    _recTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _recDuration += const Duration(seconds: 1));
    });

    setState(() { _isRecording = true; _recDuration = Duration.zero; });
  }

  Future<void> _stopRecording() async {
    _recTimer?.cancel();
    _ampSub?.cancel();
    await _recorder.stop();
    setState(() { _isRecording = false; _amplitude = 0; });
  }

  Future<void> _saveVoiceNote() async {
    if (_recordingPath == null) return;
    setState(() => _isSaving = true);

    try {
      // 1. Read audio file
      final audioBytes = await File(_recordingPath!).readAsBytes();
      final base64Audio = base64Encode(audioBytes);

      // 2. Post the interaction immediately with placeholder summary
      final result = await ApiService.logInteraction(
        contactId: widget.contactId,
        type: 'voice_note',
        summary: '🎙 Voice note — transcript pending...',
        interactionDate: _selectedDate.toIso8601String(),
        details: {'duration_seconds': _recDuration.inSeconds, 'has_audio': true},
      );

      final interactionId = result['data']?['id'] as String?;

      if (mounted) {
        Navigator.of(context).pop(true);
      }

      // 3. Transcribe in background — no await, fire and forget
      if (interactionId != null) {
        _transcribeInBackground(interactionId, base64Audio);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        showFToast(
          context: context,
          title: Text('Failed to save: $e'),
          variant: FToastVariant.destructive,
        );
      }
    }
  }

  void _transcribeInBackground(String interactionId, String base64Audio) {
    ApiService.transcribeAudio(base64Audio).then((transcript) {
      if (transcript.isNotEmpty) {
        ApiService.updateInteraction(interactionId, {
          'summary': transcript,
          'details': {'has_audio': true, 'transcript': transcript},
        });
      }
    }).catchError((_) {});
  }

  // ── Text save ─────────────────────────────────────────────────────────────

  Future<void> _saveInteraction() async {
    final notes = _notesController.text.trim();
    if (notes.isEmpty) {
      showFToast(
        context: context,
        title: const Text('Please add some notes'),
        variant: FToastVariant.destructive,
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final mode = _modeController.text.trim();
      await ApiService.logInteraction(
        contactId: widget.contactId,
        type: mode.isNotEmpty ? mode.toLowerCase().replaceAll(' ', '_') : 'manual',
        summary: notes,
        interactionDate: _selectedDate.toIso8601String(),
        details: mode.isNotEmpty ? {'mode': mode} : null,
      );

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        showFToast(
          context: context,
          title: Text('Failed to save: $e'),
          variant: FToastVariant.destructive,
        );
      }
    }
  }

  // ── Date picker ──────────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        final c = AppTheme.colorsOf(context);
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              surface: c.surfaceAlt,
              primary: c.accent,
              onPrimary: Colors.white,
              onSurface: c.textSecondary,
            ),
            dialogTheme: DialogThemeData(backgroundColor: c.background),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) return 'Today';
    if (d.year == now.year && d.month == now.month && d.day == now.day - 1) return 'Yesterday';
    return '${d.day}/${d.month}/${d.year}';
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 420, maxHeight: mediaQuery.size.height * 0.92),
            child: Container(
              decoration: BoxDecoration(
                color: _c.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(
                  top: BorderSide(color: _c.border),
                  left: BorderSide(color: _c.border),
                  right: BorderSide(color: _c.border),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: _c.border,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Log Interaction',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.4,
                              color: _c.textPrimary,
                            ),
                          ),
                        ),
                        // Voice / text toggle
                        GestureDetector(
                          onTap: () {
                            if (_isRecording) return;
                            setState(() => _isVoiceMode = !_isVoiceMode);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: _isVoiceMode ? _c.accent : _c.surfaceElevated,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: _isVoiceMode ? _c.accent : _c.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _isVoiceMode ? Icons.mic : Icons.mic_none_outlined,
                                  size: 14,
                                  color: _isVoiceMode ? Colors.white : _c.textMuted,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'VOICE',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.2,
                                    color: _isVoiceMode ? Colors.white : _c.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                      child: _isVoiceMode ? _buildVoiceContent() : _buildTextContent(),
                    ),
                  ),
                  _buildSaveButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Text content ──────────────────────────────────────────────────────────

  Widget _buildTextContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionLabel('Date'),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickDate,
          child: AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            radius: 12,
            elevated: true,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _formatDate(_selectedDate),
                    style: TextStyle(fontSize: 14, color: _c.textSecondary),
                  ),
                ),
                Icon(Icons.calendar_today_outlined, size: 16, color: _c.accent),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        AppSectionLabel('Mode of Interaction'),
        const SizedBox(height: 8),
        AppInput(
          controller: _modeController,
          hint: 'e.g. Coffee chat, WhatsApp, Call...',
        ),
        const SizedBox(height: 20),
        AppSectionLabel('What happened?'),
        const SizedBox(height: 8),
        AppInput(
          controller: _notesController,
          minLines: 5,
          maxLines: 8,
          hint: 'Key discussion points, decisions, next steps...',
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ── Voice content ─────────────────────────────────────────────────────────

  Widget _buildVoiceContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionLabel('Date'),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _isRecording ? null : _pickDate,
          child: AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            radius: 12,
            elevated: true,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _formatDate(_selectedDate),
                    style: TextStyle(fontSize: 14, color: _c.textSecondary),
                  ),
                ),
                Icon(Icons.calendar_today_outlined, size: 16, color: _c.accent),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
        Center(
          child: AppCard(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
            radius: 20,
            child: Column(
              children: [
                // Waveform visualiser — simple amplitude bars
                SizedBox(
                  height: 48,
                  child: _isRecording
                      ? _buildWaveform()
                      : _recordingPath != null
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_outline, color: _c.success, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Recording ready  (${_formatDuration(_recDuration)})',
                                  style: TextStyle(fontSize: 13, color: _c.textSecondary),
                                ),
                              ],
                            )
                          : Text(
                              'Tap to start recording',
                              style: TextStyle(fontSize: 13, color: _c.textMuted),
                            ),
                ),
                const SizedBox(height: 20),
                // Timer
                if (_isRecording) ...[
                  Text(
                    _formatDuration(_recDuration),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      color: _c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                // Record / stop button
                GestureDetector(
                  onTap: _isRecording ? _stopRecording : (_recordingPath == null ? _startRecording : null),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isRecording ? _c.destructive : _c.accent,
                    ),
                    child: Icon(
                      _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
                if (!_isRecording && _recordingPath != null) ...[
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () {
                      setState(() { _recordingPath = null; _recDuration = Duration.zero; });
                    },
                    child: Text(
                      'Record again',
                      style: TextStyle(fontSize: 12, color: _c.textMuted, decoration: TextDecoration.underline),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 13, color: _c.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Voice note is saved instantly. Transcript is generated in background.',
                  style: TextStyle(fontSize: 12, color: _c.textMuted, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildWaveform() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: List.generate(20, (i) {
        final center = 9.5;
        final dist = (i - center).abs() / center;
        final base = 0.15 + (1 - dist) * 0.4;
        final height = (base + _amplitude * (1 - dist) * 0.45).clamp(0.05, 1.0);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: 3,
            height: 48 * height,
            decoration: BoxDecoration(
              color: _c.accent.withValues(alpha: 0.7 + height * 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }

  // ── Save button ────────────────────────────────────────────────────────────

  Widget _buildSaveButton() {
    final canSave = _isVoiceMode
        ? (_recordingPath != null && !_isRecording && !_isSaving)
        : !_isSaving;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: FButton(
          variant: FButtonVariant.primary,
          onPress: canSave ? (_isVoiceMode ? _saveVoiceNote : _saveInteraction) : null,
          child: _isSaving
              ? const FCircularProgress()
              : Text(
                  _isVoiceMode ? 'SAVE VOICE NOTE' : 'SAVE TO TIMELINE',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}
