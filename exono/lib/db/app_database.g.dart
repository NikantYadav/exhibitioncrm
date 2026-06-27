// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $EventsTableTable extends EventsTable
    with TableInfo<$EventsTableTable, EventsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EventsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _locationMeta = const VerificationMeta(
    'location',
  );
  @override
  late final GeneratedColumn<String> location = GeneratedColumn<String>(
    'location',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startDateMeta = const VerificationMeta(
    'startDate',
  );
  @override
  late final GeneratedColumn<DateTime> startDate = GeneratedColumn<DateTime>(
    'start_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endDateMeta = const VerificationMeta(
    'endDate',
  );
  @override
  late final GeneratedColumn<DateTime> endDate = GeneratedColumn<DateTime>(
    'end_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startTimeMeta = const VerificationMeta(
    'startTime',
  );
  @override
  late final GeneratedColumn<String> startTime = GeneratedColumn<String>(
    'start_time',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endTimeMeta = const VerificationMeta(
    'endTime',
  );
  @override
  late final GeneratedColumn<String> endTime = GeneratedColumn<String>(
    'end_time',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _eventTypeMeta = const VerificationMeta(
    'eventType',
  );
  @override
  late final GeneratedColumn<String> eventType = GeneratedColumn<String>(
    'event_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    name,
    location,
    startDate,
    endDate,
    startTime,
    endTime,
    eventType,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'events';
  @override
  VerificationContext validateIntegrity(
    Insertable<EventsTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('location')) {
      context.handle(
        _locationMeta,
        location.isAcceptableOrUnknown(data['location']!, _locationMeta),
      );
    }
    if (data.containsKey('start_date')) {
      context.handle(
        _startDateMeta,
        startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta),
      );
    } else if (isInserting) {
      context.missing(_startDateMeta);
    }
    if (data.containsKey('end_date')) {
      context.handle(
        _endDateMeta,
        endDate.isAcceptableOrUnknown(data['end_date']!, _endDateMeta),
      );
    }
    if (data.containsKey('start_time')) {
      context.handle(
        _startTimeMeta,
        startTime.isAcceptableOrUnknown(data['start_time']!, _startTimeMeta),
      );
    }
    if (data.containsKey('end_time')) {
      context.handle(
        _endTimeMeta,
        endTime.isAcceptableOrUnknown(data['end_time']!, _endTimeMeta),
      );
    }
    if (data.containsKey('event_type')) {
      context.handle(
        _eventTypeMeta,
        eventType.isAcceptableOrUnknown(data['event_type']!, _eventTypeMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EventsTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EventsTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      location: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location'],
      ),
      startDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_date'],
      )!,
      endDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}end_date'],
      ),
      startTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}start_time'],
      ),
      endTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}end_time'],
      ),
      eventType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_type'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $EventsTableTable createAlias(String alias) {
    return $EventsTableTable(attachedDatabase, alias);
  }
}

class EventsTableData extends DataClass implements Insertable<EventsTableData> {
  final String id;
  final String? userId;
  final String name;
  final String? location;
  final DateTime startDate;
  final DateTime? endDate;
  final String? startTime;
  final String? endTime;
  final String? eventType;
  final DateTime? createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const EventsTableData({
    required this.id,
    this.userId,
    required this.name,
    this.location,
    required this.startDate,
    this.endDate,
    this.startTime,
    this.endTime,
    this.eventType,
    this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || userId != null) {
      map['user_id'] = Variable<String>(userId);
    }
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || location != null) {
      map['location'] = Variable<String>(location);
    }
    map['start_date'] = Variable<DateTime>(startDate);
    if (!nullToAbsent || endDate != null) {
      map['end_date'] = Variable<DateTime>(endDate);
    }
    if (!nullToAbsent || startTime != null) {
      map['start_time'] = Variable<String>(startTime);
    }
    if (!nullToAbsent || endTime != null) {
      map['end_time'] = Variable<String>(endTime);
    }
    if (!nullToAbsent || eventType != null) {
      map['event_type'] = Variable<String>(eventType);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  EventsTableCompanion toCompanion(bool nullToAbsent) {
    return EventsTableCompanion(
      id: Value(id),
      userId: userId == null && nullToAbsent
          ? const Value.absent()
          : Value(userId),
      name: Value(name),
      location: location == null && nullToAbsent
          ? const Value.absent()
          : Value(location),
      startDate: Value(startDate),
      endDate: endDate == null && nullToAbsent
          ? const Value.absent()
          : Value(endDate),
      startTime: startTime == null && nullToAbsent
          ? const Value.absent()
          : Value(startTime),
      endTime: endTime == null && nullToAbsent
          ? const Value.absent()
          : Value(endTime),
      eventType: eventType == null && nullToAbsent
          ? const Value.absent()
          : Value(eventType),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory EventsTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EventsTableData(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String?>(json['userId']),
      name: serializer.fromJson<String>(json['name']),
      location: serializer.fromJson<String?>(json['location']),
      startDate: serializer.fromJson<DateTime>(json['startDate']),
      endDate: serializer.fromJson<DateTime?>(json['endDate']),
      startTime: serializer.fromJson<String?>(json['startTime']),
      endTime: serializer.fromJson<String?>(json['endTime']),
      eventType: serializer.fromJson<String?>(json['eventType']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String?>(userId),
      'name': serializer.toJson<String>(name),
      'location': serializer.toJson<String?>(location),
      'startDate': serializer.toJson<DateTime>(startDate),
      'endDate': serializer.toJson<DateTime?>(endDate),
      'startTime': serializer.toJson<String?>(startTime),
      'endTime': serializer.toJson<String?>(endTime),
      'eventType': serializer.toJson<String?>(eventType),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  EventsTableData copyWith({
    String? id,
    Value<String?> userId = const Value.absent(),
    String? name,
    Value<String?> location = const Value.absent(),
    DateTime? startDate,
    Value<DateTime?> endDate = const Value.absent(),
    Value<String?> startTime = const Value.absent(),
    Value<String?> endTime = const Value.absent(),
    Value<String?> eventType = const Value.absent(),
    Value<DateTime?> createdAt = const Value.absent(),
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => EventsTableData(
    id: id ?? this.id,
    userId: userId.present ? userId.value : this.userId,
    name: name ?? this.name,
    location: location.present ? location.value : this.location,
    startDate: startDate ?? this.startDate,
    endDate: endDate.present ? endDate.value : this.endDate,
    startTime: startTime.present ? startTime.value : this.startTime,
    endTime: endTime.present ? endTime.value : this.endTime,
    eventType: eventType.present ? eventType.value : this.eventType,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  EventsTableData copyWithCompanion(EventsTableCompanion data) {
    return EventsTableData(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      name: data.name.present ? data.name.value : this.name,
      location: data.location.present ? data.location.value : this.location,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      endDate: data.endDate.present ? data.endDate.value : this.endDate,
      startTime: data.startTime.present ? data.startTime.value : this.startTime,
      endTime: data.endTime.present ? data.endTime.value : this.endTime,
      eventType: data.eventType.present ? data.eventType.value : this.eventType,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EventsTableData(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('name: $name, ')
          ..write('location: $location, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('startTime: $startTime, ')
          ..write('endTime: $endTime, ')
          ..write('eventType: $eventType, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    name,
    location,
    startDate,
    endDate,
    startTime,
    endTime,
    eventType,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventsTableData &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.name == this.name &&
          other.location == this.location &&
          other.startDate == this.startDate &&
          other.endDate == this.endDate &&
          other.startTime == this.startTime &&
          other.endTime == this.endTime &&
          other.eventType == this.eventType &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class EventsTableCompanion extends UpdateCompanion<EventsTableData> {
  final Value<String> id;
  final Value<String?> userId;
  final Value<String> name;
  final Value<String?> location;
  final Value<DateTime> startDate;
  final Value<DateTime?> endDate;
  final Value<String?> startTime;
  final Value<String?> endTime;
  final Value<String?> eventType;
  final Value<DateTime?> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const EventsTableCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.name = const Value.absent(),
    this.location = const Value.absent(),
    this.startDate = const Value.absent(),
    this.endDate = const Value.absent(),
    this.startTime = const Value.absent(),
    this.endTime = const Value.absent(),
    this.eventType = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EventsTableCompanion.insert({
    required String id,
    this.userId = const Value.absent(),
    required String name,
    this.location = const Value.absent(),
    required DateTime startDate,
    this.endDate = const Value.absent(),
    this.startTime = const Value.absent(),
    this.endTime = const Value.absent(),
    this.eventType = const Value.absent(),
    this.createdAt = const Value.absent(),
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       startDate = Value(startDate),
       updatedAt = Value(updatedAt);
  static Insertable<EventsTableData> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? name,
    Expression<String>? location,
    Expression<DateTime>? startDate,
    Expression<DateTime>? endDate,
    Expression<String>? startTime,
    Expression<String>? endTime,
    Expression<String>? eventType,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (name != null) 'name': name,
      if (location != null) 'location': location,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (startTime != null) 'start_time': startTime,
      if (endTime != null) 'end_time': endTime,
      if (eventType != null) 'event_type': eventType,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EventsTableCompanion copyWith({
    Value<String>? id,
    Value<String?>? userId,
    Value<String>? name,
    Value<String?>? location,
    Value<DateTime>? startDate,
    Value<DateTime?>? endDate,
    Value<String?>? startTime,
    Value<String?>? endTime,
    Value<String?>? eventType,
    Value<DateTime?>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return EventsTableCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      location: location ?? this.location,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      eventType: eventType ?? this.eventType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (location.present) {
      map['location'] = Variable<String>(location.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<DateTime>(startDate.value);
    }
    if (endDate.present) {
      map['end_date'] = Variable<DateTime>(endDate.value);
    }
    if (startTime.present) {
      map['start_time'] = Variable<String>(startTime.value);
    }
    if (endTime.present) {
      map['end_time'] = Variable<String>(endTime.value);
    }
    if (eventType.present) {
      map['event_type'] = Variable<String>(eventType.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EventsTableCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('name: $name, ')
          ..write('location: $location, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('startTime: $startTime, ')
          ..write('endTime: $endTime, ')
          ..write('eventType: $eventType, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ContactsTableTable extends ContactsTable
    with TableInfo<$ContactsTableTable, ContactsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ContactsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _companyIdMeta = const VerificationMeta(
    'companyId',
  );
  @override
  late final GeneratedColumn<String> companyId = GeneratedColumn<String>(
    'company_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _firstNameMeta = const VerificationMeta(
    'firstName',
  );
  @override
  late final GeneratedColumn<String> firstName = GeneratedColumn<String>(
    'first_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastNameMeta = const VerificationMeta(
    'lastName',
  );
  @override
  late final GeneratedColumn<String> lastName = GeneratedColumn<String>(
    'last_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _jobTitleMeta = const VerificationMeta(
    'jobTitle',
  );
  @override
  late final GeneratedColumn<String> jobTitle = GeneratedColumn<String>(
    'job_title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _linkedinUrlMeta = const VerificationMeta(
    'linkedinUrl',
  );
  @override
  late final GeneratedColumn<String> linkedinUrl = GeneratedColumn<String>(
    'linkedin_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _avatarUrlMeta = const VerificationMeta(
    'avatarUrl',
  );
  @override
  late final GeneratedColumn<String> avatarUrl = GeneratedColumn<String>(
    'avatar_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _followUpStatusMeta = const VerificationMeta(
    'followUpStatus',
  );
  @override
  late final GeneratedColumn<String> followUpStatus = GeneratedColumn<String>(
    'follow_up_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('not_contacted'),
  );
  static const VerificationMeta _lastContactedAtMeta = const VerificationMeta(
    'lastContactedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastContactedAt =
      GeneratedColumn<DateTime>(
        'last_contacted_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _contactAssetsJsonMeta = const VerificationMeta(
    'contactAssetsJson',
  );
  @override
  late final GeneratedColumn<String> contactAssetsJson =
      GeneratedColumn<String>(
        'contact_assets_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _scannedDetailsJsonMeta =
      const VerificationMeta('scannedDetailsJson');
  @override
  late final GeneratedColumn<String> scannedDetailsJson =
      GeneratedColumn<String>(
        'scanned_details_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _aiInsightsJsonMeta = const VerificationMeta(
    'aiInsightsJson',
  );
  @override
  late final GeneratedColumn<String> aiInsightsJson = GeneratedColumn<String>(
    'ai_insights_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _aiContextSummaryMeta = const VerificationMeta(
    'aiContextSummary',
  );
  @override
  late final GeneratedColumn<String> aiContextSummary = GeneratedColumn<String>(
    'ai_context_summary',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    companyId,
    firstName,
    lastName,
    email,
    phone,
    jobTitle,
    linkedinUrl,
    notes,
    avatarUrl,
    followUpStatus,
    lastContactedAt,
    contactAssetsJson,
    scannedDetailsJson,
    aiInsightsJson,
    aiContextSummary,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'contacts';
  @override
  VerificationContext validateIntegrity(
    Insertable<ContactsTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    }
    if (data.containsKey('company_id')) {
      context.handle(
        _companyIdMeta,
        companyId.isAcceptableOrUnknown(data['company_id']!, _companyIdMeta),
      );
    }
    if (data.containsKey('first_name')) {
      context.handle(
        _firstNameMeta,
        firstName.isAcceptableOrUnknown(data['first_name']!, _firstNameMeta),
      );
    } else if (isInserting) {
      context.missing(_firstNameMeta);
    }
    if (data.containsKey('last_name')) {
      context.handle(
        _lastNameMeta,
        lastName.isAcceptableOrUnknown(data['last_name']!, _lastNameMeta),
      );
    }
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    }
    if (data.containsKey('job_title')) {
      context.handle(
        _jobTitleMeta,
        jobTitle.isAcceptableOrUnknown(data['job_title']!, _jobTitleMeta),
      );
    }
    if (data.containsKey('linkedin_url')) {
      context.handle(
        _linkedinUrlMeta,
        linkedinUrl.isAcceptableOrUnknown(
          data['linkedin_url']!,
          _linkedinUrlMeta,
        ),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('avatar_url')) {
      context.handle(
        _avatarUrlMeta,
        avatarUrl.isAcceptableOrUnknown(data['avatar_url']!, _avatarUrlMeta),
      );
    }
    if (data.containsKey('follow_up_status')) {
      context.handle(
        _followUpStatusMeta,
        followUpStatus.isAcceptableOrUnknown(
          data['follow_up_status']!,
          _followUpStatusMeta,
        ),
      );
    }
    if (data.containsKey('last_contacted_at')) {
      context.handle(
        _lastContactedAtMeta,
        lastContactedAt.isAcceptableOrUnknown(
          data['last_contacted_at']!,
          _lastContactedAtMeta,
        ),
      );
    }
    if (data.containsKey('contact_assets_json')) {
      context.handle(
        _contactAssetsJsonMeta,
        contactAssetsJson.isAcceptableOrUnknown(
          data['contact_assets_json']!,
          _contactAssetsJsonMeta,
        ),
      );
    }
    if (data.containsKey('scanned_details_json')) {
      context.handle(
        _scannedDetailsJsonMeta,
        scannedDetailsJson.isAcceptableOrUnknown(
          data['scanned_details_json']!,
          _scannedDetailsJsonMeta,
        ),
      );
    }
    if (data.containsKey('ai_insights_json')) {
      context.handle(
        _aiInsightsJsonMeta,
        aiInsightsJson.isAcceptableOrUnknown(
          data['ai_insights_json']!,
          _aiInsightsJsonMeta,
        ),
      );
    }
    if (data.containsKey('ai_context_summary')) {
      context.handle(
        _aiContextSummaryMeta,
        aiContextSummary.isAcceptableOrUnknown(
          data['ai_context_summary']!,
          _aiContextSummaryMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ContactsTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ContactsTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      ),
      companyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}company_id'],
      ),
      firstName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}first_name'],
      )!,
      lastName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_name'],
      ),
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      ),
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      ),
      jobTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}job_title'],
      ),
      linkedinUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}linkedin_url'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      avatarUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}avatar_url'],
      ),
      followUpStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}follow_up_status'],
      )!,
      lastContactedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_contacted_at'],
      ),
      contactAssetsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}contact_assets_json'],
      ),
      scannedDetailsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scanned_details_json'],
      ),
      aiInsightsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ai_insights_json'],
      ),
      aiContextSummary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ai_context_summary'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $ContactsTableTable createAlias(String alias) {
    return $ContactsTableTable(attachedDatabase, alias);
  }
}

class ContactsTableData extends DataClass
    implements Insertable<ContactsTableData> {
  final String id;
  final String? userId;
  final String? companyId;
  final String firstName;
  final String? lastName;
  final String? email;
  final String? phone;
  final String? jobTitle;
  final String? linkedinUrl;
  final String? notes;
  final String? avatarUrl;
  final String followUpStatus;
  final DateTime? lastContactedAt;
  final String? contactAssetsJson;
  final String? scannedDetailsJson;
  final String? aiInsightsJson;
  final String? aiContextSummary;
  final DateTime? createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const ContactsTableData({
    required this.id,
    this.userId,
    this.companyId,
    required this.firstName,
    this.lastName,
    this.email,
    this.phone,
    this.jobTitle,
    this.linkedinUrl,
    this.notes,
    this.avatarUrl,
    required this.followUpStatus,
    this.lastContactedAt,
    this.contactAssetsJson,
    this.scannedDetailsJson,
    this.aiInsightsJson,
    this.aiContextSummary,
    this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || userId != null) {
      map['user_id'] = Variable<String>(userId);
    }
    if (!nullToAbsent || companyId != null) {
      map['company_id'] = Variable<String>(companyId);
    }
    map['first_name'] = Variable<String>(firstName);
    if (!nullToAbsent || lastName != null) {
      map['last_name'] = Variable<String>(lastName);
    }
    if (!nullToAbsent || email != null) {
      map['email'] = Variable<String>(email);
    }
    if (!nullToAbsent || phone != null) {
      map['phone'] = Variable<String>(phone);
    }
    if (!nullToAbsent || jobTitle != null) {
      map['job_title'] = Variable<String>(jobTitle);
    }
    if (!nullToAbsent || linkedinUrl != null) {
      map['linkedin_url'] = Variable<String>(linkedinUrl);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || avatarUrl != null) {
      map['avatar_url'] = Variable<String>(avatarUrl);
    }
    map['follow_up_status'] = Variable<String>(followUpStatus);
    if (!nullToAbsent || lastContactedAt != null) {
      map['last_contacted_at'] = Variable<DateTime>(lastContactedAt);
    }
    if (!nullToAbsent || contactAssetsJson != null) {
      map['contact_assets_json'] = Variable<String>(contactAssetsJson);
    }
    if (!nullToAbsent || scannedDetailsJson != null) {
      map['scanned_details_json'] = Variable<String>(scannedDetailsJson);
    }
    if (!nullToAbsent || aiInsightsJson != null) {
      map['ai_insights_json'] = Variable<String>(aiInsightsJson);
    }
    if (!nullToAbsent || aiContextSummary != null) {
      map['ai_context_summary'] = Variable<String>(aiContextSummary);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  ContactsTableCompanion toCompanion(bool nullToAbsent) {
    return ContactsTableCompanion(
      id: Value(id),
      userId: userId == null && nullToAbsent
          ? const Value.absent()
          : Value(userId),
      companyId: companyId == null && nullToAbsent
          ? const Value.absent()
          : Value(companyId),
      firstName: Value(firstName),
      lastName: lastName == null && nullToAbsent
          ? const Value.absent()
          : Value(lastName),
      email: email == null && nullToAbsent
          ? const Value.absent()
          : Value(email),
      phone: phone == null && nullToAbsent
          ? const Value.absent()
          : Value(phone),
      jobTitle: jobTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(jobTitle),
      linkedinUrl: linkedinUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(linkedinUrl),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      avatarUrl: avatarUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(avatarUrl),
      followUpStatus: Value(followUpStatus),
      lastContactedAt: lastContactedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastContactedAt),
      contactAssetsJson: contactAssetsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(contactAssetsJson),
      scannedDetailsJson: scannedDetailsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(scannedDetailsJson),
      aiInsightsJson: aiInsightsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(aiInsightsJson),
      aiContextSummary: aiContextSummary == null && nullToAbsent
          ? const Value.absent()
          : Value(aiContextSummary),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory ContactsTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ContactsTableData(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String?>(json['userId']),
      companyId: serializer.fromJson<String?>(json['companyId']),
      firstName: serializer.fromJson<String>(json['firstName']),
      lastName: serializer.fromJson<String?>(json['lastName']),
      email: serializer.fromJson<String?>(json['email']),
      phone: serializer.fromJson<String?>(json['phone']),
      jobTitle: serializer.fromJson<String?>(json['jobTitle']),
      linkedinUrl: serializer.fromJson<String?>(json['linkedinUrl']),
      notes: serializer.fromJson<String?>(json['notes']),
      avatarUrl: serializer.fromJson<String?>(json['avatarUrl']),
      followUpStatus: serializer.fromJson<String>(json['followUpStatus']),
      lastContactedAt: serializer.fromJson<DateTime?>(json['lastContactedAt']),
      contactAssetsJson: serializer.fromJson<String?>(
        json['contactAssetsJson'],
      ),
      scannedDetailsJson: serializer.fromJson<String?>(
        json['scannedDetailsJson'],
      ),
      aiInsightsJson: serializer.fromJson<String?>(json['aiInsightsJson']),
      aiContextSummary: serializer.fromJson<String?>(json['aiContextSummary']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String?>(userId),
      'companyId': serializer.toJson<String?>(companyId),
      'firstName': serializer.toJson<String>(firstName),
      'lastName': serializer.toJson<String?>(lastName),
      'email': serializer.toJson<String?>(email),
      'phone': serializer.toJson<String?>(phone),
      'jobTitle': serializer.toJson<String?>(jobTitle),
      'linkedinUrl': serializer.toJson<String?>(linkedinUrl),
      'notes': serializer.toJson<String?>(notes),
      'avatarUrl': serializer.toJson<String?>(avatarUrl),
      'followUpStatus': serializer.toJson<String>(followUpStatus),
      'lastContactedAt': serializer.toJson<DateTime?>(lastContactedAt),
      'contactAssetsJson': serializer.toJson<String?>(contactAssetsJson),
      'scannedDetailsJson': serializer.toJson<String?>(scannedDetailsJson),
      'aiInsightsJson': serializer.toJson<String?>(aiInsightsJson),
      'aiContextSummary': serializer.toJson<String?>(aiContextSummary),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  ContactsTableData copyWith({
    String? id,
    Value<String?> userId = const Value.absent(),
    Value<String?> companyId = const Value.absent(),
    String? firstName,
    Value<String?> lastName = const Value.absent(),
    Value<String?> email = const Value.absent(),
    Value<String?> phone = const Value.absent(),
    Value<String?> jobTitle = const Value.absent(),
    Value<String?> linkedinUrl = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    Value<String?> avatarUrl = const Value.absent(),
    String? followUpStatus,
    Value<DateTime?> lastContactedAt = const Value.absent(),
    Value<String?> contactAssetsJson = const Value.absent(),
    Value<String?> scannedDetailsJson = const Value.absent(),
    Value<String?> aiInsightsJson = const Value.absent(),
    Value<String?> aiContextSummary = const Value.absent(),
    Value<DateTime?> createdAt = const Value.absent(),
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => ContactsTableData(
    id: id ?? this.id,
    userId: userId.present ? userId.value : this.userId,
    companyId: companyId.present ? companyId.value : this.companyId,
    firstName: firstName ?? this.firstName,
    lastName: lastName.present ? lastName.value : this.lastName,
    email: email.present ? email.value : this.email,
    phone: phone.present ? phone.value : this.phone,
    jobTitle: jobTitle.present ? jobTitle.value : this.jobTitle,
    linkedinUrl: linkedinUrl.present ? linkedinUrl.value : this.linkedinUrl,
    notes: notes.present ? notes.value : this.notes,
    avatarUrl: avatarUrl.present ? avatarUrl.value : this.avatarUrl,
    followUpStatus: followUpStatus ?? this.followUpStatus,
    lastContactedAt: lastContactedAt.present
        ? lastContactedAt.value
        : this.lastContactedAt,
    contactAssetsJson: contactAssetsJson.present
        ? contactAssetsJson.value
        : this.contactAssetsJson,
    scannedDetailsJson: scannedDetailsJson.present
        ? scannedDetailsJson.value
        : this.scannedDetailsJson,
    aiInsightsJson: aiInsightsJson.present
        ? aiInsightsJson.value
        : this.aiInsightsJson,
    aiContextSummary: aiContextSummary.present
        ? aiContextSummary.value
        : this.aiContextSummary,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  ContactsTableData copyWithCompanion(ContactsTableCompanion data) {
    return ContactsTableData(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      companyId: data.companyId.present ? data.companyId.value : this.companyId,
      firstName: data.firstName.present ? data.firstName.value : this.firstName,
      lastName: data.lastName.present ? data.lastName.value : this.lastName,
      email: data.email.present ? data.email.value : this.email,
      phone: data.phone.present ? data.phone.value : this.phone,
      jobTitle: data.jobTitle.present ? data.jobTitle.value : this.jobTitle,
      linkedinUrl: data.linkedinUrl.present
          ? data.linkedinUrl.value
          : this.linkedinUrl,
      notes: data.notes.present ? data.notes.value : this.notes,
      avatarUrl: data.avatarUrl.present ? data.avatarUrl.value : this.avatarUrl,
      followUpStatus: data.followUpStatus.present
          ? data.followUpStatus.value
          : this.followUpStatus,
      lastContactedAt: data.lastContactedAt.present
          ? data.lastContactedAt.value
          : this.lastContactedAt,
      contactAssetsJson: data.contactAssetsJson.present
          ? data.contactAssetsJson.value
          : this.contactAssetsJson,
      scannedDetailsJson: data.scannedDetailsJson.present
          ? data.scannedDetailsJson.value
          : this.scannedDetailsJson,
      aiInsightsJson: data.aiInsightsJson.present
          ? data.aiInsightsJson.value
          : this.aiInsightsJson,
      aiContextSummary: data.aiContextSummary.present
          ? data.aiContextSummary.value
          : this.aiContextSummary,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ContactsTableData(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('companyId: $companyId, ')
          ..write('firstName: $firstName, ')
          ..write('lastName: $lastName, ')
          ..write('email: $email, ')
          ..write('phone: $phone, ')
          ..write('jobTitle: $jobTitle, ')
          ..write('linkedinUrl: $linkedinUrl, ')
          ..write('notes: $notes, ')
          ..write('avatarUrl: $avatarUrl, ')
          ..write('followUpStatus: $followUpStatus, ')
          ..write('lastContactedAt: $lastContactedAt, ')
          ..write('contactAssetsJson: $contactAssetsJson, ')
          ..write('scannedDetailsJson: $scannedDetailsJson, ')
          ..write('aiInsightsJson: $aiInsightsJson, ')
          ..write('aiContextSummary: $aiContextSummary, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    companyId,
    firstName,
    lastName,
    email,
    phone,
    jobTitle,
    linkedinUrl,
    notes,
    avatarUrl,
    followUpStatus,
    lastContactedAt,
    contactAssetsJson,
    scannedDetailsJson,
    aiInsightsJson,
    aiContextSummary,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContactsTableData &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.companyId == this.companyId &&
          other.firstName == this.firstName &&
          other.lastName == this.lastName &&
          other.email == this.email &&
          other.phone == this.phone &&
          other.jobTitle == this.jobTitle &&
          other.linkedinUrl == this.linkedinUrl &&
          other.notes == this.notes &&
          other.avatarUrl == this.avatarUrl &&
          other.followUpStatus == this.followUpStatus &&
          other.lastContactedAt == this.lastContactedAt &&
          other.contactAssetsJson == this.contactAssetsJson &&
          other.scannedDetailsJson == this.scannedDetailsJson &&
          other.aiInsightsJson == this.aiInsightsJson &&
          other.aiContextSummary == this.aiContextSummary &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class ContactsTableCompanion extends UpdateCompanion<ContactsTableData> {
  final Value<String> id;
  final Value<String?> userId;
  final Value<String?> companyId;
  final Value<String> firstName;
  final Value<String?> lastName;
  final Value<String?> email;
  final Value<String?> phone;
  final Value<String?> jobTitle;
  final Value<String?> linkedinUrl;
  final Value<String?> notes;
  final Value<String?> avatarUrl;
  final Value<String> followUpStatus;
  final Value<DateTime?> lastContactedAt;
  final Value<String?> contactAssetsJson;
  final Value<String?> scannedDetailsJson;
  final Value<String?> aiInsightsJson;
  final Value<String?> aiContextSummary;
  final Value<DateTime?> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const ContactsTableCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.companyId = const Value.absent(),
    this.firstName = const Value.absent(),
    this.lastName = const Value.absent(),
    this.email = const Value.absent(),
    this.phone = const Value.absent(),
    this.jobTitle = const Value.absent(),
    this.linkedinUrl = const Value.absent(),
    this.notes = const Value.absent(),
    this.avatarUrl = const Value.absent(),
    this.followUpStatus = const Value.absent(),
    this.lastContactedAt = const Value.absent(),
    this.contactAssetsJson = const Value.absent(),
    this.scannedDetailsJson = const Value.absent(),
    this.aiInsightsJson = const Value.absent(),
    this.aiContextSummary = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ContactsTableCompanion.insert({
    required String id,
    this.userId = const Value.absent(),
    this.companyId = const Value.absent(),
    required String firstName,
    this.lastName = const Value.absent(),
    this.email = const Value.absent(),
    this.phone = const Value.absent(),
    this.jobTitle = const Value.absent(),
    this.linkedinUrl = const Value.absent(),
    this.notes = const Value.absent(),
    this.avatarUrl = const Value.absent(),
    this.followUpStatus = const Value.absent(),
    this.lastContactedAt = const Value.absent(),
    this.contactAssetsJson = const Value.absent(),
    this.scannedDetailsJson = const Value.absent(),
    this.aiInsightsJson = const Value.absent(),
    this.aiContextSummary = const Value.absent(),
    this.createdAt = const Value.absent(),
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       firstName = Value(firstName),
       updatedAt = Value(updatedAt);
  static Insertable<ContactsTableData> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? companyId,
    Expression<String>? firstName,
    Expression<String>? lastName,
    Expression<String>? email,
    Expression<String>? phone,
    Expression<String>? jobTitle,
    Expression<String>? linkedinUrl,
    Expression<String>? notes,
    Expression<String>? avatarUrl,
    Expression<String>? followUpStatus,
    Expression<DateTime>? lastContactedAt,
    Expression<String>? contactAssetsJson,
    Expression<String>? scannedDetailsJson,
    Expression<String>? aiInsightsJson,
    Expression<String>? aiContextSummary,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (companyId != null) 'company_id': companyId,
      if (firstName != null) 'first_name': firstName,
      if (lastName != null) 'last_name': lastName,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (jobTitle != null) 'job_title': jobTitle,
      if (linkedinUrl != null) 'linkedin_url': linkedinUrl,
      if (notes != null) 'notes': notes,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (followUpStatus != null) 'follow_up_status': followUpStatus,
      if (lastContactedAt != null) 'last_contacted_at': lastContactedAt,
      if (contactAssetsJson != null) 'contact_assets_json': contactAssetsJson,
      if (scannedDetailsJson != null)
        'scanned_details_json': scannedDetailsJson,
      if (aiInsightsJson != null) 'ai_insights_json': aiInsightsJson,
      if (aiContextSummary != null) 'ai_context_summary': aiContextSummary,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ContactsTableCompanion copyWith({
    Value<String>? id,
    Value<String?>? userId,
    Value<String?>? companyId,
    Value<String>? firstName,
    Value<String?>? lastName,
    Value<String?>? email,
    Value<String?>? phone,
    Value<String?>? jobTitle,
    Value<String?>? linkedinUrl,
    Value<String?>? notes,
    Value<String?>? avatarUrl,
    Value<String>? followUpStatus,
    Value<DateTime?>? lastContactedAt,
    Value<String?>? contactAssetsJson,
    Value<String?>? scannedDetailsJson,
    Value<String?>? aiInsightsJson,
    Value<String?>? aiContextSummary,
    Value<DateTime?>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return ContactsTableCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      companyId: companyId ?? this.companyId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      jobTitle: jobTitle ?? this.jobTitle,
      linkedinUrl: linkedinUrl ?? this.linkedinUrl,
      notes: notes ?? this.notes,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      followUpStatus: followUpStatus ?? this.followUpStatus,
      lastContactedAt: lastContactedAt ?? this.lastContactedAt,
      contactAssetsJson: contactAssetsJson ?? this.contactAssetsJson,
      scannedDetailsJson: scannedDetailsJson ?? this.scannedDetailsJson,
      aiInsightsJson: aiInsightsJson ?? this.aiInsightsJson,
      aiContextSummary: aiContextSummary ?? this.aiContextSummary,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (companyId.present) {
      map['company_id'] = Variable<String>(companyId.value);
    }
    if (firstName.present) {
      map['first_name'] = Variable<String>(firstName.value);
    }
    if (lastName.present) {
      map['last_name'] = Variable<String>(lastName.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (jobTitle.present) {
      map['job_title'] = Variable<String>(jobTitle.value);
    }
    if (linkedinUrl.present) {
      map['linkedin_url'] = Variable<String>(linkedinUrl.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (avatarUrl.present) {
      map['avatar_url'] = Variable<String>(avatarUrl.value);
    }
    if (followUpStatus.present) {
      map['follow_up_status'] = Variable<String>(followUpStatus.value);
    }
    if (lastContactedAt.present) {
      map['last_contacted_at'] = Variable<DateTime>(lastContactedAt.value);
    }
    if (contactAssetsJson.present) {
      map['contact_assets_json'] = Variable<String>(contactAssetsJson.value);
    }
    if (scannedDetailsJson.present) {
      map['scanned_details_json'] = Variable<String>(scannedDetailsJson.value);
    }
    if (aiInsightsJson.present) {
      map['ai_insights_json'] = Variable<String>(aiInsightsJson.value);
    }
    if (aiContextSummary.present) {
      map['ai_context_summary'] = Variable<String>(aiContextSummary.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ContactsTableCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('companyId: $companyId, ')
          ..write('firstName: $firstName, ')
          ..write('lastName: $lastName, ')
          ..write('email: $email, ')
          ..write('phone: $phone, ')
          ..write('jobTitle: $jobTitle, ')
          ..write('linkedinUrl: $linkedinUrl, ')
          ..write('notes: $notes, ')
          ..write('avatarUrl: $avatarUrl, ')
          ..write('followUpStatus: $followUpStatus, ')
          ..write('lastContactedAt: $lastContactedAt, ')
          ..write('contactAssetsJson: $contactAssetsJson, ')
          ..write('scannedDetailsJson: $scannedDetailsJson, ')
          ..write('aiInsightsJson: $aiInsightsJson, ')
          ..write('aiContextSummary: $aiContextSummary, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CapturesTableTable extends CapturesTable
    with TableInfo<$CapturesTableTable, CapturesTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CapturesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _eventIdMeta = const VerificationMeta(
    'eventId',
  );
  @override
  late final GeneratedColumn<String> eventId = GeneratedColumn<String>(
    'event_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contactIdMeta = const VerificationMeta(
    'contactId',
  );
  @override
  late final GeneratedColumn<String> contactId = GeneratedColumn<String>(
    'contact_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _captureTypeMeta = const VerificationMeta(
    'captureType',
  );
  @override
  late final GeneratedColumn<String> captureType = GeneratedColumn<String>(
    'capture_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _imageUrlMeta = const VerificationMeta(
    'imageUrl',
  );
  @override
  late final GeneratedColumn<String> imageUrl = GeneratedColumn<String>(
    'image_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rawDataJsonMeta = const VerificationMeta(
    'rawDataJson',
  );
  @override
  late final GeneratedColumn<String> rawDataJson = GeneratedColumn<String>(
    'raw_data_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _extractedDataJsonMeta = const VerificationMeta(
    'extractedDataJson',
  );
  @override
  late final GeneratedColumn<String> extractedDataJson =
      GeneratedColumn<String>(
        'extracted_data_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _clientOpIdMeta = const VerificationMeta(
    'clientOpId',
  );
  @override
  late final GeneratedColumn<String> clientOpId = GeneratedColumn<String>(
    'client_op_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    eventId,
    contactId,
    captureType,
    imageUrl,
    rawDataJson,
    extractedDataJson,
    status,
    clientOpId,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'captures';
  @override
  VerificationContext validateIntegrity(
    Insertable<CapturesTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    }
    if (data.containsKey('event_id')) {
      context.handle(
        _eventIdMeta,
        eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta),
      );
    }
    if (data.containsKey('contact_id')) {
      context.handle(
        _contactIdMeta,
        contactId.isAcceptableOrUnknown(data['contact_id']!, _contactIdMeta),
      );
    }
    if (data.containsKey('capture_type')) {
      context.handle(
        _captureTypeMeta,
        captureType.isAcceptableOrUnknown(
          data['capture_type']!,
          _captureTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_captureTypeMeta);
    }
    if (data.containsKey('image_url')) {
      context.handle(
        _imageUrlMeta,
        imageUrl.isAcceptableOrUnknown(data['image_url']!, _imageUrlMeta),
      );
    }
    if (data.containsKey('raw_data_json')) {
      context.handle(
        _rawDataJsonMeta,
        rawDataJson.isAcceptableOrUnknown(
          data['raw_data_json']!,
          _rawDataJsonMeta,
        ),
      );
    }
    if (data.containsKey('extracted_data_json')) {
      context.handle(
        _extractedDataJsonMeta,
        extractedDataJson.isAcceptableOrUnknown(
          data['extracted_data_json']!,
          _extractedDataJsonMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('client_op_id')) {
      context.handle(
        _clientOpIdMeta,
        clientOpId.isAcceptableOrUnknown(
          data['client_op_id']!,
          _clientOpIdMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CapturesTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CapturesTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      ),
      eventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_id'],
      ),
      contactId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}contact_id'],
      ),
      captureType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}capture_type'],
      )!,
      imageUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_url'],
      ),
      rawDataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_data_json'],
      ),
      extractedDataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}extracted_data_json'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      clientOpId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_op_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $CapturesTableTable createAlias(String alias) {
    return $CapturesTableTable(attachedDatabase, alias);
  }
}

class CapturesTableData extends DataClass
    implements Insertable<CapturesTableData> {
  final String id;
  final String? userId;
  final String? eventId;
  final String? contactId;
  final String captureType;
  final String? imageUrl;
  final String? rawDataJson;
  final String? extractedDataJson;
  final String status;
  final String? clientOpId;
  final DateTime? createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const CapturesTableData({
    required this.id,
    this.userId,
    this.eventId,
    this.contactId,
    required this.captureType,
    this.imageUrl,
    this.rawDataJson,
    this.extractedDataJson,
    required this.status,
    this.clientOpId,
    this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || userId != null) {
      map['user_id'] = Variable<String>(userId);
    }
    if (!nullToAbsent || eventId != null) {
      map['event_id'] = Variable<String>(eventId);
    }
    if (!nullToAbsent || contactId != null) {
      map['contact_id'] = Variable<String>(contactId);
    }
    map['capture_type'] = Variable<String>(captureType);
    if (!nullToAbsent || imageUrl != null) {
      map['image_url'] = Variable<String>(imageUrl);
    }
    if (!nullToAbsent || rawDataJson != null) {
      map['raw_data_json'] = Variable<String>(rawDataJson);
    }
    if (!nullToAbsent || extractedDataJson != null) {
      map['extracted_data_json'] = Variable<String>(extractedDataJson);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || clientOpId != null) {
      map['client_op_id'] = Variable<String>(clientOpId);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  CapturesTableCompanion toCompanion(bool nullToAbsent) {
    return CapturesTableCompanion(
      id: Value(id),
      userId: userId == null && nullToAbsent
          ? const Value.absent()
          : Value(userId),
      eventId: eventId == null && nullToAbsent
          ? const Value.absent()
          : Value(eventId),
      contactId: contactId == null && nullToAbsent
          ? const Value.absent()
          : Value(contactId),
      captureType: Value(captureType),
      imageUrl: imageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(imageUrl),
      rawDataJson: rawDataJson == null && nullToAbsent
          ? const Value.absent()
          : Value(rawDataJson),
      extractedDataJson: extractedDataJson == null && nullToAbsent
          ? const Value.absent()
          : Value(extractedDataJson),
      status: Value(status),
      clientOpId: clientOpId == null && nullToAbsent
          ? const Value.absent()
          : Value(clientOpId),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory CapturesTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CapturesTableData(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String?>(json['userId']),
      eventId: serializer.fromJson<String?>(json['eventId']),
      contactId: serializer.fromJson<String?>(json['contactId']),
      captureType: serializer.fromJson<String>(json['captureType']),
      imageUrl: serializer.fromJson<String?>(json['imageUrl']),
      rawDataJson: serializer.fromJson<String?>(json['rawDataJson']),
      extractedDataJson: serializer.fromJson<String?>(
        json['extractedDataJson'],
      ),
      status: serializer.fromJson<String>(json['status']),
      clientOpId: serializer.fromJson<String?>(json['clientOpId']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String?>(userId),
      'eventId': serializer.toJson<String?>(eventId),
      'contactId': serializer.toJson<String?>(contactId),
      'captureType': serializer.toJson<String>(captureType),
      'imageUrl': serializer.toJson<String?>(imageUrl),
      'rawDataJson': serializer.toJson<String?>(rawDataJson),
      'extractedDataJson': serializer.toJson<String?>(extractedDataJson),
      'status': serializer.toJson<String>(status),
      'clientOpId': serializer.toJson<String?>(clientOpId),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  CapturesTableData copyWith({
    String? id,
    Value<String?> userId = const Value.absent(),
    Value<String?> eventId = const Value.absent(),
    Value<String?> contactId = const Value.absent(),
    String? captureType,
    Value<String?> imageUrl = const Value.absent(),
    Value<String?> rawDataJson = const Value.absent(),
    Value<String?> extractedDataJson = const Value.absent(),
    String? status,
    Value<String?> clientOpId = const Value.absent(),
    Value<DateTime?> createdAt = const Value.absent(),
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => CapturesTableData(
    id: id ?? this.id,
    userId: userId.present ? userId.value : this.userId,
    eventId: eventId.present ? eventId.value : this.eventId,
    contactId: contactId.present ? contactId.value : this.contactId,
    captureType: captureType ?? this.captureType,
    imageUrl: imageUrl.present ? imageUrl.value : this.imageUrl,
    rawDataJson: rawDataJson.present ? rawDataJson.value : this.rawDataJson,
    extractedDataJson: extractedDataJson.present
        ? extractedDataJson.value
        : this.extractedDataJson,
    status: status ?? this.status,
    clientOpId: clientOpId.present ? clientOpId.value : this.clientOpId,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  CapturesTableData copyWithCompanion(CapturesTableCompanion data) {
    return CapturesTableData(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      contactId: data.contactId.present ? data.contactId.value : this.contactId,
      captureType: data.captureType.present
          ? data.captureType.value
          : this.captureType,
      imageUrl: data.imageUrl.present ? data.imageUrl.value : this.imageUrl,
      rawDataJson: data.rawDataJson.present
          ? data.rawDataJson.value
          : this.rawDataJson,
      extractedDataJson: data.extractedDataJson.present
          ? data.extractedDataJson.value
          : this.extractedDataJson,
      status: data.status.present ? data.status.value : this.status,
      clientOpId: data.clientOpId.present
          ? data.clientOpId.value
          : this.clientOpId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CapturesTableData(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('eventId: $eventId, ')
          ..write('contactId: $contactId, ')
          ..write('captureType: $captureType, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('rawDataJson: $rawDataJson, ')
          ..write('extractedDataJson: $extractedDataJson, ')
          ..write('status: $status, ')
          ..write('clientOpId: $clientOpId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    eventId,
    contactId,
    captureType,
    imageUrl,
    rawDataJson,
    extractedDataJson,
    status,
    clientOpId,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CapturesTableData &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.eventId == this.eventId &&
          other.contactId == this.contactId &&
          other.captureType == this.captureType &&
          other.imageUrl == this.imageUrl &&
          other.rawDataJson == this.rawDataJson &&
          other.extractedDataJson == this.extractedDataJson &&
          other.status == this.status &&
          other.clientOpId == this.clientOpId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class CapturesTableCompanion extends UpdateCompanion<CapturesTableData> {
  final Value<String> id;
  final Value<String?> userId;
  final Value<String?> eventId;
  final Value<String?> contactId;
  final Value<String> captureType;
  final Value<String?> imageUrl;
  final Value<String?> rawDataJson;
  final Value<String?> extractedDataJson;
  final Value<String> status;
  final Value<String?> clientOpId;
  final Value<DateTime?> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const CapturesTableCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.eventId = const Value.absent(),
    this.contactId = const Value.absent(),
    this.captureType = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.rawDataJson = const Value.absent(),
    this.extractedDataJson = const Value.absent(),
    this.status = const Value.absent(),
    this.clientOpId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CapturesTableCompanion.insert({
    required String id,
    this.userId = const Value.absent(),
    this.eventId = const Value.absent(),
    this.contactId = const Value.absent(),
    required String captureType,
    this.imageUrl = const Value.absent(),
    this.rawDataJson = const Value.absent(),
    this.extractedDataJson = const Value.absent(),
    this.status = const Value.absent(),
    this.clientOpId = const Value.absent(),
    this.createdAt = const Value.absent(),
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       captureType = Value(captureType),
       updatedAt = Value(updatedAt);
  static Insertable<CapturesTableData> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? eventId,
    Expression<String>? contactId,
    Expression<String>? captureType,
    Expression<String>? imageUrl,
    Expression<String>? rawDataJson,
    Expression<String>? extractedDataJson,
    Expression<String>? status,
    Expression<String>? clientOpId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (eventId != null) 'event_id': eventId,
      if (contactId != null) 'contact_id': contactId,
      if (captureType != null) 'capture_type': captureType,
      if (imageUrl != null) 'image_url': imageUrl,
      if (rawDataJson != null) 'raw_data_json': rawDataJson,
      if (extractedDataJson != null) 'extracted_data_json': extractedDataJson,
      if (status != null) 'status': status,
      if (clientOpId != null) 'client_op_id': clientOpId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CapturesTableCompanion copyWith({
    Value<String>? id,
    Value<String?>? userId,
    Value<String?>? eventId,
    Value<String?>? contactId,
    Value<String>? captureType,
    Value<String?>? imageUrl,
    Value<String?>? rawDataJson,
    Value<String?>? extractedDataJson,
    Value<String>? status,
    Value<String?>? clientOpId,
    Value<DateTime?>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return CapturesTableCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      eventId: eventId ?? this.eventId,
      contactId: contactId ?? this.contactId,
      captureType: captureType ?? this.captureType,
      imageUrl: imageUrl ?? this.imageUrl,
      rawDataJson: rawDataJson ?? this.rawDataJson,
      extractedDataJson: extractedDataJson ?? this.extractedDataJson,
      status: status ?? this.status,
      clientOpId: clientOpId ?? this.clientOpId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (eventId.present) {
      map['event_id'] = Variable<String>(eventId.value);
    }
    if (contactId.present) {
      map['contact_id'] = Variable<String>(contactId.value);
    }
    if (captureType.present) {
      map['capture_type'] = Variable<String>(captureType.value);
    }
    if (imageUrl.present) {
      map['image_url'] = Variable<String>(imageUrl.value);
    }
    if (rawDataJson.present) {
      map['raw_data_json'] = Variable<String>(rawDataJson.value);
    }
    if (extractedDataJson.present) {
      map['extracted_data_json'] = Variable<String>(extractedDataJson.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (clientOpId.present) {
      map['client_op_id'] = Variable<String>(clientOpId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CapturesTableCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('eventId: $eventId, ')
          ..write('contactId: $contactId, ')
          ..write('captureType: $captureType, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('rawDataJson: $rawDataJson, ')
          ..write('extractedDataJson: $extractedDataJson, ')
          ..write('status: $status, ')
          ..write('clientOpId: $clientOpId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TargetCompaniesTableTable extends TargetCompaniesTable
    with TableInfo<$TargetCompaniesTableTable, TargetCompaniesTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TargetCompaniesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _eventIdMeta = const VerificationMeta(
    'eventId',
  );
  @override
  late final GeneratedColumn<String> eventId = GeneratedColumn<String>(
    'event_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _companyIdMeta = const VerificationMeta(
    'companyId',
  );
  @override
  late final GeneratedColumn<String> companyId = GeneratedColumn<String>(
    'company_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<String> priority = GeneratedColumn<String>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('medium'),
  );
  static const VerificationMeta _boothLocationMeta = const VerificationMeta(
    'boothLocation',
  );
  @override
  late final GeneratedColumn<String> boothLocation = GeneratedColumn<String>(
    'booth_location',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _talkingPointsMeta = const VerificationMeta(
    'talkingPoints',
  );
  @override
  late final GeneratedColumn<String> talkingPoints = GeneratedColumn<String>(
    'talking_points',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('not_contacted'),
  );
  static const VerificationMeta _useNotesForBriefingMeta =
      const VerificationMeta('useNotesForBriefing');
  @override
  late final GeneratedColumn<bool> useNotesForBriefing = GeneratedColumn<bool>(
    'use_notes_for_briefing',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("use_notes_for_briefing" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    eventId,
    companyId,
    priority,
    boothLocation,
    talkingPoints,
    notes,
    status,
    useNotesForBriefing,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'target_companies';
  @override
  VerificationContext validateIntegrity(
    Insertable<TargetCompaniesTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    }
    if (data.containsKey('event_id')) {
      context.handle(
        _eventIdMeta,
        eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta),
      );
    }
    if (data.containsKey('company_id')) {
      context.handle(
        _companyIdMeta,
        companyId.isAcceptableOrUnknown(data['company_id']!, _companyIdMeta),
      );
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    }
    if (data.containsKey('booth_location')) {
      context.handle(
        _boothLocationMeta,
        boothLocation.isAcceptableOrUnknown(
          data['booth_location']!,
          _boothLocationMeta,
        ),
      );
    }
    if (data.containsKey('talking_points')) {
      context.handle(
        _talkingPointsMeta,
        talkingPoints.isAcceptableOrUnknown(
          data['talking_points']!,
          _talkingPointsMeta,
        ),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('use_notes_for_briefing')) {
      context.handle(
        _useNotesForBriefingMeta,
        useNotesForBriefing.isAcceptableOrUnknown(
          data['use_notes_for_briefing']!,
          _useNotesForBriefingMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TargetCompaniesTableData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TargetCompaniesTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      ),
      eventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_id'],
      ),
      companyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}company_id'],
      ),
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}priority'],
      )!,
      boothLocation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}booth_location'],
      ),
      talkingPoints: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}talking_points'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      useNotesForBriefing: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}use_notes_for_briefing'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $TargetCompaniesTableTable createAlias(String alias) {
    return $TargetCompaniesTableTable(attachedDatabase, alias);
  }
}

class TargetCompaniesTableData extends DataClass
    implements Insertable<TargetCompaniesTableData> {
  final String id;
  final String? userId;
  final String? eventId;
  final String? companyId;
  final String priority;
  final String? boothLocation;
  final String? talkingPoints;
  final String? notes;
  final String status;
  final bool useNotesForBriefing;
  final DateTime? createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const TargetCompaniesTableData({
    required this.id,
    this.userId,
    this.eventId,
    this.companyId,
    required this.priority,
    this.boothLocation,
    this.talkingPoints,
    this.notes,
    required this.status,
    required this.useNotesForBriefing,
    this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || userId != null) {
      map['user_id'] = Variable<String>(userId);
    }
    if (!nullToAbsent || eventId != null) {
      map['event_id'] = Variable<String>(eventId);
    }
    if (!nullToAbsent || companyId != null) {
      map['company_id'] = Variable<String>(companyId);
    }
    map['priority'] = Variable<String>(priority);
    if (!nullToAbsent || boothLocation != null) {
      map['booth_location'] = Variable<String>(boothLocation);
    }
    if (!nullToAbsent || talkingPoints != null) {
      map['talking_points'] = Variable<String>(talkingPoints);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['status'] = Variable<String>(status);
    map['use_notes_for_briefing'] = Variable<bool>(useNotesForBriefing);
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  TargetCompaniesTableCompanion toCompanion(bool nullToAbsent) {
    return TargetCompaniesTableCompanion(
      id: Value(id),
      userId: userId == null && nullToAbsent
          ? const Value.absent()
          : Value(userId),
      eventId: eventId == null && nullToAbsent
          ? const Value.absent()
          : Value(eventId),
      companyId: companyId == null && nullToAbsent
          ? const Value.absent()
          : Value(companyId),
      priority: Value(priority),
      boothLocation: boothLocation == null && nullToAbsent
          ? const Value.absent()
          : Value(boothLocation),
      talkingPoints: talkingPoints == null && nullToAbsent
          ? const Value.absent()
          : Value(talkingPoints),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      status: Value(status),
      useNotesForBriefing: Value(useNotesForBriefing),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory TargetCompaniesTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TargetCompaniesTableData(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String?>(json['userId']),
      eventId: serializer.fromJson<String?>(json['eventId']),
      companyId: serializer.fromJson<String?>(json['companyId']),
      priority: serializer.fromJson<String>(json['priority']),
      boothLocation: serializer.fromJson<String?>(json['boothLocation']),
      talkingPoints: serializer.fromJson<String?>(json['talkingPoints']),
      notes: serializer.fromJson<String?>(json['notes']),
      status: serializer.fromJson<String>(json['status']),
      useNotesForBriefing: serializer.fromJson<bool>(
        json['useNotesForBriefing'],
      ),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String?>(userId),
      'eventId': serializer.toJson<String?>(eventId),
      'companyId': serializer.toJson<String?>(companyId),
      'priority': serializer.toJson<String>(priority),
      'boothLocation': serializer.toJson<String?>(boothLocation),
      'talkingPoints': serializer.toJson<String?>(talkingPoints),
      'notes': serializer.toJson<String?>(notes),
      'status': serializer.toJson<String>(status),
      'useNotesForBriefing': serializer.toJson<bool>(useNotesForBriefing),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  TargetCompaniesTableData copyWith({
    String? id,
    Value<String?> userId = const Value.absent(),
    Value<String?> eventId = const Value.absent(),
    Value<String?> companyId = const Value.absent(),
    String? priority,
    Value<String?> boothLocation = const Value.absent(),
    Value<String?> talkingPoints = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    String? status,
    bool? useNotesForBriefing,
    Value<DateTime?> createdAt = const Value.absent(),
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => TargetCompaniesTableData(
    id: id ?? this.id,
    userId: userId.present ? userId.value : this.userId,
    eventId: eventId.present ? eventId.value : this.eventId,
    companyId: companyId.present ? companyId.value : this.companyId,
    priority: priority ?? this.priority,
    boothLocation: boothLocation.present
        ? boothLocation.value
        : this.boothLocation,
    talkingPoints: talkingPoints.present
        ? talkingPoints.value
        : this.talkingPoints,
    notes: notes.present ? notes.value : this.notes,
    status: status ?? this.status,
    useNotesForBriefing: useNotesForBriefing ?? this.useNotesForBriefing,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  TargetCompaniesTableData copyWithCompanion(
    TargetCompaniesTableCompanion data,
  ) {
    return TargetCompaniesTableData(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      companyId: data.companyId.present ? data.companyId.value : this.companyId,
      priority: data.priority.present ? data.priority.value : this.priority,
      boothLocation: data.boothLocation.present
          ? data.boothLocation.value
          : this.boothLocation,
      talkingPoints: data.talkingPoints.present
          ? data.talkingPoints.value
          : this.talkingPoints,
      notes: data.notes.present ? data.notes.value : this.notes,
      status: data.status.present ? data.status.value : this.status,
      useNotesForBriefing: data.useNotesForBriefing.present
          ? data.useNotesForBriefing.value
          : this.useNotesForBriefing,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TargetCompaniesTableData(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('eventId: $eventId, ')
          ..write('companyId: $companyId, ')
          ..write('priority: $priority, ')
          ..write('boothLocation: $boothLocation, ')
          ..write('talkingPoints: $talkingPoints, ')
          ..write('notes: $notes, ')
          ..write('status: $status, ')
          ..write('useNotesForBriefing: $useNotesForBriefing, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    eventId,
    companyId,
    priority,
    boothLocation,
    talkingPoints,
    notes,
    status,
    useNotesForBriefing,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TargetCompaniesTableData &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.eventId == this.eventId &&
          other.companyId == this.companyId &&
          other.priority == this.priority &&
          other.boothLocation == this.boothLocation &&
          other.talkingPoints == this.talkingPoints &&
          other.notes == this.notes &&
          other.status == this.status &&
          other.useNotesForBriefing == this.useNotesForBriefing &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class TargetCompaniesTableCompanion
    extends UpdateCompanion<TargetCompaniesTableData> {
  final Value<String> id;
  final Value<String?> userId;
  final Value<String?> eventId;
  final Value<String?> companyId;
  final Value<String> priority;
  final Value<String?> boothLocation;
  final Value<String?> talkingPoints;
  final Value<String?> notes;
  final Value<String> status;
  final Value<bool> useNotesForBriefing;
  final Value<DateTime?> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const TargetCompaniesTableCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.eventId = const Value.absent(),
    this.companyId = const Value.absent(),
    this.priority = const Value.absent(),
    this.boothLocation = const Value.absent(),
    this.talkingPoints = const Value.absent(),
    this.notes = const Value.absent(),
    this.status = const Value.absent(),
    this.useNotesForBriefing = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TargetCompaniesTableCompanion.insert({
    required String id,
    this.userId = const Value.absent(),
    this.eventId = const Value.absent(),
    this.companyId = const Value.absent(),
    this.priority = const Value.absent(),
    this.boothLocation = const Value.absent(),
    this.talkingPoints = const Value.absent(),
    this.notes = const Value.absent(),
    this.status = const Value.absent(),
    this.useNotesForBriefing = const Value.absent(),
    this.createdAt = const Value.absent(),
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       updatedAt = Value(updatedAt);
  static Insertable<TargetCompaniesTableData> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? eventId,
    Expression<String>? companyId,
    Expression<String>? priority,
    Expression<String>? boothLocation,
    Expression<String>? talkingPoints,
    Expression<String>? notes,
    Expression<String>? status,
    Expression<bool>? useNotesForBriefing,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (eventId != null) 'event_id': eventId,
      if (companyId != null) 'company_id': companyId,
      if (priority != null) 'priority': priority,
      if (boothLocation != null) 'booth_location': boothLocation,
      if (talkingPoints != null) 'talking_points': talkingPoints,
      if (notes != null) 'notes': notes,
      if (status != null) 'status': status,
      if (useNotesForBriefing != null)
        'use_notes_for_briefing': useNotesForBriefing,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TargetCompaniesTableCompanion copyWith({
    Value<String>? id,
    Value<String?>? userId,
    Value<String?>? eventId,
    Value<String?>? companyId,
    Value<String>? priority,
    Value<String?>? boothLocation,
    Value<String?>? talkingPoints,
    Value<String?>? notes,
    Value<String>? status,
    Value<bool>? useNotesForBriefing,
    Value<DateTime?>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return TargetCompaniesTableCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      eventId: eventId ?? this.eventId,
      companyId: companyId ?? this.companyId,
      priority: priority ?? this.priority,
      boothLocation: boothLocation ?? this.boothLocation,
      talkingPoints: talkingPoints ?? this.talkingPoints,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      useNotesForBriefing: useNotesForBriefing ?? this.useNotesForBriefing,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (eventId.present) {
      map['event_id'] = Variable<String>(eventId.value);
    }
    if (companyId.present) {
      map['company_id'] = Variable<String>(companyId.value);
    }
    if (priority.present) {
      map['priority'] = Variable<String>(priority.value);
    }
    if (boothLocation.present) {
      map['booth_location'] = Variable<String>(boothLocation.value);
    }
    if (talkingPoints.present) {
      map['talking_points'] = Variable<String>(talkingPoints.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (useNotesForBriefing.present) {
      map['use_notes_for_briefing'] = Variable<bool>(useNotesForBriefing.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TargetCompaniesTableCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('eventId: $eventId, ')
          ..write('companyId: $companyId, ')
          ..write('priority: $priority, ')
          ..write('boothLocation: $boothLocation, ')
          ..write('talkingPoints: $talkingPoints, ')
          ..write('notes: $notes, ')
          ..write('status: $status, ')
          ..write('useNotesForBriefing: $useNotesForBriefing, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ContactEventsTableTable extends ContactEventsTable
    with TableInfo<$ContactEventsTableTable, ContactEventsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ContactEventsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contactIdMeta = const VerificationMeta(
    'contactId',
  );
  @override
  late final GeneratedColumn<String> contactId = GeneratedColumn<String>(
    'contact_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eventIdMeta = const VerificationMeta(
    'eventId',
  );
  @override
  late final GeneratedColumn<String> eventId = GeneratedColumn<String>(
    'event_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('not_contacted'),
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _talkingPointsMeta = const VerificationMeta(
    'talkingPoints',
  );
  @override
  late final GeneratedColumn<String> talkingPoints = GeneratedColumn<String>(
    'talking_points',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    contactId,
    eventId,
    status,
    notes,
    talkingPoints,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'contact_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<ContactEventsTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    }
    if (data.containsKey('contact_id')) {
      context.handle(
        _contactIdMeta,
        contactId.isAcceptableOrUnknown(data['contact_id']!, _contactIdMeta),
      );
    } else if (isInserting) {
      context.missing(_contactIdMeta);
    }
    if (data.containsKey('event_id')) {
      context.handle(
        _eventIdMeta,
        eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta),
      );
    } else if (isInserting) {
      context.missing(_eventIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('talking_points')) {
      context.handle(
        _talkingPointsMeta,
        talkingPoints.isAcceptableOrUnknown(
          data['talking_points']!,
          _talkingPointsMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ContactEventsTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ContactEventsTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      ),
      contactId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}contact_id'],
      )!,
      eventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_id'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      talkingPoints: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}talking_points'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $ContactEventsTableTable createAlias(String alias) {
    return $ContactEventsTableTable(attachedDatabase, alias);
  }
}

class ContactEventsTableData extends DataClass
    implements Insertable<ContactEventsTableData> {
  final String id;
  final String? userId;
  final String contactId;
  final String eventId;
  final String status;
  final String? notes;
  final String? talkingPoints;
  final DateTime? createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const ContactEventsTableData({
    required this.id,
    this.userId,
    required this.contactId,
    required this.eventId,
    required this.status,
    this.notes,
    this.talkingPoints,
    this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || userId != null) {
      map['user_id'] = Variable<String>(userId);
    }
    map['contact_id'] = Variable<String>(contactId);
    map['event_id'] = Variable<String>(eventId);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || talkingPoints != null) {
      map['talking_points'] = Variable<String>(talkingPoints);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  ContactEventsTableCompanion toCompanion(bool nullToAbsent) {
    return ContactEventsTableCompanion(
      id: Value(id),
      userId: userId == null && nullToAbsent
          ? const Value.absent()
          : Value(userId),
      contactId: Value(contactId),
      eventId: Value(eventId),
      status: Value(status),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      talkingPoints: talkingPoints == null && nullToAbsent
          ? const Value.absent()
          : Value(talkingPoints),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory ContactEventsTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ContactEventsTableData(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String?>(json['userId']),
      contactId: serializer.fromJson<String>(json['contactId']),
      eventId: serializer.fromJson<String>(json['eventId']),
      status: serializer.fromJson<String>(json['status']),
      notes: serializer.fromJson<String?>(json['notes']),
      talkingPoints: serializer.fromJson<String?>(json['talkingPoints']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String?>(userId),
      'contactId': serializer.toJson<String>(contactId),
      'eventId': serializer.toJson<String>(eventId),
      'status': serializer.toJson<String>(status),
      'notes': serializer.toJson<String?>(notes),
      'talkingPoints': serializer.toJson<String?>(talkingPoints),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  ContactEventsTableData copyWith({
    String? id,
    Value<String?> userId = const Value.absent(),
    String? contactId,
    String? eventId,
    String? status,
    Value<String?> notes = const Value.absent(),
    Value<String?> talkingPoints = const Value.absent(),
    Value<DateTime?> createdAt = const Value.absent(),
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => ContactEventsTableData(
    id: id ?? this.id,
    userId: userId.present ? userId.value : this.userId,
    contactId: contactId ?? this.contactId,
    eventId: eventId ?? this.eventId,
    status: status ?? this.status,
    notes: notes.present ? notes.value : this.notes,
    talkingPoints: talkingPoints.present
        ? talkingPoints.value
        : this.talkingPoints,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  ContactEventsTableData copyWithCompanion(ContactEventsTableCompanion data) {
    return ContactEventsTableData(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      contactId: data.contactId.present ? data.contactId.value : this.contactId,
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      status: data.status.present ? data.status.value : this.status,
      notes: data.notes.present ? data.notes.value : this.notes,
      talkingPoints: data.talkingPoints.present
          ? data.talkingPoints.value
          : this.talkingPoints,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ContactEventsTableData(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('contactId: $contactId, ')
          ..write('eventId: $eventId, ')
          ..write('status: $status, ')
          ..write('notes: $notes, ')
          ..write('talkingPoints: $talkingPoints, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    contactId,
    eventId,
    status,
    notes,
    talkingPoints,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContactEventsTableData &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.contactId == this.contactId &&
          other.eventId == this.eventId &&
          other.status == this.status &&
          other.notes == this.notes &&
          other.talkingPoints == this.talkingPoints &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class ContactEventsTableCompanion
    extends UpdateCompanion<ContactEventsTableData> {
  final Value<String> id;
  final Value<String?> userId;
  final Value<String> contactId;
  final Value<String> eventId;
  final Value<String> status;
  final Value<String?> notes;
  final Value<String?> talkingPoints;
  final Value<DateTime?> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const ContactEventsTableCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.contactId = const Value.absent(),
    this.eventId = const Value.absent(),
    this.status = const Value.absent(),
    this.notes = const Value.absent(),
    this.talkingPoints = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ContactEventsTableCompanion.insert({
    required String id,
    this.userId = const Value.absent(),
    required String contactId,
    required String eventId,
    this.status = const Value.absent(),
    this.notes = const Value.absent(),
    this.talkingPoints = const Value.absent(),
    this.createdAt = const Value.absent(),
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       contactId = Value(contactId),
       eventId = Value(eventId),
       updatedAt = Value(updatedAt);
  static Insertable<ContactEventsTableData> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? contactId,
    Expression<String>? eventId,
    Expression<String>? status,
    Expression<String>? notes,
    Expression<String>? talkingPoints,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (contactId != null) 'contact_id': contactId,
      if (eventId != null) 'event_id': eventId,
      if (status != null) 'status': status,
      if (notes != null) 'notes': notes,
      if (talkingPoints != null) 'talking_points': talkingPoints,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ContactEventsTableCompanion copyWith({
    Value<String>? id,
    Value<String?>? userId,
    Value<String>? contactId,
    Value<String>? eventId,
    Value<String>? status,
    Value<String?>? notes,
    Value<String?>? talkingPoints,
    Value<DateTime?>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return ContactEventsTableCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      contactId: contactId ?? this.contactId,
      eventId: eventId ?? this.eventId,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      talkingPoints: talkingPoints ?? this.talkingPoints,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (contactId.present) {
      map['contact_id'] = Variable<String>(contactId.value);
    }
    if (eventId.present) {
      map['event_id'] = Variable<String>(eventId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (talkingPoints.present) {
      map['talking_points'] = Variable<String>(talkingPoints.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ContactEventsTableCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('contactId: $contactId, ')
          ..write('eventId: $eventId, ')
          ..write('status: $status, ')
          ..write('notes: $notes, ')
          ..write('talkingPoints: $talkingPoints, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EventGoalsTableTable extends EventGoalsTable
    with TableInfo<$EventGoalsTableTable, EventGoalsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EventGoalsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _eventIdMeta = const VerificationMeta(
    'eventId',
  );
  @override
  late final GeneratedColumn<String> eventId = GeneratedColumn<String>(
    'event_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currentMeta = const VerificationMeta(
    'current',
  );
  @override
  late final GeneratedColumn<int> current = GeneratedColumn<int>(
    'current',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _totalMeta = const VerificationMeta('total');
  @override
  late final GeneratedColumn<int> total = GeneratedColumn<int>(
    'total',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    eventId,
    label,
    current,
    total,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'event_goals';
  @override
  VerificationContext validateIntegrity(
    Insertable<EventGoalsTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    }
    if (data.containsKey('event_id')) {
      context.handle(
        _eventIdMeta,
        eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta),
      );
    } else if (isInserting) {
      context.missing(_eventIdMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('current')) {
      context.handle(
        _currentMeta,
        current.isAcceptableOrUnknown(data['current']!, _currentMeta),
      );
    }
    if (data.containsKey('total')) {
      context.handle(
        _totalMeta,
        total.isAcceptableOrUnknown(data['total']!, _totalMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EventGoalsTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EventGoalsTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      ),
      eventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_id'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      current: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}current'],
      )!,
      total: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $EventGoalsTableTable createAlias(String alias) {
    return $EventGoalsTableTable(attachedDatabase, alias);
  }
}

class EventGoalsTableData extends DataClass
    implements Insertable<EventGoalsTableData> {
  final String id;
  final String? userId;
  final String eventId;
  final String label;
  final int current;
  final int total;
  final DateTime? createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const EventGoalsTableData({
    required this.id,
    this.userId,
    required this.eventId,
    required this.label,
    required this.current,
    required this.total,
    this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || userId != null) {
      map['user_id'] = Variable<String>(userId);
    }
    map['event_id'] = Variable<String>(eventId);
    map['label'] = Variable<String>(label);
    map['current'] = Variable<int>(current);
    map['total'] = Variable<int>(total);
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  EventGoalsTableCompanion toCompanion(bool nullToAbsent) {
    return EventGoalsTableCompanion(
      id: Value(id),
      userId: userId == null && nullToAbsent
          ? const Value.absent()
          : Value(userId),
      eventId: Value(eventId),
      label: Value(label),
      current: Value(current),
      total: Value(total),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory EventGoalsTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EventGoalsTableData(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String?>(json['userId']),
      eventId: serializer.fromJson<String>(json['eventId']),
      label: serializer.fromJson<String>(json['label']),
      current: serializer.fromJson<int>(json['current']),
      total: serializer.fromJson<int>(json['total']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String?>(userId),
      'eventId': serializer.toJson<String>(eventId),
      'label': serializer.toJson<String>(label),
      'current': serializer.toJson<int>(current),
      'total': serializer.toJson<int>(total),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  EventGoalsTableData copyWith({
    String? id,
    Value<String?> userId = const Value.absent(),
    String? eventId,
    String? label,
    int? current,
    int? total,
    Value<DateTime?> createdAt = const Value.absent(),
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => EventGoalsTableData(
    id: id ?? this.id,
    userId: userId.present ? userId.value : this.userId,
    eventId: eventId ?? this.eventId,
    label: label ?? this.label,
    current: current ?? this.current,
    total: total ?? this.total,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  EventGoalsTableData copyWithCompanion(EventGoalsTableCompanion data) {
    return EventGoalsTableData(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      label: data.label.present ? data.label.value : this.label,
      current: data.current.present ? data.current.value : this.current,
      total: data.total.present ? data.total.value : this.total,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EventGoalsTableData(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('eventId: $eventId, ')
          ..write('label: $label, ')
          ..write('current: $current, ')
          ..write('total: $total, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    eventId,
    label,
    current,
    total,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventGoalsTableData &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.eventId == this.eventId &&
          other.label == this.label &&
          other.current == this.current &&
          other.total == this.total &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class EventGoalsTableCompanion extends UpdateCompanion<EventGoalsTableData> {
  final Value<String> id;
  final Value<String?> userId;
  final Value<String> eventId;
  final Value<String> label;
  final Value<int> current;
  final Value<int> total;
  final Value<DateTime?> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const EventGoalsTableCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.eventId = const Value.absent(),
    this.label = const Value.absent(),
    this.current = const Value.absent(),
    this.total = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EventGoalsTableCompanion.insert({
    required String id,
    this.userId = const Value.absent(),
    required String eventId,
    required String label,
    this.current = const Value.absent(),
    this.total = const Value.absent(),
    this.createdAt = const Value.absent(),
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       eventId = Value(eventId),
       label = Value(label),
       updatedAt = Value(updatedAt);
  static Insertable<EventGoalsTableData> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? eventId,
    Expression<String>? label,
    Expression<int>? current,
    Expression<int>? total,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (eventId != null) 'event_id': eventId,
      if (label != null) 'label': label,
      if (current != null) 'current': current,
      if (total != null) 'total': total,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EventGoalsTableCompanion copyWith({
    Value<String>? id,
    Value<String?>? userId,
    Value<String>? eventId,
    Value<String>? label,
    Value<int>? current,
    Value<int>? total,
    Value<DateTime?>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return EventGoalsTableCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      eventId: eventId ?? this.eventId,
      label: label ?? this.label,
      current: current ?? this.current,
      total: total ?? this.total,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (eventId.present) {
      map['event_id'] = Variable<String>(eventId.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (current.present) {
      map['current'] = Variable<int>(current.value);
    }
    if (total.present) {
      map['total'] = Variable<int>(total.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EventGoalsTableCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('eventId: $eventId, ')
          ..write('label: $label, ')
          ..write('current: $current, ')
          ..write('total: $total, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EmailDraftsTableTable extends EmailDraftsTable
    with TableInfo<$EmailDraftsTableTable, EmailDraftsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EmailDraftsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contactIdMeta = const VerificationMeta(
    'contactId',
  );
  @override
  late final GeneratedColumn<String> contactId = GeneratedColumn<String>(
    'contact_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _eventIdMeta = const VerificationMeta(
    'eventId',
  );
  @override
  late final GeneratedColumn<String> eventId = GeneratedColumn<String>(
    'event_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _emailTypeMeta = const VerificationMeta(
    'emailType',
  );
  @override
  late final GeneratedColumn<String> emailType = GeneratedColumn<String>(
    'email_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subjectMeta = const VerificationMeta(
    'subject',
  );
  @override
  late final GeneratedColumn<String> subject = GeneratedColumn<String>(
    'subject',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('draft'),
  );
  static const VerificationMeta _sentAtMeta = const VerificationMeta('sentAt');
  @override
  late final GeneratedColumn<DateTime> sentAt = GeneratedColumn<DateTime>(
    'sent_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    contactId,
    eventId,
    emailType,
    subject,
    body,
    status,
    sentAt,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'email_drafts';
  @override
  VerificationContext validateIntegrity(
    Insertable<EmailDraftsTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    }
    if (data.containsKey('contact_id')) {
      context.handle(
        _contactIdMeta,
        contactId.isAcceptableOrUnknown(data['contact_id']!, _contactIdMeta),
      );
    }
    if (data.containsKey('event_id')) {
      context.handle(
        _eventIdMeta,
        eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta),
      );
    }
    if (data.containsKey('email_type')) {
      context.handle(
        _emailTypeMeta,
        emailType.isAcceptableOrUnknown(data['email_type']!, _emailTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_emailTypeMeta);
    }
    if (data.containsKey('subject')) {
      context.handle(
        _subjectMeta,
        subject.isAcceptableOrUnknown(data['subject']!, _subjectMeta),
      );
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('sent_at')) {
      context.handle(
        _sentAtMeta,
        sentAt.isAcceptableOrUnknown(data['sent_at']!, _sentAtMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EmailDraftsTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EmailDraftsTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      ),
      contactId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}contact_id'],
      ),
      eventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_id'],
      ),
      emailType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email_type'],
      )!,
      subject: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject'],
      ),
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      sentAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}sent_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $EmailDraftsTableTable createAlias(String alias) {
    return $EmailDraftsTableTable(attachedDatabase, alias);
  }
}

class EmailDraftsTableData extends DataClass
    implements Insertable<EmailDraftsTableData> {
  final String id;
  final String? userId;
  final String? contactId;
  final String? eventId;
  final String emailType;
  final String? subject;
  final String? body;
  final String status;
  final DateTime? sentAt;
  final DateTime? createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const EmailDraftsTableData({
    required this.id,
    this.userId,
    this.contactId,
    this.eventId,
    required this.emailType,
    this.subject,
    this.body,
    required this.status,
    this.sentAt,
    this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || userId != null) {
      map['user_id'] = Variable<String>(userId);
    }
    if (!nullToAbsent || contactId != null) {
      map['contact_id'] = Variable<String>(contactId);
    }
    if (!nullToAbsent || eventId != null) {
      map['event_id'] = Variable<String>(eventId);
    }
    map['email_type'] = Variable<String>(emailType);
    if (!nullToAbsent || subject != null) {
      map['subject'] = Variable<String>(subject);
    }
    if (!nullToAbsent || body != null) {
      map['body'] = Variable<String>(body);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || sentAt != null) {
      map['sent_at'] = Variable<DateTime>(sentAt);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  EmailDraftsTableCompanion toCompanion(bool nullToAbsent) {
    return EmailDraftsTableCompanion(
      id: Value(id),
      userId: userId == null && nullToAbsent
          ? const Value.absent()
          : Value(userId),
      contactId: contactId == null && nullToAbsent
          ? const Value.absent()
          : Value(contactId),
      eventId: eventId == null && nullToAbsent
          ? const Value.absent()
          : Value(eventId),
      emailType: Value(emailType),
      subject: subject == null && nullToAbsent
          ? const Value.absent()
          : Value(subject),
      body: body == null && nullToAbsent ? const Value.absent() : Value(body),
      status: Value(status),
      sentAt: sentAt == null && nullToAbsent
          ? const Value.absent()
          : Value(sentAt),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory EmailDraftsTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EmailDraftsTableData(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String?>(json['userId']),
      contactId: serializer.fromJson<String?>(json['contactId']),
      eventId: serializer.fromJson<String?>(json['eventId']),
      emailType: serializer.fromJson<String>(json['emailType']),
      subject: serializer.fromJson<String?>(json['subject']),
      body: serializer.fromJson<String?>(json['body']),
      status: serializer.fromJson<String>(json['status']),
      sentAt: serializer.fromJson<DateTime?>(json['sentAt']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String?>(userId),
      'contactId': serializer.toJson<String?>(contactId),
      'eventId': serializer.toJson<String?>(eventId),
      'emailType': serializer.toJson<String>(emailType),
      'subject': serializer.toJson<String?>(subject),
      'body': serializer.toJson<String?>(body),
      'status': serializer.toJson<String>(status),
      'sentAt': serializer.toJson<DateTime?>(sentAt),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  EmailDraftsTableData copyWith({
    String? id,
    Value<String?> userId = const Value.absent(),
    Value<String?> contactId = const Value.absent(),
    Value<String?> eventId = const Value.absent(),
    String? emailType,
    Value<String?> subject = const Value.absent(),
    Value<String?> body = const Value.absent(),
    String? status,
    Value<DateTime?> sentAt = const Value.absent(),
    Value<DateTime?> createdAt = const Value.absent(),
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => EmailDraftsTableData(
    id: id ?? this.id,
    userId: userId.present ? userId.value : this.userId,
    contactId: contactId.present ? contactId.value : this.contactId,
    eventId: eventId.present ? eventId.value : this.eventId,
    emailType: emailType ?? this.emailType,
    subject: subject.present ? subject.value : this.subject,
    body: body.present ? body.value : this.body,
    status: status ?? this.status,
    sentAt: sentAt.present ? sentAt.value : this.sentAt,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  EmailDraftsTableData copyWithCompanion(EmailDraftsTableCompanion data) {
    return EmailDraftsTableData(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      contactId: data.contactId.present ? data.contactId.value : this.contactId,
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      emailType: data.emailType.present ? data.emailType.value : this.emailType,
      subject: data.subject.present ? data.subject.value : this.subject,
      body: data.body.present ? data.body.value : this.body,
      status: data.status.present ? data.status.value : this.status,
      sentAt: data.sentAt.present ? data.sentAt.value : this.sentAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EmailDraftsTableData(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('contactId: $contactId, ')
          ..write('eventId: $eventId, ')
          ..write('emailType: $emailType, ')
          ..write('subject: $subject, ')
          ..write('body: $body, ')
          ..write('status: $status, ')
          ..write('sentAt: $sentAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    contactId,
    eventId,
    emailType,
    subject,
    body,
    status,
    sentAt,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EmailDraftsTableData &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.contactId == this.contactId &&
          other.eventId == this.eventId &&
          other.emailType == this.emailType &&
          other.subject == this.subject &&
          other.body == this.body &&
          other.status == this.status &&
          other.sentAt == this.sentAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class EmailDraftsTableCompanion extends UpdateCompanion<EmailDraftsTableData> {
  final Value<String> id;
  final Value<String?> userId;
  final Value<String?> contactId;
  final Value<String?> eventId;
  final Value<String> emailType;
  final Value<String?> subject;
  final Value<String?> body;
  final Value<String> status;
  final Value<DateTime?> sentAt;
  final Value<DateTime?> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const EmailDraftsTableCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.contactId = const Value.absent(),
    this.eventId = const Value.absent(),
    this.emailType = const Value.absent(),
    this.subject = const Value.absent(),
    this.body = const Value.absent(),
    this.status = const Value.absent(),
    this.sentAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EmailDraftsTableCompanion.insert({
    required String id,
    this.userId = const Value.absent(),
    this.contactId = const Value.absent(),
    this.eventId = const Value.absent(),
    required String emailType,
    this.subject = const Value.absent(),
    this.body = const Value.absent(),
    this.status = const Value.absent(),
    this.sentAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       emailType = Value(emailType),
       updatedAt = Value(updatedAt);
  static Insertable<EmailDraftsTableData> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? contactId,
    Expression<String>? eventId,
    Expression<String>? emailType,
    Expression<String>? subject,
    Expression<String>? body,
    Expression<String>? status,
    Expression<DateTime>? sentAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (contactId != null) 'contact_id': contactId,
      if (eventId != null) 'event_id': eventId,
      if (emailType != null) 'email_type': emailType,
      if (subject != null) 'subject': subject,
      if (body != null) 'body': body,
      if (status != null) 'status': status,
      if (sentAt != null) 'sent_at': sentAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EmailDraftsTableCompanion copyWith({
    Value<String>? id,
    Value<String?>? userId,
    Value<String?>? contactId,
    Value<String?>? eventId,
    Value<String>? emailType,
    Value<String?>? subject,
    Value<String?>? body,
    Value<String>? status,
    Value<DateTime?>? sentAt,
    Value<DateTime?>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return EmailDraftsTableCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      contactId: contactId ?? this.contactId,
      eventId: eventId ?? this.eventId,
      emailType: emailType ?? this.emailType,
      subject: subject ?? this.subject,
      body: body ?? this.body,
      status: status ?? this.status,
      sentAt: sentAt ?? this.sentAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (contactId.present) {
      map['contact_id'] = Variable<String>(contactId.value);
    }
    if (eventId.present) {
      map['event_id'] = Variable<String>(eventId.value);
    }
    if (emailType.present) {
      map['email_type'] = Variable<String>(emailType.value);
    }
    if (subject.present) {
      map['subject'] = Variable<String>(subject.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (sentAt.present) {
      map['sent_at'] = Variable<DateTime>(sentAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EmailDraftsTableCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('contactId: $contactId, ')
          ..write('eventId: $eventId, ')
          ..write('emailType: $emailType, ')
          ..write('subject: $subject, ')
          ..write('body: $body, ')
          ..write('status: $status, ')
          ..write('sentAt: $sentAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $InteractionsTableTable extends InteractionsTable
    with TableInfo<$InteractionsTableTable, InteractionsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InteractionsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contactIdMeta = const VerificationMeta(
    'contactId',
  );
  @override
  late final GeneratedColumn<String> contactId = GeneratedColumn<String>(
    'contact_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _eventIdMeta = const VerificationMeta(
    'eventId',
  );
  @override
  late final GeneratedColumn<String> eventId = GeneratedColumn<String>(
    'event_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _interactionTypeMeta = const VerificationMeta(
    'interactionType',
  );
  @override
  late final GeneratedColumn<String> interactionType = GeneratedColumn<String>(
    'interaction_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _interactionDateMeta = const VerificationMeta(
    'interactionDate',
  );
  @override
  late final GeneratedColumn<DateTime> interactionDate =
      GeneratedColumn<DateTime>(
        'interaction_date',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _summaryMeta = const VerificationMeta(
    'summary',
  );
  @override
  late final GeneratedColumn<String> summary = GeneratedColumn<String>(
    'summary',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _detailsJsonMeta = const VerificationMeta(
    'detailsJson',
  );
  @override
  late final GeneratedColumn<String> detailsJson = GeneratedColumn<String>(
    'details_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    contactId,
    eventId,
    interactionType,
    interactionDate,
    summary,
    detailsJson,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'interactions';
  @override
  VerificationContext validateIntegrity(
    Insertable<InteractionsTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    }
    if (data.containsKey('contact_id')) {
      context.handle(
        _contactIdMeta,
        contactId.isAcceptableOrUnknown(data['contact_id']!, _contactIdMeta),
      );
    }
    if (data.containsKey('event_id')) {
      context.handle(
        _eventIdMeta,
        eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta),
      );
    }
    if (data.containsKey('interaction_type')) {
      context.handle(
        _interactionTypeMeta,
        interactionType.isAcceptableOrUnknown(
          data['interaction_type']!,
          _interactionTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_interactionTypeMeta);
    }
    if (data.containsKey('interaction_date')) {
      context.handle(
        _interactionDateMeta,
        interactionDate.isAcceptableOrUnknown(
          data['interaction_date']!,
          _interactionDateMeta,
        ),
      );
    }
    if (data.containsKey('summary')) {
      context.handle(
        _summaryMeta,
        summary.isAcceptableOrUnknown(data['summary']!, _summaryMeta),
      );
    }
    if (data.containsKey('details_json')) {
      context.handle(
        _detailsJsonMeta,
        detailsJson.isAcceptableOrUnknown(
          data['details_json']!,
          _detailsJsonMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  InteractionsTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InteractionsTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      ),
      contactId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}contact_id'],
      ),
      eventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_id'],
      ),
      interactionType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}interaction_type'],
      )!,
      interactionDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}interaction_date'],
      ),
      summary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary'],
      ),
      detailsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}details_json'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $InteractionsTableTable createAlias(String alias) {
    return $InteractionsTableTable(attachedDatabase, alias);
  }
}

class InteractionsTableData extends DataClass
    implements Insertable<InteractionsTableData> {
  final String id;
  final String? userId;
  final String? contactId;
  final String? eventId;
  final String interactionType;
  final DateTime? interactionDate;
  final String? summary;
  final String? detailsJson;
  final DateTime? createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const InteractionsTableData({
    required this.id,
    this.userId,
    this.contactId,
    this.eventId,
    required this.interactionType,
    this.interactionDate,
    this.summary,
    this.detailsJson,
    this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || userId != null) {
      map['user_id'] = Variable<String>(userId);
    }
    if (!nullToAbsent || contactId != null) {
      map['contact_id'] = Variable<String>(contactId);
    }
    if (!nullToAbsent || eventId != null) {
      map['event_id'] = Variable<String>(eventId);
    }
    map['interaction_type'] = Variable<String>(interactionType);
    if (!nullToAbsent || interactionDate != null) {
      map['interaction_date'] = Variable<DateTime>(interactionDate);
    }
    if (!nullToAbsent || summary != null) {
      map['summary'] = Variable<String>(summary);
    }
    if (!nullToAbsent || detailsJson != null) {
      map['details_json'] = Variable<String>(detailsJson);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  InteractionsTableCompanion toCompanion(bool nullToAbsent) {
    return InteractionsTableCompanion(
      id: Value(id),
      userId: userId == null && nullToAbsent
          ? const Value.absent()
          : Value(userId),
      contactId: contactId == null && nullToAbsent
          ? const Value.absent()
          : Value(contactId),
      eventId: eventId == null && nullToAbsent
          ? const Value.absent()
          : Value(eventId),
      interactionType: Value(interactionType),
      interactionDate: interactionDate == null && nullToAbsent
          ? const Value.absent()
          : Value(interactionDate),
      summary: summary == null && nullToAbsent
          ? const Value.absent()
          : Value(summary),
      detailsJson: detailsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(detailsJson),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory InteractionsTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InteractionsTableData(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String?>(json['userId']),
      contactId: serializer.fromJson<String?>(json['contactId']),
      eventId: serializer.fromJson<String?>(json['eventId']),
      interactionType: serializer.fromJson<String>(json['interactionType']),
      interactionDate: serializer.fromJson<DateTime?>(json['interactionDate']),
      summary: serializer.fromJson<String?>(json['summary']),
      detailsJson: serializer.fromJson<String?>(json['detailsJson']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String?>(userId),
      'contactId': serializer.toJson<String?>(contactId),
      'eventId': serializer.toJson<String?>(eventId),
      'interactionType': serializer.toJson<String>(interactionType),
      'interactionDate': serializer.toJson<DateTime?>(interactionDate),
      'summary': serializer.toJson<String?>(summary),
      'detailsJson': serializer.toJson<String?>(detailsJson),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  InteractionsTableData copyWith({
    String? id,
    Value<String?> userId = const Value.absent(),
    Value<String?> contactId = const Value.absent(),
    Value<String?> eventId = const Value.absent(),
    String? interactionType,
    Value<DateTime?> interactionDate = const Value.absent(),
    Value<String?> summary = const Value.absent(),
    Value<String?> detailsJson = const Value.absent(),
    Value<DateTime?> createdAt = const Value.absent(),
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => InteractionsTableData(
    id: id ?? this.id,
    userId: userId.present ? userId.value : this.userId,
    contactId: contactId.present ? contactId.value : this.contactId,
    eventId: eventId.present ? eventId.value : this.eventId,
    interactionType: interactionType ?? this.interactionType,
    interactionDate: interactionDate.present
        ? interactionDate.value
        : this.interactionDate,
    summary: summary.present ? summary.value : this.summary,
    detailsJson: detailsJson.present ? detailsJson.value : this.detailsJson,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  InteractionsTableData copyWithCompanion(InteractionsTableCompanion data) {
    return InteractionsTableData(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      contactId: data.contactId.present ? data.contactId.value : this.contactId,
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      interactionType: data.interactionType.present
          ? data.interactionType.value
          : this.interactionType,
      interactionDate: data.interactionDate.present
          ? data.interactionDate.value
          : this.interactionDate,
      summary: data.summary.present ? data.summary.value : this.summary,
      detailsJson: data.detailsJson.present
          ? data.detailsJson.value
          : this.detailsJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InteractionsTableData(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('contactId: $contactId, ')
          ..write('eventId: $eventId, ')
          ..write('interactionType: $interactionType, ')
          ..write('interactionDate: $interactionDate, ')
          ..write('summary: $summary, ')
          ..write('detailsJson: $detailsJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    contactId,
    eventId,
    interactionType,
    interactionDate,
    summary,
    detailsJson,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InteractionsTableData &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.contactId == this.contactId &&
          other.eventId == this.eventId &&
          other.interactionType == this.interactionType &&
          other.interactionDate == this.interactionDate &&
          other.summary == this.summary &&
          other.detailsJson == this.detailsJson &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class InteractionsTableCompanion
    extends UpdateCompanion<InteractionsTableData> {
  final Value<String> id;
  final Value<String?> userId;
  final Value<String?> contactId;
  final Value<String?> eventId;
  final Value<String> interactionType;
  final Value<DateTime?> interactionDate;
  final Value<String?> summary;
  final Value<String?> detailsJson;
  final Value<DateTime?> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const InteractionsTableCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.contactId = const Value.absent(),
    this.eventId = const Value.absent(),
    this.interactionType = const Value.absent(),
    this.interactionDate = const Value.absent(),
    this.summary = const Value.absent(),
    this.detailsJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  InteractionsTableCompanion.insert({
    required String id,
    this.userId = const Value.absent(),
    this.contactId = const Value.absent(),
    this.eventId = const Value.absent(),
    required String interactionType,
    this.interactionDate = const Value.absent(),
    this.summary = const Value.absent(),
    this.detailsJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       interactionType = Value(interactionType),
       updatedAt = Value(updatedAt);
  static Insertable<InteractionsTableData> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? contactId,
    Expression<String>? eventId,
    Expression<String>? interactionType,
    Expression<DateTime>? interactionDate,
    Expression<String>? summary,
    Expression<String>? detailsJson,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (contactId != null) 'contact_id': contactId,
      if (eventId != null) 'event_id': eventId,
      if (interactionType != null) 'interaction_type': interactionType,
      if (interactionDate != null) 'interaction_date': interactionDate,
      if (summary != null) 'summary': summary,
      if (detailsJson != null) 'details_json': detailsJson,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  InteractionsTableCompanion copyWith({
    Value<String>? id,
    Value<String?>? userId,
    Value<String?>? contactId,
    Value<String?>? eventId,
    Value<String>? interactionType,
    Value<DateTime?>? interactionDate,
    Value<String?>? summary,
    Value<String?>? detailsJson,
    Value<DateTime?>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return InteractionsTableCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      contactId: contactId ?? this.contactId,
      eventId: eventId ?? this.eventId,
      interactionType: interactionType ?? this.interactionType,
      interactionDate: interactionDate ?? this.interactionDate,
      summary: summary ?? this.summary,
      detailsJson: detailsJson ?? this.detailsJson,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (contactId.present) {
      map['contact_id'] = Variable<String>(contactId.value);
    }
    if (eventId.present) {
      map['event_id'] = Variable<String>(eventId.value);
    }
    if (interactionType.present) {
      map['interaction_type'] = Variable<String>(interactionType.value);
    }
    if (interactionDate.present) {
      map['interaction_date'] = Variable<DateTime>(interactionDate.value);
    }
    if (summary.present) {
      map['summary'] = Variable<String>(summary.value);
    }
    if (detailsJson.present) {
      map['details_json'] = Variable<String>(detailsJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InteractionsTableCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('contactId: $contactId, ')
          ..write('eventId: $eventId, ')
          ..write('interactionType: $interactionType, ')
          ..write('interactionDate: $interactionDate, ')
          ..write('summary: $summary, ')
          ..write('detailsJson: $detailsJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CompaniesTableTable extends CompaniesTable
    with TableInfo<$CompaniesTableTable, CompaniesTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CompaniesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _websiteMeta = const VerificationMeta(
    'website',
  );
  @override
  late final GeneratedColumn<String> website = GeneratedColumn<String>(
    'website',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _industryMeta = const VerificationMeta(
    'industry',
  );
  @override
  late final GeneratedColumn<String> industry = GeneratedColumn<String>(
    'industry',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _locationMeta = const VerificationMeta(
    'location',
  );
  @override
  late final GeneratedColumn<String> location = GeneratedColumn<String>(
    'location',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _companySizeMeta = const VerificationMeta(
    'companySize',
  );
  @override
  late final GeneratedColumn<String> companySize = GeneratedColumn<String>(
    'company_size',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _productsServicesMeta = const VerificationMeta(
    'productsServices',
  );
  @override
  late final GeneratedColumn<String> productsServices = GeneratedColumn<String>(
    'products_services',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _headquartersMeta = const VerificationMeta(
    'headquarters',
  );
  @override
  late final GeneratedColumn<String> headquarters = GeneratedColumn<String>(
    'headquarters',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _employeeCountMeta = const VerificationMeta(
    'employeeCount',
  );
  @override
  late final GeneratedColumn<String> employeeCount = GeneratedColumn<String>(
    'employee_count',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _foundedYearMeta = const VerificationMeta(
    'foundedYear',
  );
  @override
  late final GeneratedColumn<String> foundedYear = GeneratedColumn<String>(
    'founded_year',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _linkedinUrlMeta = const VerificationMeta(
    'linkedinUrl',
  );
  @override
  late final GeneratedColumn<String> linkedinUrl = GeneratedColumn<String>(
    'linkedin_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tickerSymbolMeta = const VerificationMeta(
    'tickerSymbol',
  );
  @override
  late final GeneratedColumn<String> tickerSymbol = GeneratedColumn<String>(
    'ticker_symbol',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _enrichedAtMeta = const VerificationMeta(
    'enrichedAt',
  );
  @override
  late final GeneratedColumn<DateTime> enrichedAt = GeneratedColumn<DateTime>(
    'enriched_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _enrichmentFailedMeta = const VerificationMeta(
    'enrichmentFailed',
  );
  @override
  late final GeneratedColumn<bool> enrichmentFailed = GeneratedColumn<bool>(
    'enrichment_failed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enrichment_failed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _talkingPointsJsonMeta = const VerificationMeta(
    'talkingPointsJson',
  );
  @override
  late final GeneratedColumn<String> talkingPointsJson =
      GeneratedColumn<String>(
        'talking_points_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    website,
    industry,
    description,
    location,
    companySize,
    productsServices,
    headquarters,
    employeeCount,
    foundedYear,
    linkedinUrl,
    tickerSymbol,
    enrichedAt,
    enrichmentFailed,
    talkingPointsJson,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'companies';
  @override
  VerificationContext validateIntegrity(
    Insertable<CompaniesTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('website')) {
      context.handle(
        _websiteMeta,
        website.isAcceptableOrUnknown(data['website']!, _websiteMeta),
      );
    }
    if (data.containsKey('industry')) {
      context.handle(
        _industryMeta,
        industry.isAcceptableOrUnknown(data['industry']!, _industryMeta),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('location')) {
      context.handle(
        _locationMeta,
        location.isAcceptableOrUnknown(data['location']!, _locationMeta),
      );
    }
    if (data.containsKey('company_size')) {
      context.handle(
        _companySizeMeta,
        companySize.isAcceptableOrUnknown(
          data['company_size']!,
          _companySizeMeta,
        ),
      );
    }
    if (data.containsKey('products_services')) {
      context.handle(
        _productsServicesMeta,
        productsServices.isAcceptableOrUnknown(
          data['products_services']!,
          _productsServicesMeta,
        ),
      );
    }
    if (data.containsKey('headquarters')) {
      context.handle(
        _headquartersMeta,
        headquarters.isAcceptableOrUnknown(
          data['headquarters']!,
          _headquartersMeta,
        ),
      );
    }
    if (data.containsKey('employee_count')) {
      context.handle(
        _employeeCountMeta,
        employeeCount.isAcceptableOrUnknown(
          data['employee_count']!,
          _employeeCountMeta,
        ),
      );
    }
    if (data.containsKey('founded_year')) {
      context.handle(
        _foundedYearMeta,
        foundedYear.isAcceptableOrUnknown(
          data['founded_year']!,
          _foundedYearMeta,
        ),
      );
    }
    if (data.containsKey('linkedin_url')) {
      context.handle(
        _linkedinUrlMeta,
        linkedinUrl.isAcceptableOrUnknown(
          data['linkedin_url']!,
          _linkedinUrlMeta,
        ),
      );
    }
    if (data.containsKey('ticker_symbol')) {
      context.handle(
        _tickerSymbolMeta,
        tickerSymbol.isAcceptableOrUnknown(
          data['ticker_symbol']!,
          _tickerSymbolMeta,
        ),
      );
    }
    if (data.containsKey('enriched_at')) {
      context.handle(
        _enrichedAtMeta,
        enrichedAt.isAcceptableOrUnknown(data['enriched_at']!, _enrichedAtMeta),
      );
    }
    if (data.containsKey('enrichment_failed')) {
      context.handle(
        _enrichmentFailedMeta,
        enrichmentFailed.isAcceptableOrUnknown(
          data['enrichment_failed']!,
          _enrichmentFailedMeta,
        ),
      );
    }
    if (data.containsKey('talking_points_json')) {
      context.handle(
        _talkingPointsJsonMeta,
        talkingPointsJson.isAcceptableOrUnknown(
          data['talking_points_json']!,
          _talkingPointsJsonMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CompaniesTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CompaniesTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      website: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}website'],
      ),
      industry: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}industry'],
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      location: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location'],
      ),
      companySize: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}company_size'],
      ),
      productsServices: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}products_services'],
      ),
      headquarters: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}headquarters'],
      ),
      employeeCount: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}employee_count'],
      ),
      foundedYear: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}founded_year'],
      ),
      linkedinUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}linkedin_url'],
      ),
      tickerSymbol: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ticker_symbol'],
      ),
      enrichedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}enriched_at'],
      ),
      enrichmentFailed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enrichment_failed'],
      )!,
      talkingPointsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}talking_points_json'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $CompaniesTableTable createAlias(String alias) {
    return $CompaniesTableTable(attachedDatabase, alias);
  }
}

class CompaniesTableData extends DataClass
    implements Insertable<CompaniesTableData> {
  final String id;
  final String name;
  final String? website;
  final String? industry;
  final String? description;
  final String? location;
  final String? companySize;
  final String? productsServices;
  final String? headquarters;
  final String? employeeCount;
  final String? foundedYear;
  final String? linkedinUrl;
  final String? tickerSymbol;
  final DateTime? enrichedAt;
  final bool enrichmentFailed;
  final String? talkingPointsJson;
  final DateTime? createdAt;
  final DateTime updatedAt;
  const CompaniesTableData({
    required this.id,
    required this.name,
    this.website,
    this.industry,
    this.description,
    this.location,
    this.companySize,
    this.productsServices,
    this.headquarters,
    this.employeeCount,
    this.foundedYear,
    this.linkedinUrl,
    this.tickerSymbol,
    this.enrichedAt,
    required this.enrichmentFailed,
    this.talkingPointsJson,
    this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || website != null) {
      map['website'] = Variable<String>(website);
    }
    if (!nullToAbsent || industry != null) {
      map['industry'] = Variable<String>(industry);
    }
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || location != null) {
      map['location'] = Variable<String>(location);
    }
    if (!nullToAbsent || companySize != null) {
      map['company_size'] = Variable<String>(companySize);
    }
    if (!nullToAbsent || productsServices != null) {
      map['products_services'] = Variable<String>(productsServices);
    }
    if (!nullToAbsent || headquarters != null) {
      map['headquarters'] = Variable<String>(headquarters);
    }
    if (!nullToAbsent || employeeCount != null) {
      map['employee_count'] = Variable<String>(employeeCount);
    }
    if (!nullToAbsent || foundedYear != null) {
      map['founded_year'] = Variable<String>(foundedYear);
    }
    if (!nullToAbsent || linkedinUrl != null) {
      map['linkedin_url'] = Variable<String>(linkedinUrl);
    }
    if (!nullToAbsent || tickerSymbol != null) {
      map['ticker_symbol'] = Variable<String>(tickerSymbol);
    }
    if (!nullToAbsent || enrichedAt != null) {
      map['enriched_at'] = Variable<DateTime>(enrichedAt);
    }
    map['enrichment_failed'] = Variable<bool>(enrichmentFailed);
    if (!nullToAbsent || talkingPointsJson != null) {
      map['talking_points_json'] = Variable<String>(talkingPointsJson);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CompaniesTableCompanion toCompanion(bool nullToAbsent) {
    return CompaniesTableCompanion(
      id: Value(id),
      name: Value(name),
      website: website == null && nullToAbsent
          ? const Value.absent()
          : Value(website),
      industry: industry == null && nullToAbsent
          ? const Value.absent()
          : Value(industry),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      location: location == null && nullToAbsent
          ? const Value.absent()
          : Value(location),
      companySize: companySize == null && nullToAbsent
          ? const Value.absent()
          : Value(companySize),
      productsServices: productsServices == null && nullToAbsent
          ? const Value.absent()
          : Value(productsServices),
      headquarters: headquarters == null && nullToAbsent
          ? const Value.absent()
          : Value(headquarters),
      employeeCount: employeeCount == null && nullToAbsent
          ? const Value.absent()
          : Value(employeeCount),
      foundedYear: foundedYear == null && nullToAbsent
          ? const Value.absent()
          : Value(foundedYear),
      linkedinUrl: linkedinUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(linkedinUrl),
      tickerSymbol: tickerSymbol == null && nullToAbsent
          ? const Value.absent()
          : Value(tickerSymbol),
      enrichedAt: enrichedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(enrichedAt),
      enrichmentFailed: Value(enrichmentFailed),
      talkingPointsJson: talkingPointsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(talkingPointsJson),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory CompaniesTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CompaniesTableData(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      website: serializer.fromJson<String?>(json['website']),
      industry: serializer.fromJson<String?>(json['industry']),
      description: serializer.fromJson<String?>(json['description']),
      location: serializer.fromJson<String?>(json['location']),
      companySize: serializer.fromJson<String?>(json['companySize']),
      productsServices: serializer.fromJson<String?>(json['productsServices']),
      headquarters: serializer.fromJson<String?>(json['headquarters']),
      employeeCount: serializer.fromJson<String?>(json['employeeCount']),
      foundedYear: serializer.fromJson<String?>(json['foundedYear']),
      linkedinUrl: serializer.fromJson<String?>(json['linkedinUrl']),
      tickerSymbol: serializer.fromJson<String?>(json['tickerSymbol']),
      enrichedAt: serializer.fromJson<DateTime?>(json['enrichedAt']),
      enrichmentFailed: serializer.fromJson<bool>(json['enrichmentFailed']),
      talkingPointsJson: serializer.fromJson<String?>(
        json['talkingPointsJson'],
      ),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'website': serializer.toJson<String?>(website),
      'industry': serializer.toJson<String?>(industry),
      'description': serializer.toJson<String?>(description),
      'location': serializer.toJson<String?>(location),
      'companySize': serializer.toJson<String?>(companySize),
      'productsServices': serializer.toJson<String?>(productsServices),
      'headquarters': serializer.toJson<String?>(headquarters),
      'employeeCount': serializer.toJson<String?>(employeeCount),
      'foundedYear': serializer.toJson<String?>(foundedYear),
      'linkedinUrl': serializer.toJson<String?>(linkedinUrl),
      'tickerSymbol': serializer.toJson<String?>(tickerSymbol),
      'enrichedAt': serializer.toJson<DateTime?>(enrichedAt),
      'enrichmentFailed': serializer.toJson<bool>(enrichmentFailed),
      'talkingPointsJson': serializer.toJson<String?>(talkingPointsJson),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  CompaniesTableData copyWith({
    String? id,
    String? name,
    Value<String?> website = const Value.absent(),
    Value<String?> industry = const Value.absent(),
    Value<String?> description = const Value.absent(),
    Value<String?> location = const Value.absent(),
    Value<String?> companySize = const Value.absent(),
    Value<String?> productsServices = const Value.absent(),
    Value<String?> headquarters = const Value.absent(),
    Value<String?> employeeCount = const Value.absent(),
    Value<String?> foundedYear = const Value.absent(),
    Value<String?> linkedinUrl = const Value.absent(),
    Value<String?> tickerSymbol = const Value.absent(),
    Value<DateTime?> enrichedAt = const Value.absent(),
    bool? enrichmentFailed,
    Value<String?> talkingPointsJson = const Value.absent(),
    Value<DateTime?> createdAt = const Value.absent(),
    DateTime? updatedAt,
  }) => CompaniesTableData(
    id: id ?? this.id,
    name: name ?? this.name,
    website: website.present ? website.value : this.website,
    industry: industry.present ? industry.value : this.industry,
    description: description.present ? description.value : this.description,
    location: location.present ? location.value : this.location,
    companySize: companySize.present ? companySize.value : this.companySize,
    productsServices: productsServices.present
        ? productsServices.value
        : this.productsServices,
    headquarters: headquarters.present ? headquarters.value : this.headquarters,
    employeeCount: employeeCount.present
        ? employeeCount.value
        : this.employeeCount,
    foundedYear: foundedYear.present ? foundedYear.value : this.foundedYear,
    linkedinUrl: linkedinUrl.present ? linkedinUrl.value : this.linkedinUrl,
    tickerSymbol: tickerSymbol.present ? tickerSymbol.value : this.tickerSymbol,
    enrichedAt: enrichedAt.present ? enrichedAt.value : this.enrichedAt,
    enrichmentFailed: enrichmentFailed ?? this.enrichmentFailed,
    talkingPointsJson: talkingPointsJson.present
        ? talkingPointsJson.value
        : this.talkingPointsJson,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CompaniesTableData copyWithCompanion(CompaniesTableCompanion data) {
    return CompaniesTableData(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      website: data.website.present ? data.website.value : this.website,
      industry: data.industry.present ? data.industry.value : this.industry,
      description: data.description.present
          ? data.description.value
          : this.description,
      location: data.location.present ? data.location.value : this.location,
      companySize: data.companySize.present
          ? data.companySize.value
          : this.companySize,
      productsServices: data.productsServices.present
          ? data.productsServices.value
          : this.productsServices,
      headquarters: data.headquarters.present
          ? data.headquarters.value
          : this.headquarters,
      employeeCount: data.employeeCount.present
          ? data.employeeCount.value
          : this.employeeCount,
      foundedYear: data.foundedYear.present
          ? data.foundedYear.value
          : this.foundedYear,
      linkedinUrl: data.linkedinUrl.present
          ? data.linkedinUrl.value
          : this.linkedinUrl,
      tickerSymbol: data.tickerSymbol.present
          ? data.tickerSymbol.value
          : this.tickerSymbol,
      enrichedAt: data.enrichedAt.present
          ? data.enrichedAt.value
          : this.enrichedAt,
      enrichmentFailed: data.enrichmentFailed.present
          ? data.enrichmentFailed.value
          : this.enrichmentFailed,
      talkingPointsJson: data.talkingPointsJson.present
          ? data.talkingPointsJson.value
          : this.talkingPointsJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CompaniesTableData(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('website: $website, ')
          ..write('industry: $industry, ')
          ..write('description: $description, ')
          ..write('location: $location, ')
          ..write('companySize: $companySize, ')
          ..write('productsServices: $productsServices, ')
          ..write('headquarters: $headquarters, ')
          ..write('employeeCount: $employeeCount, ')
          ..write('foundedYear: $foundedYear, ')
          ..write('linkedinUrl: $linkedinUrl, ')
          ..write('tickerSymbol: $tickerSymbol, ')
          ..write('enrichedAt: $enrichedAt, ')
          ..write('enrichmentFailed: $enrichmentFailed, ')
          ..write('talkingPointsJson: $talkingPointsJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    website,
    industry,
    description,
    location,
    companySize,
    productsServices,
    headquarters,
    employeeCount,
    foundedYear,
    linkedinUrl,
    tickerSymbol,
    enrichedAt,
    enrichmentFailed,
    talkingPointsJson,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CompaniesTableData &&
          other.id == this.id &&
          other.name == this.name &&
          other.website == this.website &&
          other.industry == this.industry &&
          other.description == this.description &&
          other.location == this.location &&
          other.companySize == this.companySize &&
          other.productsServices == this.productsServices &&
          other.headquarters == this.headquarters &&
          other.employeeCount == this.employeeCount &&
          other.foundedYear == this.foundedYear &&
          other.linkedinUrl == this.linkedinUrl &&
          other.tickerSymbol == this.tickerSymbol &&
          other.enrichedAt == this.enrichedAt &&
          other.enrichmentFailed == this.enrichmentFailed &&
          other.talkingPointsJson == this.talkingPointsJson &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class CompaniesTableCompanion extends UpdateCompanion<CompaniesTableData> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> website;
  final Value<String?> industry;
  final Value<String?> description;
  final Value<String?> location;
  final Value<String?> companySize;
  final Value<String?> productsServices;
  final Value<String?> headquarters;
  final Value<String?> employeeCount;
  final Value<String?> foundedYear;
  final Value<String?> linkedinUrl;
  final Value<String?> tickerSymbol;
  final Value<DateTime?> enrichedAt;
  final Value<bool> enrichmentFailed;
  final Value<String?> talkingPointsJson;
  final Value<DateTime?> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const CompaniesTableCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.website = const Value.absent(),
    this.industry = const Value.absent(),
    this.description = const Value.absent(),
    this.location = const Value.absent(),
    this.companySize = const Value.absent(),
    this.productsServices = const Value.absent(),
    this.headquarters = const Value.absent(),
    this.employeeCount = const Value.absent(),
    this.foundedYear = const Value.absent(),
    this.linkedinUrl = const Value.absent(),
    this.tickerSymbol = const Value.absent(),
    this.enrichedAt = const Value.absent(),
    this.enrichmentFailed = const Value.absent(),
    this.talkingPointsJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CompaniesTableCompanion.insert({
    required String id,
    required String name,
    this.website = const Value.absent(),
    this.industry = const Value.absent(),
    this.description = const Value.absent(),
    this.location = const Value.absent(),
    this.companySize = const Value.absent(),
    this.productsServices = const Value.absent(),
    this.headquarters = const Value.absent(),
    this.employeeCount = const Value.absent(),
    this.foundedYear = const Value.absent(),
    this.linkedinUrl = const Value.absent(),
    this.tickerSymbol = const Value.absent(),
    this.enrichedAt = const Value.absent(),
    this.enrichmentFailed = const Value.absent(),
    this.talkingPointsJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       updatedAt = Value(updatedAt);
  static Insertable<CompaniesTableData> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? website,
    Expression<String>? industry,
    Expression<String>? description,
    Expression<String>? location,
    Expression<String>? companySize,
    Expression<String>? productsServices,
    Expression<String>? headquarters,
    Expression<String>? employeeCount,
    Expression<String>? foundedYear,
    Expression<String>? linkedinUrl,
    Expression<String>? tickerSymbol,
    Expression<DateTime>? enrichedAt,
    Expression<bool>? enrichmentFailed,
    Expression<String>? talkingPointsJson,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (website != null) 'website': website,
      if (industry != null) 'industry': industry,
      if (description != null) 'description': description,
      if (location != null) 'location': location,
      if (companySize != null) 'company_size': companySize,
      if (productsServices != null) 'products_services': productsServices,
      if (headquarters != null) 'headquarters': headquarters,
      if (employeeCount != null) 'employee_count': employeeCount,
      if (foundedYear != null) 'founded_year': foundedYear,
      if (linkedinUrl != null) 'linkedin_url': linkedinUrl,
      if (tickerSymbol != null) 'ticker_symbol': tickerSymbol,
      if (enrichedAt != null) 'enriched_at': enrichedAt,
      if (enrichmentFailed != null) 'enrichment_failed': enrichmentFailed,
      if (talkingPointsJson != null) 'talking_points_json': talkingPointsJson,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CompaniesTableCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? website,
    Value<String?>? industry,
    Value<String?>? description,
    Value<String?>? location,
    Value<String?>? companySize,
    Value<String?>? productsServices,
    Value<String?>? headquarters,
    Value<String?>? employeeCount,
    Value<String?>? foundedYear,
    Value<String?>? linkedinUrl,
    Value<String?>? tickerSymbol,
    Value<DateTime?>? enrichedAt,
    Value<bool>? enrichmentFailed,
    Value<String?>? talkingPointsJson,
    Value<DateTime?>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return CompaniesTableCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      website: website ?? this.website,
      industry: industry ?? this.industry,
      description: description ?? this.description,
      location: location ?? this.location,
      companySize: companySize ?? this.companySize,
      productsServices: productsServices ?? this.productsServices,
      headquarters: headquarters ?? this.headquarters,
      employeeCount: employeeCount ?? this.employeeCount,
      foundedYear: foundedYear ?? this.foundedYear,
      linkedinUrl: linkedinUrl ?? this.linkedinUrl,
      tickerSymbol: tickerSymbol ?? this.tickerSymbol,
      enrichedAt: enrichedAt ?? this.enrichedAt,
      enrichmentFailed: enrichmentFailed ?? this.enrichmentFailed,
      talkingPointsJson: talkingPointsJson ?? this.talkingPointsJson,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (website.present) {
      map['website'] = Variable<String>(website.value);
    }
    if (industry.present) {
      map['industry'] = Variable<String>(industry.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (location.present) {
      map['location'] = Variable<String>(location.value);
    }
    if (companySize.present) {
      map['company_size'] = Variable<String>(companySize.value);
    }
    if (productsServices.present) {
      map['products_services'] = Variable<String>(productsServices.value);
    }
    if (headquarters.present) {
      map['headquarters'] = Variable<String>(headquarters.value);
    }
    if (employeeCount.present) {
      map['employee_count'] = Variable<String>(employeeCount.value);
    }
    if (foundedYear.present) {
      map['founded_year'] = Variable<String>(foundedYear.value);
    }
    if (linkedinUrl.present) {
      map['linkedin_url'] = Variable<String>(linkedinUrl.value);
    }
    if (tickerSymbol.present) {
      map['ticker_symbol'] = Variable<String>(tickerSymbol.value);
    }
    if (enrichedAt.present) {
      map['enriched_at'] = Variable<DateTime>(enrichedAt.value);
    }
    if (enrichmentFailed.present) {
      map['enrichment_failed'] = Variable<bool>(enrichmentFailed.value);
    }
    if (talkingPointsJson.present) {
      map['talking_points_json'] = Variable<String>(talkingPointsJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CompaniesTableCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('website: $website, ')
          ..write('industry: $industry, ')
          ..write('description: $description, ')
          ..write('location: $location, ')
          ..write('companySize: $companySize, ')
          ..write('productsServices: $productsServices, ')
          ..write('headquarters: $headquarters, ')
          ..write('employeeCount: $employeeCount, ')
          ..write('foundedYear: $foundedYear, ')
          ..write('linkedinUrl: $linkedinUrl, ')
          ..write('tickerSymbol: $tickerSymbol, ')
          ..write('enrichedAt: $enrichedAt, ')
          ..write('enrichmentFailed: $enrichmentFailed, ')
          ..write('talkingPointsJson: $talkingPointsJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FollowUpsTableTable extends FollowUpsTable
    with TableInfo<$FollowUpsTableTable, FollowUpsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FollowUpsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contactIdMeta = const VerificationMeta(
    'contactId',
  );
  @override
  late final GeneratedColumn<String> contactId = GeneratedColumn<String>(
    'contact_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eventIdMeta = const VerificationMeta(
    'eventId',
  );
  @override
  late final GeneratedColumn<String> eventId = GeneratedColumn<String>(
    'event_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('new'),
  );
  static const VerificationMeta _channelMeta = const VerificationMeta(
    'channel',
  );
  @override
  late final GeneratedColumn<String> channel = GeneratedColumn<String>(
    'channel',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('email'),
  );
  static const VerificationMeta _lastInteractionAtMeta = const VerificationMeta(
    'lastInteractionAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastInteractionAt =
      GeneratedColumn<DateTime>(
        'last_interaction_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _doneAtMeta = const VerificationMeta('doneAt');
  @override
  late final GeneratedColumn<DateTime> doneAt = GeneratedColumn<DateTime>(
    'done_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    contactId,
    eventId,
    status,
    channel,
    lastInteractionAt,
    doneAt,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'follow_ups';
  @override
  VerificationContext validateIntegrity(
    Insertable<FollowUpsTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    }
    if (data.containsKey('contact_id')) {
      context.handle(
        _contactIdMeta,
        contactId.isAcceptableOrUnknown(data['contact_id']!, _contactIdMeta),
      );
    } else if (isInserting) {
      context.missing(_contactIdMeta);
    }
    if (data.containsKey('event_id')) {
      context.handle(
        _eventIdMeta,
        eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('channel')) {
      context.handle(
        _channelMeta,
        channel.isAcceptableOrUnknown(data['channel']!, _channelMeta),
      );
    }
    if (data.containsKey('last_interaction_at')) {
      context.handle(
        _lastInteractionAtMeta,
        lastInteractionAt.isAcceptableOrUnknown(
          data['last_interaction_at']!,
          _lastInteractionAtMeta,
        ),
      );
    }
    if (data.containsKey('done_at')) {
      context.handle(
        _doneAtMeta,
        doneAt.isAcceptableOrUnknown(data['done_at']!, _doneAtMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FollowUpsTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FollowUpsTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      ),
      contactId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}contact_id'],
      )!,
      eventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_id'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      channel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}channel'],
      )!,
      lastInteractionAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_interaction_at'],
      ),
      doneAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}done_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $FollowUpsTableTable createAlias(String alias) {
    return $FollowUpsTableTable(attachedDatabase, alias);
  }
}

class FollowUpsTableData extends DataClass
    implements Insertable<FollowUpsTableData> {
  final String id;
  final String? userId;
  final String contactId;
  final String? eventId;
  final String status;
  final String channel;
  final DateTime? lastInteractionAt;
  final DateTime? doneAt;
  final DateTime? createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const FollowUpsTableData({
    required this.id,
    this.userId,
    required this.contactId,
    this.eventId,
    required this.status,
    required this.channel,
    this.lastInteractionAt,
    this.doneAt,
    this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || userId != null) {
      map['user_id'] = Variable<String>(userId);
    }
    map['contact_id'] = Variable<String>(contactId);
    if (!nullToAbsent || eventId != null) {
      map['event_id'] = Variable<String>(eventId);
    }
    map['status'] = Variable<String>(status);
    map['channel'] = Variable<String>(channel);
    if (!nullToAbsent || lastInteractionAt != null) {
      map['last_interaction_at'] = Variable<DateTime>(lastInteractionAt);
    }
    if (!nullToAbsent || doneAt != null) {
      map['done_at'] = Variable<DateTime>(doneAt);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  FollowUpsTableCompanion toCompanion(bool nullToAbsent) {
    return FollowUpsTableCompanion(
      id: Value(id),
      userId: userId == null && nullToAbsent
          ? const Value.absent()
          : Value(userId),
      contactId: Value(contactId),
      eventId: eventId == null && nullToAbsent
          ? const Value.absent()
          : Value(eventId),
      status: Value(status),
      channel: Value(channel),
      lastInteractionAt: lastInteractionAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastInteractionAt),
      doneAt: doneAt == null && nullToAbsent
          ? const Value.absent()
          : Value(doneAt),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory FollowUpsTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FollowUpsTableData(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String?>(json['userId']),
      contactId: serializer.fromJson<String>(json['contactId']),
      eventId: serializer.fromJson<String?>(json['eventId']),
      status: serializer.fromJson<String>(json['status']),
      channel: serializer.fromJson<String>(json['channel']),
      lastInteractionAt: serializer.fromJson<DateTime?>(
        json['lastInteractionAt'],
      ),
      doneAt: serializer.fromJson<DateTime?>(json['doneAt']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String?>(userId),
      'contactId': serializer.toJson<String>(contactId),
      'eventId': serializer.toJson<String?>(eventId),
      'status': serializer.toJson<String>(status),
      'channel': serializer.toJson<String>(channel),
      'lastInteractionAt': serializer.toJson<DateTime?>(lastInteractionAt),
      'doneAt': serializer.toJson<DateTime?>(doneAt),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  FollowUpsTableData copyWith({
    String? id,
    Value<String?> userId = const Value.absent(),
    String? contactId,
    Value<String?> eventId = const Value.absent(),
    String? status,
    String? channel,
    Value<DateTime?> lastInteractionAt = const Value.absent(),
    Value<DateTime?> doneAt = const Value.absent(),
    Value<DateTime?> createdAt = const Value.absent(),
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => FollowUpsTableData(
    id: id ?? this.id,
    userId: userId.present ? userId.value : this.userId,
    contactId: contactId ?? this.contactId,
    eventId: eventId.present ? eventId.value : this.eventId,
    status: status ?? this.status,
    channel: channel ?? this.channel,
    lastInteractionAt: lastInteractionAt.present
        ? lastInteractionAt.value
        : this.lastInteractionAt,
    doneAt: doneAt.present ? doneAt.value : this.doneAt,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  FollowUpsTableData copyWithCompanion(FollowUpsTableCompanion data) {
    return FollowUpsTableData(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      contactId: data.contactId.present ? data.contactId.value : this.contactId,
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      status: data.status.present ? data.status.value : this.status,
      channel: data.channel.present ? data.channel.value : this.channel,
      lastInteractionAt: data.lastInteractionAt.present
          ? data.lastInteractionAt.value
          : this.lastInteractionAt,
      doneAt: data.doneAt.present ? data.doneAt.value : this.doneAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FollowUpsTableData(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('contactId: $contactId, ')
          ..write('eventId: $eventId, ')
          ..write('status: $status, ')
          ..write('channel: $channel, ')
          ..write('lastInteractionAt: $lastInteractionAt, ')
          ..write('doneAt: $doneAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    contactId,
    eventId,
    status,
    channel,
    lastInteractionAt,
    doneAt,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FollowUpsTableData &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.contactId == this.contactId &&
          other.eventId == this.eventId &&
          other.status == this.status &&
          other.channel == this.channel &&
          other.lastInteractionAt == this.lastInteractionAt &&
          other.doneAt == this.doneAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class FollowUpsTableCompanion extends UpdateCompanion<FollowUpsTableData> {
  final Value<String> id;
  final Value<String?> userId;
  final Value<String> contactId;
  final Value<String?> eventId;
  final Value<String> status;
  final Value<String> channel;
  final Value<DateTime?> lastInteractionAt;
  final Value<DateTime?> doneAt;
  final Value<DateTime?> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const FollowUpsTableCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.contactId = const Value.absent(),
    this.eventId = const Value.absent(),
    this.status = const Value.absent(),
    this.channel = const Value.absent(),
    this.lastInteractionAt = const Value.absent(),
    this.doneAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FollowUpsTableCompanion.insert({
    required String id,
    this.userId = const Value.absent(),
    required String contactId,
    this.eventId = const Value.absent(),
    this.status = const Value.absent(),
    this.channel = const Value.absent(),
    this.lastInteractionAt = const Value.absent(),
    this.doneAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       contactId = Value(contactId),
       updatedAt = Value(updatedAt);
  static Insertable<FollowUpsTableData> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? contactId,
    Expression<String>? eventId,
    Expression<String>? status,
    Expression<String>? channel,
    Expression<DateTime>? lastInteractionAt,
    Expression<DateTime>? doneAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (contactId != null) 'contact_id': contactId,
      if (eventId != null) 'event_id': eventId,
      if (status != null) 'status': status,
      if (channel != null) 'channel': channel,
      if (lastInteractionAt != null) 'last_interaction_at': lastInteractionAt,
      if (doneAt != null) 'done_at': doneAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FollowUpsTableCompanion copyWith({
    Value<String>? id,
    Value<String?>? userId,
    Value<String>? contactId,
    Value<String?>? eventId,
    Value<String>? status,
    Value<String>? channel,
    Value<DateTime?>? lastInteractionAt,
    Value<DateTime?>? doneAt,
    Value<DateTime?>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return FollowUpsTableCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      contactId: contactId ?? this.contactId,
      eventId: eventId ?? this.eventId,
      status: status ?? this.status,
      channel: channel ?? this.channel,
      lastInteractionAt: lastInteractionAt ?? this.lastInteractionAt,
      doneAt: doneAt ?? this.doneAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (contactId.present) {
      map['contact_id'] = Variable<String>(contactId.value);
    }
    if (eventId.present) {
      map['event_id'] = Variable<String>(eventId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (channel.present) {
      map['channel'] = Variable<String>(channel.value);
    }
    if (lastInteractionAt.present) {
      map['last_interaction_at'] = Variable<DateTime>(lastInteractionAt.value);
    }
    if (doneAt.present) {
      map['done_at'] = Variable<DateTime>(doneAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FollowUpsTableCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('contactId: $contactId, ')
          ..write('eventId: $eventId, ')
          ..write('status: $status, ')
          ..write('channel: $channel, ')
          ..write('lastInteractionAt: $lastInteractionAt, ')
          ..write('doneAt: $doneAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TargetCompanyMetTableTable extends TargetCompanyMetTable
    with TableInfo<$TargetCompanyMetTableTable, TargetCompanyMetTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TargetCompanyMetTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _eventIdMeta = const VerificationMeta(
    'eventId',
  );
  @override
  late final GeneratedColumn<String> eventId = GeneratedColumn<String>(
    'event_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _targetIdMeta = const VerificationMeta(
    'targetId',
  );
  @override
  late final GeneratedColumn<String> targetId = GeneratedColumn<String>(
    'target_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _metMeta = const VerificationMeta('met');
  @override
  late final GeneratedColumn<bool> met = GeneratedColumn<bool>(
    'met',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("met" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    eventId,
    targetId,
    met,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'target_company_met';
  @override
  VerificationContext validateIntegrity(
    Insertable<TargetCompanyMetTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    }
    if (data.containsKey('event_id')) {
      context.handle(
        _eventIdMeta,
        eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta),
      );
    }
    if (data.containsKey('target_id')) {
      context.handle(
        _targetIdMeta,
        targetId.isAcceptableOrUnknown(data['target_id']!, _targetIdMeta),
      );
    }
    if (data.containsKey('met')) {
      context.handle(
        _metMeta,
        met.isAcceptableOrUnknown(data['met']!, _metMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TargetCompanyMetTableData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TargetCompanyMetTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      ),
      eventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_id'],
      ),
      targetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_id'],
      ),
      met: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}met'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $TargetCompanyMetTableTable createAlias(String alias) {
    return $TargetCompanyMetTableTable(attachedDatabase, alias);
  }
}

class TargetCompanyMetTableData extends DataClass
    implements Insertable<TargetCompanyMetTableData> {
  final String id;
  final String? userId;
  final String? eventId;
  final String? targetId;
  final bool met;
  final DateTime? createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const TargetCompanyMetTableData({
    required this.id,
    this.userId,
    this.eventId,
    this.targetId,
    required this.met,
    this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || userId != null) {
      map['user_id'] = Variable<String>(userId);
    }
    if (!nullToAbsent || eventId != null) {
      map['event_id'] = Variable<String>(eventId);
    }
    if (!nullToAbsent || targetId != null) {
      map['target_id'] = Variable<String>(targetId);
    }
    map['met'] = Variable<bool>(met);
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  TargetCompanyMetTableCompanion toCompanion(bool nullToAbsent) {
    return TargetCompanyMetTableCompanion(
      id: Value(id),
      userId: userId == null && nullToAbsent
          ? const Value.absent()
          : Value(userId),
      eventId: eventId == null && nullToAbsent
          ? const Value.absent()
          : Value(eventId),
      targetId: targetId == null && nullToAbsent
          ? const Value.absent()
          : Value(targetId),
      met: Value(met),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory TargetCompanyMetTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TargetCompanyMetTableData(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String?>(json['userId']),
      eventId: serializer.fromJson<String?>(json['eventId']),
      targetId: serializer.fromJson<String?>(json['targetId']),
      met: serializer.fromJson<bool>(json['met']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String?>(userId),
      'eventId': serializer.toJson<String?>(eventId),
      'targetId': serializer.toJson<String?>(targetId),
      'met': serializer.toJson<bool>(met),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  TargetCompanyMetTableData copyWith({
    String? id,
    Value<String?> userId = const Value.absent(),
    Value<String?> eventId = const Value.absent(),
    Value<String?> targetId = const Value.absent(),
    bool? met,
    Value<DateTime?> createdAt = const Value.absent(),
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => TargetCompanyMetTableData(
    id: id ?? this.id,
    userId: userId.present ? userId.value : this.userId,
    eventId: eventId.present ? eventId.value : this.eventId,
    targetId: targetId.present ? targetId.value : this.targetId,
    met: met ?? this.met,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  TargetCompanyMetTableData copyWithCompanion(
    TargetCompanyMetTableCompanion data,
  ) {
    return TargetCompanyMetTableData(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      targetId: data.targetId.present ? data.targetId.value : this.targetId,
      met: data.met.present ? data.met.value : this.met,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TargetCompanyMetTableData(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('eventId: $eventId, ')
          ..write('targetId: $targetId, ')
          ..write('met: $met, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    eventId,
    targetId,
    met,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TargetCompanyMetTableData &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.eventId == this.eventId &&
          other.targetId == this.targetId &&
          other.met == this.met &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class TargetCompanyMetTableCompanion
    extends UpdateCompanion<TargetCompanyMetTableData> {
  final Value<String> id;
  final Value<String?> userId;
  final Value<String?> eventId;
  final Value<String?> targetId;
  final Value<bool> met;
  final Value<DateTime?> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const TargetCompanyMetTableCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.eventId = const Value.absent(),
    this.targetId = const Value.absent(),
    this.met = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TargetCompanyMetTableCompanion.insert({
    required String id,
    this.userId = const Value.absent(),
    this.eventId = const Value.absent(),
    this.targetId = const Value.absent(),
    this.met = const Value.absent(),
    this.createdAt = const Value.absent(),
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       updatedAt = Value(updatedAt);
  static Insertable<TargetCompanyMetTableData> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? eventId,
    Expression<String>? targetId,
    Expression<bool>? met,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (eventId != null) 'event_id': eventId,
      if (targetId != null) 'target_id': targetId,
      if (met != null) 'met': met,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TargetCompanyMetTableCompanion copyWith({
    Value<String>? id,
    Value<String?>? userId,
    Value<String?>? eventId,
    Value<String?>? targetId,
    Value<bool>? met,
    Value<DateTime?>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return TargetCompanyMetTableCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      eventId: eventId ?? this.eventId,
      targetId: targetId ?? this.targetId,
      met: met ?? this.met,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (eventId.present) {
      map['event_id'] = Variable<String>(eventId.value);
    }
    if (targetId.present) {
      map['target_id'] = Variable<String>(targetId.value);
    }
    if (met.present) {
      map['met'] = Variable<bool>(met.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TargetCompanyMetTableCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('eventId: $eventId, ')
          ..write('targetId: $targetId, ')
          ..write('met: $met, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncStateTableTable extends SyncStateTable
    with TableInfo<$SyncStateTableTable, SyncStateTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncStateTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _tableName_Meta = const VerificationMeta(
    'tableName_',
  );
  @override
  late final GeneratedColumn<String> tableName_ = GeneratedColumn<String>(
    'table_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSyncedAtMeta = const VerificationMeta(
    'lastSyncedAt',
  );
  @override
  late final GeneratedColumn<String> lastSyncedAt = GeneratedColumn<String>(
    'last_synced_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [tableName_, lastSyncedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncStateTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('table_name')) {
      context.handle(
        _tableName_Meta,
        tableName_.isAcceptableOrUnknown(data['table_name']!, _tableName_Meta),
      );
    } else if (isInserting) {
      context.missing(_tableName_Meta);
    }
    if (data.containsKey('last_synced_at')) {
      context.handle(
        _lastSyncedAtMeta,
        lastSyncedAt.isAcceptableOrUnknown(
          data['last_synced_at']!,
          _lastSyncedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {tableName_};
  @override
  SyncStateTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncStateTableData(
      tableName_: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}table_name'],
      )!,
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_synced_at'],
      ),
    );
  }

  @override
  $SyncStateTableTable createAlias(String alias) {
    return $SyncStateTableTable(attachedDatabase, alias);
  }
}

class SyncStateTableData extends DataClass
    implements Insertable<SyncStateTableData> {
  final String tableName_;
  final String? lastSyncedAt;
  const SyncStateTableData({required this.tableName_, this.lastSyncedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['table_name'] = Variable<String>(tableName_);
    if (!nullToAbsent || lastSyncedAt != null) {
      map['last_synced_at'] = Variable<String>(lastSyncedAt);
    }
    return map;
  }

  SyncStateTableCompanion toCompanion(bool nullToAbsent) {
    return SyncStateTableCompanion(
      tableName_: Value(tableName_),
      lastSyncedAt: lastSyncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncedAt),
    );
  }

  factory SyncStateTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncStateTableData(
      tableName_: serializer.fromJson<String>(json['tableName_']),
      lastSyncedAt: serializer.fromJson<String?>(json['lastSyncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'tableName_': serializer.toJson<String>(tableName_),
      'lastSyncedAt': serializer.toJson<String?>(lastSyncedAt),
    };
  }

  SyncStateTableData copyWith({
    String? tableName_,
    Value<String?> lastSyncedAt = const Value.absent(),
  }) => SyncStateTableData(
    tableName_: tableName_ ?? this.tableName_,
    lastSyncedAt: lastSyncedAt.present ? lastSyncedAt.value : this.lastSyncedAt,
  );
  SyncStateTableData copyWithCompanion(SyncStateTableCompanion data) {
    return SyncStateTableData(
      tableName_: data.tableName_.present
          ? data.tableName_.value
          : this.tableName_,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateTableData(')
          ..write('tableName_: $tableName_, ')
          ..write('lastSyncedAt: $lastSyncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(tableName_, lastSyncedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncStateTableData &&
          other.tableName_ == this.tableName_ &&
          other.lastSyncedAt == this.lastSyncedAt);
}

class SyncStateTableCompanion extends UpdateCompanion<SyncStateTableData> {
  final Value<String> tableName_;
  final Value<String?> lastSyncedAt;
  final Value<int> rowid;
  const SyncStateTableCompanion({
    this.tableName_ = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncStateTableCompanion.insert({
    required String tableName_,
    this.lastSyncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : tableName_ = Value(tableName_);
  static Insertable<SyncStateTableData> custom({
    Expression<String>? tableName_,
    Expression<String>? lastSyncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (tableName_ != null) 'table_name': tableName_,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncStateTableCompanion copyWith({
    Value<String>? tableName_,
    Value<String?>? lastSyncedAt,
    Value<int>? rowid,
  }) {
    return SyncStateTableCompanion(
      tableName_: tableName_ ?? this.tableName_,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (tableName_.present) {
      map['table_name'] = Variable<String>(tableName_.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<String>(lastSyncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateTableCompanion(')
          ..write('tableName_: $tableName_, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $EventsTableTable eventsTable = $EventsTableTable(this);
  late final $ContactsTableTable contactsTable = $ContactsTableTable(this);
  late final $CapturesTableTable capturesTable = $CapturesTableTable(this);
  late final $TargetCompaniesTableTable targetCompaniesTable =
      $TargetCompaniesTableTable(this);
  late final $ContactEventsTableTable contactEventsTable =
      $ContactEventsTableTable(this);
  late final $EventGoalsTableTable eventGoalsTable = $EventGoalsTableTable(
    this,
  );
  late final $EmailDraftsTableTable emailDraftsTable = $EmailDraftsTableTable(
    this,
  );
  late final $InteractionsTableTable interactionsTable =
      $InteractionsTableTable(this);
  late final $CompaniesTableTable companiesTable = $CompaniesTableTable(this);
  late final $FollowUpsTableTable followUpsTable = $FollowUpsTableTable(this);
  late final $TargetCompanyMetTableTable targetCompanyMetTable =
      $TargetCompanyMetTableTable(this);
  late final $SyncStateTableTable syncStateTable = $SyncStateTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    eventsTable,
    contactsTable,
    capturesTable,
    targetCompaniesTable,
    contactEventsTable,
    eventGoalsTable,
    emailDraftsTable,
    interactionsTable,
    companiesTable,
    followUpsTable,
    targetCompanyMetTable,
    syncStateTable,
  ];
}

typedef $$EventsTableTableCreateCompanionBuilder =
    EventsTableCompanion Function({
      required String id,
      Value<String?> userId,
      required String name,
      Value<String?> location,
      required DateTime startDate,
      Value<DateTime?> endDate,
      Value<String?> startTime,
      Value<String?> endTime,
      Value<String?> eventType,
      Value<DateTime?> createdAt,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$EventsTableTableUpdateCompanionBuilder =
    EventsTableCompanion Function({
      Value<String> id,
      Value<String?> userId,
      Value<String> name,
      Value<String?> location,
      Value<DateTime> startDate,
      Value<DateTime?> endDate,
      Value<String?> startTime,
      Value<String?> endTime,
      Value<String?> eventType,
      Value<DateTime?> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

class $$EventsTableTableFilterComposer
    extends Composer<_$AppDatabase, $EventsTableTable> {
  $$EventsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startTime => $composableBuilder(
    column: $table.startTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get endTime => $composableBuilder(
    column: $table.endTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eventType => $composableBuilder(
    column: $table.eventType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EventsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $EventsTableTable> {
  $$EventsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startTime => $composableBuilder(
    column: $table.startTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get endTime => $composableBuilder(
    column: $table.endTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eventType => $composableBuilder(
    column: $table.eventType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EventsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $EventsTableTable> {
  $$EventsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get location =>
      $composableBuilder(column: $table.location, builder: (column) => column);

  GeneratedColumn<DateTime> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<DateTime> get endDate =>
      $composableBuilder(column: $table.endDate, builder: (column) => column);

  GeneratedColumn<String> get startTime =>
      $composableBuilder(column: $table.startTime, builder: (column) => column);

  GeneratedColumn<String> get endTime =>
      $composableBuilder(column: $table.endTime, builder: (column) => column);

  GeneratedColumn<String> get eventType =>
      $composableBuilder(column: $table.eventType, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$EventsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EventsTableTable,
          EventsTableData,
          $$EventsTableTableFilterComposer,
          $$EventsTableTableOrderingComposer,
          $$EventsTableTableAnnotationComposer,
          $$EventsTableTableCreateCompanionBuilder,
          $$EventsTableTableUpdateCompanionBuilder,
          (
            EventsTableData,
            BaseReferences<_$AppDatabase, $EventsTableTable, EventsTableData>,
          ),
          EventsTableData,
          PrefetchHooks Function()
        > {
  $$EventsTableTableTableManager(_$AppDatabase db, $EventsTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EventsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EventsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EventsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> userId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> location = const Value.absent(),
                Value<DateTime> startDate = const Value.absent(),
                Value<DateTime?> endDate = const Value.absent(),
                Value<String?> startTime = const Value.absent(),
                Value<String?> endTime = const Value.absent(),
                Value<String?> eventType = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EventsTableCompanion(
                id: id,
                userId: userId,
                name: name,
                location: location,
                startDate: startDate,
                endDate: endDate,
                startTime: startTime,
                endTime: endTime,
                eventType: eventType,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> userId = const Value.absent(),
                required String name,
                Value<String?> location = const Value.absent(),
                required DateTime startDate,
                Value<DateTime?> endDate = const Value.absent(),
                Value<String?> startTime = const Value.absent(),
                Value<String?> endTime = const Value.absent(),
                Value<String?> eventType = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EventsTableCompanion.insert(
                id: id,
                userId: userId,
                name: name,
                location: location,
                startDate: startDate,
                endDate: endDate,
                startTime: startTime,
                endTime: endTime,
                eventType: eventType,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EventsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EventsTableTable,
      EventsTableData,
      $$EventsTableTableFilterComposer,
      $$EventsTableTableOrderingComposer,
      $$EventsTableTableAnnotationComposer,
      $$EventsTableTableCreateCompanionBuilder,
      $$EventsTableTableUpdateCompanionBuilder,
      (
        EventsTableData,
        BaseReferences<_$AppDatabase, $EventsTableTable, EventsTableData>,
      ),
      EventsTableData,
      PrefetchHooks Function()
    >;
typedef $$ContactsTableTableCreateCompanionBuilder =
    ContactsTableCompanion Function({
      required String id,
      Value<String?> userId,
      Value<String?> companyId,
      required String firstName,
      Value<String?> lastName,
      Value<String?> email,
      Value<String?> phone,
      Value<String?> jobTitle,
      Value<String?> linkedinUrl,
      Value<String?> notes,
      Value<String?> avatarUrl,
      Value<String> followUpStatus,
      Value<DateTime?> lastContactedAt,
      Value<String?> contactAssetsJson,
      Value<String?> scannedDetailsJson,
      Value<String?> aiInsightsJson,
      Value<String?> aiContextSummary,
      Value<DateTime?> createdAt,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$ContactsTableTableUpdateCompanionBuilder =
    ContactsTableCompanion Function({
      Value<String> id,
      Value<String?> userId,
      Value<String?> companyId,
      Value<String> firstName,
      Value<String?> lastName,
      Value<String?> email,
      Value<String?> phone,
      Value<String?> jobTitle,
      Value<String?> linkedinUrl,
      Value<String?> notes,
      Value<String?> avatarUrl,
      Value<String> followUpStatus,
      Value<DateTime?> lastContactedAt,
      Value<String?> contactAssetsJson,
      Value<String?> scannedDetailsJson,
      Value<String?> aiInsightsJson,
      Value<String?> aiContextSummary,
      Value<DateTime?> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

class $$ContactsTableTableFilterComposer
    extends Composer<_$AppDatabase, $ContactsTableTable> {
  $$ContactsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get companyId => $composableBuilder(
    column: $table.companyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get firstName => $composableBuilder(
    column: $table.firstName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastName => $composableBuilder(
    column: $table.lastName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get jobTitle => $composableBuilder(
    column: $table.jobTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get linkedinUrl => $composableBuilder(
    column: $table.linkedinUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get avatarUrl => $composableBuilder(
    column: $table.avatarUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get followUpStatus => $composableBuilder(
    column: $table.followUpStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastContactedAt => $composableBuilder(
    column: $table.lastContactedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contactAssetsJson => $composableBuilder(
    column: $table.contactAssetsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scannedDetailsJson => $composableBuilder(
    column: $table.scannedDetailsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get aiInsightsJson => $composableBuilder(
    column: $table.aiInsightsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get aiContextSummary => $composableBuilder(
    column: $table.aiContextSummary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ContactsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ContactsTableTable> {
  $$ContactsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get companyId => $composableBuilder(
    column: $table.companyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get firstName => $composableBuilder(
    column: $table.firstName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastName => $composableBuilder(
    column: $table.lastName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get jobTitle => $composableBuilder(
    column: $table.jobTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get linkedinUrl => $composableBuilder(
    column: $table.linkedinUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get avatarUrl => $composableBuilder(
    column: $table.avatarUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get followUpStatus => $composableBuilder(
    column: $table.followUpStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastContactedAt => $composableBuilder(
    column: $table.lastContactedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contactAssetsJson => $composableBuilder(
    column: $table.contactAssetsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scannedDetailsJson => $composableBuilder(
    column: $table.scannedDetailsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get aiInsightsJson => $composableBuilder(
    column: $table.aiInsightsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get aiContextSummary => $composableBuilder(
    column: $table.aiContextSummary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ContactsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ContactsTableTable> {
  $$ContactsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get companyId =>
      $composableBuilder(column: $table.companyId, builder: (column) => column);

  GeneratedColumn<String> get firstName =>
      $composableBuilder(column: $table.firstName, builder: (column) => column);

  GeneratedColumn<String> get lastName =>
      $composableBuilder(column: $table.lastName, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get jobTitle =>
      $composableBuilder(column: $table.jobTitle, builder: (column) => column);

  GeneratedColumn<String> get linkedinUrl => $composableBuilder(
    column: $table.linkedinUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get avatarUrl =>
      $composableBuilder(column: $table.avatarUrl, builder: (column) => column);

  GeneratedColumn<String> get followUpStatus => $composableBuilder(
    column: $table.followUpStatus,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastContactedAt => $composableBuilder(
    column: $table.lastContactedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get contactAssetsJson => $composableBuilder(
    column: $table.contactAssetsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get scannedDetailsJson => $composableBuilder(
    column: $table.scannedDetailsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get aiInsightsJson => $composableBuilder(
    column: $table.aiInsightsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get aiContextSummary => $composableBuilder(
    column: $table.aiContextSummary,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$ContactsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ContactsTableTable,
          ContactsTableData,
          $$ContactsTableTableFilterComposer,
          $$ContactsTableTableOrderingComposer,
          $$ContactsTableTableAnnotationComposer,
          $$ContactsTableTableCreateCompanionBuilder,
          $$ContactsTableTableUpdateCompanionBuilder,
          (
            ContactsTableData,
            BaseReferences<
              _$AppDatabase,
              $ContactsTableTable,
              ContactsTableData
            >,
          ),
          ContactsTableData,
          PrefetchHooks Function()
        > {
  $$ContactsTableTableTableManager(_$AppDatabase db, $ContactsTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ContactsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ContactsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ContactsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> userId = const Value.absent(),
                Value<String?> companyId = const Value.absent(),
                Value<String> firstName = const Value.absent(),
                Value<String?> lastName = const Value.absent(),
                Value<String?> email = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<String?> jobTitle = const Value.absent(),
                Value<String?> linkedinUrl = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> avatarUrl = const Value.absent(),
                Value<String> followUpStatus = const Value.absent(),
                Value<DateTime?> lastContactedAt = const Value.absent(),
                Value<String?> contactAssetsJson = const Value.absent(),
                Value<String?> scannedDetailsJson = const Value.absent(),
                Value<String?> aiInsightsJson = const Value.absent(),
                Value<String?> aiContextSummary = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ContactsTableCompanion(
                id: id,
                userId: userId,
                companyId: companyId,
                firstName: firstName,
                lastName: lastName,
                email: email,
                phone: phone,
                jobTitle: jobTitle,
                linkedinUrl: linkedinUrl,
                notes: notes,
                avatarUrl: avatarUrl,
                followUpStatus: followUpStatus,
                lastContactedAt: lastContactedAt,
                contactAssetsJson: contactAssetsJson,
                scannedDetailsJson: scannedDetailsJson,
                aiInsightsJson: aiInsightsJson,
                aiContextSummary: aiContextSummary,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> userId = const Value.absent(),
                Value<String?> companyId = const Value.absent(),
                required String firstName,
                Value<String?> lastName = const Value.absent(),
                Value<String?> email = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<String?> jobTitle = const Value.absent(),
                Value<String?> linkedinUrl = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> avatarUrl = const Value.absent(),
                Value<String> followUpStatus = const Value.absent(),
                Value<DateTime?> lastContactedAt = const Value.absent(),
                Value<String?> contactAssetsJson = const Value.absent(),
                Value<String?> scannedDetailsJson = const Value.absent(),
                Value<String?> aiInsightsJson = const Value.absent(),
                Value<String?> aiContextSummary = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ContactsTableCompanion.insert(
                id: id,
                userId: userId,
                companyId: companyId,
                firstName: firstName,
                lastName: lastName,
                email: email,
                phone: phone,
                jobTitle: jobTitle,
                linkedinUrl: linkedinUrl,
                notes: notes,
                avatarUrl: avatarUrl,
                followUpStatus: followUpStatus,
                lastContactedAt: lastContactedAt,
                contactAssetsJson: contactAssetsJson,
                scannedDetailsJson: scannedDetailsJson,
                aiInsightsJson: aiInsightsJson,
                aiContextSummary: aiContextSummary,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ContactsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ContactsTableTable,
      ContactsTableData,
      $$ContactsTableTableFilterComposer,
      $$ContactsTableTableOrderingComposer,
      $$ContactsTableTableAnnotationComposer,
      $$ContactsTableTableCreateCompanionBuilder,
      $$ContactsTableTableUpdateCompanionBuilder,
      (
        ContactsTableData,
        BaseReferences<_$AppDatabase, $ContactsTableTable, ContactsTableData>,
      ),
      ContactsTableData,
      PrefetchHooks Function()
    >;
typedef $$CapturesTableTableCreateCompanionBuilder =
    CapturesTableCompanion Function({
      required String id,
      Value<String?> userId,
      Value<String?> eventId,
      Value<String?> contactId,
      required String captureType,
      Value<String?> imageUrl,
      Value<String?> rawDataJson,
      Value<String?> extractedDataJson,
      Value<String> status,
      Value<String?> clientOpId,
      Value<DateTime?> createdAt,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$CapturesTableTableUpdateCompanionBuilder =
    CapturesTableCompanion Function({
      Value<String> id,
      Value<String?> userId,
      Value<String?> eventId,
      Value<String?> contactId,
      Value<String> captureType,
      Value<String?> imageUrl,
      Value<String?> rawDataJson,
      Value<String?> extractedDataJson,
      Value<String> status,
      Value<String?> clientOpId,
      Value<DateTime?> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

class $$CapturesTableTableFilterComposer
    extends Composer<_$AppDatabase, $CapturesTableTable> {
  $$CapturesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contactId => $composableBuilder(
    column: $table.contactId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get captureType => $composableBuilder(
    column: $table.captureType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawDataJson => $composableBuilder(
    column: $table.rawDataJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get extractedDataJson => $composableBuilder(
    column: $table.extractedDataJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get clientOpId => $composableBuilder(
    column: $table.clientOpId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CapturesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $CapturesTableTable> {
  $$CapturesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contactId => $composableBuilder(
    column: $table.contactId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get captureType => $composableBuilder(
    column: $table.captureType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawDataJson => $composableBuilder(
    column: $table.rawDataJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get extractedDataJson => $composableBuilder(
    column: $table.extractedDataJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clientOpId => $composableBuilder(
    column: $table.clientOpId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CapturesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $CapturesTableTable> {
  $$CapturesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get eventId =>
      $composableBuilder(column: $table.eventId, builder: (column) => column);

  GeneratedColumn<String> get contactId =>
      $composableBuilder(column: $table.contactId, builder: (column) => column);

  GeneratedColumn<String> get captureType => $composableBuilder(
    column: $table.captureType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => column);

  GeneratedColumn<String> get rawDataJson => $composableBuilder(
    column: $table.rawDataJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get extractedDataJson => $composableBuilder(
    column: $table.extractedDataJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get clientOpId => $composableBuilder(
    column: $table.clientOpId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$CapturesTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CapturesTableTable,
          CapturesTableData,
          $$CapturesTableTableFilterComposer,
          $$CapturesTableTableOrderingComposer,
          $$CapturesTableTableAnnotationComposer,
          $$CapturesTableTableCreateCompanionBuilder,
          $$CapturesTableTableUpdateCompanionBuilder,
          (
            CapturesTableData,
            BaseReferences<
              _$AppDatabase,
              $CapturesTableTable,
              CapturesTableData
            >,
          ),
          CapturesTableData,
          PrefetchHooks Function()
        > {
  $$CapturesTableTableTableManager(_$AppDatabase db, $CapturesTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CapturesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CapturesTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CapturesTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> userId = const Value.absent(),
                Value<String?> eventId = const Value.absent(),
                Value<String?> contactId = const Value.absent(),
                Value<String> captureType = const Value.absent(),
                Value<String?> imageUrl = const Value.absent(),
                Value<String?> rawDataJson = const Value.absent(),
                Value<String?> extractedDataJson = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> clientOpId = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CapturesTableCompanion(
                id: id,
                userId: userId,
                eventId: eventId,
                contactId: contactId,
                captureType: captureType,
                imageUrl: imageUrl,
                rawDataJson: rawDataJson,
                extractedDataJson: extractedDataJson,
                status: status,
                clientOpId: clientOpId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> userId = const Value.absent(),
                Value<String?> eventId = const Value.absent(),
                Value<String?> contactId = const Value.absent(),
                required String captureType,
                Value<String?> imageUrl = const Value.absent(),
                Value<String?> rawDataJson = const Value.absent(),
                Value<String?> extractedDataJson = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> clientOpId = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CapturesTableCompanion.insert(
                id: id,
                userId: userId,
                eventId: eventId,
                contactId: contactId,
                captureType: captureType,
                imageUrl: imageUrl,
                rawDataJson: rawDataJson,
                extractedDataJson: extractedDataJson,
                status: status,
                clientOpId: clientOpId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CapturesTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CapturesTableTable,
      CapturesTableData,
      $$CapturesTableTableFilterComposer,
      $$CapturesTableTableOrderingComposer,
      $$CapturesTableTableAnnotationComposer,
      $$CapturesTableTableCreateCompanionBuilder,
      $$CapturesTableTableUpdateCompanionBuilder,
      (
        CapturesTableData,
        BaseReferences<_$AppDatabase, $CapturesTableTable, CapturesTableData>,
      ),
      CapturesTableData,
      PrefetchHooks Function()
    >;
typedef $$TargetCompaniesTableTableCreateCompanionBuilder =
    TargetCompaniesTableCompanion Function({
      required String id,
      Value<String?> userId,
      Value<String?> eventId,
      Value<String?> companyId,
      Value<String> priority,
      Value<String?> boothLocation,
      Value<String?> talkingPoints,
      Value<String?> notes,
      Value<String> status,
      Value<bool> useNotesForBriefing,
      Value<DateTime?> createdAt,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$TargetCompaniesTableTableUpdateCompanionBuilder =
    TargetCompaniesTableCompanion Function({
      Value<String> id,
      Value<String?> userId,
      Value<String?> eventId,
      Value<String?> companyId,
      Value<String> priority,
      Value<String?> boothLocation,
      Value<String?> talkingPoints,
      Value<String?> notes,
      Value<String> status,
      Value<bool> useNotesForBriefing,
      Value<DateTime?> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

class $$TargetCompaniesTableTableFilterComposer
    extends Composer<_$AppDatabase, $TargetCompaniesTableTable> {
  $$TargetCompaniesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get companyId => $composableBuilder(
    column: $table.companyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get boothLocation => $composableBuilder(
    column: $table.boothLocation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get talkingPoints => $composableBuilder(
    column: $table.talkingPoints,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get useNotesForBriefing => $composableBuilder(
    column: $table.useNotesForBriefing,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TargetCompaniesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $TargetCompaniesTableTable> {
  $$TargetCompaniesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get companyId => $composableBuilder(
    column: $table.companyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get boothLocation => $composableBuilder(
    column: $table.boothLocation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get talkingPoints => $composableBuilder(
    column: $table.talkingPoints,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get useNotesForBriefing => $composableBuilder(
    column: $table.useNotesForBriefing,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TargetCompaniesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $TargetCompaniesTableTable> {
  $$TargetCompaniesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get eventId =>
      $composableBuilder(column: $table.eventId, builder: (column) => column);

  GeneratedColumn<String> get companyId =>
      $composableBuilder(column: $table.companyId, builder: (column) => column);

  GeneratedColumn<String> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<String> get boothLocation => $composableBuilder(
    column: $table.boothLocation,
    builder: (column) => column,
  );

  GeneratedColumn<String> get talkingPoints => $composableBuilder(
    column: $table.talkingPoints,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<bool> get useNotesForBriefing => $composableBuilder(
    column: $table.useNotesForBriefing,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$TargetCompaniesTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TargetCompaniesTableTable,
          TargetCompaniesTableData,
          $$TargetCompaniesTableTableFilterComposer,
          $$TargetCompaniesTableTableOrderingComposer,
          $$TargetCompaniesTableTableAnnotationComposer,
          $$TargetCompaniesTableTableCreateCompanionBuilder,
          $$TargetCompaniesTableTableUpdateCompanionBuilder,
          (
            TargetCompaniesTableData,
            BaseReferences<
              _$AppDatabase,
              $TargetCompaniesTableTable,
              TargetCompaniesTableData
            >,
          ),
          TargetCompaniesTableData,
          PrefetchHooks Function()
        > {
  $$TargetCompaniesTableTableTableManager(
    _$AppDatabase db,
    $TargetCompaniesTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TargetCompaniesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TargetCompaniesTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$TargetCompaniesTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> userId = const Value.absent(),
                Value<String?> eventId = const Value.absent(),
                Value<String?> companyId = const Value.absent(),
                Value<String> priority = const Value.absent(),
                Value<String?> boothLocation = const Value.absent(),
                Value<String?> talkingPoints = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<bool> useNotesForBriefing = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TargetCompaniesTableCompanion(
                id: id,
                userId: userId,
                eventId: eventId,
                companyId: companyId,
                priority: priority,
                boothLocation: boothLocation,
                talkingPoints: talkingPoints,
                notes: notes,
                status: status,
                useNotesForBriefing: useNotesForBriefing,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> userId = const Value.absent(),
                Value<String?> eventId = const Value.absent(),
                Value<String?> companyId = const Value.absent(),
                Value<String> priority = const Value.absent(),
                Value<String?> boothLocation = const Value.absent(),
                Value<String?> talkingPoints = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<bool> useNotesForBriefing = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TargetCompaniesTableCompanion.insert(
                id: id,
                userId: userId,
                eventId: eventId,
                companyId: companyId,
                priority: priority,
                boothLocation: boothLocation,
                talkingPoints: talkingPoints,
                notes: notes,
                status: status,
                useNotesForBriefing: useNotesForBriefing,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TargetCompaniesTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TargetCompaniesTableTable,
      TargetCompaniesTableData,
      $$TargetCompaniesTableTableFilterComposer,
      $$TargetCompaniesTableTableOrderingComposer,
      $$TargetCompaniesTableTableAnnotationComposer,
      $$TargetCompaniesTableTableCreateCompanionBuilder,
      $$TargetCompaniesTableTableUpdateCompanionBuilder,
      (
        TargetCompaniesTableData,
        BaseReferences<
          _$AppDatabase,
          $TargetCompaniesTableTable,
          TargetCompaniesTableData
        >,
      ),
      TargetCompaniesTableData,
      PrefetchHooks Function()
    >;
typedef $$ContactEventsTableTableCreateCompanionBuilder =
    ContactEventsTableCompanion Function({
      required String id,
      Value<String?> userId,
      required String contactId,
      required String eventId,
      Value<String> status,
      Value<String?> notes,
      Value<String?> talkingPoints,
      Value<DateTime?> createdAt,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$ContactEventsTableTableUpdateCompanionBuilder =
    ContactEventsTableCompanion Function({
      Value<String> id,
      Value<String?> userId,
      Value<String> contactId,
      Value<String> eventId,
      Value<String> status,
      Value<String?> notes,
      Value<String?> talkingPoints,
      Value<DateTime?> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

class $$ContactEventsTableTableFilterComposer
    extends Composer<_$AppDatabase, $ContactEventsTableTable> {
  $$ContactEventsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contactId => $composableBuilder(
    column: $table.contactId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get talkingPoints => $composableBuilder(
    column: $table.talkingPoints,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ContactEventsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ContactEventsTableTable> {
  $$ContactEventsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contactId => $composableBuilder(
    column: $table.contactId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get talkingPoints => $composableBuilder(
    column: $table.talkingPoints,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ContactEventsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ContactEventsTableTable> {
  $$ContactEventsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get contactId =>
      $composableBuilder(column: $table.contactId, builder: (column) => column);

  GeneratedColumn<String> get eventId =>
      $composableBuilder(column: $table.eventId, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get talkingPoints => $composableBuilder(
    column: $table.talkingPoints,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$ContactEventsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ContactEventsTableTable,
          ContactEventsTableData,
          $$ContactEventsTableTableFilterComposer,
          $$ContactEventsTableTableOrderingComposer,
          $$ContactEventsTableTableAnnotationComposer,
          $$ContactEventsTableTableCreateCompanionBuilder,
          $$ContactEventsTableTableUpdateCompanionBuilder,
          (
            ContactEventsTableData,
            BaseReferences<
              _$AppDatabase,
              $ContactEventsTableTable,
              ContactEventsTableData
            >,
          ),
          ContactEventsTableData,
          PrefetchHooks Function()
        > {
  $$ContactEventsTableTableTableManager(
    _$AppDatabase db,
    $ContactEventsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ContactEventsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ContactEventsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ContactEventsTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> userId = const Value.absent(),
                Value<String> contactId = const Value.absent(),
                Value<String> eventId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> talkingPoints = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ContactEventsTableCompanion(
                id: id,
                userId: userId,
                contactId: contactId,
                eventId: eventId,
                status: status,
                notes: notes,
                talkingPoints: talkingPoints,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> userId = const Value.absent(),
                required String contactId,
                required String eventId,
                Value<String> status = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> talkingPoints = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ContactEventsTableCompanion.insert(
                id: id,
                userId: userId,
                contactId: contactId,
                eventId: eventId,
                status: status,
                notes: notes,
                talkingPoints: talkingPoints,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ContactEventsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ContactEventsTableTable,
      ContactEventsTableData,
      $$ContactEventsTableTableFilterComposer,
      $$ContactEventsTableTableOrderingComposer,
      $$ContactEventsTableTableAnnotationComposer,
      $$ContactEventsTableTableCreateCompanionBuilder,
      $$ContactEventsTableTableUpdateCompanionBuilder,
      (
        ContactEventsTableData,
        BaseReferences<
          _$AppDatabase,
          $ContactEventsTableTable,
          ContactEventsTableData
        >,
      ),
      ContactEventsTableData,
      PrefetchHooks Function()
    >;
typedef $$EventGoalsTableTableCreateCompanionBuilder =
    EventGoalsTableCompanion Function({
      required String id,
      Value<String?> userId,
      required String eventId,
      required String label,
      Value<int> current,
      Value<int> total,
      Value<DateTime?> createdAt,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$EventGoalsTableTableUpdateCompanionBuilder =
    EventGoalsTableCompanion Function({
      Value<String> id,
      Value<String?> userId,
      Value<String> eventId,
      Value<String> label,
      Value<int> current,
      Value<int> total,
      Value<DateTime?> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

class $$EventGoalsTableTableFilterComposer
    extends Composer<_$AppDatabase, $EventGoalsTableTable> {
  $$EventGoalsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get current => $composableBuilder(
    column: $table.current,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EventGoalsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $EventGoalsTableTable> {
  $$EventGoalsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get current => $composableBuilder(
    column: $table.current,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EventGoalsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $EventGoalsTableTable> {
  $$EventGoalsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get eventId =>
      $composableBuilder(column: $table.eventId, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<int> get current =>
      $composableBuilder(column: $table.current, builder: (column) => column);

  GeneratedColumn<int> get total =>
      $composableBuilder(column: $table.total, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$EventGoalsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EventGoalsTableTable,
          EventGoalsTableData,
          $$EventGoalsTableTableFilterComposer,
          $$EventGoalsTableTableOrderingComposer,
          $$EventGoalsTableTableAnnotationComposer,
          $$EventGoalsTableTableCreateCompanionBuilder,
          $$EventGoalsTableTableUpdateCompanionBuilder,
          (
            EventGoalsTableData,
            BaseReferences<
              _$AppDatabase,
              $EventGoalsTableTable,
              EventGoalsTableData
            >,
          ),
          EventGoalsTableData,
          PrefetchHooks Function()
        > {
  $$EventGoalsTableTableTableManager(
    _$AppDatabase db,
    $EventGoalsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EventGoalsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EventGoalsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EventGoalsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> userId = const Value.absent(),
                Value<String> eventId = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<int> current = const Value.absent(),
                Value<int> total = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EventGoalsTableCompanion(
                id: id,
                userId: userId,
                eventId: eventId,
                label: label,
                current: current,
                total: total,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> userId = const Value.absent(),
                required String eventId,
                required String label,
                Value<int> current = const Value.absent(),
                Value<int> total = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EventGoalsTableCompanion.insert(
                id: id,
                userId: userId,
                eventId: eventId,
                label: label,
                current: current,
                total: total,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EventGoalsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EventGoalsTableTable,
      EventGoalsTableData,
      $$EventGoalsTableTableFilterComposer,
      $$EventGoalsTableTableOrderingComposer,
      $$EventGoalsTableTableAnnotationComposer,
      $$EventGoalsTableTableCreateCompanionBuilder,
      $$EventGoalsTableTableUpdateCompanionBuilder,
      (
        EventGoalsTableData,
        BaseReferences<
          _$AppDatabase,
          $EventGoalsTableTable,
          EventGoalsTableData
        >,
      ),
      EventGoalsTableData,
      PrefetchHooks Function()
    >;
typedef $$EmailDraftsTableTableCreateCompanionBuilder =
    EmailDraftsTableCompanion Function({
      required String id,
      Value<String?> userId,
      Value<String?> contactId,
      Value<String?> eventId,
      required String emailType,
      Value<String?> subject,
      Value<String?> body,
      Value<String> status,
      Value<DateTime?> sentAt,
      Value<DateTime?> createdAt,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$EmailDraftsTableTableUpdateCompanionBuilder =
    EmailDraftsTableCompanion Function({
      Value<String> id,
      Value<String?> userId,
      Value<String?> contactId,
      Value<String?> eventId,
      Value<String> emailType,
      Value<String?> subject,
      Value<String?> body,
      Value<String> status,
      Value<DateTime?> sentAt,
      Value<DateTime?> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

class $$EmailDraftsTableTableFilterComposer
    extends Composer<_$AppDatabase, $EmailDraftsTableTable> {
  $$EmailDraftsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contactId => $composableBuilder(
    column: $table.contactId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get emailType => $composableBuilder(
    column: $table.emailType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subject => $composableBuilder(
    column: $table.subject,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get sentAt => $composableBuilder(
    column: $table.sentAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EmailDraftsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $EmailDraftsTableTable> {
  $$EmailDraftsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contactId => $composableBuilder(
    column: $table.contactId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get emailType => $composableBuilder(
    column: $table.emailType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subject => $composableBuilder(
    column: $table.subject,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get sentAt => $composableBuilder(
    column: $table.sentAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EmailDraftsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $EmailDraftsTableTable> {
  $$EmailDraftsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get contactId =>
      $composableBuilder(column: $table.contactId, builder: (column) => column);

  GeneratedColumn<String> get eventId =>
      $composableBuilder(column: $table.eventId, builder: (column) => column);

  GeneratedColumn<String> get emailType =>
      $composableBuilder(column: $table.emailType, builder: (column) => column);

  GeneratedColumn<String> get subject =>
      $composableBuilder(column: $table.subject, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get sentAt =>
      $composableBuilder(column: $table.sentAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$EmailDraftsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EmailDraftsTableTable,
          EmailDraftsTableData,
          $$EmailDraftsTableTableFilterComposer,
          $$EmailDraftsTableTableOrderingComposer,
          $$EmailDraftsTableTableAnnotationComposer,
          $$EmailDraftsTableTableCreateCompanionBuilder,
          $$EmailDraftsTableTableUpdateCompanionBuilder,
          (
            EmailDraftsTableData,
            BaseReferences<
              _$AppDatabase,
              $EmailDraftsTableTable,
              EmailDraftsTableData
            >,
          ),
          EmailDraftsTableData,
          PrefetchHooks Function()
        > {
  $$EmailDraftsTableTableTableManager(
    _$AppDatabase db,
    $EmailDraftsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EmailDraftsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EmailDraftsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EmailDraftsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> userId = const Value.absent(),
                Value<String?> contactId = const Value.absent(),
                Value<String?> eventId = const Value.absent(),
                Value<String> emailType = const Value.absent(),
                Value<String?> subject = const Value.absent(),
                Value<String?> body = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime?> sentAt = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EmailDraftsTableCompanion(
                id: id,
                userId: userId,
                contactId: contactId,
                eventId: eventId,
                emailType: emailType,
                subject: subject,
                body: body,
                status: status,
                sentAt: sentAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> userId = const Value.absent(),
                Value<String?> contactId = const Value.absent(),
                Value<String?> eventId = const Value.absent(),
                required String emailType,
                Value<String?> subject = const Value.absent(),
                Value<String?> body = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime?> sentAt = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EmailDraftsTableCompanion.insert(
                id: id,
                userId: userId,
                contactId: contactId,
                eventId: eventId,
                emailType: emailType,
                subject: subject,
                body: body,
                status: status,
                sentAt: sentAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EmailDraftsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EmailDraftsTableTable,
      EmailDraftsTableData,
      $$EmailDraftsTableTableFilterComposer,
      $$EmailDraftsTableTableOrderingComposer,
      $$EmailDraftsTableTableAnnotationComposer,
      $$EmailDraftsTableTableCreateCompanionBuilder,
      $$EmailDraftsTableTableUpdateCompanionBuilder,
      (
        EmailDraftsTableData,
        BaseReferences<
          _$AppDatabase,
          $EmailDraftsTableTable,
          EmailDraftsTableData
        >,
      ),
      EmailDraftsTableData,
      PrefetchHooks Function()
    >;
typedef $$InteractionsTableTableCreateCompanionBuilder =
    InteractionsTableCompanion Function({
      required String id,
      Value<String?> userId,
      Value<String?> contactId,
      Value<String?> eventId,
      required String interactionType,
      Value<DateTime?> interactionDate,
      Value<String?> summary,
      Value<String?> detailsJson,
      Value<DateTime?> createdAt,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$InteractionsTableTableUpdateCompanionBuilder =
    InteractionsTableCompanion Function({
      Value<String> id,
      Value<String?> userId,
      Value<String?> contactId,
      Value<String?> eventId,
      Value<String> interactionType,
      Value<DateTime?> interactionDate,
      Value<String?> summary,
      Value<String?> detailsJson,
      Value<DateTime?> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

class $$InteractionsTableTableFilterComposer
    extends Composer<_$AppDatabase, $InteractionsTableTable> {
  $$InteractionsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contactId => $composableBuilder(
    column: $table.contactId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get interactionType => $composableBuilder(
    column: $table.interactionType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get interactionDate => $composableBuilder(
    column: $table.interactionDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get detailsJson => $composableBuilder(
    column: $table.detailsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$InteractionsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $InteractionsTableTable> {
  $$InteractionsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contactId => $composableBuilder(
    column: $table.contactId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get interactionType => $composableBuilder(
    column: $table.interactionType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get interactionDate => $composableBuilder(
    column: $table.interactionDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get detailsJson => $composableBuilder(
    column: $table.detailsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$InteractionsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $InteractionsTableTable> {
  $$InteractionsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get contactId =>
      $composableBuilder(column: $table.contactId, builder: (column) => column);

  GeneratedColumn<String> get eventId =>
      $composableBuilder(column: $table.eventId, builder: (column) => column);

  GeneratedColumn<String> get interactionType => $composableBuilder(
    column: $table.interactionType,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get interactionDate => $composableBuilder(
    column: $table.interactionDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get summary =>
      $composableBuilder(column: $table.summary, builder: (column) => column);

  GeneratedColumn<String> get detailsJson => $composableBuilder(
    column: $table.detailsJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$InteractionsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $InteractionsTableTable,
          InteractionsTableData,
          $$InteractionsTableTableFilterComposer,
          $$InteractionsTableTableOrderingComposer,
          $$InteractionsTableTableAnnotationComposer,
          $$InteractionsTableTableCreateCompanionBuilder,
          $$InteractionsTableTableUpdateCompanionBuilder,
          (
            InteractionsTableData,
            BaseReferences<
              _$AppDatabase,
              $InteractionsTableTable,
              InteractionsTableData
            >,
          ),
          InteractionsTableData,
          PrefetchHooks Function()
        > {
  $$InteractionsTableTableTableManager(
    _$AppDatabase db,
    $InteractionsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InteractionsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$InteractionsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$InteractionsTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> userId = const Value.absent(),
                Value<String?> contactId = const Value.absent(),
                Value<String?> eventId = const Value.absent(),
                Value<String> interactionType = const Value.absent(),
                Value<DateTime?> interactionDate = const Value.absent(),
                Value<String?> summary = const Value.absent(),
                Value<String?> detailsJson = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InteractionsTableCompanion(
                id: id,
                userId: userId,
                contactId: contactId,
                eventId: eventId,
                interactionType: interactionType,
                interactionDate: interactionDate,
                summary: summary,
                detailsJson: detailsJson,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> userId = const Value.absent(),
                Value<String?> contactId = const Value.absent(),
                Value<String?> eventId = const Value.absent(),
                required String interactionType,
                Value<DateTime?> interactionDate = const Value.absent(),
                Value<String?> summary = const Value.absent(),
                Value<String?> detailsJson = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InteractionsTableCompanion.insert(
                id: id,
                userId: userId,
                contactId: contactId,
                eventId: eventId,
                interactionType: interactionType,
                interactionDate: interactionDate,
                summary: summary,
                detailsJson: detailsJson,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$InteractionsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $InteractionsTableTable,
      InteractionsTableData,
      $$InteractionsTableTableFilterComposer,
      $$InteractionsTableTableOrderingComposer,
      $$InteractionsTableTableAnnotationComposer,
      $$InteractionsTableTableCreateCompanionBuilder,
      $$InteractionsTableTableUpdateCompanionBuilder,
      (
        InteractionsTableData,
        BaseReferences<
          _$AppDatabase,
          $InteractionsTableTable,
          InteractionsTableData
        >,
      ),
      InteractionsTableData,
      PrefetchHooks Function()
    >;
typedef $$CompaniesTableTableCreateCompanionBuilder =
    CompaniesTableCompanion Function({
      required String id,
      required String name,
      Value<String?> website,
      Value<String?> industry,
      Value<String?> description,
      Value<String?> location,
      Value<String?> companySize,
      Value<String?> productsServices,
      Value<String?> headquarters,
      Value<String?> employeeCount,
      Value<String?> foundedYear,
      Value<String?> linkedinUrl,
      Value<String?> tickerSymbol,
      Value<DateTime?> enrichedAt,
      Value<bool> enrichmentFailed,
      Value<String?> talkingPointsJson,
      Value<DateTime?> createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$CompaniesTableTableUpdateCompanionBuilder =
    CompaniesTableCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> website,
      Value<String?> industry,
      Value<String?> description,
      Value<String?> location,
      Value<String?> companySize,
      Value<String?> productsServices,
      Value<String?> headquarters,
      Value<String?> employeeCount,
      Value<String?> foundedYear,
      Value<String?> linkedinUrl,
      Value<String?> tickerSymbol,
      Value<DateTime?> enrichedAt,
      Value<bool> enrichmentFailed,
      Value<String?> talkingPointsJson,
      Value<DateTime?> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$CompaniesTableTableFilterComposer
    extends Composer<_$AppDatabase, $CompaniesTableTable> {
  $$CompaniesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get website => $composableBuilder(
    column: $table.website,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get industry => $composableBuilder(
    column: $table.industry,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get companySize => $composableBuilder(
    column: $table.companySize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get productsServices => $composableBuilder(
    column: $table.productsServices,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get headquarters => $composableBuilder(
    column: $table.headquarters,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get employeeCount => $composableBuilder(
    column: $table.employeeCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get foundedYear => $composableBuilder(
    column: $table.foundedYear,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get linkedinUrl => $composableBuilder(
    column: $table.linkedinUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tickerSymbol => $composableBuilder(
    column: $table.tickerSymbol,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get enrichedAt => $composableBuilder(
    column: $table.enrichedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enrichmentFailed => $composableBuilder(
    column: $table.enrichmentFailed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get talkingPointsJson => $composableBuilder(
    column: $table.talkingPointsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CompaniesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $CompaniesTableTable> {
  $$CompaniesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get website => $composableBuilder(
    column: $table.website,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get industry => $composableBuilder(
    column: $table.industry,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get companySize => $composableBuilder(
    column: $table.companySize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get productsServices => $composableBuilder(
    column: $table.productsServices,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get headquarters => $composableBuilder(
    column: $table.headquarters,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get employeeCount => $composableBuilder(
    column: $table.employeeCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get foundedYear => $composableBuilder(
    column: $table.foundedYear,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get linkedinUrl => $composableBuilder(
    column: $table.linkedinUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tickerSymbol => $composableBuilder(
    column: $table.tickerSymbol,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get enrichedAt => $composableBuilder(
    column: $table.enrichedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enrichmentFailed => $composableBuilder(
    column: $table.enrichmentFailed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get talkingPointsJson => $composableBuilder(
    column: $table.talkingPointsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CompaniesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $CompaniesTableTable> {
  $$CompaniesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get website =>
      $composableBuilder(column: $table.website, builder: (column) => column);

  GeneratedColumn<String> get industry =>
      $composableBuilder(column: $table.industry, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get location =>
      $composableBuilder(column: $table.location, builder: (column) => column);

  GeneratedColumn<String> get companySize => $composableBuilder(
    column: $table.companySize,
    builder: (column) => column,
  );

  GeneratedColumn<String> get productsServices => $composableBuilder(
    column: $table.productsServices,
    builder: (column) => column,
  );

  GeneratedColumn<String> get headquarters => $composableBuilder(
    column: $table.headquarters,
    builder: (column) => column,
  );

  GeneratedColumn<String> get employeeCount => $composableBuilder(
    column: $table.employeeCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get foundedYear => $composableBuilder(
    column: $table.foundedYear,
    builder: (column) => column,
  );

  GeneratedColumn<String> get linkedinUrl => $composableBuilder(
    column: $table.linkedinUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tickerSymbol => $composableBuilder(
    column: $table.tickerSymbol,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get enrichedAt => $composableBuilder(
    column: $table.enrichedAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get enrichmentFailed => $composableBuilder(
    column: $table.enrichmentFailed,
    builder: (column) => column,
  );

  GeneratedColumn<String> get talkingPointsJson => $composableBuilder(
    column: $table.talkingPointsJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$CompaniesTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CompaniesTableTable,
          CompaniesTableData,
          $$CompaniesTableTableFilterComposer,
          $$CompaniesTableTableOrderingComposer,
          $$CompaniesTableTableAnnotationComposer,
          $$CompaniesTableTableCreateCompanionBuilder,
          $$CompaniesTableTableUpdateCompanionBuilder,
          (
            CompaniesTableData,
            BaseReferences<
              _$AppDatabase,
              $CompaniesTableTable,
              CompaniesTableData
            >,
          ),
          CompaniesTableData,
          PrefetchHooks Function()
        > {
  $$CompaniesTableTableTableManager(
    _$AppDatabase db,
    $CompaniesTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CompaniesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CompaniesTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CompaniesTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> website = const Value.absent(),
                Value<String?> industry = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> location = const Value.absent(),
                Value<String?> companySize = const Value.absent(),
                Value<String?> productsServices = const Value.absent(),
                Value<String?> headquarters = const Value.absent(),
                Value<String?> employeeCount = const Value.absent(),
                Value<String?> foundedYear = const Value.absent(),
                Value<String?> linkedinUrl = const Value.absent(),
                Value<String?> tickerSymbol = const Value.absent(),
                Value<DateTime?> enrichedAt = const Value.absent(),
                Value<bool> enrichmentFailed = const Value.absent(),
                Value<String?> talkingPointsJson = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CompaniesTableCompanion(
                id: id,
                name: name,
                website: website,
                industry: industry,
                description: description,
                location: location,
                companySize: companySize,
                productsServices: productsServices,
                headquarters: headquarters,
                employeeCount: employeeCount,
                foundedYear: foundedYear,
                linkedinUrl: linkedinUrl,
                tickerSymbol: tickerSymbol,
                enrichedAt: enrichedAt,
                enrichmentFailed: enrichmentFailed,
                talkingPointsJson: talkingPointsJson,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> website = const Value.absent(),
                Value<String?> industry = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> location = const Value.absent(),
                Value<String?> companySize = const Value.absent(),
                Value<String?> productsServices = const Value.absent(),
                Value<String?> headquarters = const Value.absent(),
                Value<String?> employeeCount = const Value.absent(),
                Value<String?> foundedYear = const Value.absent(),
                Value<String?> linkedinUrl = const Value.absent(),
                Value<String?> tickerSymbol = const Value.absent(),
                Value<DateTime?> enrichedAt = const Value.absent(),
                Value<bool> enrichmentFailed = const Value.absent(),
                Value<String?> talkingPointsJson = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => CompaniesTableCompanion.insert(
                id: id,
                name: name,
                website: website,
                industry: industry,
                description: description,
                location: location,
                companySize: companySize,
                productsServices: productsServices,
                headquarters: headquarters,
                employeeCount: employeeCount,
                foundedYear: foundedYear,
                linkedinUrl: linkedinUrl,
                tickerSymbol: tickerSymbol,
                enrichedAt: enrichedAt,
                enrichmentFailed: enrichmentFailed,
                talkingPointsJson: talkingPointsJson,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CompaniesTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CompaniesTableTable,
      CompaniesTableData,
      $$CompaniesTableTableFilterComposer,
      $$CompaniesTableTableOrderingComposer,
      $$CompaniesTableTableAnnotationComposer,
      $$CompaniesTableTableCreateCompanionBuilder,
      $$CompaniesTableTableUpdateCompanionBuilder,
      (
        CompaniesTableData,
        BaseReferences<_$AppDatabase, $CompaniesTableTable, CompaniesTableData>,
      ),
      CompaniesTableData,
      PrefetchHooks Function()
    >;
typedef $$FollowUpsTableTableCreateCompanionBuilder =
    FollowUpsTableCompanion Function({
      required String id,
      Value<String?> userId,
      required String contactId,
      Value<String?> eventId,
      Value<String> status,
      Value<String> channel,
      Value<DateTime?> lastInteractionAt,
      Value<DateTime?> doneAt,
      Value<DateTime?> createdAt,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$FollowUpsTableTableUpdateCompanionBuilder =
    FollowUpsTableCompanion Function({
      Value<String> id,
      Value<String?> userId,
      Value<String> contactId,
      Value<String?> eventId,
      Value<String> status,
      Value<String> channel,
      Value<DateTime?> lastInteractionAt,
      Value<DateTime?> doneAt,
      Value<DateTime?> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

class $$FollowUpsTableTableFilterComposer
    extends Composer<_$AppDatabase, $FollowUpsTableTable> {
  $$FollowUpsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contactId => $composableBuilder(
    column: $table.contactId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get channel => $composableBuilder(
    column: $table.channel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastInteractionAt => $composableBuilder(
    column: $table.lastInteractionAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get doneAt => $composableBuilder(
    column: $table.doneAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FollowUpsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $FollowUpsTableTable> {
  $$FollowUpsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contactId => $composableBuilder(
    column: $table.contactId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get channel => $composableBuilder(
    column: $table.channel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastInteractionAt => $composableBuilder(
    column: $table.lastInteractionAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get doneAt => $composableBuilder(
    column: $table.doneAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FollowUpsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $FollowUpsTableTable> {
  $$FollowUpsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get contactId =>
      $composableBuilder(column: $table.contactId, builder: (column) => column);

  GeneratedColumn<String> get eventId =>
      $composableBuilder(column: $table.eventId, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get channel =>
      $composableBuilder(column: $table.channel, builder: (column) => column);

  GeneratedColumn<DateTime> get lastInteractionAt => $composableBuilder(
    column: $table.lastInteractionAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get doneAt =>
      $composableBuilder(column: $table.doneAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$FollowUpsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FollowUpsTableTable,
          FollowUpsTableData,
          $$FollowUpsTableTableFilterComposer,
          $$FollowUpsTableTableOrderingComposer,
          $$FollowUpsTableTableAnnotationComposer,
          $$FollowUpsTableTableCreateCompanionBuilder,
          $$FollowUpsTableTableUpdateCompanionBuilder,
          (
            FollowUpsTableData,
            BaseReferences<
              _$AppDatabase,
              $FollowUpsTableTable,
              FollowUpsTableData
            >,
          ),
          FollowUpsTableData,
          PrefetchHooks Function()
        > {
  $$FollowUpsTableTableTableManager(
    _$AppDatabase db,
    $FollowUpsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FollowUpsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FollowUpsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FollowUpsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> userId = const Value.absent(),
                Value<String> contactId = const Value.absent(),
                Value<String?> eventId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> channel = const Value.absent(),
                Value<DateTime?> lastInteractionAt = const Value.absent(),
                Value<DateTime?> doneAt = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FollowUpsTableCompanion(
                id: id,
                userId: userId,
                contactId: contactId,
                eventId: eventId,
                status: status,
                channel: channel,
                lastInteractionAt: lastInteractionAt,
                doneAt: doneAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> userId = const Value.absent(),
                required String contactId,
                Value<String?> eventId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> channel = const Value.absent(),
                Value<DateTime?> lastInteractionAt = const Value.absent(),
                Value<DateTime?> doneAt = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FollowUpsTableCompanion.insert(
                id: id,
                userId: userId,
                contactId: contactId,
                eventId: eventId,
                status: status,
                channel: channel,
                lastInteractionAt: lastInteractionAt,
                doneAt: doneAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FollowUpsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FollowUpsTableTable,
      FollowUpsTableData,
      $$FollowUpsTableTableFilterComposer,
      $$FollowUpsTableTableOrderingComposer,
      $$FollowUpsTableTableAnnotationComposer,
      $$FollowUpsTableTableCreateCompanionBuilder,
      $$FollowUpsTableTableUpdateCompanionBuilder,
      (
        FollowUpsTableData,
        BaseReferences<_$AppDatabase, $FollowUpsTableTable, FollowUpsTableData>,
      ),
      FollowUpsTableData,
      PrefetchHooks Function()
    >;
typedef $$TargetCompanyMetTableTableCreateCompanionBuilder =
    TargetCompanyMetTableCompanion Function({
      required String id,
      Value<String?> userId,
      Value<String?> eventId,
      Value<String?> targetId,
      Value<bool> met,
      Value<DateTime?> createdAt,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$TargetCompanyMetTableTableUpdateCompanionBuilder =
    TargetCompanyMetTableCompanion Function({
      Value<String> id,
      Value<String?> userId,
      Value<String?> eventId,
      Value<String?> targetId,
      Value<bool> met,
      Value<DateTime?> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

class $$TargetCompanyMetTableTableFilterComposer
    extends Composer<_$AppDatabase, $TargetCompanyMetTableTable> {
  $$TargetCompanyMetTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetId => $composableBuilder(
    column: $table.targetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get met => $composableBuilder(
    column: $table.met,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TargetCompanyMetTableTableOrderingComposer
    extends Composer<_$AppDatabase, $TargetCompanyMetTableTable> {
  $$TargetCompanyMetTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetId => $composableBuilder(
    column: $table.targetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get met => $composableBuilder(
    column: $table.met,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TargetCompanyMetTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $TargetCompanyMetTableTable> {
  $$TargetCompanyMetTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get eventId =>
      $composableBuilder(column: $table.eventId, builder: (column) => column);

  GeneratedColumn<String> get targetId =>
      $composableBuilder(column: $table.targetId, builder: (column) => column);

  GeneratedColumn<bool> get met =>
      $composableBuilder(column: $table.met, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$TargetCompanyMetTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TargetCompanyMetTableTable,
          TargetCompanyMetTableData,
          $$TargetCompanyMetTableTableFilterComposer,
          $$TargetCompanyMetTableTableOrderingComposer,
          $$TargetCompanyMetTableTableAnnotationComposer,
          $$TargetCompanyMetTableTableCreateCompanionBuilder,
          $$TargetCompanyMetTableTableUpdateCompanionBuilder,
          (
            TargetCompanyMetTableData,
            BaseReferences<
              _$AppDatabase,
              $TargetCompanyMetTableTable,
              TargetCompanyMetTableData
            >,
          ),
          TargetCompanyMetTableData,
          PrefetchHooks Function()
        > {
  $$TargetCompanyMetTableTableTableManager(
    _$AppDatabase db,
    $TargetCompanyMetTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TargetCompanyMetTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$TargetCompanyMetTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$TargetCompanyMetTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> userId = const Value.absent(),
                Value<String?> eventId = const Value.absent(),
                Value<String?> targetId = const Value.absent(),
                Value<bool> met = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TargetCompanyMetTableCompanion(
                id: id,
                userId: userId,
                eventId: eventId,
                targetId: targetId,
                met: met,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> userId = const Value.absent(),
                Value<String?> eventId = const Value.absent(),
                Value<String?> targetId = const Value.absent(),
                Value<bool> met = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TargetCompanyMetTableCompanion.insert(
                id: id,
                userId: userId,
                eventId: eventId,
                targetId: targetId,
                met: met,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TargetCompanyMetTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TargetCompanyMetTableTable,
      TargetCompanyMetTableData,
      $$TargetCompanyMetTableTableFilterComposer,
      $$TargetCompanyMetTableTableOrderingComposer,
      $$TargetCompanyMetTableTableAnnotationComposer,
      $$TargetCompanyMetTableTableCreateCompanionBuilder,
      $$TargetCompanyMetTableTableUpdateCompanionBuilder,
      (
        TargetCompanyMetTableData,
        BaseReferences<
          _$AppDatabase,
          $TargetCompanyMetTableTable,
          TargetCompanyMetTableData
        >,
      ),
      TargetCompanyMetTableData,
      PrefetchHooks Function()
    >;
typedef $$SyncStateTableTableCreateCompanionBuilder =
    SyncStateTableCompanion Function({
      required String tableName_,
      Value<String?> lastSyncedAt,
      Value<int> rowid,
    });
typedef $$SyncStateTableTableUpdateCompanionBuilder =
    SyncStateTableCompanion Function({
      Value<String> tableName_,
      Value<String?> lastSyncedAt,
      Value<int> rowid,
    });

class $$SyncStateTableTableFilterComposer
    extends Composer<_$AppDatabase, $SyncStateTableTable> {
  $$SyncStateTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get tableName_ => $composableBuilder(
    column: $table.tableName_,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncStateTableTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncStateTableTable> {
  $$SyncStateTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get tableName_ => $composableBuilder(
    column: $table.tableName_,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncStateTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncStateTableTable> {
  $$SyncStateTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get tableName_ => $composableBuilder(
    column: $table.tableName_,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );
}

class $$SyncStateTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncStateTableTable,
          SyncStateTableData,
          $$SyncStateTableTableFilterComposer,
          $$SyncStateTableTableOrderingComposer,
          $$SyncStateTableTableAnnotationComposer,
          $$SyncStateTableTableCreateCompanionBuilder,
          $$SyncStateTableTableUpdateCompanionBuilder,
          (
            SyncStateTableData,
            BaseReferences<
              _$AppDatabase,
              $SyncStateTableTable,
              SyncStateTableData
            >,
          ),
          SyncStateTableData,
          PrefetchHooks Function()
        > {
  $$SyncStateTableTableTableManager(
    _$AppDatabase db,
    $SyncStateTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncStateTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncStateTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncStateTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> tableName_ = const Value.absent(),
                Value<String?> lastSyncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncStateTableCompanion(
                tableName_: tableName_,
                lastSyncedAt: lastSyncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String tableName_,
                Value<String?> lastSyncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncStateTableCompanion.insert(
                tableName_: tableName_,
                lastSyncedAt: lastSyncedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncStateTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncStateTableTable,
      SyncStateTableData,
      $$SyncStateTableTableFilterComposer,
      $$SyncStateTableTableOrderingComposer,
      $$SyncStateTableTableAnnotationComposer,
      $$SyncStateTableTableCreateCompanionBuilder,
      $$SyncStateTableTableUpdateCompanionBuilder,
      (
        SyncStateTableData,
        BaseReferences<_$AppDatabase, $SyncStateTableTable, SyncStateTableData>,
      ),
      SyncStateTableData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$EventsTableTableTableManager get eventsTable =>
      $$EventsTableTableTableManager(_db, _db.eventsTable);
  $$ContactsTableTableTableManager get contactsTable =>
      $$ContactsTableTableTableManager(_db, _db.contactsTable);
  $$CapturesTableTableTableManager get capturesTable =>
      $$CapturesTableTableTableManager(_db, _db.capturesTable);
  $$TargetCompaniesTableTableTableManager get targetCompaniesTable =>
      $$TargetCompaniesTableTableTableManager(_db, _db.targetCompaniesTable);
  $$ContactEventsTableTableTableManager get contactEventsTable =>
      $$ContactEventsTableTableTableManager(_db, _db.contactEventsTable);
  $$EventGoalsTableTableTableManager get eventGoalsTable =>
      $$EventGoalsTableTableTableManager(_db, _db.eventGoalsTable);
  $$EmailDraftsTableTableTableManager get emailDraftsTable =>
      $$EmailDraftsTableTableTableManager(_db, _db.emailDraftsTable);
  $$InteractionsTableTableTableManager get interactionsTable =>
      $$InteractionsTableTableTableManager(_db, _db.interactionsTable);
  $$CompaniesTableTableTableManager get companiesTable =>
      $$CompaniesTableTableTableManager(_db, _db.companiesTable);
  $$FollowUpsTableTableTableManager get followUpsTable =>
      $$FollowUpsTableTableTableManager(_db, _db.followUpsTable);
  $$TargetCompanyMetTableTableTableManager get targetCompanyMetTable =>
      $$TargetCompanyMetTableTableTableManager(_db, _db.targetCompanyMetTable);
  $$SyncStateTableTableTableManager get syncStateTable =>
      $$SyncStateTableTableTableManager(_db, _db.syncStateTable);
}
