import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_theme.dart';
import '../widgets/entry_flow_components.dart';

class ModeSelectionScreen extends StatefulWidget {
  const ModeSelectionScreen({super.key});

  @override
  State<ModeSelectionScreen> createState() => _ModeSelectionScreenState();
}

class _ModeSelectionScreenState extends State<ModeSelectionScreen> {
  static const String _chatMode = 'chat';
  static const String _crmMode = 'main';

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

    context.go(mode == _chatMode ? '/chat' : '/');
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return EntryFlowScaffold(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(isMobile ? 16 : 24, 8, isMobile ? 16 : 24, isMobile ? 24 : 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const EntryFlowTopBar(
                  leadingIcon: Icons.grid_view_rounded,
                  title: 'EXONO',
                  badgeLabel: 'Mode Select',
                ),
                const SizedBox(height: 24),
                _buildHeroCard(),
                const SizedBox(height: 24),
                Text(
                  'AVAILABLE MODES',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(letterSpacing: 1.3),
                ),
                const SizedBox(height: 12),
                if (isMobile)
                  Column(
                    children: [
                      _buildModeCard(
                        mode: _chatMode,
                        title: 'AI Chat Mode',
                        description: 'Launch directly into the assistant for quick questions, summaries, and follow-up drafting.',
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
                        description: 'Open the full mobile CRM with targets, events, capture flows, contacts, and follow-ups.',
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
                          description: 'Launch directly into the assistant for quick questions, summaries, and follow-up drafting.',
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
                          description: 'Open the full mobile CRM with targets, events, capture flows, contacts, and follow-ups.',
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
    );
  }

  Widget _buildHeroCard() {
    return EntryPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const EntryEyebrow(label: 'EXONO EXPERIENCE'),
          const SizedBox(height: 18),
          Text(
            'Choose how you want to work today.',
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 10),
          Text(
            'Jump straight into AI chat for lightweight assistance, or open the full CRM command center for targets, events, capture, and contact operations.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 18),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              EntryChip(icon: Icons.forum_rounded, label: 'AI Chat'),
              EntryChip(icon: Icons.track_changes_rounded, label: 'Targets + Events'),
              EntryChip(icon: Icons.qr_code_scanner_rounded, label: 'Capture Flow'),
            ],
          ),
        ],
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
    final colors = AppTheme.colorsOf(context);
    final isSelected = _selectedMode == mode;
    final isBusy = isSelected && _isNavigating;

    return InkWell(
      onTap: () => _selectMode(mode),
      borderRadius: BorderRadius.circular(28),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: isSelected ? LinearGradient(colors: [colors.accentSoft, colors.surface]) : null,
          color: isSelected ? null : colors.surface.withValues(alpha: colors.isDark ? 0.90 : 0.97),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isSelected ? colors.accent.withValues(alpha: 0.45) : colors.border,
            width: 1,
          ),
          boxShadow: isSelected ? AppTheme.softShadow(context) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: isSelected ? colors.surface : colors.surfaceAlt,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: colors.border),
                  ),
                  child: Icon(icon, color: colors.accentStrong, size: 24),
                ),
                const Spacer(),
                Icon(accentIcon, size: 22, color: isSelected ? colors.accentStrong : colors.textMuted),
              ],
            ),
            const SizedBox(height: 18),
            Text(title, style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 8),
            Text(description, style: Theme.of(context).textTheme.bodyLarge),
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
                        color: colors.accentSoft,
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.border),
                      ),
                      child: Icon(Icons.check_rounded, size: 12, color: colors.accentStrong),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        feature,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            EntrySoftTile(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  if (isBusy)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: FCircularProgress(),
                    )
                  else
                    Icon(
                      isSelected ? Icons.arrow_forward_rounded : Icons.touch_app_rounded,
                      size: 16,
                      color: colors.accentStrong,
                    ),
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
                        color: colors.textPrimary,
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
