import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../providers/notification_provider.dart';
import '../providers/offline_provider.dart';
import '../services/api_service.dart';
import '../services/offline/write_gateway.dart';
import 'app_button.dart';
import 'app_card.dart';
import 'app_feedback.dart';
import 'app_section_label.dart';

void showAppNotificationSheet(BuildContext context) {
  showAppSheet(context: context, builder: (ctx) => const _NotificationSheet());
}

class _NotificationSheet extends StatelessWidget {
  const _NotificationSheet();

  @override
  Widget build(BuildContext context) {
    final notifications = context.watch<NotificationProvider>().notifications;

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: context.theme.colors.border,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Notifications',
                    style: context.theme.typography.lg.copyWith(
                      fontWeight: FontWeight.w700,
                      color: context.theme.colors.foreground,
                    ),
                  ),
                ),
                if (notifications.isNotEmpty)
                  GestureDetector(
                    onTap: () => context.read<NotificationProvider>().clear(),
                    child: Text(
                      'Clear all',
                      style: context.theme.typography.sm.copyWith(
                        color: AppTheme.colorsOf(context).accent,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (notifications.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
              child: Column(
                children: [
                  Icon(
                    Icons.notifications_none_rounded,
                    size: 40,
                    color: context.theme.colors.mutedForeground,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No unread notifications',
                    style: context.theme.typography.sm.copyWith(
                      color: context.theme.colors.mutedForeground,
                    ),
                  ),
                ],
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                itemCount: notifications.length,
                separatorBuilder: (_, i) => const SizedBox(height: 12),
                itemBuilder: (ctx, i) {
                  final n = notifications[i];
                  if (n is DedupNotification) {
                    return _DedupCard(notification: n);
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _DedupCard extends StatefulWidget {
  final DedupNotification notification;
  const _DedupCard({required this.notification});

  @override
  State<_DedupCard> createState() => _DedupCardState();
}

class _DedupCardState extends State<_DedupCard> {
  bool _isLoading = false;

  DedupNotification get n => widget.notification;

  /// Best available display name for the pending contact, falling back through
  /// first/last -> name -> email -> a generic label so the card is never empty.
  String _pendingLabel(Map<String, dynamic> c) {
    final full = [
      (c['first_name'] ?? '').toString().trim(),
      (c['last_name'] ?? '').toString().trim(),
    ].where((s) => s.isNotEmpty).join(' ');
    if (full.isNotEmpty) return full;
    final name = (c['name'] ?? '').toString().trim();
    if (name.isNotEmpty) return name;
    final email = (c['email'] ?? '').toString().trim();
    if (email.isNotEmpty) return email;
    return 'New contact';
  }

  Future<void> _resolve({required bool merge}) async {
    setState(() => _isLoading = true);
    try {
      if (merge) {
        final existingId = n.dupes.first['id'] as String?;
        if (existingId == null) {
          await _createNew();
          return;
        }
        await ApiService.logInteraction(
          contactId: existingId,
          type: 'manual',
          summary: n.rawText ?? 'Merged contact',
          eventId: n.eventId,
        );
      } else {
        await _createNew();
        return;
      }
      if (!mounted) return;
      await _clearNotification();
      if (!mounted) return;
      showAppToast(context, merge ? 'Merged with existing contact' : 'Saved as new contact');
    } catch (_) {
      if (!mounted) return;
      showAppToast(context, 'Action failed — please try again');
    } finally {
      if (mounted) { setState(() => _isLoading = false); }
    }
  }

  Future<void> _createNew() async {
    await WriteGateway().createCapture(
      captureType: 'manual',
      rawText: n.rawText,
      eventId: n.eventId,
      extractedData: n.pendingContact,
      skipDuplicateCheck: true,
    );
    if (!mounted) return;
    await _clearNotification();
    if (!mounted) return;
    showAppToast(context, 'Saved as new contact');
  }

  /// Removes the in-memory card and deletes the durable parked op so the
  /// notification doesn't reappear on the next sync/restart.
  Future<void> _clearNotification() async {
    context.read<NotificationProvider>().remove(n.id);
    await context.read<OfflineProvider>().resolveReview(n.id);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.colorsOf(context);
    final existing = n.dupes.isNotEmpty ? n.dupes.first : null;
    final pendingName = _pendingLabel(n.pendingContact);

    return AppCard(
      elevated: true,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: c.accent, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Possible duplicate detected',
                  style: context.theme.typography.sm.copyWith(
                    fontWeight: FontWeight.w700,
                    color: context.theme.colors.foreground,
                  ),
                ),
              ),
              GestureDetector(
                onTap: _isLoading ? null : _clearNotification,
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: c.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AppSectionLabel('New contact'),
          const SizedBox(height: 8),
          AppCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pendingName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.theme.typography.sm.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.theme.colors.foreground,
                  ),
                ),
                if ((n.pendingContact['email'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    n.pendingContact['email'].toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.theme.typography.sm.copyWith(
                      color: context.theme.colors.mutedForeground,
                    ),
                  ),
                ],
                if ((n.pendingContact['company'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    n.pendingContact['company'].toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.theme.typography.xs.copyWith(
                      color: context.theme.colors.mutedForeground,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (existing != null) ...[
            const SizedBox(height: 12),
            AppSectionLabel('Existing record'),
            const SizedBox(height: 8),
            AppCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${existing['first_name'] ?? ''} ${existing['last_name'] ?? ''}'.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.theme.typography.sm.copyWith(
                      fontWeight: FontWeight.w600,
                      color: context.theme.colors.foreground,
                    ),
                  ),
                  if (existing['email'] != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      existing['email'] as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.theme.typography.sm.copyWith(
                        color: context.theme.colors.mutedForeground,
                      ),
                    ),
                  ],
                  if (existing['company'] != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      (existing['company'] as Map?)?['name'] as String? ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.theme.typography.xs.copyWith(
                        color: context.theme.colors.mutedForeground,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          AppButton(
            label: 'MERGE WITH EXISTING',
            onPressed: _isLoading ? null : () => _resolve(merge: true),
            isLoading: _isLoading,
            fullWidth: true,
          ),
          const SizedBox(height: 8),
          AppButton(
            label: 'CREATE AS NEW CONTACT',
            onPressed: _isLoading ? null : () => _resolve(merge: false),
            variant: ButtonVariant.secondary,
            fullWidth: true,
          ),
          const SizedBox(height: 8),
          AppButton(
            label: 'DISMISS',
            onPressed: _isLoading ? null : _clearNotification,
            variant: ButtonVariant.ghost,
            fullWidth: true,
          ),
        ],
      ),
    );
  }
}
