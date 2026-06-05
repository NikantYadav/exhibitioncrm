import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ModeSelectionScreen extends StatefulWidget {
  const ModeSelectionScreen({super.key});

  @override
  State<ModeSelectionScreen> createState() => _ModeSelectionScreenState();
}

class _ModeSelectionScreenState extends State<ModeSelectionScreen> {
  static const String _chatMode = 'chat';
  static const String _crmMode = 'main';

  static const Color _backgroundColor = Color(0xFF080808);
  static const Color _surfaceColor = Color(0xFF141313);
  static const Color _surfaceAltColor = Color(0xFF1C1B1B);
  static const Color _borderColor = Color(0xFF444748);
  static const Color _mutedColor = Color(0xFFC4C7C8);

  String? _selectedMode;
  bool _isNavigating = false;

  Future<void> _selectMode(String mode) async {
    if (_isNavigating) return;

    setState(() {
      _selectedMode = mode;
      _isNavigating = true;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_mode', mode);

    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    Navigator.of(
      context,
    ).pushReplacementNamed(mode == _chatMode ? '/chat' : '/main');
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isMobile = mediaQuery.size.width < 768;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: _backgroundColor,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _backgroundColor,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              isMobile ? 16 : 24,
              8,
              isMobile ? 16 : 24,
              isMobile ? 24 : 32,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTopBar(),
                    const SizedBox(height: 24),
                    _buildHeroCard(isMobile),
                    const SizedBox(height: 24),
                    _buildSectionLabel('Available Modes'),
                    const SizedBox(height: 12),
                    if (isMobile)
                      Column(
                        children: [
                          _buildModeCard(
                            mode: _chatMode,
                            title: 'AI Chat Mode',
                            description:
                                'Launch directly into the assistant for quick questions, summaries, and follow-up drafting.',
                            icon: Icons.forum_rounded,
                            accentIcon: Icons.psychology_alt_rounded,
                            features: const [
                              'Fast conversational assistance',
                              'Message search and thread context',
                              'Best for solo AI workflows',
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildModeCard(
                            mode: _crmMode,
                            title: 'CRM Command Center',
                            description:
                                'Open the full mobile CRM with targets, events, capture flows, contacts, and follow-ups.',
                            icon: Icons.track_changes_rounded,
                            accentIcon: Icons.dashboard_customize_rounded,
                            features: const [
                              'Targets, events, and offline prep',
                              'Capture cards, voice notes, and logs',
                              'Best for event-day execution',
                            ],
                          ),
                        ],
                      )
                    else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildModeCard(
                              mode: _chatMode,
                              title: 'AI Chat Mode',
                              description:
                                  'Launch directly into the assistant for quick questions, summaries, and follow-up drafting.',
                              icon: Icons.forum_rounded,
                              accentIcon: Icons.psychology_alt_rounded,
                              features: const [
                                'Fast conversational assistance',
                                'Message search and thread context',
                                'Best for solo AI workflows',
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildModeCard(
                              mode: _crmMode,
                              title: 'CRM Command Center',
                              description:
                                  'Open the full mobile CRM with targets, events, capture flows, contacts, and follow-ups.',
                              icon: Icons.track_changes_rounded,
                              accentIcon: Icons.dashboard_customize_rounded,
                              features: const [
                                'Targets, events, and offline prep',
                                'Capture cards, voice notes, and logs',
                                'Best for event-day execution',
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.grid_view_rounded,
              color: _backgroundColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'EXONO',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.2,
              color: Colors.white,
              height: 1,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _surfaceColor,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _borderColor),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.tune_rounded, size: 16, color: _mutedColor),
                SizedBox(width: 8),
                Text(
                  'Mode Select',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: _mutedColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 20 : 24),
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E0E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _borderColor),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -8,
            right: -8,
            child: Icon(
              Icons.psychology_alt_rounded,
              size: isMobile ? 84 : 112,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: const Text(
                  'EXONO EXPERIENCE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Choose how you want to work today.',
                style: TextStyle(
                  fontSize: isMobile ? 28 : 34,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.2,
                  color: Colors.white,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 10),
              const SizedBox(
                width: 540,
                child: Text(
                  'Jump straight into AI chat for lightweight assistance, or open the full CRM command center for targets, events, capture, and contact operations.',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    height: 1.5,
                    color: _mutedColor,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const [
                  _HeroPill(icon: Icons.forum_rounded, label: 'AI Chat'),
                  _HeroPill(
                    icon: Icons.track_changes_rounded,
                    label: 'Targets + Events',
                  ),
                  _HeroPill(
                    icon: Icons.qr_code_scanner_rounded,
                    label: 'Capture Flow',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
        color: _mutedColor,
      ),
    );
  }

  Widget _buildModeCard({
    required String mode,
    required String title,
    required String description,
    required IconData icon,
    required IconData accentIcon,
    required List<String> features,
  }) {
    final isSelected = _selectedMode == mode;
    final isBusy = isSelected && _isNavigating;

    return InkWell(
      onTap: () => _selectMode(mode),
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : _surfaceColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? Colors.white : _borderColor,
            width: 1,
          ),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 24,
                    offset: Offset(0, 12),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _backgroundColor.withValues(alpha: 0.06)
                        : _surfaceAltColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? _backgroundColor.withValues(alpha: 0.08)
                          : _borderColor,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: isSelected ? _backgroundColor : Colors.white,
                    size: 24,
                  ),
                ),
                const Spacer(),
                Icon(
                  accentIcon,
                  size: 22,
                  color: isSelected ? _backgroundColor : _mutedColor,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.8,
                color: isSelected ? _backgroundColor : Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: isSelected
                    ? _backgroundColor.withValues(alpha: 0.72)
                    : _mutedColor,
              ),
            ),
            const SizedBox(height: 18),
            ...features.map(
              (feature) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? _backgroundColor.withValues(alpha: 0.08)
                            : _surfaceAltColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? _backgroundColor.withValues(alpha: 0.08)
                              : _borderColor,
                        ),
                      ),
                      child: Icon(
                        Icons.check_rounded,
                        size: 12,
                        color: isSelected ? _backgroundColor : Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        feature,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? _backgroundColor
                              : Colors.white.withValues(alpha: 0.92),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? _backgroundColor : _surfaceAltColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? _backgroundColor
                      : Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Row(
                children: [
                  if (isBusy) ...[
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isSelected ? Colors.white : _mutedColor,
                        ),
                      ),
                    ),
                  ] else ...[
                    Icon(
                      isSelected
                          ? Icons.arrow_forward_rounded
                          : Icons.touch_app_rounded,
                      size: 16,
                      color: isSelected ? Colors.white : _mutedColor,
                    ),
                  ],
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isBusy
                          ? 'Opening ${mode == _chatMode ? 'AI Chat' : 'CRM'}...'
                          : isSelected
                          ? 'Selected — entering now'
                          : 'Tap to enter',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                        color: isSelected ? Colors.white : _mutedColor,
                      ),
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
}

class _HeroPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
