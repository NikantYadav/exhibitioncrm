import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../widgets/app_card.dart';

Future<List<ContactAsset>?> showContactLinksFilesSheet(
  BuildContext context, {
  required List<ContactAsset> initialAssets,
}) {
  return showModalBottomSheet<List<ContactAsset>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: false,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.50),
    builder: (_) => _ContactLinksFilesSheet(initialAssets: initialAssets),
  );
}

class _ContactLinksFilesSheet extends StatefulWidget {
  final List<ContactAsset> initialAssets;

  const _ContactLinksFilesSheet({required this.initialAssets});

  @override
  State<_ContactLinksFilesSheet> createState() =>
      _ContactLinksFilesSheetState();
}

class _ContactLinksFilesSheetState extends State<_ContactLinksFilesSheet> {
  ExonoColors get _c => AppTheme.colorsOf(context);

  late final List<ContactAsset> _assets = [...widget.initialAssets];

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
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
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
                        onPressed: _addLink,
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
                        onPressed: _addFile,
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
              child: Icon(
                Icons.attachment_outlined,
                color: _c.textMuted,
                size: 32,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No links added',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _c.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Attach priority docs, shared decks, or useful follow-up links for this contact.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                height: 1.5,
                color: _c.textMuted,
              ),
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
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final asset = _assets[index];
        return AppCard(
          padding: const EdgeInsets.all(16),
          radius: 8,
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
                    const SizedBox(height: 4),
                    Text(
                      asset.subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: _c.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _assets.removeAt(index);
                  });
                },
                splashRadius: 18,
                icon: Icon(
                  Icons.delete_outline,
                  color: _c.textMuted,
                  size: 20,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _addLink() async {
    final result = await _showAddDialog(
      title: 'Add link',
      hint: 'https://example.com/brief',
      type: ContactAssetType.link,
    );
    if (result == null) return;
    setState(() => _assets.insert(0, result));
  }

  Future<void> _addFile() async {
    final result = await _showAddDialog(
      title: 'Add file',
      hint: 'Q3_Security_Deck.pdf',
      type: ContactAssetType.file,
    );
    if (result == null) return;
    setState(() => _assets.insert(0, result));
  }

  Future<ContactAsset?> _showAddDialog({
    required String title,
    required String hint,
    required ContactAssetType type,
  }) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) {
        final _c = AppTheme.colorsOf(context);
        return AlertDialog(
          backgroundColor: _c.background,
          title: Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: _c.textPrimary,
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            cursorColor: _c.textPrimary,
            style: TextStyle(color: _c.textPrimary),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: _c.textMuted),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: _c.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.30),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              style: FilledButton.styleFrom(
                backgroundColor: _c.textPrimary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
    controller.dispose();

    if (value == null || value.isEmpty) return null;

    return ContactAsset(
      type: type,
      title: value,
      subtitle: type == ContactAssetType.link ? 'Shared link' : 'Uploaded file',
    );
  }
}

enum ContactAssetType { link, file }

class ContactAsset {
  final ContactAssetType type;
  final String title;
  final String subtitle;

  const ContactAsset({
    required this.type,
    required this.title,
    required this.subtitle,
  });
}
