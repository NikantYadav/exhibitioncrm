import '../db/app_database.dart';

String computeEventStatus(DateTime startDate, DateTime? endDate) {
  final now = DateTime.now().toUtc();
  final start = startDate.toUtc();
  final end = endDate != null
      ? DateTime.utc(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999)
      : start.add(const Duration(days: 1, milliseconds: -1));
  if (!now.isBefore(start) && !now.isAfter(end)) return 'ongoing';
  if (now.isAfter(end)) return 'completed';
  return 'upcoming';
}

class Event {
  final String id;
  final String name;
  final String? location;
  final DateTime startDate;
  final DateTime? endDate;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  Event({
    required this.id,
    required this.name,
    this.location,
    required this.startDate,
    this.endDate,
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
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'location': location,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
    };
  }

  factory Event.fromDrift(EventsTableData row) {
    return Event(
      id: row.id,
      name: row.name,
      location: row.location,
      startDate: row.startDate,
      endDate: row.endDate,
      status: computeEventStatus(row.startDate, row.endDate),
      createdAt: row.createdAt ?? row.updatedAt,
      updatedAt: row.updatedAt,
    );
  }
}
