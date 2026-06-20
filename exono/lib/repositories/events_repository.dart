import 'package:drift/drift.dart';

import '../db/app_database.dart';
import 'combine_latest.dart';
import 'synced_repository.dart';

class EventsRepository extends SyncedRepository<EventsTableData, $EventsTableTable> {
  EventsRepository(super.db);

  @override
  String get tableName => 'events';

  @override
  TableInfo<$EventsTableTable, EventsTableData> get table => db.eventsTable;

  /// Events linked to a contact via either an interaction with a non-null
  /// event_id, or a contact_events row — deduped, mirroring
  /// `GET /contacts/:id/events`.
  Stream<List<EventsTableData>> watchLinkedToContact(String contactId) {
    final viaInteractions = db.select(db.eventsTable).join([
      innerJoin(db.interactionsTable, db.interactionsTable.eventId.equalsExp(db.eventsTable.id)),
    ])
      ..where(db.interactionsTable.contactId.equals(contactId) &
          db.interactionsTable.deletedAt.isNull() &
          db.eventsTable.deletedAt.isNull());

    final viaContactEvents = db.select(db.eventsTable).join([
      innerJoin(db.contactEventsTable, db.contactEventsTable.eventId.equalsExp(db.eventsTable.id)),
    ])
      ..where(db.contactEventsTable.contactId.equals(contactId) &
          db.contactEventsTable.deletedAt.isNull() &
          db.eventsTable.deletedAt.isNull());

    final stream1 = viaInteractions.watch().map((rows) => rows.map((r) => r.readTable(db.eventsTable)).toList());
    final stream2 = viaContactEvents.watch().map((rows) => rows.map((r) => r.readTable(db.eventsTable)).toList());

    return combineLatest2(stream1, stream2, (List<EventsTableData> a, List<EventsTableData> b) {
      final byId = <String, EventsTableData>{};
      for (final e in [...a, ...b]) {
        byId[e.id] = e;
      }
      return byId.values.toList();
    });
  }

  @override
  Insertable<EventsTableData> companionFromJson(Map<String, dynamic> json) {
    return EventsTableCompanion(
      id: Value(json['id'] as String),
      userId: Value(json['user_id'] as String?),
      name: Value(json['name'] as String),
      location: Value(json['location'] as String?),
      startDate: Value(DateTime.parse(json['start_date'] as String)),
      endDate: Value(json['end_date'] != null ? DateTime.parse(json['end_date'] as String) : null),
      eventType: Value(json['event_type'] as String?),
      createdAt: Value(json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null),
      updatedAt: Value(DateTime.parse(json['updated_at'] as String)),
      deletedAt: Value(json['deleted_at'] != null ? DateTime.parse(json['deleted_at'] as String) : null),
    );
  }
}
