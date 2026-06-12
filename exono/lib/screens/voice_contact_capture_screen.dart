import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../config/app_theme.dart';
import '../models/event.dart';
import '../services/api_service.dart';
import '../widgets/app_card.dart';
import '../widgets/app_chip.dart';
import '../widgets/app_section_label.dart';

// ── Result type ────────────────────────────────────────────────────────────────

class VoiceContactResult {
  final String savedName;
  const VoiceContactResult(this.savedName);
}

// ── Phase enum ─────────────────────────────────────────────────────────────────

enum _Phase { recording, transcribing, review }

// ── Screen ─────────────────────────────────────────────────────────────────────

class VoiceContactCaptureScreen extends StatefulWidget {
  const VoiceContactCaptureScreen({super.key});

  @override
  State<VoiceContactCaptureScreen> createState() =>
      _VoiceContactCaptureScreenState();
}

class _VoiceContactCaptureScreenState extends State<VoiceContactCaptureScreen>
    with TickerProviderStateMixin {
  ExonoColors get _c => AppTheme.colorsOf(context);

  // ── Phase ────────────────────────────────────────────────────
  _Phase _phase = _Phase.recording;

  // ── Recording ────────────────────────────────────────────────
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  Timer? _recTimer;
  Duration _recDuration = Duration.zero;
  double _amplitude = 0.0;
  StreamSubscription<Amplitude>? _ampSub;

  // ── Transcript ───────────────────────────────────────────────
  String _transcript = '';

  // ── Animations ───────────────────────────────────────────────
  late final AnimationController _pulseCtrl1;
  late final AnimationController _pulseCtrl2;
  late final AnimationController _waveCtrl;

  // ── Contact field controllers ─────────────────────────────────
  final _fnCtrl    = TextEditingController();
  final _lnCtrl    = TextEditingController();
  final _coCtrl    = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();

  // ── Events ───────────────────────────────────────────────────
  List<Event> _events = [];
  String? _eventId;

  // ── Save state ───────────────────────────────────────────────
  bool _isSaving = false;
  bool _saved = false;

  // ── Dedup ────────────────────────────────────────────────────
  bool _showDedup = false;
  List<Map<String, dynamic>> _dupes = [];

  // ── Transcript card ──────────────────────────────────────────
  bool _transcriptExpanded = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl1 = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _pulseCtrl2 = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward().then((_) {
        _pulseCtrl2.repeat();
      });
    // offset second ring by 700ms
    Future<void>.delayed(const Duration(milliseconds: 700), () {
      if (mounted) _pulseCtrl2.repeat();
    });
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _loadEvents();
  }

  @override
  void dispose() {
    _pulseCtrl1.dispose();
    _pulseCtrl2.dispose();
    _waveCtrl.dispose();
    _recTimer?.cancel();
    _ampSub?.cancel();
    _recorder.dispose();
    _fnCtrl.dispose();
    _lnCtrl.dispose();
    _coCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    try {
      final events = await ApiService.getEvents();
      if (!mounted) return;
      setState(() {
        _events = events;
        if (events.isNotEmpty) _eventId = events.first.id;
      });
    } catch (_) {}
  }

  // ════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _c.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: _phase == _Phase.review
                      ? _buildReviewBody()
                      : _buildRecordingBody(),
                ),
              ],
            ),
          ),
          if (_phase == _Phase.review)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildFixedSaveBar(),
            ),
          if (_showDedup) _buildDedupSheet(),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // HEADER
  // ════════════════════════════════════════════════════════════

  Widget _buildHeader() {
    return Material(
      color: _c.navBackground,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: _c.border)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            IconButton(
              onPressed: _onBack,
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: _c.textPrimary,
                size: 18,
              ),
              tooltip: _phase == _Phase.review ? 'Retake' : 'Back',
            ),
            const Spacer(),
            if (_phase == _Phase.review) ...[
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'REVIEW CONTACT',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.8,
                      color: _c.textPrimary,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Verify extracted details',
                    style: TextStyle(fontSize: 10, color: _c.textMuted),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close_rounded, color: _c.accent, size: 20),
                tooltip: 'Close',
              ),
            ] else ...[
              const Spacer(),
            ],
          ],
        ),
      ),
    );
  }

  void _onBack() {
    if (_phase == _Phase.review) {
      // Go back to recording phase (retake)
      setState(() {
        _phase = _Phase.recording;
        _transcript = '';
        _isRecording = false;
        _recDuration = Duration.zero;
        _amplitude = 0.0;
        _fnCtrl.clear();
        _lnCtrl.clear();
        _coCtrl.clear();
        _emailCtrl.clear();
        _phoneCtrl.clear();
        _titleCtrl.clear();
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  // ════════════════════════════════════════════════════════════
  // RECORDING / TRANSCRIBING BODY
  // ════════════════════════════════════════════════════════════

  Widget _buildRecordingBody() {
    if (_phase == _Phase.transcribing) return _buildTranscribingBody();

    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height
              - MediaQuery.of(context).padding.top
              - 56, // header height
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // ── Intro (fades when recording) ──────────────────
            AnimatedOpacity(
              opacity: _isRecording ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 320),
              child: _buildIntroSection(),
            ),

            // ── Mic + live recording info ──────────────────────
            Column(
              children: [
                _buildMicButton(),
                const SizedBox(height: 28),

                // Timer — shown while recording
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: _isRecording
                      ? Text(
                          _fmtDur(_recDuration),
                          key: const ValueKey('timer'),
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 6,
                            color: _c.textPrimary,
                          ),
                        )
                      : const SizedBox(key: ValueKey('no-timer'), height: 44),
                ),

                const SizedBox(height: 16),

                // Waveform — shown while recording
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: _isRecording
                      ? _buildWaveform(key: const ValueKey('wave'))
                      : const SizedBox(key: ValueKey('no-wave'), height: 36),
                ),

                const SizedBox(height: 14),

                // Status pill
                _buildStatusPill(),
              ],
            ),

            // ── Bottom section ────────────────────────────────
            Column(
              children: [
                _buildRecordingBottomRow(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntroSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
      child: Column(
        children: [
          // Icon badge
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _c.accentSoft,
              border: Border.all(color: _c.accent.withValues(alpha: 0.3)),
            ),
            child: Icon(Icons.record_voice_over_rounded, color: _c.accent, size: 22),
          ),
          const SizedBox(height: 16),
          Text(
            'Capture Contact\nby Voice',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              height: 1.2,
              color: _c.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Text(
              'Speak naturally about the person you just met. Our AI will extract their details automatically.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.55,
                color: _c.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _isRecording
            ? _c.destructive.withValues(alpha: 0.12)
            : _c.accentSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: _isRecording
              ? _c.destructive.withValues(alpha: 0.35)
              : _c.accent.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 7, height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isRecording ? _c.destructive : _c.accent,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _isRecording ? 'RECORDING — TAP TO STOP' : 'TAP MIC TO START',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
              color: _isRecording ? _c.destructive : _c.accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMicButton() {
    return SizedBox(
      width: 180,
      height: 180,
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulseCtrl1, _pulseCtrl2]),
        builder: (context, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Outer pulse ring 2 (offset)
              if (_isRecording)
                _buildPulseRing(
                  _pulseCtrl2.value,
                  baseRadius: 54,
                  maxRadius: 88,
                  baseAlpha: 0.18,
                ),
              // Outer pulse ring 1
              if (_isRecording)
                _buildPulseRing(
                  _pulseCtrl1.value,
                  baseRadius: 54,
                  maxRadius: 88,
                  baseAlpha: 0.25,
                ),
              // Main button
              GestureDetector(
                onTap: _toggleRecording,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  width: 108,
                  height: 108,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: _isRecording
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [_c.destructive, _c.destructive],
                          )
                        : LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [_c.accent, _c.accentStrong],
                          ),
                    boxShadow: [
                      BoxShadow(
                        color: _isRecording
                            ? _c.destructive.withValues(alpha: 0.4)
                            : _c.accent.withValues(alpha: 0.5),
                        blurRadius: 28,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Icon(
                    _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                    size: 44,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPulseRing(
    double t, {
    required double baseRadius,
    required double maxRadius,
    required double baseAlpha,
  }) {
    final radius = baseRadius + t * (maxRadius - baseRadius);
    final alpha = baseAlpha * (1.0 - t);
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: _c.destructive.withValues(alpha: alpha.clamp(0.0, 1.0)),
          width: 2,
        ),
      ),
    );
  }

  Widget _buildWaveform({Key? key}) {
    return SizedBox(
      key: key,
      height: 48,
      child: AnimatedBuilder(
        animation: _waveCtrl,
        builder: (context, _) {
          // Blend sine-wave animation with live amplitude (min 0.15 so bars are visible)
          final amp = math.max(_amplitude, 0.15);
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(13, (i) {
              final phase = _waveCtrl.value * math.pi * 2 + i * 0.6;
              final wave = math.sin(phase).abs();
              final isCenter = i >= 4 && i <= 8;
              final h = (6.0 + wave * 34.0 * amp).clamp(6.0, 40.0);
              return AnimatedContainer(
                duration: const Duration(milliseconds: 60),
                width: isCenter ? 5.0 : 4.0,
                height: h,
                margin: const EdgeInsets.symmetric(horizontal: 2.0),
                decoration: BoxDecoration(
                  color: _c.destructive,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  Widget _buildRecordingBottomRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: FButton(variant: FButtonVariant.outline, 
                  onPress: _goManual,
                  prefix: const Icon(Icons.edit_note_outlined, size: 16),
                  child: const Text('MANUAL ENTRY'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FButton(variant: FButtonVariant.ghost, 
            onPress: () => Navigator.of(context).pop(),
            child: Text(
              'CANCEL',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.8,
                color: _c.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranscribingBody() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pulsing AI orb
            AnimatedBuilder(
              animation: _pulseCtrl1,
              builder: (context, _) {
                final glow = 0.3 + _pulseCtrl1.value * 0.4;
                return Container(
                  width: 96, height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_c.accent, _c.accentStrong],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _c.accent.withValues(alpha: glow),
                        blurRadius: 36,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 38),
                );
              },
            ),
            const SizedBox(height: 32),
            Text(
              'ANALYSING',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 3.5,
                color: _c.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Transcribing and extracting\ncontact details from your recording…',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.55, color: _c.textMuted),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 160,
              child: FProgress(),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // REVIEW BODY
  // ════════════════════════════════════════════════════════════

  Widget _buildReviewBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildContactHeroCard(),
          const SizedBox(height: 20),
          AppSectionLabel('Work'),
          const SizedBox(height: 10),
          _buildWorkCard(),
          const SizedBox(height: 20),
          AppSectionLabel('Contact Info'),
          const SizedBox(height: 10),
          _buildContactInfoCard(),
          if (_events.isNotEmpty) ...[
            const SizedBox(height: 20),
            AppSectionLabel('Event'),
            const SizedBox(height: 10),
            _buildEventSelector(),
          ],
          const SizedBox(height: 20),
          _buildTranscriptCard(),
        ],
      ),
    );
  }

  Widget _buildContactHeroCard() {
    final fn = _fnCtrl.text;
    final ln = _lnCtrl.text;
    final initials = (fn.isNotEmpty ? fn[0] : '') + (ln.isNotEmpty ? ln[0] : '');
    final subtitle = [_titleCtrl.text, _coCtrl.text]
        .where((s) => s.isNotEmpty)
        .join(' · ');

    return AppCard(
      radius: 28,
      padding: const EdgeInsets.all(20),
      borderColor: _c.accent.withValues(alpha: 0.22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_c.accent, _c.accentStrong],
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  initials.toUpperCase().isEmpty ? '?' : initials.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppChip.label(
                                'AI Extracted',
                                color: _c.accentSoft,
                                textColor: _c.accent,
                              ),
                              const SizedBox(height: 8),
                              _inlineField(_fnCtrl, 'First name', fontSize: 22, bold: true),
                              const SizedBox(height: 2),
                              _inlineField(_lnCtrl, 'Last name', fontSize: 15),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _onBack,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: _c.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.refresh_rounded, size: 11, color: _c.accent),
                                const SizedBox(width: 4),
                                Text(
                                  'RETAKE',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                    color: _c.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 12, color: _c.textMuted, height: 1.3),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWorkCard() {
    return AppCard(
      elevated: true,
      radius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          _fieldRow(Icons.business_outlined, _coCtrl, 'Company'),
          FDivider(),
          _fieldRow(Icons.work_outline_rounded, _titleCtrl, 'Job title'),
        ],
      ),
    );
  }

  Widget _buildContactInfoCard() {
    return AppCard(
      elevated: true,
      radius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          _fieldRow(Icons.email_outlined, _emailCtrl, 'Email', kbd: TextInputType.emailAddress),
          FDivider(),
          _fieldRow(Icons.phone_outlined, _phoneCtrl, 'Phone', kbd: TextInputType.phone),
        ],
      ),
    );
  }

  Widget _fieldRow(
    IconData icon,
    TextEditingController ctrl,
    String hint, {
    TextInputType? kbd,
  }) {
    return SizedBox(
      height: 50,
      child: Row(
        children: [
          Icon(icon, size: 15, color: _c.accent),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: ctrl,
              keyboardType: kbd,
              style: TextStyle(fontSize: 14, color: _c.textPrimary),
              cursorColor: _c.accent,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(fontSize: 14, color: _c.textMuted),
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventSelector() {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(Icons.event_outlined, size: 15, color: _c.accent),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _eventId,
                isExpanded: true,
                dropdownColor: _c.surfaceAlt,
                icon: Icon(Icons.expand_more, color: _c.accent, size: 18),
                style: TextStyle(fontSize: 14, color: _c.textPrimary),
                hint: Text(
                  'Select event',
                  style: TextStyle(color: _c.textMuted, fontSize: 14),
                ),
                items: _events
                    .map(
                      (e) => DropdownMenuItem(value: e.id, child: Text(e.name)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _eventId = v),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptCard() {
    final hasText = _transcript.isNotEmpty;
    final preview = hasText
        ? (_transcript.length > 110 ? '${_transcript.substring(0, 110)}…' : _transcript)
        : 'No transcript available.';
    final showToggle = hasText && _transcript.length > 110;

    return AppCard(
      elevated: true,
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.mic_none_rounded, size: 14, color: _c.accent),
              const SizedBox(width: 8),
              AppSectionLabel('Transcript', color: _c.accent),
              const Spacer(),
              if (showToggle)
                GestureDetector(
                  onTap: () => setState(() => _transcriptExpanded = !_transcriptExpanded),
                  child: Text(
                    _transcriptExpanded ? 'LESS' : 'MORE',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: _c.accent,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _transcriptExpanded ? _transcript : preview,
            style: TextStyle(
              fontSize: 13,
              color: _c.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // FIXED SAVE BAR
  // ════════════════════════════════════════════════════════════

  Widget _buildFixedSaveBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16, 14, 16,
        MediaQuery.of(context).padding.bottom + 14,
      ),
      decoration: BoxDecoration(
        color: _c.navBackground,
        border: Border(top: BorderSide(color: _c.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FButton(variant: FButtonVariant.primary, 
              onPress: (_isSaving || _saved) ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: FCircularProgress(),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_saved ? Icons.check_circle_outline_rounded : Icons.person_add_outlined, size: 18),
                        const SizedBox(width: 10),
                        Text(
                          _saved ? 'CONTACT SAVED' : 'SAVE CONTACT',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.8,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 6),
          FButton(variant: FButtonVariant.ghost, 
            onPress: _onBack,
            child: Text(
              'RETAKE RECORDING',
              style: TextStyle(
                fontSize: 10,
                color: _c.textMuted,
                letterSpacing: 1.6,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // DEDUP SHEET
  // ════════════════════════════════════════════════════════════

  Widget _buildDedupSheet() {
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () {},
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.6)),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Material(
              color: _c.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _c.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: _c.accent,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Possible duplicate detected',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: _c.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          if (_dupes.isNotEmpty) ...[
                            AppSectionLabel('Existing record'),
                            const SizedBox(height: 10),
                            AppCard(
                              elevated: true,
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${_dupes.first['first_name'] ?? ''} ${_dupes.first['last_name'] ?? ''}'
                                        .trim(),
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: _c.textPrimary,
                                    ),
                                  ),
                                  if (_dupes.first['email'] != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      _dupes.first['email'] as String,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: _c.textSecondary,
                                      ),
                                    ),
                                  ],
                                  if (_dupes.first['company'] != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      (_dupes.first['company'] as Map?)?['name'] ?? '',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _c.textMuted,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      0,
                      20,
                      MediaQuery.of(context).padding.bottom + 16,
                    ),
                    child: Column(
                      children: [
                        _dedupAction(
                          'MERGE WITH EXISTING',
                          primary: true,
                          onTap: () => _resolveDuplicateAndSave(merge: true),
                        ),
                        const SizedBox(height: 10),
                        _dedupAction(
                          'CREATE AS NEW CONTACT',
                          onTap: () => _resolveDuplicateAndSave(merge: false),
                        ),
                        const SizedBox(height: 10),
                        FButton(variant: FButtonVariant.ghost, 
                          onPress: () => setState(() => _showDedup = false),
                          child: Text(
                            'CANCEL',
                            style: TextStyle(
                              fontSize: 11,
                              color: _c.textMuted,
                              letterSpacing: 1.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dedupAction(
    String label, {
    required VoidCallback onTap,
    bool primary = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FButton(variant: FButtonVariant.primary, 
        onPress: onTap,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // SHARED WIDGETS
  // ════════════════════════════════════════════════════════════


  Widget _inlineField(
    TextEditingController ctrl,
    String hint, {
    double fontSize = 14,
    bool bold = false,
  }) {
    return TextField(
      controller: ctrl,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
        color: _c.textPrimary,
      ),
      cursorColor: _c.accent,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: fontSize, color: _c.textMuted),
        isDense: true,
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  // ════════════════════════════════════════════════════════════
  // ACTIONS
  // ════════════════════════════════════════════════════════════

  Future<void> _toggleRecording() async {
    try {
      if (_isRecording) {
        _recTimer?.cancel();
        await _ampSub?.cancel();
        _ampSub = null;
        final path = await _recorder.stop();
        setState(() {
          _isRecording = false;
          _amplitude = 0.0;
          _phase = _Phase.transcribing;
        });
        if (path != null) {
          await _transcribeAndParse(path);
        } else {
          if (mounted) setState(() => _phase = _Phase.recording);
        }
        return;
      }

      // permission_handler is not supported on web — browser asks natively
      if (!kIsWeb) {
        final granted = await Permission.microphone.request();
        if (!granted.isGranted) {
          if (mounted) {
            showFToast(context: context, title: Text('Microphone permission required'));
          }
          return;
        }
      }

      // path_provider is not supported on web; record ignores path on web anyway
      final String recPath;
      if (kIsWeb) {
        recPath = 'voice_contact_${DateTime.now().millisecondsSinceEpoch}.m4a';
      } else {
        final dir = await getTemporaryDirectory();
        recPath = '${dir.path}/voice_contact_${DateTime.now().millisecondsSinceEpoch}.m4a';
      }

      // Browsers don't support AAC — use Opus (webm) on web
      final config = kIsWeb
          ? const RecordConfig(encoder: AudioEncoder.opus)
          : const RecordConfig();
      await _recorder.start(config, path: recPath);

      _ampSub = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 80))
          .listen((amp) {
        if (!mounted) return;
        // amp.current is dBFS (-160..0); treat -50 dBFS as quiet
        final normalized = ((amp.current + 50) / 50).clamp(0.0, 1.0);
        setState(() => _amplitude = normalized.toDouble());
      });

      setState(() {
        _isRecording = true;
        _recDuration = Duration.zero;
      });

      _recTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _recDuration += const Duration(seconds: 1));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isRecording = false;
        _amplitude = 0.0;
        _phase = _Phase.recording;
      });
      showFToast(context: context, title: Text('Could not start recording: $e'));
    }
  }

  Future<void> _transcribeAndParse(String path) async {
    try {
      final Uint8List bytes;
      if (kIsWeb) {
        // On web, record returns a blob URL; fetch it with http
        final response = await http.get(Uri.parse(path));
        bytes = response.bodyBytes;
      } else {
        bytes = await File(path).readAsBytes();
      }
      final b64 = base64Encode(bytes);
      final transcript = await ApiService.transcribeAudio(b64);
      if (!mounted) return;
      _transcript = transcript;
      _parseTranscript(transcript);
      setState(() => _phase = _Phase.review);
    } catch (e) {
      if (!mounted) return;
      setState(() => _phase = _Phase.recording);
      showFToast(context: context, title: Text('Transcription failed: $e'));
    }
  }

  void _parseTranscript(String text) {
    // Email
    final emailRe = RegExp(r'\b[\w.+-]+@[\w-]+\.\w+\b');
    final emailMatch = emailRe.firstMatch(text);
    if (emailMatch != null) _emailCtrl.text = emailMatch.group(0)!.trim();

    // Phone
    final phoneRe = RegExp(r'\+?[\d\s\-().]{7,}');
    final phoneMatch = phoneRe.firstMatch(text);
    if (phoneMatch != null) _phoneCtrl.text = phoneMatch.group(0)!.trim();

    // Company
    final companyRe = RegExp(
      r'(?:from|at|work(?:s)? at|company(?:\s+is)?)\s+([A-Z][A-Za-z\s&.]+?)(?:\.|,|\s+and|\s+I|\s+my|\s+as|\s+where|$)',
    );
    final companyMatch = companyRe.firstMatch(text);
    if (companyMatch != null) {
      _coCtrl.text = companyMatch.group(1)!.trim();
    }

    // Title
    final titleRe = RegExp(
      r'(?:I am a|I.m a|role is|position is|work(?:ing)? as)\s+([A-Za-z\s]+?)(?:\.|,|\s+at|\s+in|\s+and|$)',
    );
    final titleMatch = titleRe.firstMatch(text);
    if (titleMatch != null) {
      _titleCtrl.text = titleMatch.group(1)!.trim();
    }

    // Name — try "I'm X Y", "my name is X Y", "name is X Y" first
    final nameExplicit = RegExp(
      r"(?:I'm|I am|my name is|name is)\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)?)",
    );
    final nameExplicitMatch = nameExplicit.firstMatch(text);
    if (nameExplicitMatch != null) {
      final parts = nameExplicitMatch.group(1)!.trim().split(' ');
      _fnCtrl.text = parts.first;
      if (parts.length > 1) _lnCtrl.text = parts.skip(1).join(' ');
      return;
    }

    // Fallback: first two capitalized consecutive words
    final nameAuto = RegExp(r'\b([A-Z][a-z]+)\s+([A-Z][a-z]+)\b');
    final nameAutoMatch = nameAuto.firstMatch(text);
    if (nameAutoMatch != null) {
      _fnCtrl.text = nameAutoMatch.group(1)!;
      _lnCtrl.text = nameAutoMatch.group(2)!;
    }
  }

  void _goManual() {
    // Pop this screen — parent scan page will open manual entry
    Navigator.of(context).pop();
  }

  Future<void> _save() async {
    final name =
        '${_fnCtrl.text.trim()} ${_lnCtrl.text.trim()}'.trim();
    if (name.isEmpty) {
      showFToast(context: context, title: Text('Enter at least a name'));
      return;
    }
    setState(() => _isSaving = true);
    try {
      final dupResult = await ApiService.checkDuplicateContacts(
        name: name,
        email: _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
      );
      if (!mounted) return;
      if (dupResult['has_duplicates'] == true) {
        setState(() {
          _dupes = List<Map<String, dynamic>>.from(
            dupResult['data'] as List? ?? [],
          );
          _isSaving = false;
          _showDedup = true;
        });
        return;
      }
      await _doSave();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
    }
  }

  Future<void> _doSave() async {
    try {
      await ApiService.createCapture(
        captureType: 'voice',
        rawText: _transcript.isNotEmpty ? _transcript : null,
        eventId: _eventId,
        extractedData: {
          'first_name': _fnCtrl.text.trim(),
          'last_name': _lnCtrl.text.trim(),
          'name':
              '${_fnCtrl.text.trim()} ${_lnCtrl.text.trim()}'.trim(),
          'company': _coCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim(),
          'job_title': _titleCtrl.text.trim(),
        },
      );
      if (!mounted) return;
      final savedName =
          '${_fnCtrl.text.trim()} ${_lnCtrl.text.trim()}'.trim();
      setState(() {
        _saved = true;
        _isSaving = false;
        _showDedup = false;
      });
      await Future<void>.delayed(const Duration(milliseconds: 1600));
      if (!mounted) return;
      Navigator.of(context).pop(VoiceContactResult(savedName));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _saved = false;
      });
    }
  }

  Future<void> _resolveDuplicateAndSave({required bool merge}) async {
    setState(() {
      _showDedup = false;
      _isSaving = true;
    });
    await _doSave();
  }

  // ── Helpers ────────────────────────────────────────────────

  String _fmtDur(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
