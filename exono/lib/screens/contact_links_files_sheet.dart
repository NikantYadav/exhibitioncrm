import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';
import 'package:forui/forui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_theme.dart';
import '../models/contact_asset.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_feedback.dart';
import '../widgets/app_input.dart';
import '../utils/screen_logger.dart';

Future<List<ContactAsset>?> showContactLinksFilesSheet(
  BuildContext context, {
  required String contactId,
  required List<ContactAsset> initialAssets,
}) {
  return showAppSheet<List<ContactAsset>>(
    context: context,
    side: FLayout.btt,
    builder: (ctx) => _ContactLinksFilesSheet(
      contactId: contactId,
      initialAssets: initialAssets,
    ),
  );
}

class _ContactLinksFilesSheet extends StatefulWidget {
  final String contactId;
  final List<ContactAsset> initialAssets;

  const _ContactLinksFilesSheet({
    required this.contactId,
    required this.initialAssets,
  });

  @override
  State<_ContactLinksFilesSheet> createState() =>
      _ContactLinksFilesSheetState();
}

class _ContactLinksFilesSheetState extends State<_ContactLinksFilesSheet> with ScreenLogger {
  ExonoColors get _c => AppTheme.colorsOf(context);

  late final List<ContactAsset> _assets = [...widget.initialAssets];
  bool _uploading = false;

  // Real document storage (backed by the private contact-documents bucket via
  // the /documents backend). Distinct from _assets, which holds only links now.
  List<Map<String, dynamic>> _documents = [];
  bool _loadingDocs = true;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    try {
      final docs = await ApiService.getContactDocuments(widget.contactId);
      if (mounted) {
        setState(() {
          _documents = docs;
          _loadingDocs = false;
        });
      }
    } on UnauthorizedException {
      rethrow;
    } catch (_) {
      if (mounted) setState(() => _loadingDocs = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasContent = _documents.isNotEmpty || _assets.isNotEmpty || _loadingDocs;
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.82,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.theme.colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: context.theme.colors.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Links & Files',
                      style: context.theme.typography.xl.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: context.theme.colors.foreground,
                      ),
                    ),
                  ),
                  if (_uploading)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: FCircularProgress(),
                    )
                  else
                    AppButton(
                      onPressed: () => Navigator.of(context).pop(_assets),
                      variant: ButtonVariant.ghost,
                      size: ButtonSize.sm,
                      child: Icon(Icons.close, size: 18, color: _c.accent),
                    ),
                ],
              ),
            ),
            Expanded(
              child: hasContent ? _buildContent() : _buildEmptyState(),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: context.theme.colors.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'ADD LINK',
                      onPressed: _uploading ? null : _addLink,
                      variant: ButtonVariant.outline,
                      fullWidth: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppButton(
                      label: 'ADD FILE',
                      onPressed: _uploading ? null : _addFile,
                      variant: ButtonVariant.outline,
                      fullWidth: true,
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _c.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.theme.colors.border),
              ),
              child: Icon(Icons.attachment_outlined, color: _c.accent, size: 32),
            ),
            const SizedBox(height: 20),
            Text(
              'No links or files yet',
              style: context.theme.typography.lg.copyWith(fontWeight: FontWeight.w600, color: context.theme.colors.foreground),
            ),
            const SizedBox(height: 8),
            Text(
              'Attach shared decks, proposals, or useful follow-up links for this contact.',
              textAlign: TextAlign.center,
              style: context.theme.typography.sm.copyWith(height: 1.5, color: context.theme.colors.mutedForeground),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      children: [
        _buildSectionLabel('FILES'),
        const SizedBox(height: 10),
        if (_loadingDocs)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: SizedBox(width: 24, height: 24, child: FCircularProgress())),
          )
        else if (_documents.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              'No files yet.',
              style: context.theme.typography.sm.copyWith(color: context.theme.colors.mutedForeground),
            ),
          )
        else
          ..._documents.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildDocumentCard(e.value, e.key),
              )),
        const SizedBox(height: 20),
        _buildSectionLabel('LINKS'),
        const SizedBox(height: 10),
        if (_assets.isEmpty)
          Text(
            'No links yet.',
            style: context.theme.typography.sm.copyWith(color: context.theme.colors.mutedForeground),
          )
        else
          ..._assets.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildAssetCard(e.value, e.key),
              )),
      ],
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: context.theme.typography.xs.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: context.theme.colors.mutedForeground,
      ),
    );
  }

  Widget _buildDocumentCard(Map<String, dynamic> doc, int index) {
    final name = (doc['name'] as String?) ?? 'File';
    final url = (doc['file_url'] as String?) ?? '';
    final subtitle = _documentSubtitle(doc);
    return AppCard(
      padding: const EdgeInsets.all(16),
      radius: 8,
      child: GestureDetector(
        onTap: url.isNotEmpty ? () => _openUrl(url) : null,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: context.theme.colors.muted,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.insert_drive_file_outlined,
                color: context.theme.colors.foreground,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.theme.typography.sm.copyWith(
                      fontWeight: FontWeight.w600,
                      color: context.theme.colors.foreground,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.theme.typography.xs.copyWith(color: context.theme.colors.mutedForeground),
                    ),
                  ],
                ],
              ),
            ),
            AppButton(
              onPressed: () => _deleteDocument(doc, index),
              variant: ButtonVariant.ghost,
              size: ButtonSize.sm,
              child: Icon(Icons.delete_outline, color: _c.destructive, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssetCard(ContactAsset asset, int index) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      radius: 8,
      child: GestureDetector(
        onTap: asset.url.isNotEmpty ? () => _openUrl(asset.url) : null,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: context.theme.colors.muted,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                asset.type == ContactAssetType.link
                    ? Icons.link
                    : Icons.insert_drive_file_outlined,
                color: context.theme.colors.foreground,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    asset.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.theme.typography.sm.copyWith(
                      fontWeight: FontWeight.w600,
                      color: context.theme.colors.foreground,
                    ),
                  ),
                  if (asset.url.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      asset.url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.theme.typography.xs.copyWith(color: context.theme.colors.mutedForeground),
                    ),
                  ],
                ],
              ),
            ),
            AppButton(
              onPressed: () => setState(() => _assets.removeAt(index)),
              variant: ButtonVariant.ghost,
              size: ButtonSize.sm,
              child: Icon(Icons.delete_outline, color: _c.destructive, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  String _documentSubtitle(Map<String, dynamic> doc) {
    final parts = <String>[];
    final type = (doc['file_type'] as String?)?.toUpperCase();
    if (type != null && type.isNotEmpty) parts.add(type);
    final sizeRaw = doc['file_size'];
    final size = sizeRaw is int ? sizeRaw : (sizeRaw is num ? sizeRaw.toInt() : null);
    if (size != null && size > 0) parts.add(_formatBytes(size));
    return parts.join('  •  ');
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static const _allowedUrlSchemes = {'http', 'https', 'mailto', 'tel'};

  Future<void> _openUrl(String rawUrl) async {
    final url = Uri.tryParse(rawUrl);
    // Only allow safe schemes — URLs come from server/import data and could
    // carry javascript:, intent:, or file: which must never be launched.
    if (url == null || !_allowedUrlSchemes.contains(url.scheme.toLowerCase())) {
      if (mounted) {
        showAppToast(context, 'Cannot open this link');
      }
      return;
    }
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        showAppToast(context, 'Could not open $rawUrl');
      }
    }
  }

  Future<void> _deleteDocument(Map<String, dynamic> doc, int index) async {
    final id = doc['id'] as String?;
    if (id == null) return;
    // Optimistically remove, restore on failure.
    setState(() => _documents.removeAt(index));
    try {
      await ApiService.deleteContactDocument(id);
    } on UnauthorizedException {
      rethrow;
    } catch (_) {
      if (mounted) {
        setState(() {
          final at = index <= _documents.length ? index : _documents.length;
          _documents.insert(at, doc);
        });
        showAppToast(context, 'Delete failed. Please try again.');
      }
    }
  }

  Future<void> _addLink() async {
    final result = await _showAddLinkDialog();
    if (result == null) return;
    setState(() => _assets.insert(0, result));
  }

  Future<void> _addFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.custom,
      allowedExtensions: const [
        'pdf', 'doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx', 'csv', 'txt',
        'jpg', 'jpeg', 'png', 'webp',
      ],
    );
    if (result == null || result.files.isEmpty) return;
    final f = result.files.first;
    final bytes = f.bytes;
    if (bytes == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      final doc = await ApiService.uploadContactDocument(widget.contactId, bytes, f.name);
      if (mounted) {
        setState(() {
          _documents.insert(0, doc);
          _uploading = false;
        });
      }
    } on UnauthorizedException {
      rethrow;
    } catch (_) {
      if (mounted) {
        setState(() => _uploading = false);
        showAppToast(context, 'Upload failed. Please try again.');
      }
    }
  }

  Future<ContactAsset?> _showAddLinkDialog() async {
    final titleCtrl = TextEditingController();
    final urlCtrl = TextEditingController();

    final result = await showAppDialog<ContactAsset>(
      context: context,
      builder: (ctx, style, _) {
        return FDialog(
          title: Text(
            'Add link',
            style: ctx.theme.typography.lg.copyWith(fontWeight: FontWeight.w600, color: ctx.theme.colors.foreground),
          ),
          body: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppInput(
                controller: titleCtrl,
                autofocus: true,
                labelText: 'Label',
                hintText: 'e.g. Proposal Deck',
              ),
              const SizedBox(height: 12),
              AppInput(
                controller: urlCtrl,
                labelText: 'URL',
                hintText: 'https://',
                keyboardType: TextInputType.url,
              ),
            ],
          ),
          actions: [
            AppButton(
              label: 'Cancel',
              onPressed: () => Navigator.of(ctx).pop(),
              variant: ButtonVariant.ghost,
            ),
            AppButton(
              label: 'Add',
              onPressed: () {
                final url = urlCtrl.text.trim();
                final title = titleCtrl.text.trim();
                if (url.isEmpty) return;
                Navigator.of(ctx).pop(ContactAsset(
                  type: ContactAssetType.link,
                  title: title.isEmpty ? url : title,
                  url: url,
                ));
              },
              variant: ButtonVariant.primary,
            ),
          ],
        );
      },
    );

    titleCtrl.dispose();
    urlCtrl.dispose();
    return result;
  }
}
