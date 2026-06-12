import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import '../providers/chat_provider.dart';

/// Renders tappable chips for records created/linked by the assistant.
class MessageLinkChips extends StatelessWidget {
  final List<MessageLink> links;

  const MessageLinkChips({super.key, required this.links});

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];

    for (final link in links) {
      if (link.contactId != null) {
        chips.add(_chip(
          context,
          icon: Icons.person_rounded,
          label: 'Contact',
          color: const Color(0xFF2563EB),
          onTap: () => _showInfo(context, 'Contact', link.contactId!),
        ));
      }
      if (link.eventId != null) {
        chips.add(_chip(
          context,
          icon: Icons.event_rounded,
          label: 'Event',
          color: const Color(0xFF2563EB),
          onTap: () => _showInfo(context, 'Event', link.eventId!),
        ));
      }
      if (link.reminderId != null) {
        chips.add(_chip(
          context,
          icon: Icons.alarm_rounded,
          label: 'Reminder',
          color: const Color(0xFFD97706),
          onTap: () => _showInfo(context, 'Reminder', link.reminderId!),
        ));
      }
      if (link.emailDraftId != null) {
        chips.add(_chip(
          context,
          icon: Icons.mail_rounded,
          label: 'Email Draft',
          color: const Color(0xFF059669),
          onTap: () => _showInfo(context, 'Email Draft', link.emailDraftId!),
        ));
      }
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Wrap(spacing: 6, runSpacing: 4, children: chips);
  }

  Widget _chip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInfo(BuildContext context, String type, String id) {
    showFToast(context: context, title: Text('$type created (id: ${id.substring(0, 8)}...)'));
  }
}
