import '../db/app_database.dart';

/// Combines an event date (UTC) with an "HH:mm" time-of-day, treating the
/// stored time as UTC wall-clock on that date. Mirrors the backend rule.
DateTime _withTime(DateTime date, String time) {
  final parts = time.split(':');
  return DateTime.utc(date.year, date.month, date.day, int.parse(parts[0]), int.parse(parts[1]));
}

/// Per-event status. The live window starts at [startTime] (or midnight if
/// absent) and ends at [endTime], the end of the multi-day span, or — for an
/// open-ended event — [openEndedBoundary] when given (the next same-day event's
/// start, computed by [eventsWithLiveStatus]), else end of day.
String computeEventStatus(
  DateTime startDate,
  DateTime? endDate, {
  String? startTime,
  String? endTime,
  DateTime? openEndedBoundary,
}) {
  final now = DateTime.now().toUtc();
  final start = startDate.toUtc();
  final rangeStart = startTime != null ? _withTime(start, startTime) : start;
  final DateTime rangeEnd;
  if (endDate != null) {
    rangeEnd = DateTime.utc(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999);
  } else if (endTime != null) {
    rangeEnd = _withTime(start, endTime);
  } else if (openEndedBoundary != null) {
    rangeEnd = openEndedBoundary;
  } else {
    rangeEnd = DateTime.utc(start.year, start.month, start.day, 23, 59, 59, 999);
  }
  if (!now.isBefore(rangeStart) && !now.isAfter(rangeEnd)) return 'ongoing';
  if (now.isAfter(rangeEnd)) return 'completed';
  return 'upcoming';
}

/// Recomputes each event's status considering its same-day siblings, so an
/// open-ended event ends one millisecond before the next single-day event that
/// day begins (mirrors the backend effectiveEnd rule and LiveEventProvider).
/// Returns new [Event]s with corrected [Event.status]; pass the full list.
List<Event> eventsWithLiveStatus(List<Event> events) {
  DateTime? boundaryFor(Event e) {
    if (e.endDate != null || e.startTime == null || e.endTime != null) return null;
    final start = e.startDate.toUtc();
    final myStart = _withTime(start, e.startTime!);
    DateTime? boundary;
    for (final other in events) {
      if (identical(other, e) || other.endDate != null || other.startTime == null) continue;
      final os = other.startDate.toUtc();
      if (os.year != start.year || os.month != start.month || os.day != start.day) continue;
      final otherStart = _withTime(os, other.startTime!);
      if (otherStart.isAfter(myStart) && (boundary == null || otherStart.isBefore(boundary))) {
        boundary = otherStart;
      }
    }
    return boundary?.subtract(const Duration(milliseconds: 1));
  }

  return events.map((e) {
    final status = computeEventStatus(
      e.startDate,
      e.endDate,
      startTime: e.startTime,
      endTime: e.endTime,
      openEndedBoundary: boundaryFor(e),
    );
    return e.status == status ? e : e.copyWith(status: status);
  }).toList();
}

/// Postgres `time` columns come back as "HH:mm:ss"; the app stores "HH:mm".
String? _normalizeTime(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final parts = raw.split(':');
  if (parts.length < 2) return raw;
  return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
}

class Event {
  final String id;
  final String name;
  final String? location;
  final DateTime startDate;
  final DateTime? endDate;
  final String? startTime;
  final String? endTime;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  Event({
    required this.id,
    required this.name,
    this.location,
    required this.startDate,
    this.endDate,
    this.startTime,
    this.endTime,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'],
      name: json['name'],
      location: json['location'],
      startDate: DateTime.parse(json['start_date']),
      endDate: json['end_date'] != null ? DateTime.parse(json['end_date']) : null,
      startTime: _normalizeTime(json['start_time'] as String?),
      endTime: _normalizeTime(json['end_time'] as String?),
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  // ── Local-timezone display helpers ──────────────────────────────────────
  // Times are stored in UTC (paired with the UTC date anchor); the user always
  // sees them in their own timezone. These combine the UTC anchor + UTC "HH:mm"
  // into an instant and convert to local for display.
  DateTime? _localInstant(DateTime anchorUtc, String? utcHm) {
    if (utcHm == null || utcHm.isEmpty) return null;
    final p = utcHm.split(':');
    return DateTime.utc(anchorUtc.year, anchorUtc.month, anchorUtc.day,
            int.parse(p[0]), int.parse(p[1]))
        .toLocal();
  }

  static String? _hm(DateTime? local) => local == null
      ? null
      : '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';

  /// Start time as "HH:mm" in the device's local timezone, or null.
  String? get localStartTime => _hm(_localInstant(startDate.toUtc(), startTime));

  /// End time as "HH:mm" in the device's local timezone, or null.
  String? get localEndTime =>
      _hm(_localInstant((endDate ?? startDate).toUtc(), endTime));

  /// Human label for the event's time range in local time: "21:12 – 23:00" when
  /// both ends are set, "From 21:12" when only a start time exists, or null when
  /// the event has no time (legacy/all-day).
  String? get localTimeRange {
    final start = localStartTime;
    if (start == null) return null;
    final end = localEndTime;
    return end != null ? '$start – $end' : 'From $start';
  }

  /// Calendar date the event starts on, in the user's local timezone. When the
  /// event has a start time, this reflects the local day of that instant (which
  /// can differ from the UTC anchor day); otherwise the anchor day as-is.
  DateTime get localStartDate {
    final inst = _localInstant(startDate.toUtc(), startTime);
    if (inst != null) return DateTime(inst.year, inst.month, inst.day);
    final l = startDate.toLocal();
    return DateTime(l.year, l.month, l.day);
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'location': location,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'start_time': startTime,
      'end_time': endTime,
    };
  }

  Event copyWith({String? status}) => Event(
        id: id,
        name: name,
        location: location,
        startDate: startDate,
        endDate: endDate,
        startTime: startTime,
        endTime: endTime,
        status: status ?? this.status,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  factory Event.fromDrift(EventsTableData row) {
    return Event(
      id: row.id,
      name: row.name,
      location: row.location,
      startDate: row.startDate,
      endDate: row.endDate,
      startTime: row.startTime,
      endTime: row.endTime,
      status: computeEventStatus(
        row.startDate,
        row.endDate,
        startTime: row.startTime,
        endTime: row.endTime,
      ),
      createdAt: row.createdAt ?? row.updatedAt,
      updatedAt: row.updatedAt,
    );
  }
}
