import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';
import '../widgets/app_feedback.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

import '../config/app_theme.dart';
import '../models/contact.dart';
import '../providers/sync_provider.dart';
import '../services/api_service.dart';
import '../widgets/app_avatar.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_input.dart';
import '../widgets/app_section_label.dart';
import '../utils/screen_logger.dart';

Future<bool> showLogInteractionSheet(
  BuildContext context, {
  String? contactId,
  String? initialMode,
  VoidCallback? onSaved,
  // When set, auto-marks the contact as met in the event after saving
  Future<void> Function()? onMarkedMet,
}) async {
  final saved = await showAppSheet<bool>(
    context: context,
    side: FLayout.btt,
    builder: (_) => _LogInteractionSheet(contactId: contactId, initialMode: initialMode),
  );
  if (saved == true) {
    onSaved?.call();
    onMarkedMet?.call();
    return true;
  }
  return false;
}

// ── Sheet ──────────────────────────────────────────────────────────────────────

class _LogInteractionSheet extends StatefulWidget {
  final String? contactId;
  final String? initialMode;
  const _LogInteractionSheet({this.contactId, this.initialMode});

  @override
  State<_LogInteractionSheet> createState() => _LogInteractionSheetState();
}

class _LogInteractionSheetState extends State<_LogInteractionSheet> with ScreenLogger {
  ExonoColors get _c => AppTheme.colorsOf(context);

  late final TextEditingController _modeController;
  final _notesController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  // ── Contact selection (when no contactId pre-supplied) ────────────────────
  String? _pickedContactId;
  String? _pickedContactName;
  List<Contact>? _contacts;
  bool _loadingContacts = false;

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
      if (mounted) showAppToast(context, 'Microphone permission required');
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

  String? get _effectiveContactId => widget.contactId ?? _pickedContactId;

  Future<void> _saveVoiceNote() async {
    if (_recordingPath == null) return;
    setState(() => _isSaving = true);

    try {
      // 1. Read audio file
      final audioBytes = await File(_recordingPath!).readAsBytes();
      final base64Audio = base64Encode(audioBytes);

      // 2. Post the interaction immediately with placeholder summary
      final result = await ApiService.logInteraction(
        contactId: _effectiveContactId!,
        type: 'voice_note',
        summary: '🎙 Voice note — transcript pending...',
        interactionDate: _selectedDate.toIso8601String(),
        details: {'duration_seconds': _recDuration.inSeconds, 'has_audio': true},
      );

      final interactionId = result['data']?['id'] as String?;

      if (mounted) {
        showAppToast(context, 'Interaction logged.');
        Navigator.of(context).pop(true);
      }

      // 3. Transcribe in background — no await, fire and forget
      if (interactionId != null) {
        _transcribeInBackground(interactionId, base64Audio);
      }
    } on UnauthorizedException { rethrow; } catch (_) {
      if (mounted) {
        setState(() => _isSaving = false);
        showAppToast(context, 'Failed to save. Please try again.');
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
      showAppToast(context, 'Please add some notes');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final mode = _modeController.text.trim();
      await ApiService.logInteraction(
        contactId: _effectiveContactId!,
        type: mode.isNotEmpty ? mode.toLowerCase().replaceAll(' ', '_') : 'manual',
        summary: notes,
        interactionDate: _selectedDate.toIso8601String(),
        details: mode.isNotEmpty ? {'mode': mode} : null,
      );

      if (mounted) {
        showAppToast(context, 'Interaction logged.');
        Navigator.of(context).pop(true);
      }
    } on UnauthorizedException { rethrow; } catch (_) {
      if (mounted) {
        setState(() => _isSaving = false);
        showAppToast(context, 'Failed to save. Please try again.');
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

  // ── Contact picker ────────────────────────────────────────────────────────

  Future<void> _pickContact() async {
    if (_contacts == null) {
      setState(() => _loadingContacts = true);
      try {
        _contacts = await context.read<SyncProvider>().contacts.watchAllWithCompany().first;
      } catch (_) {
        _contacts = [];
      }
      if (mounted) setState(() => _loadingContacts = false);
    }

    if (!mounted) return;
    final contacts = _contacts!;

    final picked = await showAppSheet<Contact>(
      context: context,
      side: FLayout.btt,
      builder: (ctx) => _ContactPickerSheet(contacts: contacts),
    );
    if (picked != null && mounted) {
      setState(() {
        _pickedContactId = picked.id;
        _pickedContactName = picked.fullName;
      });
    }
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

    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.theme.colors.border,
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
                      style: context.theme.typography.xl.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                        color: context.theme.colors.foreground,
                      ),
                    ),
                  ),
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
                        border: Border.all(color: _isVoiceMode ? _c.accent : context.theme.colors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isVoiceMode ? Icons.mic : Icons.mic_none_outlined,
                            size: 14,
                            color: _isVoiceMode ? Colors.white : context.theme.colors.mutedForeground,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'VOICE',
                            style: context.theme.typography.xs.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              color: _isVoiceMode ? Colors.white : context.theme.colors.mutedForeground,
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
    );
  }

  // ── Text content ──────────────────────────────────────────────────────────

  Widget _buildContactPicker() {
    if (widget.contactId != null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionLabel('Contact'),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _loadingContacts ? null : _pickContact,
          child: AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            radius: 12,
            elevated: true,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _loadingContacts
                        ? 'Loading...'
                        : (_pickedContactName ?? 'Select a contact...'),
                    style: context.theme.typography.sm.copyWith(
                      color: _pickedContactName != null
                          ? context.theme.colors.foreground
                          : context.theme.colors.mutedForeground,
                    ),
                  ),
                ),
                _loadingContacts
                    ? const SizedBox(width: 16, height: 16, child: FCircularProgress())
                    : Icon(Icons.person_search_outlined, size: 16, color: _c.accent),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildTextContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildContactPicker(),
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
                    style: context.theme.typography.sm.copyWith(
                      color: context.theme.colors.foreground),
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
        _buildContactPicker(),
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
                    style: context.theme.typography.sm.copyWith(
                      color: context.theme.colors.foreground),
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
                                  style: context.theme.typography.sm.copyWith(
                                    color: context.theme.colors.foreground),
                                ),
                              ],
                            )
                          : Text(
                              'Tap to start recording',
                              style: context.theme.typography.sm.copyWith(
                                color: context.theme.colors.mutedForeground),
                            ),
                ),
                const SizedBox(height: 20),
                // Timer
                if (_isRecording) ...[
                  Text(
                    _formatDuration(_recDuration),
                    style: context.theme.typography.xl2.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      color: context.theme.colors.foreground,
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
                      style: context.theme.typography.xs.copyWith(
                        color: context.theme.colors.mutedForeground,
                        decoration: TextDecoration.underline),
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
              Icon(Icons.info_outline, size: 13, color: context.theme.colors.mutedForeground),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Voice note is saved instantly. Transcript is generated in background.',
                  style: context.theme.typography.xs.copyWith(
                    color: context.theme.colors.mutedForeground, height: 1.4),
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
    final hasContact = _effectiveContactId != null;
    final canSave = hasContact && (_isVoiceMode
        ? (_recordingPath != null && !_isRecording && !_isSaving)
        : !_isSaving);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: AppButton(
        label: _isVoiceMode ? 'SAVE VOICE NOTE' : 'SAVE TO TIMELINE',
        onPressed: canSave ? (_isVoiceMode ? _saveVoiceNote : _saveInteraction) : null,
        variant: ButtonVariant.primary,
        fullWidth: true,
        isLoading: _isSaving,
        size: ButtonSize.lg,
      ),
    );
  }
}

// ── Contact picker sheet ───────────────────────────────────────────────────────

class _ContactPickerSheet extends StatefulWidget {
  final List<Contact> contacts;
  const _ContactPickerSheet({required this.contacts});

  @override
  State<_ContactPickerSheet> createState() => _ContactPickerSheetState();
}

class _ContactPickerSheetState extends State<_ContactPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? widget.contacts
        : widget.contacts
            .where((ct) => ct.fullName.toLowerCase().contains(_query.toLowerCase()))
            .toList();

    return SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.theme.colors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Select Contact',
                style: context.theme.typography.xl.copyWith(
                  fontWeight: FontWeight.w700,
                  color: context.theme.colors.foreground,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: AppInput(
                controller: _searchController,
                hint: 'Search contacts...',
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No contacts found',
                        style: context.theme.typography.sm.copyWith(
                          color: context.theme.colors.mutedForeground,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) {
                        final contact = filtered[i];
                        final initials = contact.firstName.isNotEmpty
                            ? (contact.firstName[0] +
                                    (contact.lastName?.isNotEmpty == true ? contact.lastName![0] : ''))
                                .toUpperCase()
                            : '?';
                        return GestureDetector(
                          onTap: () => Navigator.of(context).pop(contact),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                AppAvatar(initials: initials, size: 36),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    contact.fullName,
                                    style: context.theme.typography.sm.copyWith(
                                      color: context.theme.colors.foreground,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
