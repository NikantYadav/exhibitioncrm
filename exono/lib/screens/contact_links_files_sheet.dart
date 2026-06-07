import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_theme.dart';
import '../widgets/app_card.dart';

Future<List<ContactAsset>?> showContactLinksFilesSheet(
  BuildContext context, {
  required String contactId,
  required List<ContactAsset> initialAssets,
}) {
  return showModalBottomSheet<List<ContactAsset>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: false,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.50),
    builder: (_) => _ContactLinksFilesSheet(
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

class _ContactLinksFilesSheetState extends State<_ContactLinksFilesSheet> {
  ExonoColors get _c => AppTheme.colorsOf(context);

  late final List<ContactAsset> _assets = [...widget.initialAssets];
  bool _uploading = false;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.82,
          decoration: BoxDecoration(
            color: _c.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border(top: BorderSide(color: _c.border)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: _c.border)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'LINKS & FILES',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          color: _c.textPrimary,
                        ),
                      ),
                    ),
                    if (_uploading)
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(_c.accent),
                        ),
                      )
                    else
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(_assets),
                        splashRadius: 20,
                        icon: Icon(Icons.close, color: _c.textMuted),
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
                  border: Border(top: BorderSide(color: _c.border)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _uploading ? null : _addLink,
                        icon: const Icon(Icons.link, size: 18),
                        label: const Text('ADD LINK'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _c.textPrimary,
                          side: BorderSide(color: _c.border),
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _uploading ? null : _addFile,
                        icon: const Icon(Icons.upload_file_outlined, size: 18),
                        label: const Text('ADD FILE'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _c.textPrimary,
                          side: BorderSide(color: _c.border),
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              ),
              child: Icon(Icons.attachment_outlined, color: _c.textMuted, size: 32),
            ),
            const SizedBox(height: 20),
            Text(
              'No links or files yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: _c.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Attach shared decks, proposals, or useful follow-up links for this contact.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.5, color: _c.textMuted),
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
          child: InkWell(
            onTap: asset.url.isNotEmpty ? () => _openAsset(asset) : null,
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    asset.type == ContactAssetType.link
                        ? Icons.link
                        : Icons.insert_drive_file_outlined,
                    color: _c.textPrimary,
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
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _c.textPrimary,
                        ),
                      ),
                      if (asset.url.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          asset.url,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: _c.textMuted),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _assets.removeAt(index)),
                  splashRadius: 18,
                  icon: Icon(Icons.delete_outline, color: _c.textMuted, size: 20),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open ${asset.url}'), behavior: SnackBarBehavior.floating),
        );
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
    } catch (e) {
      if (mounted) {
        setState(() => _uploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<ContactAsset?> _showAddLinkDialog() async {
    final titleCtrl = TextEditingController();
    final urlCtrl = TextEditingController();

    final result = await showDialog<ContactAsset>(
      context: context,
      builder: (ctx) {
        final c = AppTheme.colorsOf(ctx);
        return AlertDialog(
          backgroundColor: c.background,
          title: Text(
            'Add link',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: c.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                autofocus: true,
                cursorColor: c.textPrimary,
                style: TextStyle(color: c.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Label',
                  labelStyle: TextStyle(color: c.textMuted),
                  hintText: 'e.g. Proposal Deck',
                  hintStyle: TextStyle(color: c.textMuted),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: c.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: c.textPrimary),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: urlCtrl,
                cursorColor: c.textPrimary,
                style: TextStyle(color: c.textPrimary),
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: 'URL',
                  labelStyle: TextStyle(color: c.textMuted),
                  hintText: 'https://',
                  hintStyle: TextStyle(color: c.textMuted),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: c.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: c.textPrimary),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancel', style: TextStyle(color: c.textMuted)),
            ),
            FilledButton(
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
              style: FilledButton.styleFrom(
                backgroundColor: c.textPrimary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Add'),
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

enum ContactAssetType { link, file }

class ContactAsset {
  final ContactAssetType type;
  final String title;
  final String url;

  const ContactAsset({
    required this.type,
    required this.title,
    required this.url,
  });

  factory ContactAsset.fromJson(Map<String, dynamic> j) => ContactAsset(
        type: j['type'] == 'file' ? ContactAssetType.file : ContactAssetType.link,
        title: j['title'] ?? '',
        url: j['url'] ?? '',
      );

  Map<String, dynamic> toJson() => {'type': type.name, 'title': title, 'url': url};
}
