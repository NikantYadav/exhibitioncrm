import 'dart:math' as Math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_theme.dart';
import '../models/contact.dart';
import '../models/contact_profile_data.dart';
import '../models/event.dart';
import '../services/api_service.dart';
import '../widgets/app_card.dart';
import '../widgets/app_chip.dart';
import '../widgets/app_section_label.dart';
import '../widgets/skeleton_loader.dart';
import 'contact_links_files_sheet.dart';
import 'log_interaction_screen.dart';

class ContactDetailScreen extends StatefulWidget {
  final String contactId;

  const ContactDetailScreen({super.key, required this.contactId});

  @override
  State<ContactDetailScreen> createState() => _ContactDetailScreenState();
}

class _ContactDetailScreenState extends State<ContactDetailScreen> {
  ExonoColors get _c => AppTheme.colorsOf(context);

  ContactProfileData? _contact;
  bool _isLoading = true;
  bool _isLoadingDetails = false;
  bool _isLoadingInsights = false;
  bool _isUploadingAvatar = false;
  Map<String, dynamic>? _contactInsights;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadContact();
  }

  Future<void> _loadContact() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final res = await ApiService.getContact(widget.contactId);
      if (res['data'] != null) {
        final c = Contact.fromJson(res['data']);
        final profile = mapContactToProfileData(c);
        if (mounted) {
          setState(() {
            _contact = profile;
            _isLoading = false;
            _isLoadingDetails = true;
            _isLoadingInsights = true;
          });
          _fetchContactDetails(profile);
        }
      } else {
        if (mounted) setState(() { _isLoading = false; _error = 'Contact not found'; });
      }
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _error = e.toString(); });
    }
  }

  Future<void> _reloadContact() async {
    try {
      final res = await ApiService.getContact(widget.contactId);
      if (res['data'] != null && mounted) {
        final c = Contact.fromJson(res['data']);
        final profile = mapContactToProfileData(c);
        setState(() {
          _contact = profile;
          _contactInsights = null;
          _isLoadingDetails = true;
          _isLoadingInsights = true;
        });
        _fetchContactDetails(profile);
      }
    } catch (_) {}
  }

  Future<void> _fetchInsights(String contactId) async {
    if (!mounted) return;
    setState(() { _isLoadingInsights = true; _contactInsights = null; });
    try {
      final result = await ApiService.getContactInsights(contactId);
      if (mounted) {
        setState(() {
          _contactInsights = result['data'] as Map<String, dynamic>?;
          _isLoadingInsights = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingInsights = false);
    }
  }

  Future<void> _fetchContactDetails(ContactProfileData profile) async {
    _fetchInsights(profile.id);
    try {
      final results = await Future.wait([
        ApiService.getContactTimeline(profile.id),
        ApiService.getContactEvents(profile.id),
      ]);

      final timelineData = results[0] as List<Map<String, dynamic>>;
      final eventsData  = results[1] as List<Map<String, dynamic>>;

      final timelineItems = timelineData
          .where((item) => (item['interaction_type'] ?? '') != 'event_link' && item['date'] != null)
          .map((item) {
        final date = DateTime.tryParse(item['date'] as String) ?? DateTime.now();
        final type = item['type'] as String? ?? 'interaction';
        final details = item['details'] as Map<String, dynamic>?;
        final mode = details?['mode'] as String?;
        String title = item['title'] ?? (type == 'note' ? 'Note Added' : 'Interaction');
        if (type == 'meeting') title = 'Meeting: ${item['subject'] ?? 'Strategy Session'}';
        else if (type == 'interaction' && item['interaction_type'] == 'capture') title = 'Scanner Capture';
        else if (type == 'interaction' && mode != null && mode.isNotEmpty) title = mode;
        else if (type == 'interaction' && item['interaction_type'] == 'voice_note') title = '🎙 Voice Note';
        final captureNote = details?['note'] as String?;
        final description = item['summary'] ?? item['content'] ?? 'No additional details.';
        return ContactTimelineItem(
          dateLabel: '${_formatDate(date)} • ${_formatTime(date)}',
          title: title,
          description: description,
          note: (captureNote != null && captureNote.isNotEmpty) ? captureNote : null,
          isCurrent: false,
        );
      }).toList();

      final linkedEvents = eventsData.map((e) => Event.fromJson(e)).toList();

      if (mounted) {
        setState(() {
          _isLoadingDetails = false;
          _contact = _contact?.copyWith(
            timelineItems: timelineItems,
            linkedEvents: linkedEvents,
          );
        });
      }
    } catch (e) {
      debugPrint('Error fetching contact details: $e');
      if (mounted) setState(() => _isLoadingDetails = false);
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) _showErrorMessage('Could not open $url');
    }
  }

  void _navigateToCompanyDetail(ContactProfileData contact) {
    if (contact.companyId.isNotEmpty) {
      context.push('/companies/${contact.companyId}');
    } else {
      _showUiOnlyMessage('No company linked to this contact');
    }
  }

  Future<void> _pickAndUploadAvatar(ContactProfileData contact) async {
    if (_isUploadingAvatar) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null || !mounted) return;

    setState(() => _isUploadingAvatar = true);
    try {
      final bytes = await picked.readAsBytes();
      final ext = picked.path.split('.').last.toLowerCase();
      final path = 'contacts/${contact.id}/avatar.$ext';

      final supabase = Supabase.instance.client;
      await supabase.storage.from('contact-avatars').uploadBinary(
        path, bytes, fileOptions: const FileOptions(upsert: true),
      );
      final url = supabase.storage.from('contact-avatars').getPublicUrl(path);

      await ApiService.updateContact(contact.id, {'avatar_url': url});
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
        _reloadContact();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
        _showErrorMessage('Failed to upload photo: $e');
      }
    }
  }

  Future<void> _showEditContactSheet(ContactProfileData contact) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditContactSheet(contact: contact),
    );
    if (result == true && mounted) {
      _reloadContact();
    }
  }

  Future<void> _deleteContact(ContactProfileData contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Contact',
            style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.w700)),
        content: Text(
          'Are you sure you want to delete ${contact.listName}? This cannot be undone.',
          style: TextStyle(color: _c.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('CANCEL', style: TextStyle(color: _c.textMuted, fontSize: 12, letterSpacing: 1.2)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('DELETE', style: TextStyle(color: _c.destructive, fontSize: 12, letterSpacing: 1.2, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ApiService.deleteContact(contact.id);
      if (mounted) {
        _showSuccessMessage('${contact.listName} deleted');
        context.pop();
      }
    } catch (e) {
      if (mounted) _showErrorMessage('Delete failed: $e');
    }
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showUiOnlyMessage(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label is UI-only for now.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return 'Today';
    }
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _openLinksFiles() async {
    final contact = _contact;
    if (contact == null) return;

    final updatedAssets = await showContactLinksFilesSheet(
      context,
      contactId: contact.id,
      initialAssets: contact.assets,
    );

    if (!mounted || updatedAssets == null) return;

    try {
      await ApiService.updateContact(contact.id, {
        'contact_assets': updatedAssets.map((a) => a.toJson()).toList(),
      });
    } catch (_) {}

    if (mounted) {
      setState(() {
        _contact = contact.copyWith(assets: updatedAssets);
      });
    }
  }

  Future<void> _showLinkEventSheet(ContactProfileData contact) async {
    List<Event> allEvents = [];
    try {
      allEvents = await ApiService.getEvents();
    } catch (_) {}

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EventPickerSheet(
        allEvents: allEvents,
        linkedEventIds: contact.linkedEvents.map((e) => e.id).toSet(),
        colors: _c,
        onLink: (event) async {
          await ApiService.linkContactToEvent(contact.id, event.id);
          if (mounted && _contact?.id == contact.id) {
            final updated = contact.linkedEvents.any((e) => e.id == event.id)
                ? contact.linkedEvents
                : [...contact.linkedEvents, event];
            setState(() {
              _contact = _contact!.copyWith(linkedEvents: updated);
            });
          }
        },
      ),
    );
  }

  Future<void> _unlinkEvent(ContactProfileData contact, Event event) async {
    try {
      await ApiService.unlinkContactFromEvent(contact.id, event.id);
      if (mounted) {
        final updated = contact.linkedEvents.where((e) => e.id != event.id).toList();
        setState(() {
          _contact = _contact!.copyWith(linkedEvents: updated);
        });
      }
    } catch (e) {
      if (mounted) _showErrorMessage('Failed to unlink event');
    }
  }

  Future<void> _generateEmailDraft(ContactProfileData contact) async {
    try {
      final result = await ApiService.generateEmailDraft(
        contactId: contact.id,
        emailType: 'general',
      );

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: _c.surface,
            title: Text('Email Draft', style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.w700)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Subject: ${result['data']['subject']}',
                    style: TextStyle(fontWeight: FontWeight.bold, color: _c.textPrimary)),
                  const SizedBox(height: 12),
                  Text(result['data']['body'], style: TextStyle(color: _c.textSecondary)),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('DISMISS', style: TextStyle(color: _c.textMuted)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      _showErrorMessage('Failed to generate email draft: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _c.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? _buildDetailSkeleton()
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(_error!, style: TextStyle(color: _c.textSecondary), textAlign: TextAlign.center),
                          ),
                        )
                      : _buildDetailBody(_contact!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final contact = _contact;
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: _c.background,
        border: Border(bottom: BorderSide(color: _c.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: Icon(Icons.arrow_back_rounded, color: _c.accent, size: 22),
            splashRadius: 20,
            tooltip: 'Back',
          ),
          Expanded(
            child: Text(
              contact?.listName ?? '',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _c.textPrimary,
                letterSpacing: -0.3,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (contact != null) ...[
            IconButton(
              onPressed: () => _showEditContactSheet(contact),
              icon: Icon(Icons.edit_outlined, color: _c.accent, size: 20),
              splashRadius: 20,
              tooltip: 'Edit contact',
            ),
            IconButton(
              onPressed: () => _deleteContact(contact),
              icon: Icon(Icons.delete_outline_rounded, color: _c.destructive, size: 20),
              splashRadius: 20,
              tooltip: 'Delete contact',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailBody(ContactProfileData contact) {
    if (_isLoadingDetails) return _buildDetailSkeleton();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileHeroCard(contact),
          const SizedBox(height: 12),
          _buildAIIntelligenceCard(contact),
          const SizedBox(height: 12),
          _buildTimelineCard(contact),
          const SizedBox(height: 12),
          _buildLinksCard(contact),
          const SizedBox(height: 12),
          _buildEventsCard(contact),
        ],
      ),
    );
  }

  Widget _buildDetailSkeleton() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _skeletonCard(
            radius: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonLoader(width: 72, height: 72, borderRadius: BorderRadius.circular(20)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonLoader(width: double.infinity, height: 18, borderRadius: BorderRadius.circular(5)),
                          const SizedBox(height: 8),
                          SkeletonLoader(width: 160, height: 13, borderRadius: BorderRadius.circular(4)),
                          const SizedBox(height: 6),
                          SkeletonLoader(width: 120, height: 13, borderRadius: BorderRadius.circular(4)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    SkeletonLoader(width: 90, height: 32, borderRadius: BorderRadius.circular(10)),
                    const SizedBox(width: 8),
                    SkeletonLoader(width: 110, height: 32, borderRadius: BorderRadius.circular(10)),
                    const SizedBox(width: 8),
                    SkeletonLoader(width: 80, height: 32, borderRadius: BorderRadius.circular(10)),
                  ],
                ),
                const SizedBox(height: 14),
                SkeletonLoader(width: double.infinity, height: 13, borderRadius: BorderRadius.circular(4)),
                const SizedBox(height: 6),
                SkeletonLoader(width: double.infinity, height: 13, borderRadius: BorderRadius.circular(4)),
                const SizedBox(height: 6),
                SkeletonLoader(width: 200, height: 13, borderRadius: BorderRadius.circular(4)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _skeletonCard(
            accent: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SkeletonLoader(width: 15, height: 15, borderRadius: BorderRadius.circular(4)),
                    const SizedBox(width: 8),
                    SkeletonLoader(width: 110, height: 13, borderRadius: BorderRadius.circular(4)),
                  ],
                ),
                const SizedBox(height: 14),
                SkeletonLoader(width: double.infinity, height: 13, borderRadius: BorderRadius.circular(4)),
                const SizedBox(height: 6),
                SkeletonLoader(width: double.infinity, height: 13, borderRadius: BorderRadius.circular(4)),
                const SizedBox(height: 6),
                SkeletonLoader(width: 220, height: 13, borderRadius: BorderRadius.circular(4)),
                const SizedBox(height: 12),
                SkeletonLoader(width: double.infinity, height: 13, borderRadius: BorderRadius.circular(4)),
                const SizedBox(height: 6),
                SkeletonLoader(width: 180, height: 13, borderRadius: BorderRadius.circular(4)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _skeletonCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLoader(width: 140, height: 13, borderRadius: BorderRadius.circular(4)),
                const SizedBox(height: 16),
                ...List.generate(3, (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonLoader(width: 10, height: 10, borderRadius: BorderRadius.circular(5)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonLoader(width: 100, height: 11, borderRadius: BorderRadius.circular(3)),
                            const SizedBox(height: 5),
                            SkeletonLoader(width: double.infinity, height: 13, borderRadius: BorderRadius.circular(4)),
                            const SizedBox(height: 4),
                            SkeletonLoader(width: 200, height: 13, borderRadius: BorderRadius.circular(4)),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _skeletonCard({required Widget child, double radius = 16, bool accent = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _c.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: accent ? _c.accent.withValues(alpha: 0.3) : _c.border,
        ),
      ),
      child: child,
    );
  }

  // ─── Profile Hero Card ────────────────────────────────────────────────────

  Widget _buildProfileHeroCard(ContactProfileData contact) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => _pickAndUploadAvatar(contact),
                child: Stack(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: _c.accentSoft,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _c.border),
                        image: contact.avatarUrl.isNotEmpty
                            ? DecorationImage(
                                image: NetworkImage(contact.avatarUrl),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: _isUploadingAvatar
                          ? SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(_c.textPrimary),
                              ),
                            )
                          : contact.avatarUrl.isEmpty
                              ? Text(
                                  contact.initials,
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                    color: _c.textPrimary,
                                  ),
                                )
                              : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: _c.surface,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: _c.border),
                        ),
                        child: Icon(
                          Icons.camera_alt_outlined,
                          size: 12,
                          color: _c.accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.listName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _c.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (contact.title.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        contact.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: _c.textSecondary,
                        ),
                      ),
                    ],
                    if (contact.company.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        contact.company,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                          color: _c.accent,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    _followUpChip(contact.followUpStatus),
                  ],
                ),
              ),
            ],
          ),

          if (contact.email.isNotEmpty || contact.phone.isNotEmpty || contact.linkedin.isNotEmpty || contact.company.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(height: 1, color: _c.border.withValues(alpha: 0.4)),
            if (contact.company.isNotEmpty)
              _heroInfoRow(Icons.business_outlined, contact.company,
                  () => _navigateToCompanyDetail(contact)),
            if (contact.email.isNotEmpty)
              _heroInfoRow(Icons.mail_outline, contact.email,
                  () => _launchUrl('mailto:${contact.email}')),
            if (contact.phone.isNotEmpty)
              _heroInfoRow(Icons.call_outlined, contact.phone,
                  () => _launchUrl('tel:${contact.phone}')),
            if (contact.linkedin.isNotEmpty)
              _heroInfoRow(Icons.link, 'LinkedIn Profile',
                  () => _launchUrl(contact.linkedin.startsWith('http')
                      ? contact.linkedin
                      : 'https://${contact.linkedin}')),
          ],

          const SizedBox(height: 14),
          Row(
            children: [
              _quickActionBtn(Icons.call_outlined, 'Call',
                  contact.phone.isNotEmpty ? () => _launchUrl('tel:${contact.phone}') : null),
              _quickActionBtn(Icons.mail_outline, 'Email',
                  contact.email.isNotEmpty ? () => _generateEmailDraft(contact) : null),
              _quickActionBtn(Icons.calendar_month_outlined, 'Schedule',
                  () => _showUiOnlyMessage('Schedule Meeting')),
            ],
          ),

          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => showLogInteractionSheet(
                context,
                contactId: contact.id,
                onSaved: () => _fetchContactDetails(contact),
              ),
              icon: Icon(Icons.chat_bubble_outline_rounded, size: 16, color: _c.accent),
              label: Text(
                'LOG INTERACTION',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: _c.accent,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: _c.accent,
                side: BorderSide(color: _c.accent),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroInfoRow(IconData icon, String value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            Icon(icon, size: 17, color: _c.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: _c.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.chevron_right, size: 16, color: _c.accent),
          ],
        ),
      ),
    );
  }

  Widget _followUpChip(String status) {
    switch (status) {
      case 'urgent':
        return AppChip.status('URGENT', color: _c.destructive);
      case 'contacted':
        return AppChip.status('CONTACTED', color: _c.success);
      case 'needs_followup':
        return AppChip.status('FOLLOW UP', color: _c.accent);
      default:
        return AppChip.status('NOT CONTACTED', color: _c.textMuted);
    }
  }

  Widget _quickActionBtn(IconData icon, String label, VoidCallback? onTap) {
    final enabled = onTap != null;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: _c.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _c.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: enabled ? _c.accent : _c.textMuted.withValues(alpha: 0.4), size: 18),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                    color: enabled ? _c.textMuted : _c.textMuted.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── AI Intelligence Card ─────────────────────────────────────────────────

  Widget _buildAIIntelligenceCard(ContactProfileData contact) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      radius: 16,
      borderColor: _c.accent.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 15, color: _c.accent),
              const SizedBox(width: 8),
              AppSectionLabel('AI Intelligence', letterSpacing: 1.4, color: _c.accent),
              const Spacer(),
              if (_contactInsights != null)
                GestureDetector(
                  onTap: () => _fetchInsights(contact.id),
                  child: Icon(Icons.refresh, size: 15, color: _c.accent),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (_isLoadingInsights)
            const _AiThinkingDots()
          else if (_contactInsights != null)
            _buildInsightsContent(_contactInsights!)
          else
            _buildInsightsNeedMoreData(contact),
        ],
      ),
    );
  }

  Widget _buildInsightsNeedMoreData(ContactProfileData contact) {
    final hasTitle = contact.title.isNotEmpty;
    final hasCompany = contact.company.isNotEmpty;
    final hasLinkedin = contact.linkedin.isNotEmpty;
    final hasTimeline = contact.timelineItems.isNotEmpty;
    final signalCount = [hasTitle, hasCompany, hasLinkedin, hasTimeline].where((v) => v).length;
    final hasEnoughData = signalCount >= 2;

    if (hasEnoughData) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AI insights are being generated and will appear here shortly.',
            style: TextStyle(fontSize: 13, color: _c.textMuted, fontStyle: FontStyle.italic, height: 1.5),
          ),
          const SizedBox(height: 16),
          const _AiThinkingDots(),
        ],
      );
    }

    final missing = <_MissingDetail>[];
    if (!hasTitle) missing.add(_MissingDetail(Icons.work_outline, 'Job title'));
    if (!hasCompany) missing.add(_MissingDetail(Icons.domain_outlined, 'Company'));
    if (!hasLinkedin) missing.add(_MissingDetail(Icons.link, 'LinkedIn profile'));
    if (!hasTimeline) missing.add(_MissingDetail(Icons.history, 'Log an interaction'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Add more details to unlock AI-generated intelligence for this contact.',
          style: TextStyle(
            fontSize: 13,
            color: _c.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        ...missing.map((m) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(m.icon, size: 14, color: _c.accent),
                  const SizedBox(width: 8),
                  Text(
                    m.label,
                    style: TextStyle(
                      fontSize: 12,
                      color: _c.textMuted,
                    ),
                  ),
                ],
              ),
            )),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: () => showLogInteractionSheet(
            context,
            contactId: contact.id,
            onSaved: () => _fetchContactDetails(contact),
          ),
          icon: Icon(Icons.add, size: 14, color: _c.accent),
          label: Text(
            'LOG INTERACTION',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: _c.textMuted,
            ),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            side: BorderSide(color: _c.border),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  Widget _buildInsightsContent(Map<String, dynamic> insights) {
    final strategicContext = insights['strategic_context'] as String? ?? '';
    final briefing = (insights['briefing_items'] as List?)?.cast<String>() ?? [];
    final aiInsights = (insights['ai_insights'] as List?)?.cast<String>() ?? [];
    final painPoint = insights['primary_pain_point'] as String? ?? '';
    final keyMarkets = (insights['key_markets'] as List?)?.cast<String>() ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (strategicContext.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _c.accentSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              strategicContext,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                fontStyle: FontStyle.italic,
                color: _c.textSecondary,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],

        if (painPoint.isNotEmpty) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_outlined, size: 14, color: _c.accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Pain point: $painPoint',
                  style: TextStyle(fontSize: 12, color: _c.textMuted, height: 1.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],

        if (briefing.isNotEmpty) ...[
          AppSectionLabel('Before Your Meeting', letterSpacing: 1.2),
          const SizedBox(height: 8),
          ...briefing.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.only(top: 6),
                      decoration: BoxDecoration(
                        color: _c.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item,
                        style: TextStyle(
                          fontSize: 13,
                          color: _c.textSecondary,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 12),
        ],

        if (aiInsights.isNotEmpty) ...[
          AppSectionLabel('Key Insights', letterSpacing: 1.2),
          const SizedBox(height: 8),
          ...aiInsights.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.arrow_right, size: 16, color: _c.accent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item,
                        style: TextStyle(
                          fontSize: 13,
                          color: _c.textSecondary,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 8),
        ],

        if (keyMarkets.isNotEmpty) ...[
          AppSectionLabel('Key Markets', letterSpacing: 1.2),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: keyMarkets.map((m) => AppChip(m)).toList(),
          ),
        ],
      ],
    );
  }

  // ─── Timeline Card ────────────────────────────────────────────────────────

  Widget _buildTimelineCard(ContactProfileData contact) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionLabel('Engagement Timeline', letterSpacing: 1.4),
          const SizedBox(height: 16),
          if (contact.timelineItems.isEmpty)
            Text('No interactions logged yet.', style: TextStyle(fontSize: 13, color: _c.textMuted))
          else
            Stack(
              children: [
                Positioned(
                  left: 10,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 1,
                    color: _c.border.withValues(alpha: 0.4),
                  ),
                ),
                Column(
                  children: contact.timelineItems
                      .map((item) => _buildTimelineItem(item))
                      .toList(),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ─── Links Card ───────────────────────────────────────────────────────────

  Widget _buildLinksCard(ContactProfileData contact) {
    final hasAssets = contact.assets.isNotEmpty;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      radius: 16,
      child: InkWell(
        onTap: _openLinksFiles,
        borderRadius: BorderRadius.circular(8),
        child: Row(
          children: [
            Icon(Icons.attachment_outlined, size: 18, color: _c.accent),
            const SizedBox(width: 12),
            Text(
              'Links & Files',
              style: TextStyle(fontSize: 14, color: _c.textSecondary),
            ),
            const Spacer(),
            Text(
              hasAssets ? '${contact.assets.length} items' : 'None added',
              style: TextStyle(
                fontSize: 12,
                fontStyle: hasAssets ? FontStyle.normal : FontStyle.italic,
                color: _c.textMuted,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              hasAssets ? Icons.chevron_right : Icons.add,
              size: 18,
              color: _c.accent,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Events Card ─────────────────────────────────────────────────────────

  Widget _buildEventsCard(ContactProfileData contact) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppSectionLabel('Events', letterSpacing: 1.4),
              const Spacer(),
              GestureDetector(
                onTap: () => _showLinkEventSheet(contact),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _c.accentSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 14, color: _c.accent),
                      const SizedBox(width: 4),
                      Text('Link Event',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _c.accent)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (contact.linkedEvents.isEmpty)
            Text('No events linked yet.',
                style: TextStyle(fontSize: 13, color: _c.textMuted))
          else
            ...contact.linkedEvents.map((event) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: _c.accentSoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.event_outlined, size: 18, color: _c.accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(event.name,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _c.textPrimary)),
                        if (event.location != null && event.location!.isNotEmpty)
                          Text(event.location!,
                              style: TextStyle(fontSize: 11, color: _c.textMuted)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.link_off_rounded, size: 16, color: _c.accent),
                    splashRadius: 18,
                    tooltip: 'Unlink',
                    onPressed: () => _unlinkEvent(contact, event),
                  ),
                ],
              ),
            )),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(ContactTimelineItem item) {
    return Padding(
      padding: const EdgeInsets.only(left: 0, bottom: 32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 21,
            height: 21,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _c.background,
              border: Border.all(
                color: item.isCurrent
                    ? _c.textPrimary
                    : Colors.white.withValues(alpha: 0.20),
                width: 2,
              ),
            ),
            child: item.isCurrent
                ? Center(
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _c.textPrimary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.dateLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                      color: _c.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.description,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: _c.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  if (item.note != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: _c.surfaceAlt,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _c.border),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.notes_rounded, size: 14, color: _c.accent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.note!,
                              style: TextStyle(
                                fontSize: 13,
                                color: _c.textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Edit Contact Sheet ───────────────────────────────────────────────────────

class _EditContactSheet extends StatefulWidget {
  final ContactProfileData contact;
  const _EditContactSheet({required this.contact});

  @override
  State<_EditContactSheet> createState() => _EditContactSheetState();
}

class _EditContactSheetState extends State<_EditContactSheet> {
  ExonoColors get _c => AppTheme.colorsOf(context);

  late final _firstNameCtrl  = TextEditingController(text: _splitName(widget.contact.listName).first);
  late final _lastNameCtrl   = TextEditingController(text: _splitName(widget.contact.listName).last);
  late final _emailCtrl      = TextEditingController(text: widget.contact.email);
  late final _phoneCtrl      = TextEditingController(text: widget.contact.phone);
  late final _jobTitleCtrl   = TextEditingController(text: widget.contact.title);
  late final _linkedinCtrl   = TextEditingController(text: widget.contact.linkedin);
  late final _companyCtrl    = TextEditingController(text: widget.contact.company);

  bool _isSaving = false;

  List<String> _splitName(String fullName) {
    final parts = fullName.trim().split(' ');
    if (parts.length == 1) return [parts[0], ''];
    return [parts.first, parts.sublist(1).join(' ')];
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _jobTitleCtrl.dispose();
    _linkedinCtrl.dispose();
    _companyCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final firstName = _firstNameCtrl.text.trim();
    if (firstName.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      final payload = <String, dynamic>{
        'first_name': firstName,
        'last_name': _lastNameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'job_title': _jobTitleCtrl.text.trim(),
        'linkedin_url': _linkedinCtrl.text.trim(),
      };

      final newCompany = _companyCtrl.text.trim();
      final originalCompany = widget.contact.company;
      if (newCompany.toUpperCase() != originalCompany.toUpperCase()) {
        payload['company_name'] = newCompany.isEmpty ? 'INDEPENDENT' : newCompany;
      }

      await ApiService.updateContact(widget.contact.id, payload);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e'), behavior: SnackBarBehavior.floating),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: _c.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: _c.border)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: _c.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    Text(
                      'Edit Contact',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _c.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('CANCEL', style: TextStyle(color: _c.textMuted, fontSize: 12, letterSpacing: 1.2)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _field('First Name', _firstNameCtrl, required: true)),
                          const SizedBox(width: 12),
                          Expanded(child: _field('Last Name', _lastNameCtrl)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _field('Email', _emailCtrl, keyboard: TextInputType.emailAddress),
                      const SizedBox(height: 12),
                      _field('Phone', _phoneCtrl, keyboard: TextInputType.phone),
                      const SizedBox(height: 12),
                      _field('Job Title', _jobTitleCtrl),
                      const SizedBox(height: 12),
                      _field('Company', _companyCtrl),
                      const SizedBox(height: 12),
                      _field('LinkedIn URL', _linkedinCtrl, keyboard: TextInputType.url),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton(
                          onPressed: _isSaving ? null : _save,
                          style: FilledButton.styleFrom(
                            backgroundColor: _c.accent,
                            foregroundColor: _c.background,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isSaving
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(_c.background),
                                  ),
                                )
                              : const Text('SAVE CHANGES',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.4)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, {
    bool required = false,
    TextInputType? keyboard,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      style: TextStyle(color: _c.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: _c.textMuted, fontSize: 13),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _c.accent, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

// ─── AI Thinking Dots ─────────────────────────────────────────────────────────

class _AiThinkingDots extends StatefulWidget {
  const _AiThinkingDots();
  @override
  State<_AiThinkingDots> createState() => _AiThinkingDotsState();
}

class _AiThinkingDotsState extends State<_AiThinkingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.colorsOf(context);
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (i / 3.0);
            final t = ((_ctrl.value - phase) % 1.0 + 1.0) % 1.0;
            final brightness = (Math.sin(t * Math.pi)).clamp(0.0, 1.0);
            final size = 6.0 + brightness * 3.0;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.accent.withValues(alpha: 0.3 + brightness * 0.7),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _MissingDetail {
  final IconData icon;
  final String label;
  const _MissingDetail(this.icon, this.label);
}

// ─── Event Picker Sheet ───────────────────────────────────────────────────────

class _EventPickerSheet extends StatefulWidget {
  final List<Event> allEvents;
  final Set<String> linkedEventIds;
  final ExonoColors colors;
  final Future<void> Function(Event event) onLink;

  const _EventPickerSheet({
    required this.allEvents,
    required this.linkedEventIds,
    required this.colors,
    required this.onLink,
  });

  @override
  State<_EventPickerSheet> createState() => _EventPickerSheetState();
}

class _EventPickerSheetState extends State<_EventPickerSheet> {
  ExonoColors get _c => widget.colors;
  final _searchCtrl = TextEditingController();
  List<Event> _filtered = [];
  bool _linking = false;

  @override
  void initState() {
    super.initState();
    _filtered = widget.allEvents;
    _searchCtrl.addListener(_onSearch);
  }

  void _onSearch() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? widget.allEvents
          : widget.allEvents.where((e) => e.name.toLowerCase().contains(q) ||
              (e.location ?? '').toLowerCase().contains(q)).toList();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: _c.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: _c.border)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 48, height: 4,
                  decoration: BoxDecoration(color: _c.border, borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  children: [
                    Text('Link to Event',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _c.textPrimary)),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, color: _c.accent),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  style: TextStyle(color: _c.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search events...',
                    hintStyle: TextStyle(color: _c.textMuted, fontSize: 14),
                    prefixIcon: Icon(Icons.search, color: _c.accent, size: 18),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: _c.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: _c.accent, width: 1.6),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _filtered.isEmpty
                    ? Center(child: Text('No events found.', style: TextStyle(color: _c.textMuted)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) {
                          final event = _filtered[i];
                          final isLinked = widget.linkedEventIds.contains(event.id);
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                            leading: Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                color: _c.accentSoft,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.event_outlined, size: 18, color: _c.accent),
                            ),
                            title: Text(event.name,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _c.textPrimary)),
                            subtitle: event.location != null && event.location!.isNotEmpty
                                ? Text(event.location!, style: TextStyle(fontSize: 11, color: _c.textMuted))
                                : null,
                            trailing: isLinked
                                ? Icon(Icons.check_circle_rounded, color: _c.accent, size: 20)
                                : (_linking
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                    : Icon(Icons.add_circle_outline, color: _c.accent, size: 20)),
                            onTap: isLinked ? null : () async {
                              setState(() => _linking = true);
                              try {
                                await widget.onLink(event);
                              } finally {
                                if (mounted) setState(() => _linking = false);
                              }
                              if (mounted) Navigator.pop(context);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
