import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/app_card.dart';
import '../widgets/app_chip.dart';
import '../widgets/app_section_label.dart';

class VoiceMemoryCaptureScreen extends StatefulWidget {
  const VoiceMemoryCaptureScreen({super.key});

  @override
  State<VoiceMemoryCaptureScreen> createState() =>
      _VoiceMemoryCaptureScreenState();
}

class _VoiceMemoryCaptureScreenState extends State<VoiceMemoryCaptureScreen>
    with TickerProviderStateMixin {
  ExonoColors get _c => AppTheme.colorsOf(context);

  late final AnimationController _ringController;
  late final AnimationController _waveController;

  bool _isRecording = false;
  bool _showAiPreview = false;
  Duration _elapsed = Duration.zero;
  Timer? _timer;

  final List<String> _topics = const ['Expansion', 'Q3 Roadmap'];
  final List<String> _actions = const ['Sync with HR', 'Draft PRD'];

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ringController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _c.background,
      bottomNavigationBar: AppBottomNav(
        selectedIndex: 4,
        onNavigate: (i) => Navigator.of(context).pop(),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight:
                        MediaQuery.of(context).size.height -
                        MediaQuery.of(context).padding.top -
                        80,
                  ),
                  child: Column(
                    children: [
                      if (!_showAiPreview) ...[
                        const SizedBox(height: 28),
                        AnimatedOpacity(
                          opacity: _isRecording ? 0.4 : 1,
                          duration: const Duration(milliseconds: 300),
                          child: _buildIntro(),
                        ),
                        const SizedBox(height: 28),
                        _buildRecorder(),
                        const SizedBox(height: 32),
                        AnimatedOpacity(
                          opacity: _isRecording ? 1 : 0,
                          duration: const Duration(milliseconds: 300),
                          child: _buildRecordingInfo(),
                        ),
                        const SizedBox(height: 32),
                        _buildUtilityActions(),
                      ] else ...[
                        _buildAiPreview(),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _c.background.withValues(alpha: 0.88),
        border: Border(bottom: BorderSide(color: _c.border, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  splashRadius: 20,
                  icon: Icon(Icons.close, color: _c.textPrimary, size: 22),
                ),
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
              ],
            ),
          ),
          IconButton(
            onPressed: () => _showUiOnlyMessage('Help is UI-only for now.'),
            splashRadius: 20,
            icon: Icon(
              Icons.help_outline,
              color: _c.textMuted,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntro() {
    return Column(
      children: [
        Text(
          'Record Memory',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.6,
            color: _c.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Text(
            'Speak naturally. Our AI will extract key insights and link them to your timeline.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              height: 1.5,
              color: _c.textMuted,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecorder() {
    return SizedBox(
      width: 260,
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_isRecording) ...[
            _buildPulseRing(delay: 0),
            _buildPulseRing(delay: 0.5),
          ],
          GestureDetector(
            onTap: _toggleRecording,
            child: AnimatedScale(
              scale: _isRecording ? 0.96 : 1,
              duration: const Duration(milliseconds: 180),
              child: Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  color: _c.textPrimary,
                  shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1AFFFFFF),
                      blurRadius: 40,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Icon(
                  _isRecording ? Icons.stop_rounded : Icons.mic,
                  size: 40,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPulseRing({required double delay}) {
    return AnimatedBuilder(
      animation: _ringController,
      builder: (context, child) {
        final progress = (_ringController.value + delay) % 1.0;
        final scale = 0.8 + (0.5 * progress);
        final opacity = (0.5 * (1 - progress)).clamp(0.0, 0.5);

        return Transform.scale(
          scale: scale,
          child: Container(
            width: 192,
            height: 192,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _c.textPrimary.withValues(alpha: opacity)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecordingInfo() {
    return IgnorePointer(
      ignoring: !_isRecording,
      child: Column(
        children: [
          Text(
            _formatDuration(_elapsed),
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: 4,
              color: _c.textPrimary,
              height: 1,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 32,
            child: AnimatedBuilder(
              animation: _waveController,
              builder: (context, child) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(7, (index) {
                    final phase = _waveController.value * 2 * math.pi;
                    final value = math.sin(phase + (index * 0.8)).abs();
                    final height = 8 + (value * 18);
                    return Container(
                      width: 4,
                      height: height,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: _c.textPrimary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'RECORDING...',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 2.2,
              color: _c.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUtilityActions() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildUtilityButton(
              icon: Icons.keyboard_outlined,
              label: 'MANUAL',
              onTap: () => Navigator.of(context).pop(_VoiceMemoryResult.manual),
            ),
            const SizedBox(width: 16),
            _buildUtilityButton(
              icon: Icons.upload_file_outlined,
              label: 'UPLOAD',
              onTap: () => _showUiOnlyMessage(
                'Upload from voice memory is UI-only for now.',
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'CANCEL',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 2.2,
              color: _c.textMuted,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUtilityButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: _c.textMuted,
        side: BorderSide(color: _c.border),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 1.8,
        ),
      ),
    );
  }

  Widget _buildAiPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'AI Analysis',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: _c.textPrimary,
              ),
            ),
            AppChip.label('DRAFT'),
          ],
        ),
        const SizedBox(height: 24),
        _buildPreviewCard(
          icon: Icons.psychology_outlined,
          title: 'MEMORIES',
          child: Text(
            'Discussed the strategic expansion into the Southeast Asian market during the Q3 planning session.',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              height: 1.45,
              color: _c.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildPreviewCard(
                icon: Icons.sell_outlined,
                title: 'TOPICS',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _topics.map((topic) => AppChip(topic)).toList(),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildPreviewCard(
                icon: Icons.task_alt_outlined,
                title: 'ACTIONS',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _actions
                      .map(
                        (action) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '• $action',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: _c.textPrimary,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () =>
                    _showUiOnlyMessage('Edit draft is UI-only for now.'),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('EDIT'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _c.textSecondary,
                  side: BorderSide(color: _c.border),
                  backgroundColor: _c.surface,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.8,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: FilledButton.icon(
                onPressed: () =>
                    Navigator.of(context).pop(_VoiceMemoryResult.saved),
                icon: const Icon(Icons.save_outlined, size: 18),
                label: const Text('SAVE TO TIMELINE'),
                style: FilledButton.styleFrom(
                  backgroundColor: _c.textPrimary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.3,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPreviewCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      radius: 8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: _c.textPrimary),
              const SizedBox(width: 8),
              AppSectionLabel(title),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  void _toggleRecording() {
    if (_showAiPreview) return;

    if (_isRecording) {
      _timer?.cancel();
      _ringController.stop();
      setState(() {
        _isRecording = false;
        _showAiPreview = true;
      });
      return;
    }

    setState(() {
      _showAiPreview = false;
      _isRecording = true;
      _elapsed = Duration.zero;
    });

    _ringController.repeat();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsed += const Duration(seconds: 1);
      });
    });
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  void _showUiOnlyMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}

enum _VoiceMemoryResult { manual, saved }
