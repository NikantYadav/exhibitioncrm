import 'package:flutter/material.dart';

import '../repositories/companies_repository.dart';
import 'api_service.dart';

/// Resolves a company by ID via a direct `GET /companies/:id` call when the
/// row is missing from the local synced `companies` table, then PERSISTS it
/// locally so every existing local join resolves the name, it survives app
/// restarts, works offline thereafter, and stays in the user's synced set
/// (the backend's `/sync` scopes `companies` to rows referenced by the user's
/// contacts/target_companies, so a referenced company stays current).
///
/// Why this is needed: a company that is newly referenced but whose row
/// predates the client's sync cursor is never delivered by `/sync` (it filters
/// referenced companies by `updated_at > since`), so the local join shows
/// "Unknown". This lazily backfills exactly the companies the user touches.
class CompanyNameResolver {
  CompanyNameResolver._();

  /// Set once at startup by [SyncProvider] so the resolver can persist rows.
  static CompaniesRepository? repo;

  static final Map<String, String> _cache = {};
  static final Map<String, Future<String?>> _inFlight = {};

  // Notifier incremented whenever any company name is updated, so CompanyName
  // widgets subscribed to a specific id can re-read the cache and rebuild.
  static final ValueNotifier<Map<String, String>> _updates =
      ValueNotifier(<String, String>{});

  /// Returns the cached name for [companyId] if already resolved, else null.
  static String? cached(String? companyId) =>
      companyId == null ? null : _cache[companyId];

  /// Writes [name] into the cache for [companyId] and notifies all listening
  /// [CompanyName] widgets to rebuild. Call this after enrichment updates a
  /// company's name so tiles on other screens update without a reload.
  static void update(String companyId, String name) {
    _cache[companyId] = name;
    _updates.value = Map.of(_cache);
  }

  /// Fetches the company from the API, persists it locally, and caches its
  /// name. Returns null on failure (e.g. offline) so callers can fall back.
  static Future<String?> resolve(String? companyId) {
    if (companyId == null || companyId.isEmpty) return Future.value(null);
    final hit = _cache[companyId];
    if (hit != null) return Future.value(hit);

    return _inFlight.putIfAbsent(companyId, () async {
      try {
        final data = await ApiService.getCompany(companyId);
        await repo?.upsertOne(data);
        final name = data['name'] as String?;
        if (name != null && name.isNotEmpty) {
          update(companyId, name);
        }
        return name;
      } catch (_) {
        return null;
      } finally {
        _inFlight.remove(companyId);
      }
    });
  }
}

/// Displays a company's name. Shows [fallback] (the local/cached name, which
/// may be "Unknown" or empty) immediately, then resolves the authoritative
/// name from the API if needed (which also persists it locally for next time).
class CompanyName extends StatefulWidget {
  final String? companyId;
  final String fallback;
  final TextStyle? style;
  final TextOverflow? overflow;
  final int? maxLines;

  const CompanyName({
    super.key,
    required this.companyId,
    this.fallback = '',
    this.style,
    this.overflow,
    this.maxLines,
  });

  @override
  State<CompanyName> createState() => _CompanyNameState();
}

class _CompanyNameState extends State<CompanyName> {
  late String _name;

  @override
  void initState() {
    super.initState();
    _name = CompanyNameResolver.cached(widget.companyId) ?? widget.fallback;
    CompanyNameResolver._updates.addListener(_onUpdate);
    _resolve();
  }

  @override
  void didUpdateWidget(CompanyName oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.companyId != widget.companyId) {
      _name = CompanyNameResolver.cached(widget.companyId) ?? widget.fallback;
      _resolve();
    }
  }

  @override
  void dispose() {
    CompanyNameResolver._updates.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    final latest = CompanyNameResolver.cached(widget.companyId);
    if (latest != null && latest != _name && mounted) {
      setState(() => _name = latest);
    }
  }

  Future<void> _resolve() async {
    final resolved = await CompanyNameResolver.resolve(widget.companyId);
    if (resolved != null && resolved != _name && mounted) {
      setState(() => _name = resolved);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _name,
      style: widget.style,
      overflow: widget.overflow,
      maxLines: widget.maxLines,
    );
  }
}
