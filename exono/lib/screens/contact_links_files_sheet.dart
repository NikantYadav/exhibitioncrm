import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:forui/forui.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  @override
  Widget build(BuildContext context) {
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
              child: _assets.isEmpty ? _buildEmptyState() : _buildAssetList(),
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

  Widget _buildAssetList() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      itemCount: _assets.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final asset = _assets[index];
        return AppCard(
          padding: const EdgeInsets.all(16),
          radius: 8,
          child: GestureDetector(
            onTap: asset.url.isNotEmpty ? () => _openAsset(asset) : null,
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
      },
    );
  }

  Future<void> _openAsset(ContactAsset asset) async {
    final url = Uri.tryParse(asset.url);
    if (url == null) return;
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        showAppToast(context, 'Could not open ${asset.url}');
      }
    }
  }

  Future<void> _addLink() async {
    final result = await _showAddLinkDialog();
    if (result == null) return;
    setState(() => _assets.insert(0, result));
  }

  Future<void> _addFile() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      final bytes = await picked.readAsBytes();
      final ext = picked.path.split('.').last.toLowerCase();
      final filename = picked.name;
      final path = 'contacts/${widget.contactId}/files/${DateTime.now().millisecondsSinceEpoch}.$ext';

      final supabase = Supabase.instance.client;
      await supabase.storage.from('contact-avatars').uploadBinary(
        path,
        bytes,
        fileOptions: const FileOptions(upsert: true),
      );
      final url = supabase.storage.from('contact-avatars').getPublicUrl(path);

      if (mounted) {
        setState(() {
          _assets.insert(0, ContactAsset(
            type: ContactAssetType.file,
            title: filename,
            url: url,
          ));
          _uploading = false;
        });
      }
    } on UnauthorizedException { rethrow; } catch (_) {
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

