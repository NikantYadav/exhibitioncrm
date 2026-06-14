import 'dart:async';
import 'dart:convert';
import 'dart:io' show File;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../models/event.dart';
import '../providers/offline_provider.dart';
import '../services/api_service.dart';
import '../services/offline/write_gateway.dart';
import '../services/web_file_picker.dart' if (dart.library.io) '../services/web_file_picker_stub.dart';
import '../widgets/app_avatar.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_feedback.dart';
import '../widgets/app_filter_row.dart';
import '../widgets/app_input.dart';
import '../widgets/app_section_label.dart';
import 'app_shell.dart';
import 'manual_entry_screen.dart';
import 'voice_contact_capture_screen.dart';
import '../utils/screen_logger.dart';

class CaptureScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigateTab;
  const CaptureScreen({super.key, this.onNavigateTab});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

enum _Stage { scan, notes }

enum _ScanMode { qr, card }

class _CaptureScreenState extends State<CaptureScreen>
    with TickerProviderStateMixin, ScreenLogger {
  ExonoColors get _c => AppTheme.colorsOf(context);

  // ── Scanner ────────────────────────────────────────────────
  final MobileScannerController _scanner = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  // ── Animations ─────────────────────────────────────────────
  late final AnimationController _lineCtrl;
  late final AnimationController _pulseCtrl;

  // ── Stage & mode ───────────────────────────────────────────
  _Stage _stage = _Stage.scan;
  _ScanMode _scanMode = _ScanMode.card;
  String _notesMode = 'Manual';

  // ── Loading states ─────────────────────────────────────────
  bool _isCapturing = false;
  bool _isAnalyzing = false;
  bool _isRecording = false;
  bool _isTranscribing = false;
  bool _isSaving = false;
  bool _saved = false;

  // ── Recording ──────────────────────────────────────────────
  final AudioRecorder _recorder = AudioRecorder();
  Timer? _recTimer;
  Duration _recDuration = Duration.zero;
  String? _recPath;

  // ── Contact fields ─────────────────────────────────────────
  final _fnCtrl    = TextEditingController();
  final _lnCtrl    = TextEditingController();
  final _coCtrl    = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _voiceCtrl = TextEditingController();

  // ── Events ─────────────────────────────────────────────────
  List<Event> _events = [];
  String? _eventId;

  // ── Dedup ──────────────────────────────────────────────────
  bool _showDedup = false;
  List<Map<String, dynamic>> _dupes = [];

  // ── Last capture ───────────────────────────────────────────
  String? _lastCapture;

  // ── Offline: raw image bytes held until save ────────────────
  Uint8List? _pendingImageBytes;

  @override
  void initState() {
    super.initState();
    _lineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _loadEvents();
  }

  @override
  void dispose() {
    _lineCtrl.dispose();
    _pulseCtrl.dispose();
    _scanner.dispose();
    _recTimer?.cancel();
    _recorder.dispose();
    _fnCtrl.dispose(); _lnCtrl.dispose(); _coCtrl.dispose();
    _emailCtrl.dispose(); _phoneCtrl.dispose(); _titleCtrl.dispose();
    _notesCtrl.dispose(); _voiceCtrl.dispose();
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
    } on UnauthorizedException { rethrow; } catch (_) {}
  }

  // ── Build ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _stage == _Stage.scan ? Colors.black : _c.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _stage == _Stage.scan ? _buildScanPage() : _buildNotesPage(),
          if (_showDedup) _buildDedupSheet(),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // SCAN PAGE
  // ════════════════════════════════════════════════════════════

  Widget _buildScanPage() {
    return Stack(
      children: [
        // Live camera
        Positioned.fill(
          child: MobileScanner(
            controller: _scanner,
            onDetect: _onQrDetected,
            fit: BoxFit.cover,
          ),
        ),
        // Top-dark + bottom-dark gradient vignette
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.74),
                  Colors.black.withValues(alpha: 0.08),
                  Colors.black.withValues(alpha: 0.88),
                ],
                stops: const [0.0, 0.44, 1.0],
              ),
            ),
          ),
        ),
        _buildFloatingTopBar(),
        _buildScanCenter(),
        _buildCaptureDock(),
        if (_isCapturing) _buildAnalyzingOverlay(),
      ],
    );
  }

  Widget _buildFloatingTopBar() {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(
            children: [
              _glassBtn(Icons.close_rounded, _close),
              const Spacer(),
              _scanTitlePill(),
              const Spacer(),
              _glassBtn(Icons.flashlight_on_rounded, () => _scanner.toggleTorch()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _glassBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _scanTitlePill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Text(
        'CAPTURE CONTACT',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.9),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 2.2,
        ),
      ),
    );
  }

  Widget _buildScanCenter() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: 76, bottom: 130),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_lastCapture != null) ...[
                _savedPill(),
                const SizedBox(height: 20),
              ],
              _scanModeTabs(),
              const SizedBox(height: 28),
              _buildFinder(),
              const SizedBox(height: 22),
              Text(
                _scanMode == _ScanMode.qr
                    ? 'ALIGN QR CODE IN FRAME'
                    : 'ALIGN BUSINESS CARD IN FRAME',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2.8,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                _scanMode == _ScanMode.qr
                    ? 'Auto-detection active'
                    : 'Tap capture when ready',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.42),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _savedPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: _c.success.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _c.success.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: 13, color: _c.success),
          const SizedBox(width: 7),
          Text(
            'Saved: $_lastCapture',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: _c.success),
          ),
        ],
      ),
    );
  }

  Widget _scanModeTabs() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _scanModeTab('QR CODE', _ScanMode.qr),
          _scanModeTab('BUSINESS CARD', _ScanMode.card),
        ],
      ),
    );
  }

  Widget _scanModeTab(String label, _ScanMode mode) {
    final active = _scanMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _scanMode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? _c.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.white.withValues(alpha: 0.5),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildFinder() {
    final isCard = _scanMode == _ScanMode.card;
    final w = isCard ? 300.0 : 250.0;
    final h = isCard ? 188.0 : 250.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
      width: w, height: h,
      child: AnimatedBuilder(
        animation: _pulseCtrl,
        builder: (context, _) {
          final glowAlpha = 0.3 + _pulseCtrl.value * 0.45;
          return Stack(
            children: [
              // Pulsing accent border
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _c.accent.withValues(alpha: glowAlpha),
                    width: 1.5,
                  ),
                ),
              ),
              // Accent corner brackets
              ..._bracketCorners(),
              // Scan line — QR mode only
              if (_scanMode == _ScanMode.qr)
                AnimatedBuilder(
                  animation: _lineCtrl,
                  builder: (ctx, _) {
                    final y = 10.0 + _lineCtrl.value * (h - 20);
                    return Positioned(
                      top: y, left: 12, right: 12,
                      child: Container(
                        height: 2,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              _c.accent.withValues(alpha: 0.9),
                              Colors.transparent,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _bracketCorners() {
    Widget corner(Alignment a, bool top, bool left) => Align(
      alignment: a,
      child: SizedBox(
        width: 24, height: 24,
        child: CustomPaint(
          painter: _BracketPainter(color: _c.accent, top: top, left: left),
        ),
      ),
    );
    return [
      corner(Alignment.topLeft, true, true),
      corner(Alignment.topRight, true, false),
      corner(Alignment.bottomLeft, false, true),
      corner(Alignment.bottomRight, false, false),
    ];
  }

  Widget _buildCaptureDock() {
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _dockSideBtn(Icons.mic_none_rounded, 'VOICE', _onVoice),
                  const Spacer(),
                  _centerCaptureBtn(),
                  const Spacer(),
                  _buildUploadButton(),
                ],
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: _onManual,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_note_outlined, size: 14, color: Colors.white.withValues(alpha: 0.6)),
                      const SizedBox(width: 8),
                      Text(
                        'ENTER MANUALLY',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _centerCaptureBtn() {
    final isQr = _scanMode == _ScanMode.qr;
    return GestureDetector(
      onTap: (_isCapturing || isQr) ? null : _capturePhoto,
      child: AnimatedScale(
        scale: _isCapturing ? 0.88 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (context, _) {
            final alpha = isQr ? (0.25 + _pulseCtrl.value * 0.25) : 1.0;
            return Container(
              width: 76, height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _c.accent.withValues(alpha: alpha),
                    _c.accentStrong.withValues(alpha: alpha),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: isQr ? 0.15 : 0.3),
                  width: 2,
                ),
                boxShadow: isQr ? null : [
                  BoxShadow(
                    color: _c.accent.withValues(alpha: 0.5),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                isQr ? Icons.qr_code_scanner_rounded : Icons.camera_alt_rounded,
                color: Colors.white.withValues(alpha: isQr ? 0.5 : 1.0),
                size: 30,
              ),
            );
          },
        ),
      ),
    );
  }

  // UPLOAD button. On web, a transparent <input type="file"> is stacked on top
  // so the user's tap lands on a real DOM element — the only reliable way to
  // open a file dialog on Flutter web (the canvas glass pane swallows clicks
  // routed through Dart, so file_picker/image_picker return null).
  Widget _buildUploadButton() {
    final btn = _dockSideBtn(Icons.upload_file_outlined, 'UPLOAD', _onFiles);
    if (!kIsWeb) return btn;
    return SizedBox(
      width: 76,
      child: Stack(
        children: [
          btn,
          Positioned.fill(
            child: WebImagePickerInput(onPicked: _onWebPicked),
          ),
        ],
      ),
    );
  }

  Widget _dockSideBtn(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 76,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: Colors.white.withValues(alpha: 0.75)),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.4,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyzingOverlay() {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.78),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FCircularProgress(),
            const SizedBox(height: 20),
            Text(
              'ANALYZING',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 3.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Extracting contact details…',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.48),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // NOTES PAGE
  // ════════════════════════════════════════════════════════════

  Widget _buildNotesPage() {
    return Stack(
      children: [
        ColoredBox(
          color: _c.background,
          child: Column(
            children: [
              _buildNotesHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildContactHeroCard(),
                      const SizedBox(height: 12),
                      _buildContactFieldsCard(),
                      if (_events.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _buildEventSelector(),
                      ],
                      const SizedBox(height: 20),
                      AppSectionLabel('Meeting Notes'),
                      const SizedBox(height: 12),
                      AppFilterRow(
                        filters: const ['Manual', 'Voice', 'Upload'],
                        selected: _notesMode,
                        onSelect: (f) => setState(() => _notesMode = f),
                      ),
                      const SizedBox(height: 14),
                      _buildNotesContent(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: _buildFixedSaveButton(),
        ),
      ],
    );
  }

  Widget _buildNotesHeader() {
    return ColoredBox(
      color: _c.navBackground,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: _c.border)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              AppButton(
                onPressed: () => setState(() => _stage = _Stage.scan),
                variant: ButtonVariant.ghost,
                size: ButtonSize.sm,
                child: Icon(Icons.arrow_back_ios_new_rounded, color: _c.accent, size: 18),
              ),
              const Spacer(),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'NEW CONTACT',
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
                    'Review & save details',
                    style: TextStyle(
                      fontSize: 10,
                      color: _c.textMuted,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              AppButton(
                onPressed: _close,
                variant: ButtonVariant.ghost,
                size: ButtonSize.sm,
                child: Icon(Icons.close_rounded, color: _c.accent, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactHeroCard() {
    final fn = _fnCtrl.text;
    final ln = _lnCtrl.text;
    final initials = (fn.isNotEmpty ? fn[0] : '') + (ln.isNotEmpty ? ln[0] : '');

    return AppCard(
      radius: 20,
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AppAvatar(initials: initials.isEmpty ? '?' : initials, size: 60),
          const SizedBox(width: 16),
          // Editable name fields
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _inlineField(_fnCtrl, 'First name', fontSize: 20, bold: true),
                const SizedBox(height: 2),
                _inlineField(_lnCtrl, 'Last name', fontSize: 15),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Rescan chip
          GestureDetector(
            onTap: () => setState(() => _stage = _Stage.scan),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: _c.accentSoft,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: _c.accent.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.qr_code_scanner, size: 12, color: _c.accent),
                  const SizedBox(width: 5),
                  Text(
                    'RESCAN',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: _c.accent,
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

  Widget _buildContactFieldsCard() {
    return AppCard(
      elevated: true,
      radius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          _fieldRow(Icons.business_outlined, _coCtrl, 'Company'),
          FDivider(),
          _fieldRow(Icons.work_outline_rounded, _titleCtrl, 'Job title'),
          FDivider(),
          _fieldRow(Icons.email_outlined, _emailCtrl, 'Email', kbd: TextInputType.emailAddress),
          FDivider(),
          _fieldRow(Icons.phone_outlined, _phoneCtrl, 'Phone', kbd: TextInputType.phone),
        ],
      ),
    );
  }

  Widget _fieldRow(IconData icon, TextEditingController ctrl, String hint, {TextInputType? kbd}) {
    return SizedBox(
      height: 50,
      child: Row(
        children: [
          Icon(icon, size: 15, color: _c.accent),
          const SizedBox(width: 12),
          Expanded(
            child: AppInput(
              controller: ctrl,
              keyboardType: kbd,
              hint: hint,
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
                hint: Text('Select event', style: TextStyle(color: _c.textMuted, fontSize: 14)),
                items: _events
                    .map((e) => DropdownMenuItem(value: e.id, child: Text(e.name)))
                    .toList(),
                onChanged: (v) => setState(() => _eventId = v),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesContent() {
    return switch (_notesMode) {
      'Voice' => _buildVoiceTab(),
      'Upload' => _buildUploadTab(),
      _ => AppCard(
        elevated: true,
        padding: const EdgeInsets.all(4),
        child: AppInput(
          controller: _notesCtrl,
          maxLines: 6,
          hint: 'Key topics, next steps, what they need…',
        ),
      ),
    };
  }

  Widget _buildFixedSaveButton() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16, 12, 16, MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: _c.background,
        border: Border(top: BorderSide(color: _c.border)),
      ),
      child: AppButton(
        label: _saved ? 'CONTACT SAVED' : 'SAVE CONTACT',
        onPressed: (_isSaving || _saved) ? null : _save,
        isLoading: _isSaving,
        fullWidth: true,
      ),
    );
  }

  // ── Voice tab ──────────────────────────────────────────────

  Widget _buildVoiceTab() {
    return AppCard(
      elevated: true,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          if (_isTranscribing) ...[
            FCircularProgress(),
            const SizedBox(height: 14),
            Text('Transcribing…', style: TextStyle(fontSize: 13, color: _c.textMuted)),
          ] else if (_voiceCtrl.text.isNotEmpty) ...[
            AppSectionLabel('Transcript'),
            const SizedBox(height: 10),
            AppInput(
              controller: _voiceCtrl,
              maxLines: 5,
              hint: 'Transcript will appear here…',
            ),
            const SizedBox(height: 14),
            _outlineBtn(
              icon: Icons.refresh_rounded,
              label: 'RECORD AGAIN',
              onTap: () => setState(() {
                _voiceCtrl.clear();
                _recDuration = Duration.zero;
              }),
            ),
          ] else ...[
            GestureDetector(
              onTap: _toggleRecording,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 72, height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isRecording ? _c.destructive : _c.accentSoft,
                  border: Border.all(
                    color: _isRecording ? _c.destructive : _c.accent,
                    width: 2,
                  ),
                ),
                child: Icon(
                  _isRecording ? Icons.stop_rounded : Icons.mic,
                  size: 30,
                  color: _isRecording ? Colors.white : _c.accent,
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (_isRecording) ...[
              Text(
                _fmtDur(_recDuration),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3,
                  color: _c.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              _waveform(),
              const SizedBox(height: 6),
              Text(
                'TAP TO STOP',
                style: TextStyle(fontSize: 10, letterSpacing: 1.6, color: _c.textMuted),
              ),
            ] else
              Text('Tap to record', style: TextStyle(fontSize: 13, color: _c.textMuted)),
          ],
        ],
      ),
    );
  }

  Widget _waveform() {
    return SizedBox(
      height: 28,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(7, (i) {
          return AnimatedBuilder(
            animation: _lineCtrl,
            builder: (ctx, _) {
              final h = 4 + (math.sin(_lineCtrl.value * math.pi * 2 + i * 0.8).abs() * 20);
              return Container(
                width: 4,
                height: h.clamp(4.0, 24.0),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: _c.accent,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            },
          );
        }),
      ),
    );
  }

  // ── Upload tab ─────────────────────────────────────────────

  Widget _buildUploadTab() {
    if (_isAnalyzing) {
      return AppCard(
        elevated: true,
        padding: const EdgeInsets.symmetric(vertical: 44),
        child: Column(
          children: [
            FCircularProgress(),
            const SizedBox(height: 14),
            Text('Analyzing image…', style: TextStyle(fontSize: 13, color: _c.textMuted)),
          ],
        ),
      );
    }
    return GestureDetector(
      onTap: _pickFile,
      child: AppCard(
        elevated: true,
        padding: const EdgeInsets.symmetric(vertical: 44),
        child: Column(
          children: [
            Icon(Icons.upload_file_rounded, size: 36, color: _c.accent),
            const SizedBox(height: 12),
            Text(
              'TAP TO BROWSE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.4,
                color: _c.textMuted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'PDF · JPG · PNG up to 10 MB',
              style: TextStyle(fontSize: 11, color: _c.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  // ── Dedup sheet ────────────────────────────────────────────

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
            left: 0, right: 0, bottom: 0,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: ColoredBox(
              color: _c.surface,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40, height: 4,
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
                              Icon(Icons.warning_amber_rounded, color: _c.accent, size: 20),
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
                                    '${_dupes.first['first_name'] ?? ''} ${_dupes.first['last_name'] ?? ''}'.trim(),
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
                                      style: TextStyle(fontSize: 13, color: _c.textSecondary),
                                    ),
                                  ],
                                  if (_dupes.first['company'] != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      (_dupes.first['company'] as Map?)?['name'] ?? '',
                                      style: TextStyle(fontSize: 12, color: _c.textMuted),
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
                      20, 0, 20, MediaQuery.of(context).padding.bottom + 16,
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
                        AppButton(
                          label: 'CANCEL',
                          onPressed: () => setState(() => _showDedup = false),
                          variant: ButtonVariant.ghost,
                          fullWidth: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          ),
        ],
      ),
    );
  }

  Widget _dedupAction(String label, {required VoidCallback onTap, bool primary = false}) {
    return AppButton(
      label: label,
      onPressed: onTap,
      variant: primary ? ButtonVariant.primary : ButtonVariant.outline,
      fullWidth: true,
    );
  }

  Widget _outlineBtn({required IconData icon, required String label, required VoidCallback onTap}) {
    return AppButton(
      label: label,
      onPressed: onTap,
      variant: ButtonVariant.outline,
    );
  }

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

  // ── Actions ────────────────────────────────────────────────

  void _close() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      widget.onNavigateTab?.call(0);
    }
  }

  void _onQrDetected(BarcodeCapture capture) {
    if (_stage != _Stage.scan || _isCapturing || _scanMode != _ScanMode.qr) return;
    final raw = capture.barcodes.firstOrNull?.rawValue ?? '';
    if (raw.isEmpty) return;
    _applyQrData(raw);
    setState(() => _stage = _Stage.notes);
  }

  Future<void> _capturePhoto() async {
    setState(() => _isCapturing = true);
    try {
      final picker = ImagePicker();
      final img = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
      if (img == null) { setState(() => _isCapturing = false); return; }
      final bytes = await img.readAsBytes();
      await _processImageBytes(bytes);
    } on UnauthorizedException { rethrow; } catch (_) {
      if (!mounted) return;
      setState(() { _isCapturing = false; _stage = _Stage.notes; });
    }
  }

  Future<void> _onVoice() async {
    final result = await Navigator.of(context).push<VoiceContactResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const VoiceContactCaptureScreen(),
      ),
    );
    if (result != null && mounted) {
      setState(() => _lastCapture = result.savedName);
    }
  }

  // Tap handler for the UPLOAD button. On web the click is handled by the
  // embedded <input type="file"> (see _uploadButton), so this only runs on
  // mobile, where FilePicker opens the native picker directly.
  Future<void> _onFiles() async {
    if (kIsWeb) return;
    setState(() => _isCapturing = true);
    try {
      final picked =
          await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
      if (picked == null || picked.files.isEmpty) {
        setState(() => _isCapturing = false);
        return;
      }
      final file = picked.files.first;
      final bytes = file.bytes ?? await File(file.path!).readAsBytes();
      await _analyzeBytes(bytes);
    } on UnauthorizedException { rethrow; } catch (e) {
      _onFilesError(e);
    }
  }

  // Called by the embedded web file input when the user picks (or cancels).
  void _onWebPicked(Uint8List? bytes) {
    if (bytes == null || !mounted) return;
    setState(() => _isCapturing = true);
    _analyzeBytes(bytes).catchError(_onFilesError);
  }

  Future<void> _analyzeBytes(Uint8List bytes) => _processImageBytes(bytes);

  /// Online: calls AI immediately. Offline: saves bytes for deferred analysis at sync.
  Future<void> _processImageBytes(Uint8List bytes) async {
    final isOnline = context.read<OfflineProvider>().isOnline;
    if (isOnline) {
      final b64 = base64Encode(bytes);
      final res = await ApiService.analyzeCard(b64);
      _applyExtracted(res['data'] as Map<String, dynamic>? ?? {});
      if (!mounted) return;
      setState(() { _isCapturing = false; _stage = _Stage.notes; });
    } else {
      // Defer AI; hold bytes until user saves.
      _pendingImageBytes = bytes;
      if (!mounted) return;
      setState(() { _isCapturing = false; _stage = _Stage.notes; });
      showAppToast(context, 'Offline - fill in details and save. Card will be analyzed when online.');
    }
  }

  void _onFilesError(Object e) {
    if (!mounted) return;
    setState(() => _isCapturing = false);
    showAppToast(context, 'Failed to analyze image: $e');
  }

  Future<void> _onManual() async {
    final result = await Navigator.of(context).push<ManualEntryResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const ManualEntryScreen(),
      ),
    );
    if (result != null && mounted) {
      setState(() => _lastCapture = result.savedName);
    }
  }

  Future<void> _pickFile() async {
    setState(() => _isAnalyzing = true);
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
      if (result == null || result.files.isEmpty) {
        setState(() => _isAnalyzing = false);
        return;
      }
      final bytes = result.files.first.bytes ?? await File(result.files.first.path!).readAsBytes();
      final b64 = base64Encode(bytes);
      final res = await ApiService.analyzeCard(b64);
      _applyExtracted(res['data'] as Map<String, dynamic>? ?? {});
      if (!mounted) return;
      setState(() => _isAnalyzing = false);
    } on UnauthorizedException { rethrow; } catch (_) {
      if (!mounted) return;
      setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      _recTimer?.cancel();
      final path = await _recorder.stop();
      setState(() { _isRecording = false; _isTranscribing = true; });
      if (path != null) await _transcribe(path);
      return;
    }
    if (!kIsWeb) {
      final granted = await Permission.microphone.request();
      if (!granted.isGranted) {
        if (mounted) {
          showAppToast(context, 'Microphone permission required');
        }
        return;
      }
    }
    if (kIsWeb) {
      _recPath = 'rec_${DateTime.now().millisecondsSinceEpoch}.m4a';
    } else {
      final dir = await getTemporaryDirectory();
      _recPath = '${dir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.m4a';
    }
    final config = kIsWeb
        ? const RecordConfig(encoder: AudioEncoder.opus)
        : const RecordConfig();
    await _recorder.start(config, path: _recPath!);
    setState(() { _isRecording = true; _recDuration = Duration.zero; });
    _recTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _recDuration += const Duration(seconds: 1));
    });
  }

  Future<void> _transcribe(String path) async {
    try {
      final Uint8List bytes;
      if (kIsWeb) {
        final response = await http.get(Uri.parse(path));
        bytes = response.bodyBytes;
      } else {
        bytes = await File(path).readAsBytes();
      }
      final b64 = base64Encode(bytes);
      final transcript = await ApiService.transcribeAudio(b64);
      if (!mounted) return;
      setState(() { _voiceCtrl.text = transcript; _isTranscribing = false; });
    } on UnauthorizedException { rethrow; } catch (_) {
      if (!mounted) return;
      setState(() => _isTranscribing = false);
    }
  }

  Future<void> _save() async {
    final name = '${_fnCtrl.text.trim()} ${_lnCtrl.text.trim()}'.trim();
    if (name.isEmpty) {
      showAppToast(context, 'Enter at least a name');
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
          _dupes = List<Map<String, dynamic>>.from(dupResult['data'] as List? ?? []);
          _isSaving = false;
          _showDedup = true;
        });
        return;
      }
      await _doSave();
    } on UnauthorizedException { rethrow; } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
    }
  }

  Future<void> _doSave() async {
    try {
      final rawText = [_notesCtrl.text, _voiceCtrl.text]
          .where((s) => s.isNotEmpty)
          .join('\n\n');
      final extractedData = {
        'first_name': _fnCtrl.text.trim(),
        'last_name':  _lnCtrl.text.trim(),
        'name': '${_fnCtrl.text.trim()} ${_lnCtrl.text.trim()}'.trim(),
        'company':    _coCtrl.text.trim(),
        'email':      _emailCtrl.text.trim(),
        'phone':      _phoneCtrl.text.trim(),
        'job_title':  _titleCtrl.text.trim(),
      };

      // Use WriteGateway so offline scans get queued with their image bytes.
      final captureType = _pendingImageBytes != null ? 'card_scan' : 'manual';
      final result = await WriteGateway().createCapture(
        captureType: captureType,
        imageBytes: _pendingImageBytes,
        rawText: rawText.isEmpty ? null : rawText,
        eventId: _eventId,
        extractedData: extractedData,
      );

      if (!mounted) return;

      if (result.savedOffline) {
        if (!mounted) return;
        context.read<OfflineProvider>().refreshPendingCount();
        showAppToast(context, 'Saved offline - will be processed when online');
        setState(() { _isSaving = false; _showDedup = false; _pendingImageBytes = null; _stage = _Stage.scan; });
        captureReturnSignal.value++;
        return;
      }

      final captureName = '${_fnCtrl.text.trim()} (${_coCtrl.text.trim()})'.trim();
      setState(() {
        _saved = true;
        _isSaving = false;
        _showDedup = false;
        _lastCapture = captureName;
        _pendingImageBytes = null;
      });
      captureReturnSignal.value++;
      await Future<void>.delayed(const Duration(milliseconds: 1800));
      if (!mounted) return;
      setState(() { _saved = false; _stage = _Stage.scan; });
    } on UnauthorizedException { rethrow; } catch (_) {
      if (!mounted) return;
      setState(() { _isSaving = false; _saved = false; });
    }
  }

  Future<void> _resolveDuplicateAndSave({required bool merge}) async {
    if (!merge) {
      await _promptRenameAndSave();
      return;
    }
    setState(() { _showDedup = false; _isSaving = true; });
    await _doMerge();
  }

  Future<void> _doMerge() async {
    try {
      final existingId = _dupes.first['id'] as String?;
      if (existingId == null) {
        await _doSave();
        return;
      }

      final rawNotes = [_notesCtrl.text, _voiceCtrl.text]
          .where((s) => s.isNotEmpty)
          .join('\n')
          .trim();
      final summary = rawNotes.isNotEmpty ? rawNotes : 'Met at event';

      await WriteGateway().logInteraction(
        contactId: existingId,
        eventId: _eventId,
        type: 'meeting',
        summary: summary,
        interactionDate: DateTime.now().toIso8601String(),
      );

      // Explicitly link the contact to the event so it shows in Events tab
      if (_eventId != null) {
        try {
          await ApiService.linkContactToEvent(existingId, _eventId!);
        } on UnauthorizedException { rethrow; } catch (_) {}
      }

      if (!mounted) return;
      final captureName = '${_fnCtrl.text.trim()} (${_coCtrl.text.trim()})'.trim();
      setState(() {
        _saved = true;
        _isSaving = false;
        _showDedup = false;
        _lastCapture = captureName;
      });
      captureReturnSignal.value++;
      await Future<void>.delayed(const Duration(milliseconds: 1800));
      if (!mounted) return;
      setState(() { _saved = false; _stage = _Stage.scan; });
    } on UnauthorizedException { rethrow; } catch (_) {
      if (!mounted) return;
      setState(() { _isSaving = false; _saved = false; });
    }
  }

  Future<void> _promptRenameAndSave() async {
    final fnTemp = TextEditingController(text: _fnCtrl.text);
    final lnTemp = TextEditingController(text: _lnCtrl.text);

    final confirmed = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx, style, _) {
        final c = AppTheme.colorsOf(ctx);
        return FDialog(
          title: Text(
            'Rename new contact',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.textPrimary),
          ),
          body: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Update the name to distinguish this contact from the existing one.',
                style: TextStyle(fontSize: 13, color: c.textMuted, height: 1.5),
              ),
              const SizedBox(height: 16),
              _dialogField(fnTemp, 'First name', c),
              const SizedBox(height: 10),
              _dialogField(lnTemp, 'Last name', c),
            ],
          ),
          actions: [
            AppButton(
              label: 'CANCEL',
              onPressed: () => Navigator.of(ctx).pop(false),
              variant: ButtonVariant.ghost,
            ),
            AppButton(
              label: 'SAVE',
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    _fnCtrl.text = fnTemp.text.trim();
    _lnCtrl.text = lnTemp.text.trim();
    fnTemp.dispose();
    lnTemp.dispose();

    setState(() { _showDedup = false; _isSaving = true; });
    await _doSave();
  }

  Widget _dialogField(TextEditingController ctrl, String hint, ExonoColors c) {
    return AppInput(
      controller: ctrl,
      hint: hint,
    );
  }

  void _applyExtracted(Map<String, dynamic> d) {
    _fnCtrl.text   = (d['first_name'] as String?)?.trim() ?? (d['name'] as String? ?? '').split(' ').first;
    _lnCtrl.text   = (d['last_name']  as String?)?.trim() ?? (d['name'] as String? ?? '').split(' ').skip(1).join(' ');
    _coCtrl.text   = (d['company']    as String?)?.trim() ?? '';
    _emailCtrl.text = (d['email']     as String?)?.trim() ?? '';
    _phoneCtrl.text = (d['phone']     as String?)?.trim() ?? '';
    _titleCtrl.text = (d['job_title'] as String?)?.trim() ?? (d['title'] as String?)?.trim() ?? '';
  }

  void _applyQrData(String raw) {
    if (raw.startsWith('BEGIN:VCARD')) {
      for (final line in raw.split('\n')) {
        if (line.startsWith('FN:'))    _fnCtrl.text    = line.substring(3).trim();
        if (line.startsWith('ORG:'))   _coCtrl.text    = line.substring(4).trim();
        if (line.startsWith('TITLE:')) _titleCtrl.text = line.substring(6).trim();
        if (line.startsWith('EMAIL:')) _emailCtrl.text = line.replaceAll(RegExp(r'EMAIL[^:]*:'), '').trim();
        if (line.startsWith('TEL:'))   _phoneCtrl.text = line.replaceAll(RegExp(r'TEL[^:]*:'), '').trim();
      }
    } else {
      final emailRe = RegExp(r'\b[\w.+-]+@[\w-]+\.\w+\b');
      final phoneRe = RegExp(r'\+?[\d\s\-().]{7,}');
      final em = emailRe.firstMatch(raw);
      final ph = phoneRe.firstMatch(raw);
      if (em != null) _emailCtrl.text = em.group(0)!;
      if (ph != null) _phoneCtrl.text = ph.group(0)!.trim();
    }
  }

  String _fmtDur(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ── Bracket corner painter ─────────────────────────────────────────────────────

class _BracketPainter extends CustomPainter {
  final Color color;
  final bool top, left;

  const _BracketPainter({required this.color, required this.top, required this.left});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final x = left ? 0.0 : size.width;
    final y = top  ? 0.0 : size.height;
    final dx = left ? size.width  : -size.width;
    final dy = top  ? size.height : -size.height;

    canvas.drawLine(Offset(x, y), Offset(x + dx, y), paint);
    canvas.drawLine(Offset(x, y), Offset(x, y + dy), paint);
  }

  @override
  bool shouldRepaint(_BracketPainter old) => old.color != color;
}
