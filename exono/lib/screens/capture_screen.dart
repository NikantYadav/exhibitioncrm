import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

import '../config/app_theme.dart';
import '../models/event.dart';
import '../services/api_service.dart';
import '../widgets/app_chip.dart';
import 'voice_memory_capture_screen.dart';

class CaptureScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigateTab;

  const CaptureScreen({super.key, this.onNavigateTab});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

enum _CaptureStage { scanner, notes }

enum _CaptureNotesTab { manual, voice, upload }

class _CaptureScreenState extends State<CaptureScreen>
    with SingleTickerProviderStateMixin {
  ExonoColors get _c => AppTheme.colorsOf(context);

  late final AnimationController _scanController;
  final TextEditingController _manualNotesController = TextEditingController();
  final TextEditingController _voiceTranscriptController = TextEditingController();

  // MobileScanner controller
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  // Audio recorder
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  bool _isTranscribing = false;
  DateTime? _recordingStartTime;

  _CaptureStage _stage = _CaptureStage.scanner;
  _CaptureNotesTab _notesTab = _CaptureNotesTab.manual;
  bool _isCapturing = false;
  bool _isSavingLead = false;
  bool _leadSaved = false;
  bool _showDedupAlert = false;
  String? _selectedEventId;
  List<Event> _events = [];
  String? _capturedImageBase64;
  String _captureType = 'business_card';

  // Dedup data
  List<Map<String, dynamic>> _duplicates = [];

  // Last capture
  String? _lastCaptureName;

  // Contact fields from capture/analysis/manual
  String _firstName = '';
  String _lastName = '';
  String _company = '';
  String _email = '';
  String _phone = '';
  String _jobTitle = '';

  // Upload analyzing state
  bool _isAnalyzingUpload = false;


  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    try {
      final events = await ApiService.getEvents();
      if (mounted) {
        setState(() {
          _events = events;
          if (events.isNotEmpty) {
            _selectedEventId = events.first.id;
          }
        });
      }
    } catch (_) {
      // silently fail — not critical
    }
  }

  @override
  void dispose() {
    _scanController.dispose();
    _manualNotesController.dispose();
    _voiceTranscriptController.dispose();
    _scannerController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  String get _fullName {
    final parts = [_firstName, _lastName].where((s) => s.isNotEmpty).toList();
    return parts.join(' ');
  }

  String get _initials {
    final f = _firstName.isNotEmpty ? _firstName[0] : '';
    final l = _lastName.isNotEmpty ? _lastName[0] : '';
    final combined = (f + l).toUpperCase();
    return combined.isNotEmpty ? combined : '?';
  }

  @override
  Widget build(BuildContext context) {
    final baseScreen = ColoredBox(
      color: _stage == _CaptureStage.scanner
          ? _c.surface
          : _c.background,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: _stage == _CaptureStage.scanner
                  ? _buildScannerStage()
                  : _buildNotesStage(),
            ),
          ],
        ),
      ),
    );

    return Stack(
      children: [baseScreen, if (_showDedupAlert) _buildDedupAlertOverlay()],
    );
  }

  Widget _buildTopBar() {
    if (_stage == _CaptureStage.scanner) {
      return Container(
            height: 56,
            decoration: BoxDecoration(
              color: _c.navBackground,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Expanded(child: SizedBox()),
                  Text(
                    'EXONO',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.2,
                      color: _c.textPrimary,
                      height: 1,
                    ),
                  ),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          onPressed: _toggleFlash,
                          splashRadius: 20,
                          icon: Icon(
                            Icons.flashlight_on,
                            color: _c.textPrimary,
                            size: 22,
                          ),
                        ),
                        IconButton(
                          onPressed: () => widget.onNavigateTab?.call(0),
                          splashRadius: 20,
                          icon: Icon(
                            Icons.close,
                            color: _c.textPrimary,
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
    }

    return Container(
      height: 56,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _c.border, width: 1)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            IconButton(
              onPressed: () {
                setState(() => _stage = _CaptureStage.scanner);
              },
              splashRadius: 20,
              icon: Icon(Icons.arrow_back, color: _c.textPrimary, size: 24),
            ),
            const Spacer(),
            Text(
              'EXONO',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.2,
                color: _c.textPrimary,
                height: 1,
              ),
            ),
            const Spacer(),
            const SizedBox(width: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildScannerStage() {
    return Stack(
      children: [
        // Live camera via MobileScanner
        Positioned.fill(
          child: MobileScanner(
            controller: _scannerController,
            onDetect: _onQrDetected,
          ),
        ),
        // Dark gradient overlay
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.40),
                  Colors.black.withValues(alpha: 0.20),
                  Colors.black.withValues(alpha: 0.46),
                ],
                stops: const [0.0, 0.46, 1.0],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildFinder(),
                        const SizedBox(height: 44),
                        Text(
                          'ALIGN CARD OR QR CODE',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 4,
                            color: _c.textPrimary.withValues(alpha: 0.80),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'PRECISE AUTO-CAPTURE ACTIVE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1.5,
                            color: _c.textMuted.withValues(alpha: 0.60),
                          ),
                        ),
                        const SizedBox(height: 32),
                        _buildCaptureButton(),
                        const SizedBox(height: 40),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildScannerActionButton(
                              icon: Icons.mic_none_rounded,
                              label: 'VOICE',
                              onTap: _openVoiceMemoryCapture,
                            ),
                            const SizedBox(width: 48),
                            _buildScannerActionButton(
                              icon: Icons.folder_open_outlined,
                              label: 'FILES',
                              onTap: _pickFileAndAnalyze,
                            ),
                            const SizedBox(width: 48),
                            _buildScannerActionButton(
                              icon: Icons.edit_note_outlined,
                              label: 'MANUAL',
                              onTap: () {
                                _scannerController.stop();
                                setState(() {
                                  _stage = _CaptureStage.notes;
                                  _notesTab = _CaptureNotesTab.manual;
                                  _captureType = 'manual';
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Loading overlay when analyzing
        if (_isCapturing)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.6),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: _c.textPrimary),
                    const SizedBox(height: 16),
                    Text(
                      'ANALYZING CARD...',
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 2,
                        color: _c.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNotesStage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCapturedIdentityBar(),
          const SizedBox(height: 24),
          _buildFieldLabel('EVENT CONTEXT'),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: _c.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _c.border),
            ),
            child: _events.isEmpty
                ? Row(
                    children: [
                      Text(
                        'No events',
                        style: TextStyle(fontSize: 14, color: _c.textMuted),
                      ),
                    ],
                  )
                : DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedEventId,
                      dropdownColor: _c.surfaceAlt,
                      isExpanded: true,
                      icon: Icon(Icons.expand_more, color: _c.textMuted),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: _c.textPrimary,
                      ),
                      items: _events.map((e) => DropdownMenuItem<String>(
                        value: e.id,
                        child: Text(e.name, overflow: TextOverflow.ellipsis),
                      )).toList(),
                      onChanged: (v) => setState(() => _selectedEventId = v),
                    ),
                  ),
          ),
          const SizedBox(height: 30),
          Row(
            children: [
              Container(width: 2, height: 24, color: _c.textPrimary),
              const SizedBox(width: 10),
              Text(
                'CAPTURE NOTES',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.8,
                  color: _c.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildNotesTabs(),
          const SizedBox(height: 16),
          _buildNotesTabContent(),
          const SizedBox(height: 26),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: _isSavingLead ? null : _finalizeLead,
              style: FilledButton.styleFrom(
                backgroundColor: _leadSaved
                    ? const Color(0xFF16A34A)
                    : _c.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _isSavingLead
                    ? const SizedBox(
                        key: ValueKey('processing'),
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        key: ValueKey(_leadSaved ? 'saved' : 'idle'),
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _leadSaved
                                ? 'LEAD SAVED'
                                : 'FINALIZE AND SAVE LEAD',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 2.0,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            _leadSaved
                                ? Icons.check_circle
                                : Icons.save_outlined,
                            size: 18,
                            color: Colors.white,
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

  Widget _buildCapturedIdentityBar() {
    final hasName = _firstName.isNotEmpty || _lastName.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _c.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _c.surfaceElevated,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _c.borderStrong),
                ),
                alignment: Alignment.center,
                child: Text(
                  _initials,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: _c.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasName ? _fullName : 'Unknown Contact',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                        color: _c.textPrimary,
                        height: 1.2,
                      ),
                    ),
                    if (_company.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        _company.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.0,
                          color: _c.textMuted,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        AppChip.status('MET', color: _c.textPrimary),
                        AppChip('FOLLOW-UP'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Editable contact fields
          _buildEditableField(
            label: 'FIRST NAME',
            initialValue: _firstName,
            onChanged: (v) => _firstName = v,
          ),
          const SizedBox(height: 10),
          _buildEditableField(
            label: 'LAST NAME',
            initialValue: _lastName,
            onChanged: (v) => _lastName = v,
          ),
          const SizedBox(height: 10),
          _buildEditableField(
            label: 'COMPANY',
            initialValue: _company,
            onChanged: (v) => _company = v,
          ),
          const SizedBox(height: 10),
          _buildEditableField(
            label: 'JOB TITLE',
            initialValue: _jobTitle,
            onChanged: (v) => _jobTitle = v,
          ),
          const SizedBox(height: 10),
          _buildEditableField(
            label: 'EMAIL',
            initialValue: _email,
            onChanged: (v) => _email = v,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 10),
          _buildEditableField(
            label: 'PHONE',
            initialValue: _phone,
            onChanged: (v) => _phone = v,
            keyboardType: TextInputType.phone,
          ),
        ],
      ),
    );
  }

  Widget _buildEditableField({
    required String label,
    required String initialValue,
    required ValueChanged<String> onChanged,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.4,
            color: _c.textMuted,
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          initialValue: initialValue,
          onChanged: onChanged,
          keyboardType: keyboardType,
          style: TextStyle(
            fontSize: 14,
            color: _c.textPrimary,
            fontWeight: FontWeight.w400,
          ),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            fillColor: _c.surface,
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: _c.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: _c.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: _c.borderStrong),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.7,
        color: _c.textMuted,
      ),
    );
  }

  Widget _buildNotesTabs() {
    Widget tab(String label, _CaptureNotesTab t) {
      final isActive = _notesTab == t;
      return Expanded(
        child: InkWell(
          onTap: () => setState(() => _notesTab = t),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isActive ? _c.textPrimary : _c.border,
                  width: isActive ? 2 : 1,
                ),
              ),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 2.1,
                color: isActive ? _c.textPrimary : _c.textMuted,
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        tab('MANUAL', _CaptureNotesTab.manual),
        tab('VOICE', _CaptureNotesTab.voice),
        tab('UPLOAD', _CaptureNotesTab.upload),
      ],
    );
  }

  Widget _buildNotesTabContent() {
    switch (_notesTab) {
      case _CaptureNotesTab.manual:
        return Container(
          height: 160,
          decoration: BoxDecoration(
            color: _c.surfaceAlt,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _c.border),
          ),
          child: TextField(
            controller: _manualNotesController,
            maxLines: null,
            expands: true,
            cursorColor: _c.textPrimary,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: _c.textSecondary,
              height: 1.4,
            ),
            decoration: InputDecoration(
              hintText:
                  'Key topics discussed, what they need, agreed next steps...',
              hintStyle: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: _c.textMuted.withValues(alpha: 0.4),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        );

      case _CaptureNotesTab.voice:
        return _buildVoiceTab();

      case _CaptureNotesTab.upload:
        return _buildUploadTab();
    }
  }

  Widget _buildVoiceTab() {
    if (_isTranscribing) {
      return Container(
        height: 160,
        decoration: BoxDecoration(
          color: _c.surfaceAlt,
          border: Border.all(color: _c.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: _c.textPrimary, strokeWidth: 2),
            const SizedBox(height: 14),
            Text(
              'TRANSCRIBING...',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 2,
                color: _c.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    // Show transcript editor if we have transcript text
    if (_voiceTranscriptController.text.isNotEmpty) {
      return Container(
        height: 160,
        decoration: BoxDecoration(
          color: _c.surfaceAlt,
          border: Border.all(color: _c.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: TextField(
          controller: _voiceTranscriptController,
          maxLines: null,
          expands: true,
          cursorColor: _c.textPrimary,
          style: TextStyle(fontSize: 14, color: _c.textSecondary, height: 1.4),
          decoration: InputDecoration(
            hintText: 'Transcript...',
            hintStyle: TextStyle(fontSize: 14, color: _c.textMuted.withValues(alpha: 0.4)),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      );
    }

    // Recording UI
    return GestureDetector(
      onTap: _toggleVoiceRecording,
      child: Container(
        height: 224,
        decoration: BoxDecoration(
          color: _c.surfaceAlt,
          border: Border.all(color: _c.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _isRecording
                      ? Colors.redAccent
                      : _c.textPrimary,
                  width: _isRecording ? 2 : 1,
                ),
                color: _isRecording
                    ? Colors.redAccent.withValues(alpha: 0.08)
                    : Colors.transparent,
              ),
              child: Icon(
                _isRecording ? Icons.stop : Icons.mic,
                color: _isRecording ? Colors.redAccent : _c.textPrimary,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            if (_isRecording) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: AnimatedBuilder(
                      animation: _scanController,
                      builder: (context, child) {
                        final base = ((_scanController.value + (index * 0.12)) % 1.0);
                        final h = 4 + (20 * (0.5 - (base - 0.5).abs()) * 2);
                        return Container(
                          width: 4,
                          height: h.clamp(4.0, 24.0),
                          color: Colors.redAccent,
                        );
                      },
                    ),
                  );
                }),
              ),
              const SizedBox(height: 12),
              Text(
                _formatRecordingTime(),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: _c.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                'TAP TO STOP',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.0, color: _c.textMuted),
              ),
            ] else ...[
              Text(
                'TAP TO RECORD',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.0, color: _c.textMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUploadTab() {
    if (_isAnalyzingUpload) {
      return Container(
        height: 160,
        decoration: BoxDecoration(
          color: _c.surfaceAlt,
          border: Border.all(color: _c.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: _c.textPrimary, strokeWidth: 2),
            const SizedBox(height: 14),
            Text(
              'ANALYZING IMAGE...',
              style: TextStyle(fontSize: 11, letterSpacing: 2, color: _c.textMuted, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: _pickFileAndAnalyze,
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: _c.surfaceAlt,
          border: Border.all(color: _c.border, style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.upload_file, color: _c.textMuted),
            const SizedBox(height: 10),
            Text(
              'DROP FILE HERE OR TAP TO BROWSE',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 1.1, color: _c.textMuted),
            ),
            const SizedBox(height: 6),
            Text(
              'PDF, JPG, PNG UP TO 10MB',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.8, color: _c.textMuted.withValues(alpha: 0.5)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinder() {
    return SizedBox(
      width: 280,
      height: 280,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _c.textPrimary.withValues(alpha: 0.18)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.55),
                  spreadRadius: 180,
                  blurRadius: 0,
                ),
              ],
            ),
          ),
          Positioned(
            top: -44,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _c.surfaceAlt.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _c.border.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.history, size: 14, color: _c.textMuted),
                    const SizedBox(width: 6),
                    Text(
                      _lastCaptureName != null
                          ? 'Last: $_lastCaptureName'
                          : 'Align card or QR code',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        color: _c.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ..._buildCornerGuides(),
          AnimatedBuilder(
            animation: _scanController,
            builder: (context, child) {
              return Positioned(
                top: 8 + (_scanController.value * 264),
                left: 0,
                right: 0,
                child: Container(
                  height: 1,
                  color: _c.textPrimary.withValues(alpha: 0.45),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCornerGuides() {
    final guideSize = 32.0;
    final guideColor = _c.textPrimary;
    const guideWidth = 1.3;

    Widget corner({
      required Alignment alignment,
      required bool top,
      required bool left,
    }) {
      return Align(
        alignment: alignment,
        child: SizedBox(
          width: guideSize,
          height: guideSize,
          child: CustomPaint(
            painter: _CornerPainter(
              color: guideColor,
              strokeWidth: guideWidth,
              top: top,
              left: left,
            ),
          ),
        ),
      );
    }

    return [
      corner(alignment: Alignment.topLeft, top: true, left: true),
      corner(alignment: Alignment.topRight, top: true, left: false),
      corner(alignment: Alignment.bottomLeft, top: false, left: true),
      corner(alignment: Alignment.bottomRight, top: false, left: false),
    ];
  }

  Widget _buildCaptureButton() {
    return GestureDetector(
      onTap: _isCapturing ? null : _capturePhoto,
      child: AnimatedScale(
        scale: _isCapturing ? 0.90 : 1,
        duration: const Duration(milliseconds: 180),
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _c.textPrimary.withValues(alpha: 0.30)),
          ),
          padding: const EdgeInsets.all(6),
          child: Container(
            decoration: BoxDecoration(color: _c.textPrimary, shape: BoxShape.circle),
            child: _isCapturing
                ? Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _c.background,
                      ),
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildScannerActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          Icon(icon, size: 24, color: _c.textMuted.withValues(alpha: 0.72)),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.8,
              color: _c.textMuted.withValues(alpha: 0.72),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Actions ----

  void _toggleFlash() {
    _scannerController.toggleTorch();
  }

  void _onQrDetected(BarcodeCapture capture) {
    if (_stage != _CaptureStage.scanner) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null) return;
    final raw = barcode.rawValue ?? '';
    if (raw.isEmpty) return;

    _scannerController.stop();

    // Try to parse vCard or extract basic fields from raw text
    final extracted = _parseQrData(raw);
    setState(() {
      _firstName = extracted['first_name'] ?? '';
      _lastName = extracted['last_name'] ?? '';
      _company = extracted['company'] ?? '';
      _email = extracted['email'] ?? '';
      _phone = extracted['phone'] ?? '';
      _jobTitle = extracted['job_title'] ?? '';
      _captureType = 'qr_code';
      _stage = _CaptureStage.notes;
      _notesTab = _CaptureNotesTab.manual;
    });
  }

  Map<String, String> _parseQrData(String raw) {
    final result = <String, String>{};
    // vCard format
    if (raw.toUpperCase().contains('BEGIN:VCARD')) {
      final lines = raw.split(RegExp(r'\r?\n'));
      for (final line in lines) {
        if (line.startsWith('FN:')) {
          final name = line.substring(3).trim();
          final parts = name.split(' ');
          result['first_name'] = parts.isNotEmpty ? parts.first : '';
          result['last_name'] = parts.length > 1 ? parts.sublist(1).join(' ') : '';
        } else if (line.startsWith('N:')) {
          final parts = line.substring(2).split(';');
          result['last_name'] = parts.isNotEmpty ? parts[0].trim() : '';
          result['first_name'] = parts.length > 1 ? parts[1].trim() : '';
        } else if (line.contains('EMAIL')) {
          final idx = line.indexOf(':');
          if (idx != -1) result['email'] = line.substring(idx + 1).trim();
        } else if (line.contains('TEL')) {
          final idx = line.indexOf(':');
          if (idx != -1) result['phone'] = line.substring(idx + 1).trim();
        } else if (line.startsWith('ORG:')) {
          result['company'] = line.substring(4).trim();
        } else if (line.startsWith('TITLE:')) {
          result['job_title'] = line.substring(6).trim();
        }
      }
    } else {
      // Plain text: try to extract email/phone
      final emailMatch = RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}').firstMatch(raw);
      if (emailMatch != null) result['email'] = emailMatch.group(0)!;
      final phoneMatch = RegExp(r'\+?[\d\s\-().]{7,15}').firstMatch(raw);
      if (phoneMatch != null) result['phone'] = phoneMatch.group(0)!.trim();
    }
    return result;
  }

  Future<void> _capturePhoto() async {
    setState(() => _isCapturing = true);
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (image == null) {
        if (mounted) setState(() => _isCapturing = false);
        return;
      }

      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);
      _capturedImageBase64 = base64Image;

      // Analyze the card
      final result = await ApiService.analyzeCard(base64Image);
      final data = result['data'] as Map<String, dynamic>? ?? {};

      if (!mounted) return;
      _applyExtractedData(data);
      _scannerController.stop();
      setState(() {
        _isCapturing = false;
        _captureType = 'business_card';
        _stage = _CaptureStage.notes;
        _notesTab = _CaptureNotesTab.manual;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCapturing = false);
      // Navigate to notes anyway so user can fill manually
      _scannerController.stop();
      setState(() {
        _captureType = 'business_card';
        _stage = _CaptureStage.notes;
        _notesTab = _CaptureNotesTab.manual;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not analyze card. Fill details manually.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _applyExtractedData(Map<String, dynamic> data) {
    final name = data['name'] as String? ?? '';
    final firstFromName = data['first_name'] as String?;
    final lastFromName = data['last_name'] as String?;

    if (firstFromName != null && firstFromName.isNotEmpty) {
      _firstName = firstFromName;
      _lastName = lastFromName ?? '';
    } else if (name.isNotEmpty) {
      final parts = name.split(' ');
      _firstName = parts.first;
      _lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    }
    _company = data['company'] as String? ?? _company;
    _email = data['email'] as String? ?? _email;
    _phone = data['phone'] as String? ?? _phone;
    _jobTitle = data['job_title'] as String? ?? _jobTitle;
  }

  Future<void> _toggleVoiceRecording() async {
    if (_isRecording) {
      // Stop recording
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
      });

      if (path != null) {
        _transcribeRecording(path);
      }
      return;
    }

    // Start recording
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission is required for recording.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final dir = await getTemporaryDirectory();
    final filePath = '${dir.path}/capture_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _audioRecorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: filePath,
    );

    setState(() {
      _isRecording = true;
      _recordingStartTime = DateTime.now();
    });
  }

  Future<void> _transcribeRecording(String path) async {
    setState(() => _isTranscribing = true);
    try {
      final file = File(path);
      final bytes = await file.readAsBytes();
      final base64Audio = base64Encode(bytes);
      final transcript = await ApiService.transcribeAudio(base64Audio);
      if (mounted) {
        setState(() {
          _isTranscribing = false;
          _voiceTranscriptController.text = transcript;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isTranscribing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transcription failed. You can type notes manually.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _formatRecordingTime() {
    if (_recordingStartTime == null) return '00:00';
    final elapsed = DateTime.now().difference(_recordingStartTime!);
    final m = elapsed.inMinutes.toString().padLeft(2, '0');
    final s = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _pickFileAndAnalyze() async {
    setState(() => _isAnalyzingUpload = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        if (mounted) setState(() => _isAnalyzingUpload = false);
        return;
      }

      final fileBytes = result.files.first.bytes;
      final filePath = result.files.first.path;

      List<int> bytes;
      if (fileBytes != null) {
        bytes = fileBytes;
      } else if (filePath != null) {
        bytes = await File(filePath).readAsBytes();
      } else {
        if (mounted) setState(() => _isAnalyzingUpload = false);
        return;
      }

      final base64Image = base64Encode(bytes);
      _capturedImageBase64 = base64Image;

      final analysisResult = await ApiService.analyzeCard(base64Image);
      final data = analysisResult['data'] as Map<String, dynamic>? ?? {};

      if (!mounted) return;
      _applyExtractedData(data);
      _captureType = 'business_card';

      // If in scanner stage, move to notes
      if (_stage == _CaptureStage.scanner) {
        _scannerController.stop();
        setState(() {
          _stage = _CaptureStage.notes;
          _notesTab = _CaptureNotesTab.upload;
          _isAnalyzingUpload = false;
        });
      } else {
        setState(() {
          _isAnalyzingUpload = false;
          _notesTab = _CaptureNotesTab.upload;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contact info extracted from image.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isAnalyzingUpload = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not analyze image.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openVoiceMemoryCapture() async {
    _scannerController.stop();
    final result = await Navigator.of(context).push<Object?>(
      MaterialPageRoute(builder: (_) => const VoiceMemoryCaptureScreen()),
    );

    if (!mounted) return;
    _scannerController.start();

    if (result == null) return;
    final resultLabel = result.toString();
    if (resultLabel.contains('manual')) {
      setState(() {
        _stage = _CaptureStage.notes;
        _notesTab = _CaptureNotesTab.manual;
        _captureType = 'manual';
        _leadSaved = false;
      });
      return;
    }
    if (resultLabel.contains('saved')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Voice memory saved.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _finalizeLead() async {
    // Validate
    if (_firstName.isEmpty && _lastName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide at least a name.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isSavingLead = true;
      _leadSaved = false;
      _showDedupAlert = false;
    });

    try {
      // Check duplicates
      final dupResult = await ApiService.checkDuplicateContacts(
        name: _fullName.isNotEmpty ? _fullName : null,
        email: _email.isNotEmpty ? _email : null,
        phone: _phone.isNotEmpty ? _phone : null,
      );

      if (!mounted) return;

      final hasDups = dupResult['has_duplicates'] as bool? ?? false;
      if (hasDups) {
        final dupData = dupResult['data'] as List? ?? [];
        setState(() {
          _isSavingLead = false;
          _duplicates = dupData.cast<Map<String, dynamic>>();
          _showDedupAlert = true;
        });
        return;
      }

      // No duplicates — save directly
      await _saveCapture();
    } catch (e) {
      if (!mounted) return;
      // If dedup check fails, still try to save
      await _saveCapture();
    }
  }

  Future<void> _saveCapture() async {
    try {
      final notes = _manualNotesController.text.trim();
      final transcript = _voiceTranscriptController.text.trim();
      final rawText = [notes, transcript].where((s) => s.isNotEmpty).join('\n\n');

      final extractedData = <String, dynamic>{
        if (_firstName.isNotEmpty) 'first_name': _firstName,
        if (_lastName.isNotEmpty) 'last_name': _lastName,
        if (_fullName.isNotEmpty) 'name': _fullName,
        if (_company.isNotEmpty) 'company': _company,
        if (_email.isNotEmpty) 'email': _email,
        if (_phone.isNotEmpty) 'phone': _phone,
        if (_jobTitle.isNotEmpty) 'job_title': _jobTitle,
      };

      await ApiService.createCapture(
        captureType: _captureType,
        imageData: _capturedImageBase64,
        rawText: rawText.isNotEmpty ? rawText : null,
        extractedData: extractedData,
        eventId: _selectedEventId,
      );

      if (!mounted) return;

      final lastName = _lastName.isNotEmpty ? _lastName : _firstName;
      final company = _company.isNotEmpty ? ' (${_company.split(' ').first})' : '';
      setState(() {
        _isSavingLead = false;
        _leadSaved = true;
        _lastCaptureName = '$_firstName $lastName$company'.trim();
      });

      await Future<void>.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSavingLead = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildDedupAlertOverlay() {
    final existing = _duplicates.isNotEmpty ? _duplicates.first : <String, dynamic>{};

    return Positioned.fill(
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () {},
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(color: Colors.black.withValues(alpha: 0.60)),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Container(
                constraints: const BoxConstraints(maxHeight: 740, maxWidth: 760),
                decoration: BoxDecoration(
                  color: _c.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  border: Border(
                    top: BorderSide(color: _c.border),
                    left: BorderSide(color: _c.border),
                    right: BorderSide(color: _c.border),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 28,
                      offset: Offset(0, -10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 48,
                      height: 4,
                      decoration: BoxDecoration(
                        color: _c.border,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.only(bottom: 22),
                              decoration: BoxDecoration(
                                border: Border(bottom: BorderSide(color: _c.border)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.warning, color: _c.textPrimary, size: 22),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'Deduplication Alert — Potential Conflict Detected',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: -0.2,
                                            color: _c.textPrimary,
                                            height: 1.3,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.05),
                                      border: Border.all(color: _c.border),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'POSSIBLE DUPLICATE',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 1.1,
                                            color: _c.textMuted,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          '${_duplicates.length} match${_duplicates.length != 1 ? 'es' : ''} found',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: _c.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            _buildDedupComparisonGrid(existing),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                      decoration: BoxDecoration(
                        color: _c.surfaceAlt,
                        border: Border(top: BorderSide(color: _c.border)),
                      ),
                      child: Column(
                        children: [
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final isWide = constraints.maxWidth >= 680;
                              final actions = [
                                _buildDedupActionButton(
                                  label: 'MERGE AND UPDATE',
                                  isPrimary: true,
                                  onTap: () => _resolveDedupAction('merge'),
                                ),
                                _buildDedupActionButton(
                                  label: 'LINK AS SAME PERSON',
                                  onTap: () => _resolveDedupAction('link'),
                                ),
                                _buildDedupActionButton(
                                  label: 'CREATE AS NEW',
                                  onTap: () => _resolveDedupAction('create_new'),
                                ),
                              ];

                              if (isWide) {
                                return Row(
                                  children: [
                                    for (var i = 0; i < actions.length; i++) ...[
                                      Expanded(child: actions[i]),
                                      if (i != actions.length - 1) const SizedBox(width: 16),
                                    ],
                                  ],
                                );
                              }

                              return Column(
                                children: [
                                  actions[0],
                                  const SizedBox(height: 12),
                                  actions[1],
                                  const SizedBox(height: 12),
                                  actions[2],
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 18),
                          TextButton.icon(
                            onPressed: () => setState(() => _showDedupAlert = false),
                            icon: const Icon(Icons.close, size: 18),
                            label: const Text(
                              'DISMISS WITHOUT ACTION',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 2.0),
                            ),
                            style: TextButton.styleFrom(foregroundColor: _c.textMuted),
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

  Widget _buildDedupComparisonGrid(Map<String, dynamic> existing) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 680;
        final existingName = existing['name'] as String? ??
            [existing['first_name'], existing['last_name']]
                .where((s) => s != null && s.toString().isNotEmpty)
                .join(' ');
        final existingEmail = existing['email'] as String? ?? '';
        final existingCompany = existing['company'] as String? ?? '';

        final existingCard = _buildDedupRecordCard(
          badge: 'Existing Record',
          badgeBackground: Colors.white.withValues(alpha: 0.10),
          badgeColor: _c.textMuted,
          name: existingName.isNotEmpty ? existingName : 'Unknown',
          email: existingEmail,
          company: existingCompany,
          lastActive: existing['created_at'] as String? ?? '—',
          isNewSubmission: false,
        );
        final incomingCard = _buildDedupRecordCard(
          badge: 'New Submission',
          badgeBackground: _c.textPrimary,
          badgeColor: Colors.white,
          name: _fullName.isNotEmpty ? _fullName : 'Unknown',
          email: _email,
          company: _company,
          lastActive: 'Current Submission',
          isNewSubmission: true,
        );

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: existingCard),
              const SizedBox(width: 16),
              Expanded(child: incomingCard),
            ],
          );
        }

        return Column(children: [existingCard, const SizedBox(height: 16), incomingCard]);
      },
    );
  }

  Widget _buildDedupRecordCard({
    required String badge,
    required Color badgeBackground,
    required Color badgeColor,
    required String name,
    required String email,
    required String company,
    required String lastActive,
    required bool isNewSubmission,
  }) {
    Widget field(String label, Widget value) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 1.4, color: _c.textMuted)),
          const SizedBox(height: 6),
          value,
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        color: _c.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _c.border),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: badgeBackground,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                badge.toUpperCase(),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.0, color: badgeColor),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                field('NAME', Row(
                  children: [
                    Text(name, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: _c.textPrimary)),
                    if (isNewSubmission) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.info_outline, color: Color(0xFF8E9192), size: 16),
                    ],
                  ],
                )),
                const SizedBox(height: 18),
                field('EMAIL', Text(email.isNotEmpty ? email : '—', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: _c.textPrimary))),
                const SizedBox(height: 18),
                field('COMPANY', Text(company.isNotEmpty ? company : '—', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: _c.textPrimary))),
                const SizedBox(height: 18),
                field('LAST ACTIVE', Text(lastActive, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: isNewSubmission ? _c.textPrimary : _c.textMuted))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDedupActionButton({
    required String label,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: isPrimary ? _c.textPrimary : Colors.transparent,
          foregroundColor: isPrimary ? Colors.white : _c.textMuted,
          side: BorderSide(color: isPrimary ? _c.textPrimary : _c.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 2.0,
            color: isPrimary ? Colors.white : _c.textMuted,
          ),
        ),
      ),
    );
  }

  Future<void> _resolveDedupAction(String action) async {
    setState(() {
      _showDedupAlert = false;
      _isSavingLead = true;
    });

    try {
      if (action == 'create_new') {
        // Save as a brand new capture/contact
        await _saveCapture();
      } else {
        // For merge/link — still create capture, backend handles dedup logic
        await _saveCapture();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSavingLead = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), behavior: SnackBarBehavior.floating),
      );
    }
  }
}

class _CornerPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final bool top;
  final bool left;

  const _CornerPainter({
    required this.color,
    required this.strokeWidth,
    required this.top,
    required this.left,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final horizontalStart = Offset(left ? 0 : size.width, top ? 0 : size.height);
    final horizontalEnd = Offset(left ? size.width : 0, top ? 0 : size.height);
    final verticalEnd = Offset(left ? 0 : size.width, top ? size.height : 0);

    canvas.drawLine(horizontalStart, horizontalEnd, paint);
    canvas.drawLine(horizontalStart, verticalEnd, paint);
  }

  @override
  bool shouldRepaint(covariant _CornerPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.top != top ||
        oldDelegate.left != left;
  }
}
