import 'dart:math' as Math;

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
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
import '../widgets/app_input.dart';
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
        else if (type == 'interaction' && item['interaction_type'] == 'voice_note') title = 'Voice Note';
        final captureNote = details?['note'] as String?;
        final eventName = (item['event'] as Map<String, dynamic>?)?['name'] as String?;
        final isMeeting = type == 'interaction' && item['interaction_type'] == 'meeting';
        final rawSummary = (item['summary'] as String? ?? '').trim();

        final String description;
        final String? note;
        if (isMeeting) {
          description = eventName ?? '';
          final summaryText = rawSummary.isNotEmpty && rawSummary != 'Met at event' ? rawSummary : null;
          note = summaryText;
        } else {
          final rawDescription = item['summary'] ?? item['content'] ?? 'No additional details.';
          description = (eventName != null && eventName.isNotEmpty)
              ? '$rawDescription\n$eventName'
              : rawDescription as String;
          note = (captureNote != null && captureNote.isNotEmpty) ? captureNote : null;
        }

        return ContactTimelineItem(
          dateLabel: '${_formatDate(date)} • ${_formatTime(date)}',
          title: title,
          description: description,
          note: note,
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
      if (mounted) _toast('Could not open $url');
    }
  }

  void _navigateToCompanyDetail(ContactProfileData contact) {
    if (contact.companyId.isNotEmpty) {
      context.push('/companies/${contact.companyId}');
    } else {
      _toast('No company linked to this contact');
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
        _toast('Failed to upload photo: $e');
      }
    }
  }

  Future<void> _showEditContactSheet(ContactProfileData contact) async {
    final result = await showFSheet<bool>(
      context: context,
      side: FLayout.btt,
      builder: (ctx) => _EditContactSheet(contact: contact),
    );
    if (result == true && mounted) _reloadContact();
  }

  Future<void> _deleteContact(ContactProfileData contact) async {
    final confirmed = await showFDialog<bool>(
      context: context,
      builder: (ctx, style, _) => FDialog(
        title: const Text('Delete Contact'),
        body: Text('Are you sure you want to delete ${contact.listName}? This cannot be undone.'),
        actions: [
          FButton(variant: FButtonVariant.ghost, onPress: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FButton(variant: FButtonVariant.destructive, onPress: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ApiService.deleteContact(contact.id);
      if (mounted) {
        _toast('${contact.listName} deleted');
        context.pop();
      }
    } catch (e) {
      if (mounted) _toast('Delete failed: $e');
    }
  }

  void _toast(String message) => showFToast(context: context, title: Text(message));

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) return 'Today';
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTime(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  Future<void> _openLinksFiles() async {
    final contact = _contact;
    if (contact == null) return;
    final updatedAssets = await showContactLinksFilesSheet(
      context, contactId: contact.id, initialAssets: contact.assets,
    );
    if (!mounted || updatedAssets == null) return;
    try {
      await ApiService.updateContact(contact.id, {
        'contact_assets': updatedAssets.map((a) => a.toJson()).toList(),
      });
    } catch (_) {}
    if (mounted) setState(() { _contact = contact.copyWith(assets: updatedAssets); });
  }

  Future<void> _showLinkEventSheet(ContactProfileData contact) async {
    List<Event> allEvents = [];
    try { allEvents = await ApiService.getEvents(); } catch (_) {}
    if (!mounted) return;
    await showFSheet(
      context: context,
      side: FLayout.btt,
      builder: (ctx) => _EventPickerSheet(
        allEvents: allEvents,
        linkedEventIds: contact.linkedEvents.map((e) => e.id).toSet(),
        onLink: (event) async {
          await ApiService.linkContactToEvent(contact.id, event.id);
          if (mounted && _contact?.id == contact.id) {
            final updated = contact.linkedEvents.any((e) => e.id == event.id)
                ? contact.linkedEvents
                : [...contact.linkedEvents, event];
            setState(() { _contact = _contact!.copyWith(linkedEvents: updated); });
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
        setState(() { _contact = _contact!.copyWith(linkedEvents: updated); });
      }
    } catch (e) {
      if (mounted) _toast('Failed to unlink event');
    }
  }

  Future<void> _generateEmailDraft(ContactProfileData contact) async {
    try {
      final result = await ApiService.generateEmailDraft(contactId: contact.id, emailType: 'general');
      if (mounted) {
        showFDialog<void>(
          context: context,
          builder: (ctx, style, _) => FDialog(
            title: const Text('Email Draft'),
            body: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Subject: ${result['data']['subject']}', style: context.theme.typography.sm.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text(result['data']['body']),
                ],
              ),
            ),
            actions: [
              FButton(variant: FButtonVariant.ghost, onPress: () => Navigator.pop(ctx), child: const Text('Dismiss')),
            ],
          ),
        );
      }
    } catch (e) {
      _toast('Failed to generate email draft: $e');
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      header: _buildHeader(),
      childPad: false,
      child: _isLoading
          ? _buildSkeleton()
          : _error != null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error!, textAlign: TextAlign.center),
                ))
              : _buildBody(_contact!),
    );
  }

  Widget _buildHeader() {
    final contact = _contact;
    return FHeader.nested(
      title: Text(contact?.listName ?? ''),
      prefixes: [
        FHeaderAction(icon: const Icon(Icons.arrow_back_rounded), onPress: () => context.pop()),
      ],
      suffixes: contact != null
          ? [
              FHeaderAction(icon: const Icon(Icons.edit_outlined), onPress: () => _showEditContactSheet(contact)),
              FHeaderAction(
                icon: Icon(Icons.delete_outline_rounded, color: context.theme.colors.error),
                onPress: () => _deleteContact(contact),
              ),
            ]
          : [],
    );
  }

  Widget _buildBody(ContactProfileData contact) {
    if (_isLoadingDetails) return _buildSkeleton();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeroCard(contact),
          const SizedBox(height: 12),
          _buildAICard(contact),
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

  // ─── Skeleton ─────────────────────────────────────────────────────────────

  Widget _buildSkeleton() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        children: [
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SkeletonLoader(width: 72, height: 72, borderRadius: BorderRadius.circular(16)),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SkeletonLoader(width: double.infinity, height: 18, borderRadius: BorderRadius.circular(5)),
                  const SizedBox(height: 8),
                  SkeletonLoader(width: 160, height: 13, borderRadius: BorderRadius.circular(4)),
                  const SizedBox(height: 6),
                  SkeletonLoader(width: 120, height: 13, borderRadius: BorderRadius.circular(4)),
                ])),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                SkeletonLoader(width: 90, height: 32, borderRadius: BorderRadius.circular(8)),
                const SizedBox(width: 8),
                SkeletonLoader(width: 110, height: 32, borderRadius: BorderRadius.circular(8)),
                const SizedBox(width: 8),
                SkeletonLoader(width: 80, height: 32, borderRadius: BorderRadius.circular(8)),
              ]),
              const SizedBox(height: 14),
              SkeletonLoader(width: double.infinity, height: 13, borderRadius: BorderRadius.circular(4)),
              const SizedBox(height: 6),
              SkeletonLoader(width: 200, height: 13, borderRadius: BorderRadius.circular(4)),
            ]),
          ),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                SkeletonLoader(width: 15, height: 15, borderRadius: BorderRadius.circular(4)),
                const SizedBox(width: 8),
                SkeletonLoader(width: 110, height: 13, borderRadius: BorderRadius.circular(4)),
              ]),
              const SizedBox(height: 14),
              SkeletonLoader(width: double.infinity, height: 13, borderRadius: BorderRadius.circular(4)),
              const SizedBox(height: 6),
              SkeletonLoader(width: double.infinity, height: 13, borderRadius: BorderRadius.circular(4)),
              const SizedBox(height: 6),
              SkeletonLoader(width: 220, height: 13, borderRadius: BorderRadius.circular(4)),
            ]),
          ),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SkeletonLoader(width: 140, height: 13, borderRadius: BorderRadius.circular(4)),
              const SizedBox(height: 16),
              ...List.generate(3, (i) => Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SkeletonLoader(width: 10, height: 10, borderRadius: BorderRadius.circular(5)),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SkeletonLoader(width: 100, height: 11, borderRadius: BorderRadius.circular(3)),
                    const SizedBox(height: 5),
                    SkeletonLoader(width: double.infinity, height: 13, borderRadius: BorderRadius.circular(4)),
                    const SizedBox(height: 4),
                    SkeletonLoader(width: 200, height: 13, borderRadius: BorderRadius.circular(4)),
                  ])),
                ]),
              )),
            ]),
          ),
        ],
      ),
    );
  }

  // ─── Hero Card ────────────────────────────────────────────────────────────

  Widget _buildHeroCard(ContactProfileData contact) {
    final theme = context.theme;
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              FButton(
                variant: FButtonVariant.ghost,
                onPress: () => _pickAndUploadAvatar(contact),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: ColoredBox(
                        color: theme.colors.secondary,
                        child: SizedBox(
                          width: 72,
                          height: 72,
                          child: _isUploadingAvatar
                              ? const Center(child: FCircularProgress())
                              : contact.avatarUrl.isNotEmpty
                                  ? Image.network(contact.avatarUrl, fit: BoxFit.cover)
                                  : Center(
                                      child: Text(
                                        contact.initials,
                                        style: theme.typography.xl2.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: theme.colors.foreground,
                                        ),
                                      ),
                                    ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: FBadge(
                        variant: FBadgeVariant.secondary,
                        child: const Icon(Icons.camera_alt_outlined, size: 10),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              // Name / title / status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(contact.listName, style: theme.typography.xl.copyWith(fontWeight: FontWeight.w700)),
                    if (contact.title.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(contact.title, style: theme.typography.sm.copyWith(color: theme.colors.mutedForeground)),
                    ],
                    if (contact.company.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(contact.company, style: theme.typography.sm.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colors.primary,
                      )),
                    ],
                    const SizedBox(height: 8),
                    _followUpBadge(contact.followUpStatus),
                  ],
                ),
              ),
            ],
          ),

          // Contact info rows
          if (contact.email.isNotEmpty || contact.phone.isNotEmpty || contact.linkedin.isNotEmpty || contact.company.isNotEmpty) ...[
            const SizedBox(height: 12),
            FDivider(),
            if (contact.company.isNotEmpty)
              _infoRow(Icons.business_outlined, contact.company, () => _navigateToCompanyDetail(contact)),
            if (contact.email.isNotEmpty)
              _infoRow(Icons.mail_outline, contact.email, () => _launchUrl('mailto:${contact.email}')),
            if (contact.phone.isNotEmpty)
              _infoRow(Icons.call_outlined, contact.phone, () => _launchUrl('tel:${contact.phone}')),
            if (contact.linkedin.isNotEmpty)
              _infoRow(Icons.link, 'LinkedIn Profile', () => _launchUrl(
                contact.linkedin.startsWith('http') ? contact.linkedin : 'https://${contact.linkedin}')),
          ],

          const SizedBox(height: 14),
          // Quick actions
          Row(
            children: [
              _quickBtn(Icons.call_outlined, 'Call',
                  contact.phone.isNotEmpty ? () => _launchUrl('tel:${contact.phone}') : null),
              const SizedBox(width: 8),
              _quickBtn(Icons.mail_outline, 'Email',
                  contact.email.isNotEmpty ? () => _generateEmailDraft(contact) : null),
              const SizedBox(width: 8),
              _quickBtn(Icons.calendar_month_outlined, 'Schedule',
                  () => _toast('Schedule Meeting is UI-only for now.')),
            ],
          ),

          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FButton(
              variant: FButtonVariant.outline,
              onPress: () => showLogInteractionSheet(context, contactId: contact.id, onSaved: () => _fetchContactDetails(contact)),
              prefix: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
              child: const Text('LOG INTERACTION'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String value, VoidCallback onTap) {
    return FButton(
      variant: FButtonVariant.ghost,
      onPress: onTap,
      prefix: Icon(icon, size: 17),
      suffix: const Icon(Icons.chevron_right, size: 16),
      child: Expanded(child: Text(value, overflow: TextOverflow.ellipsis)),
    );
  }

  Widget _followUpBadge(String status) {
    switch (status) {
      case 'urgent':       return FBadge(variant: FBadgeVariant.destructive, child: const Text('URGENT'));
      case 'contacted':    return FBadge(variant: FBadgeVariant.primary,     child: const Text('CONTACTED'));
      case 'needs_followup': return FBadge(variant: FBadgeVariant.secondary, child: const Text('FOLLOW UP'));
      default:             return FBadge(variant: FBadgeVariant.outline,     child: const Text('NOT CONTACTED'));
    }
  }

  Widget _quickBtn(IconData icon, String label, VoidCallback? onTap) {
    return Expanded(
      child: FButton(
        variant: FButtonVariant.outline,
        onPress: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(height: 4),
            Text(label, style: context.theme.typography.xs.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  // ─── AI Card ──────────────────────────────────────────────────────────────

  Widget _buildAICard(ContactProfileData contact) {
    final theme = context.theme;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 15, color: theme.colors.primary),
              const SizedBox(width: 8),
              Text('AI INTELLIGENCE', style: theme.typography.xs.copyWith(
                fontWeight: FontWeight.w700, letterSpacing: 1.4, color: theme.colors.primary,
              )),
              const Spacer(),
              if (_contactInsights != null)
                FButton(
                  variant: FButtonVariant.ghost,
                  onPress: () => _fetchInsights(contact.id),
                  child: const Icon(Icons.refresh, size: 15),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (_isLoadingInsights)
            const _AiThinkingDots()
          else if (_contactInsights != null)
            _buildInsightsContent(_contactInsights!)
          else
            _buildInsightsEmpty(contact),
        ],
      ),
    );
  }

  Widget _buildInsightsEmpty(ContactProfileData contact) {
    final theme = context.theme;
    final hasTitle = contact.title.isNotEmpty;
    final hasCompany = contact.company.isNotEmpty;
    final hasLinkedin = contact.linkedin.isNotEmpty;
    final hasTimeline = contact.timelineItems.isNotEmpty;
    final signalCount = [hasTitle, hasCompany, hasLinkedin, hasTimeline].where((v) => v).length;

    if (signalCount >= 2) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('AI insights are being generated and will appear here shortly.',
              style: theme.typography.sm.copyWith(fontStyle: FontStyle.italic, color: theme.colors.mutedForeground)),
          const SizedBox(height: 16),
          const _AiThinkingDots(),
        ],
      );
    }

    final missing = <_MissingDetail>[];
    if (!hasTitle)    missing.add(_MissingDetail(Icons.work_outline, 'Job title'));
    if (!hasCompany)  missing.add(_MissingDetail(Icons.domain_outlined, 'Company'));
    if (!hasLinkedin) missing.add(_MissingDetail(Icons.link, 'LinkedIn profile'));
    if (!hasTimeline) missing.add(_MissingDetail(Icons.history, 'Log an interaction'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Add more details to unlock AI-generated intelligence for this contact.',
            style: theme.typography.sm.copyWith(color: theme.colors.mutedForeground)),
        const SizedBox(height: 12),
        ...missing.map((m) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            Icon(m.icon, size: 14, color: theme.colors.primary),
            const SizedBox(width: 8),
            Text(m.label, style: theme.typography.sm.copyWith(color: theme.colors.mutedForeground)),
          ]),
        )),
        const SizedBox(height: 4),
        FButton(
          variant: FButtonVariant.outline,
          onPress: () => showLogInteractionSheet(context, contactId: contact.id, onSaved: () => _fetchContactDetails(contact)),
          prefix: const Icon(Icons.add, size: 14),
          child: const Text('LOG INTERACTION'),
        ),
      ],
    );
  }

  Widget _buildInsightsContent(Map<String, dynamic> insights) {
    final theme = context.theme;
    final strategicContext = insights['strategic_context'] as String? ?? '';
    final briefing = (insights['briefing_items'] as List?)?.cast<String>() ?? [];
    final aiInsights = (insights['ai_insights'] as List?)?.cast<String>() ?? [];
    final painPoint = insights['primary_pain_point'] as String? ?? '';
    final keyMarkets = (insights['key_markets'] as List?)?.cast<String>() ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (strategicContext.isNotEmpty) ...[
          AppCard(
            padding: const EdgeInsets.all(12),
            child: Text(strategicContext, style: theme.typography.sm.copyWith(
              fontStyle: FontStyle.italic, color: theme.colors.mutedForeground, height: 1.5,
            )),
          ),
          const SizedBox(height: 14),
        ],
        if (painPoint.isNotEmpty) ...[
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.warning_amber_outlined, size: 14, color: theme.colors.primary),
            const SizedBox(width: 6),
            Expanded(child: Text('Pain point: $painPoint',
                style: theme.typography.sm.copyWith(color: theme.colors.mutedForeground, height: 1.4))),
          ]),
          const SizedBox(height: 12),
        ],
        if (briefing.isNotEmpty) ...[
          Text('BEFORE YOUR MEETING', style: theme.typography.xs.copyWith(
              fontWeight: FontWeight.w700, letterSpacing: 1.2, color: theme.colors.mutedForeground)),
          const SizedBox(height: 8),
          ...briefing.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Icon(Icons.circle, size: 5, color: theme.colors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(item, style: theme.typography.sm.copyWith(
                  color: theme.colors.mutedForeground, height: 1.45))),
            ]),
          )),
          const SizedBox(height: 12),
        ],
        if (aiInsights.isNotEmpty) ...[
          Text('KEY INSIGHTS', style: theme.typography.xs.copyWith(
              fontWeight: FontWeight.w700, letterSpacing: 1.2, color: theme.colors.mutedForeground)),
          const SizedBox(height: 8),
          ...aiInsights.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.arrow_right, size: 16, color: theme.colors.primary),
              const SizedBox(width: 6),
              Expanded(child: Text(item, style: theme.typography.sm.copyWith(
                  color: theme.colors.mutedForeground, height: 1.45))),
            ]),
          )),
          const SizedBox(height: 8),
        ],
        if (keyMarkets.isNotEmpty) ...[
          Text('KEY MARKETS', style: theme.typography.xs.copyWith(
              fontWeight: FontWeight.w700, letterSpacing: 1.2, color: theme.colors.mutedForeground)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6, runSpacing: 6,
            children: keyMarkets.map((m) => FBadge(
              variant: FBadgeVariant.secondary,
              child: Text(m),
            )).toList(),
          ),
        ],
      ],
    );
  }

  // ─── Timeline Card ────────────────────────────────────────────────────────

  Widget _buildTimelineCard(ContactProfileData contact) {
    final theme = context.theme;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ENGAGEMENT TIMELINE', style: theme.typography.xs.copyWith(
              fontWeight: FontWeight.w700, letterSpacing: 1.4, color: theme.colors.mutedForeground)),
          const SizedBox(height: 16),
          if (contact.timelineItems.isEmpty)
            Text('No interactions logged yet.', style: theme.typography.sm.copyWith(color: theme.colors.mutedForeground))
          else
            SizedBox(
              height: contact.timelineItems.length > 3 ? MediaQuery.of(context).size.height * 0.55 : null,
              child: _ScrollableTimeline(
                items: contact.timelineItems,
                itemBuilder: _buildTimelineItem,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(ContactTimelineItem item) {
    final theme = context.theme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dot
          Container(
            width: 21, height: 21,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colors.background,
              border: Border.all(
                color: item.isCurrent ? theme.colors.foreground : theme.colors.border,
                width: 2,
              ),
            ),
            child: item.isCurrent
                ? Center(child: Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(color: theme.colors.foreground, shape: BoxShape.circle),
                  ))
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.dateLabel, style: theme.typography.xs.copyWith(
                    fontWeight: FontWeight.w600, letterSpacing: 1.0, color: theme.colors.mutedForeground)),
                const SizedBox(height: 6),
                Text(item.title, style: theme.typography.sm.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(item.description, style: theme.typography.sm.copyWith(
                    color: theme.colors.mutedForeground, height: 1.4)),
                if (item.note != null) ...[
                  const SizedBox(height: 10),
                  AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.notes_rounded, size: 14, color: theme.colors.primary),
                        const SizedBox(width: 8),
                        Expanded(child: Text(item.note!, style: theme.typography.sm.copyWith(
                            color: theme.colors.mutedForeground, height: 1.4))),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Links Card ───────────────────────────────────────────────────────────

  Widget _buildLinksCard(ContactProfileData contact) {
    final hasAssets = contact.assets.isNotEmpty;
    return FButton(
      variant: FButtonVariant.outline,
      onPress: _openLinksFiles,
      prefix: const Icon(Icons.attachment_outlined, size: 18),
      suffix: Icon(hasAssets ? Icons.chevron_right : Icons.add, size: 18),
      child: Expanded(
        child: Row(
          children: [
            const Text('Links & Files'),
            const Spacer(),
            Text(hasAssets ? '${contact.assets.length} items' : 'None added',
                style: context.theme.typography.xs.copyWith(
                    fontStyle: hasAssets ? FontStyle.normal : FontStyle.italic,
                    color: context.theme.colors.mutedForeground)),
          ],
        ),
      ),
    );
  }

  // ─── Events Card ──────────────────────────────────────────────────────────

  Widget _buildEventsCard(ContactProfileData contact) {
    final theme = context.theme;
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('EVENTS', style: theme.typography.xs.copyWith(
                  fontWeight: FontWeight.w700, letterSpacing: 1.4, color: theme.colors.mutedForeground)),
              const Spacer(),
              FButton(
                variant: FButtonVariant.secondary,
                onPress: () => _showLinkEventSheet(contact),
                prefix: const Icon(Icons.add, size: 14),
                child: const Text('Link Event'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (contact.linkedEvents.isEmpty)
            Text('No events linked yet.', style: theme.typography.sm.copyWith(color: theme.colors.mutedForeground))
          else
            ...contact.linkedEvents.map((event) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  FBadge(
                    variant: FBadgeVariant.secondary,
                    child: const Icon(Icons.event_outlined, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(event.name, style: theme.typography.sm.copyWith(fontWeight: FontWeight.w600)),
                        if (event.location != null && event.location!.isNotEmpty)
                          Text(event.location!, style: theme.typography.xs.copyWith(color: theme.colors.mutedForeground)),
                      ],
                    ),
                  ),
                  FButton(
                    variant: FButtonVariant.ghost,
                    onPress: () => _unlinkEvent(contact, event),
                    child: const Icon(Icons.link_off_rounded, size: 16),
                  ),
                ],
              ),
            )),
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
  late final _firstNameCtrl = TextEditingController(text: _splitName(widget.contact.listName).first);
  late final _lastNameCtrl  = TextEditingController(text: _splitName(widget.contact.listName).last);
  late final _emailCtrl     = TextEditingController(text: widget.contact.email);
  late final _phoneCtrl     = TextEditingController(text: widget.contact.phone);
  late final _jobTitleCtrl  = TextEditingController(text: widget.contact.title);
  late final _linkedinCtrl  = TextEditingController(text: widget.contact.linkedin);
  late final _companyCtrl   = TextEditingController(text: widget.contact.company);
  bool _isSaving = false;

  List<String> _splitName(String fullName) {
    final parts = fullName.trim().split(' ');
    if (parts.length == 1) return [parts[0], ''];
    return [parts.first, parts.sublist(1).join(' ')];
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose(); _lastNameCtrl.dispose(); _emailCtrl.dispose();
    _phoneCtrl.dispose(); _jobTitleCtrl.dispose(); _linkedinCtrl.dispose(); _companyCtrl.dispose();
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
        showFToast(context: context, title: Text('Save failed: $e'));
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 48, height: 4,
                decoration: BoxDecoration(
                  color: theme.colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Text('Edit Contact', style: theme.typography.lg.copyWith(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  FButton(variant: FButtonVariant.ghost, onPress: () => Navigator.pop(context), child: const Text('Cancel')),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(
                  children: [
                    Row(children: [
                      Expanded(child: AppInput(label: 'First Name', controller: _firstNameCtrl)),
                      const SizedBox(width: 12),
                      Expanded(child: AppInput(label: 'Last Name', controller: _lastNameCtrl)),
                    ]),
                    const SizedBox(height: 12),
                    AppInput(label: 'Email', controller: _emailCtrl, keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 12),
                    AppInput(label: 'Phone', controller: _phoneCtrl, keyboardType: TextInputType.phone),
                    const SizedBox(height: 12),
                    AppInput(label: 'Job Title', controller: _jobTitleCtrl),
                    const SizedBox(height: 12),
                    AppInput(label: 'Company', controller: _companyCtrl),
                    const SizedBox(height: 12),
                    AppInput(label: 'LinkedIn URL', controller: _linkedinCtrl, keyboardType: TextInputType.url),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FButton(
                        variant: FButtonVariant.primary,
                        onPress: _isSaving ? null : _save,
                        child: _isSaving
                            ? const SizedBox(width: 18, height: 18, child: FCircularProgress())
                            : const Text('SAVE CHANGES'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final color = context.theme.colors.primary;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = i / 3.0;
            final t = ((_ctrl.value - phase) % 1.0 + 1.0) % 1.0;
            final brightness = (Math.sin(t * Math.pi)).clamp(0.0, 1.0);
            final size = 6.0 + brightness * 3.0;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Container(
                width: size, height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.3 + brightness * 0.7),
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
  final Future<void> Function(Event event) onLink;

  const _EventPickerSheet({
    required this.allEvents,
    required this.linkedEventIds,
    required this.onLink,
  });

  @override
  State<_EventPickerSheet> createState() => _EventPickerSheetState();
}

class _EventPickerSheetState extends State<_EventPickerSheet> {
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
          : widget.allEvents.where((e) =>
              e.name.toLowerCase().contains(q) || (e.location ?? '').toLowerCase().contains(q)).toList();
    });
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 48, height: 4,
                  decoration: BoxDecoration(
                    color: theme.colors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  children: [
                    Text('Link to Event', style: theme.typography.lg.copyWith(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    FButton(variant: FButtonVariant.ghost, onPress: () => Navigator.pop(context), child: const Icon(Icons.close)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: AppInput(
                  controller: _searchCtrl,
                  hint: 'Search events...',
                  prefixIcon: Icon(Icons.search, color: theme.colors.primary, size: 18),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _filtered.isEmpty
                    ? Center(child: Text('No events found.',
                        style: theme.typography.sm.copyWith(color: theme.colors.mutedForeground)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) {
                          final event = _filtered[i];
                          final isLinked = widget.linkedEventIds.contains(event.id);
                          return FButton(
                            variant: FButtonVariant.ghost,
                            onPress: isLinked ? null : () async {
                              setState(() => _linking = true);
                              try { await widget.onLink(event); }
                              finally { if (mounted) setState(() => _linking = false); }
                              if (mounted) Navigator.pop(context);
                            },
                            prefix: FBadge(variant: FBadgeVariant.secondary, child: const Icon(Icons.event_outlined, size: 18)),
                            suffix: isLinked
                                ? Icon(Icons.check_circle_rounded, color: theme.colors.primary, size: 20)
                                : (_linking
                                    ? const SizedBox(width: 20, height: 20, child: FCircularProgress())
                                    : Icon(Icons.add_circle_outline, color: theme.colors.primary, size: 20)),
                            child: Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(event.name, style: theme.typography.sm.copyWith(fontWeight: FontWeight.w600)),
                                  if (event.location != null && event.location!.isNotEmpty)
                                    Text(event.location!, style: theme.typography.xs.copyWith(color: theme.colors.mutedForeground)),
                                ],
                              ),
                            ),
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

// ─── Scrollable Timeline ──────────────────────────────────────────────────────

class _ScrollableTimeline extends StatefulWidget {
  final List<ContactTimelineItem> items;
  final Widget Function(ContactTimelineItem) itemBuilder;

  const _ScrollableTimeline({required this.items, required this.itemBuilder});

  @override
  State<_ScrollableTimeline> createState() => _ScrollableTimelineState();
}

class _ScrollableTimelineState extends State<_ScrollableTimeline>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollCtrl = ScrollController();
  late final AnimationController _bounceCtrl;
  bool _showIndicator = false;

  @override
  void initState() {
    super.initState();
    _bounceCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true);
    _scrollCtrl.addListener(() {
      final atBottom = _scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 4;
      if (atBottom && _showIndicator) setState(() => _showIndicator = false);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scrollCtrl.hasClients && _scrollCtrl.position.maxScrollExtent > 0) {
        setState(() => _showIndicator = true);
      }
    });
  }

  @override
  void didUpdateWidget(_ScrollableTimeline old) {
    super.didUpdateWidget(old);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scrollCtrl.hasClients && _scrollCtrl.position.maxScrollExtent > 0) {
        setState(() => _showIndicator = true);
      }
    });
  }

  @override
  void dispose() { _bounceCtrl.dispose(); _scrollCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final color = context.theme.colors.primary;
    return Stack(
      children: [
        SingleChildScrollView(
          controller: _scrollCtrl,
          physics: const ClampingScrollPhysics(),
          child: Stack(
            children: [
              Positioned(
                left: 10, top: 0, bottom: 0,
                child: Container(width: 1, color: context.theme.colors.border),
              ),
              Column(children: widget.items.map((item) => widget.itemBuilder(item)).toList()),
            ],
          ),
        ),
        if (_showIndicator)
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: IgnorePointer(
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      context.theme.colors.background.withValues(alpha: 0),
                      context.theme.colors.background,
                    ],
                  ),
                ),
                alignment: Alignment.bottomCenter,
                padding: const EdgeInsets.only(bottom: 6),
                child: AnimatedBuilder(
                  animation: _bounceCtrl,
                  builder: (context, _) => Transform.translate(
                    offset: Offset(0, 3.0 * _bounceCtrl.value),
                    child: Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: color),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
