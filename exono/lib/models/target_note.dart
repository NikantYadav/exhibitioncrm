import 'dart:convert';

/// One prep note on a target company. Stored as an element of a JSON array
/// in the (text) `target_companies.notes` column locally (jsonb server-side).
class TargetNote {
  final String id;
  final String body;
  final DateTime createdAt;

  const TargetNote({required this.id, required this.body, required this.createdAt});

  factory TargetNote.fromJson(Map<String, dynamic> j) => TargetNote(
        id: (j['id'] ?? DateTime.now().microsecondsSinceEpoch.toString()).toString(),
        body: (j['body'] ?? '').toString(),
        createdAt: DateTime.tryParse((j['created_at'] ?? '').toString())?.toUtc() ??
            DateTime.now().toUtc(),
      );

  /// Parse the raw column value (a JSON array string locally) into a list of notes.
  /// Defensively handles legacy plain-text values from not-yet-migrated local rows.
  static List<TargetNote> parseList(String? raw) {
    if (raw == null || raw.trim().isEmpty) { return []; }
    final t = raw.trim();
    if (!t.startsWith('[')) {
      // Legacy plain-text note — treat as a single note.
      return [TargetNote(id: 'legacy', body: t, createdAt: DateTime.now().toUtc())];
    }
    try {
      final decoded = jsonDecode(t);
      if (decoded is! List) { return []; }
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(TargetNote.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }
}
