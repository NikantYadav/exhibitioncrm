import 'dart:ui';

import 'package:flutter/material.dart';

import '../config/app_theme.dart';
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

  _CaptureStage _stage = _CaptureStage.scanner;
  _CaptureNotesTab _notesTab = _CaptureNotesTab.manual;
  bool _isCapturing = false;
  bool _isSavingLead = false;
  bool _leadSaved = false;
  bool _showDedupAlert = false;
  String _selectedProduct = 'Core Platform v2';
  final _CapturedLead _capturedLead = const _CapturedLead(
    initials: 'MT',
    name: 'Marcus Thorne',
    company: 'Quantum Dynamics Inc.',
  );

  final List<String> _productOptions = const [
    'Core Platform v2',
    'Enterprise API Suite',
    'Edge Intelligence Module',
    'Add new product',
  ];

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scanController.dispose();
    _manualNotesController.dispose();
    super.dispose();
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
      return ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: _c.surface.withValues(alpha: 0.78),
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
                          onPressed: () => _showUiOnlyMessage('Flash toggle'),
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
              onPressed: () => setState(() => _stage = _CaptureStage.scanner),
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
            IconButton(
              onPressed: () => _showUiOnlyMessage('Settings'),
              splashRadius: 20,
              icon: Icon(
                Icons.settings,
                color: _c.textMuted,
                size: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScannerStage() {
    return Stack(
      children: [
        Positioned.fill(
          child: ColorFiltered(
            colorFilter: const ColorFilter.matrix(<double>[
              0.2126,
              0.7152,
              0.0722,
              0,
              0,
              0.2126,
              0.7152,
              0.0722,
              0,
              0,
              0.2126,
              0.7152,
              0.0722,
              0,
              0,
              0,
              0,
              0,
              1,
              0,
            ]),
            child: Opacity(
              opacity: 0.32,
              child: Image.network(
                'https://lh3.googleusercontent.com/aida-public/AB6AXuATbiHBNTF_S2iKxWObfhWd05n1WWdiC9-7UVATTVuNYH1mduB5y8A2g2Khr-EQ3mjFfdQ1Cb4gWobFTKkhJ7d_EM09-dprcw0rDxbFfFD6Havh--_7q8g5yaj7-OtYdd3kqNK91U7_3hoMSPfDwM6GZzZNLmDPX3CYEZ-kEhURMHm94ecDDgOU1xuPefAhONjj9ByUqUvahXy6pveYtqWJpjMXeXqzm0dv9SmmqKkullWosZ-ZaxTSFFuZAid5EhC_pS8efX7BACo',
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
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
                              onTap: () => _showUiOnlyMessage('File picker'),
                            ),
                            const SizedBox(width: 48),
                            _buildScannerActionButton(
                              icon: Icons.edit_note_outlined,
                              label: 'MANUAL',
                              onTap: () {
                                setState(() {
                                  _stage = _CaptureStage.notes;
                                  _notesTab = _CaptureNotesTab.manual;
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
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Global Tech Summit 2024',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: _c.textMuted,
                    ),
                  ),
                ),
                Icon(
                  Icons.lock,
                  size: 18,
                  color: _c.textMuted.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          _buildFieldLabel('PRODUCT INTEREST'),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: _c.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _c.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedProduct,
                dropdownColor: _c.surfaceAlt,
                isExpanded: true,
                icon: Icon(Icons.expand_more, color: _c.textMuted),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: _c.textPrimary,
                ),
                items: _productOptions
                    .map(
                      (option) => DropdownMenuItem<String>(
                        value: option,
                        child: Text(option),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedProduct = value);
                  }
                },
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
                    ? SizedBox(
                        key: const ValueKey('processing'),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _c.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _c.border),
      ),
      child: Row(
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
              _capturedLead.initials,
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
                  _capturedLead.name,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: _c.textPrimary,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _capturedLead.company.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.0,
                    color: _c.textMuted,
                  ),
                ),
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
    Widget tab(String label, _CaptureNotesTab tab) {
      final isActive = _notesTab == tab;
      return Expanded(
        child: InkWell(
          onTap: () => setState(() => _notesTab = tab),
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
        return Container(
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
                  border: Border.all(color: _c.textPrimary),
                ),
                child: Icon(Icons.mic, color: _c.textPrimary, size: 32),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: AnimatedBuilder(
                      animation: _scanController,
                      builder: (context, child) {
                        final base =
                            ((_scanController.value + (index * 0.12)) % 1.0);
                        final height =
                            4 + (20 * (0.5 - (base - 0.5).abs()) * 2);
                        return Container(
                          width: 4,
                          height: height.clamp(4, 24),
                          color: _c.textPrimary,
                        );
                      },
                    ),
                  );
                }),
              ),
              const SizedBox(height: 12),
              Text(
                '00:12',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: _c.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'TAP TO STOP',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                  color: _c.textMuted,
                ),
              ),
            ],
          ),
        );
      case _CaptureNotesTab.upload:
        return InkWell(
          onTap: () => _showUiOnlyMessage('Upload notes file'),
          child: Container(
            height: 160,
            decoration: BoxDecoration(
              color: _c.surfaceAlt,
              border: Border.all(
                color: _c.border,
                style: BorderStyle.solid,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.upload_file, color: _c.textMuted),
                const SizedBox(height: 10),
                Text(
                  'DROP FILE HERE OR TAP TO BROWSE',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.1,
                    color: _c.textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'PDF, JPG, PNG UP TO 10MB',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.8,
                    color: _c.textMuted.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        );
    }
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _c.surfaceAlt.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: _c.border.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.history,
                      size: 14,
                      color: _c.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Last: Sarah Jenkins (Aero)',
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
      onTap: _isCapturing ? null : _simulateCapture,
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
          Icon(
            icon,
            size: 24,
            color: _c.textMuted.withValues(alpha: 0.72),
          ),
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

  Future<void> _openVoiceMemoryCapture() async {
    final result = await Navigator.of(context).push<Object?>(
      MaterialPageRoute(builder: (_) => const VoiceMemoryCaptureScreen()),
    );

    if (!mounted) return;
    if (result == null) return;

    final resultLabel = result.toString();
    if (resultLabel.contains('manual')) {
      setState(() {
        _stage = _CaptureStage.notes;
        _notesTab = _CaptureNotesTab.manual;
        _leadSaved = false;
      });
      return;
    }

    if (resultLabel.contains('saved')) {
      _showUiOnlyMessage('Voice memory saved to timeline');
    }
  }

  Future<void> _simulateCapture() async {
    setState(() => _isCapturing = true);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() {
      _isCapturing = false;
      _stage = _CaptureStage.notes;
      _notesTab = _CaptureNotesTab.manual;
      _leadSaved = false;
    });
  }

  Future<void> _finalizeLead() async {
    setState(() {
      _isSavingLead = true;
      _leadSaved = false;
      _showDedupAlert = false;
    });
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    setState(() {
      _isSavingLead = false;
      _showDedupAlert = true;
    });
  }

  Widget _buildDedupAlertOverlay() {
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
                constraints: const BoxConstraints(
                  maxHeight: 740,
                  maxWidth: 760,
                ),
                decoration: BoxDecoration(
                  color: _c.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
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
                                border: Border(
                                  bottom: BorderSide(color: _c.border),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.warning,
                                        color: _c.textPrimary,
                                        size: 22,
                                      ),
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
                                  Wrap(
                                    spacing: 14,
                                    runSpacing: 10,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.05,
                                          ),
                                          border: Border.all(
                                            color: _c.border,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'AI CONFIDENCE SCORE',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: 1.1,
                                                color: _c.textMuted,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              '98% Match',
                                              style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w600,
                                                color: _c.textPrimary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 420,
                                        ),
                                        child: Text(
                                          '"High probability match based on matching email domain and phonetic name similarity across multiple datasets."',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w400,
                                            fontStyle: FontStyle.italic,
                                            color: _c.textMuted,
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            _buildDedupComparisonGrid(),
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
                                  onTap: () =>
                                      _resolveDedupAction('Merge and update'),
                                ),
                                _buildDedupActionButton(
                                  label: 'LINK AS SAME PERSON',
                                  onTap: () => _resolveDedupAction(
                                    'Link as same person',
                                  ),
                                ),
                                _buildDedupActionButton(
                                  label: 'CREATE AS NEW',
                                  onTap: () =>
                                      _resolveDedupAction('Create as new'),
                                ),
                              ];

                              if (isWide) {
                                return Row(
                                  children: [
                                    for (
                                      var i = 0;
                                      i < actions.length;
                                      i++
                                    ) ...[
                                      Expanded(child: actions[i]),
                                      if (i != actions.length - 1)
                                        const SizedBox(width: 16),
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
                            onPressed: () =>
                                setState(() => _showDedupAlert = false),
                            icon: const Icon(Icons.close, size: 18),
                            label: Text(
                              'DISMISS WITHOUT ACTION',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 2.0,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: _c.textMuted,
                            ),
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

  Widget _buildDedupComparisonGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 680;
        final existing = _buildDedupRecordCard(
          badge: 'Existing Record',
          badgeBackground: Colors.white.withValues(alpha: 0.10),
          badgeColor: _c.textMuted,
          name: 'Alexander Thorne',
          email: 'a.thorne@vanguard-ops.io',
          company: 'Vanguard Operations Ltd.',
          lastActive: '14 Oct 2023',
          isNewSubmission: false,
        );
        final incoming = _buildDedupRecordCard(
          badge: 'New Submission',
          badgeBackground: _c.textPrimary,
          badgeColor: Colors.white,
          name: 'Alex Thorne',
          email: 'alex.thorne@vanguard-ops.io',
          company: 'Vanguard Ops',
          lastActive: 'Current Submission',
          isNewSubmission: true,
        );

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: existing),
              const SizedBox(width: 16),
              Expanded(child: incoming),
            ],
          );
        }

        return Column(
          children: [existing, const SizedBox(height: 16), incoming],
        );
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
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.4,
              color: _c.textMuted,
            ),
          ),
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
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                  color: badgeColor,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                field(
                  'NAME',
                  Row(
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: _c.textPrimary,
                        ),
                      ),
                      if (isNewSubmission) ...[
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.info_outline,
                          color: Color(0xFF8E9192),
                          size: 16,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                field(
                  'EMAIL',
                  Text(
                    email,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: _c.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                field(
                  'COMPANY',
                  Text(
                    company,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: _c.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                field(
                  'LAST ACTIVE',
                  Text(
                    lastActive,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: isNewSubmission ? _c.textPrimary : _c.textMuted,
                    ),
                  ),
                ),
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

  void _resolveDedupAction(String label) {
    setState(() {
      _showDedupAlert = false;
      _leadSaved = true;
    });
    _showUiOnlyMessage(label);
  }

  void _showUiOnlyMessage(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label is UI-only for now.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}


class _CapturedLead {
  final String initials;
  final String name;
  final String company;

  const _CapturedLead({
    required this.initials,
    required this.name,
    required this.company,
  });
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

    final horizontalStart = Offset(
      left ? 0 : size.width,
      top ? 0 : size.height,
    );
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
