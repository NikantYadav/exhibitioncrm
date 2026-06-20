import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../providers/offline_provider.dart';
import '../services/offline/offline_queue.dart';
import '../services/offline/outbox_op.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_feedback.dart';
import '../widgets/app_header.dart';
import '../widgets/app_section_label.dart';
import '../widgets/app_status_badge.dart';
import '../widgets/empty_state.dart';

class SyncIssuesScreen extends StatefulWidget {
  const SyncIssuesScreen({super.key});

  @override
  State<SyncIssuesScreen> createState() => _SyncIssuesScreenState();
}

class _SyncIssuesScreenState extends State<SyncIssuesScreen> {
  List<OutboxOp> _ops = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final ops = await OfflineQueue.pending();
    if (!mounted) return;
    setState(() { _ops = ops; _loading = false; });
  }

  Future<void> _retry(OutboxOp op) async {
    await OfflineQueue.resetToPending(op.id);
    if (!mounted) return;
    context.read<OfflineProvider>().triggerSync();
    showAppToast(context, 'Queued for retry');
    await _load();
  }

  Future<void> _discard(OutboxOp op) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Discard operation?',
      message: 'This will permanently delete this queued item. It will not sync.',
      confirmLabel: 'Discard',
      destructive: true,
    );
    if (confirmed != true) return;
    await OfflineQueue.delete(op.id);
    if (!mounted) return;
    context.read<OfflineProvider>().refreshPendingCount();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.theme.colors.background,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppHeader(onBack: () => Navigator.of(context).pop()),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: FCircularProgress());
    }

    if (_ops.isEmpty) {
      return EmptyState(
        icon: Icons.check_circle_outline_rounded,
        title: 'All synced',
        description: 'No pending or failed operations.',
      );
    }

    final pending = _ops.where((o) => o.status == 'pending' || o.status == 'syncing').toList();
    final failed = _ops.where((o) => o.status == 'failed').toList();

    return RefreshIndicator(
      color: AppTheme.colorsOf(context).accent,
      backgroundColor: context.theme.colors.background,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (failed.isNotEmpty) ...[
            const AppSectionLabel('Failed'),
            const SizedBox(height: 8),
            ...failed.map((op) => _OpCard(op: op, onRetry: _retry, onDiscard: _discard)),
            const SizedBox(height: 20),
          ],
          if (pending.isNotEmpty) ...[
            const AppSectionLabel('Pending'),
            const SizedBox(height: 8),
            ...pending.map((op) => _OpCard(op: op, onDiscard: _discard)),
          ],
        ],
      ),
    );
  }
}

class _OpCard extends StatelessWidget {
  final OutboxOp op;
  final Future<void> Function(OutboxOp)? onRetry;
  final Future<void> Function(OutboxOp) onDiscard;

  const _OpCard({
    required this.op,
    this.onRetry,
    required this.onDiscard,
  });

  String get _opLabel {
    switch (op.opType) {
      case 'create_capture':
        final type = op.payload['captureType'] as String? ?? 'scan';
        final name = (op.payload['extractedData'] as Map?)?['name'] as String? ?? '';
        return '${_typeLabel(type)}${name.isNotEmpty ? ': $name' : ''}';
      case 'create_contact':
        final name = '${op.payload['first_name'] ?? ''} ${op.payload['last_name'] ?? ''}'.trim();
        return 'Contact${name.isNotEmpty ? ': $name' : ''}';
      case 'log_interaction':
        return 'Interaction: ${op.payload['summary'] ?? ''}';
      case 'create_event':
        return 'Event: ${op.payload['name'] ?? ''}';
      default:
        return op.opType;
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'card_scan': return 'Card scan';
      case 'file_scan': return 'File scan';
      case 'voice': return 'Voice capture';
      default: return 'Manual entry';
    }
  }

  String get _timeAgo {
    final diff = DateTime.now().millisecondsSinceEpoch - op.createdAt;
    final mins = diff ~/ 60000;
    if (mins < 60) { return '${mins}m ago'; } else if (mins < 1440) { return '${mins ~/ 60}h ago'; } else { return '${mins ~/ 1440}d ago'; }
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = op.imageRef != null;
    final isFailed = op.status == 'failed';
    final isSyncing = op.status == 'syncing';
    final c = AppTheme.colorsOf(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _opLabel,
                      style: context.theme.typography.sm.copyWith(
                        fontWeight: FontWeight.w600,
                        color: context.theme.colors.foreground,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (isFailed)
                    AppStatusBadge(
                      label: 'Failed',
                      leading: const Icon(Icons.error_outline_rounded),
                      color: c.destructive.withValues(alpha: 0.12),
                      textColor: c.destructive,
                    )
                  else if (isSyncing)
                    AppStatusBadge(label: 'Syncing', spinner: true)
                  else
                    AppStatusBadge(label: 'Queued'),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _timeAgo,
                style: context.theme.typography.xs.copyWith(
                  color: context.theme.colors.mutedForeground,
                ),
              ),
              if (hasImage) ...[
                const SizedBox(height: 4),
                Text(
                  'Includes image — AI extraction pending',
                  style: context.theme.typography.xs.copyWith(
                    color: context.theme.colors.mutedForeground,
                  ),
                ),
              ],
              if (isFailed && op.lastError != null) ...[
                const SizedBox(height: 4),
                Text(
                  op.lastError!,
                  style: context.theme.typography.xs.copyWith(
                    color: context.theme.colors.error,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isFailed && onRetry != null) ...[
                    AppButton(
                      label: 'Retry',
                      variant: ButtonVariant.secondary,
                      size: ButtonSize.sm,
                      onPressed: () => onRetry!(op),
                    ),
                    const SizedBox(width: 8),
                  ],
                  AppButton(
                    label: 'Discard',
                    variant: ButtonVariant.destructive,
                    size: ButtonSize.sm,
                    onPressed: () => onDiscard(op),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
