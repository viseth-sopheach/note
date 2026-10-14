// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $FolderRowsTable extends FolderRows
    with TableInfo<$FolderRowsTable, FolderRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FolderRowsTable(this.attachedDatabase, [this._alias]);
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
    additionalChecks: GeneratedColumn.checkTextLength(minTextLength: 1),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES folders (id) ON DELETE CASCADE',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> createdAt =
      GeneratedColumn<int>(
        'created_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($FolderRowsTable.$convertercreatedAt);
  @override
  List<GeneratedColumn> get $columns => [id, name, parentId, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'folders';
  @override
  VerificationContext validateIntegrity(
    Insertable<FolderRow> instance, {
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
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FolderRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FolderRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_id'],
      ),
      createdAt: $FolderRowsTable.$convertercreatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}created_at'],
        )!,
      ),
    );
  }

  @override
  $FolderRowsTable createAlias(String alias) {
    return $FolderRowsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $convertercreatedAt =
      const EpochMicrosConverter();
}

class FolderRow extends DataClass implements Insertable<FolderRow> {
  final String id;
  final String name;
  final String? parentId;
  final DateTime createdAt;
  const FolderRow({
    required this.id,
    required this.name,
    this.parentId,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    {
      map['created_at'] = Variable<int>(
        $FolderRowsTable.$convertercreatedAt.toSql(createdAt),
      );
    }
    return map;
  }

  FolderRowsCompanion toCompanion(bool nullToAbsent) {
    return FolderRowsCompanion(
      id: Value(id),
      name: Value(name),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      createdAt: Value(createdAt),
    );
  }

  factory FolderRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FolderRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      parentId: serializer.fromJson<String?>(json['parentId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'parentId': serializer.toJson<String?>(parentId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  FolderRow copyWith({
    String? id,
    String? name,
    Value<String?> parentId = const Value.absent(),
    DateTime? createdAt,
  }) => FolderRow(
    id: id ?? this.id,
    name: name ?? this.name,
    parentId: parentId.present ? parentId.value : this.parentId,
    createdAt: createdAt ?? this.createdAt,
  );
  FolderRow copyWithCompanion(FolderRowsCompanion data) {
    return FolderRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FolderRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('parentId: $parentId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, parentId, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FolderRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.parentId == this.parentId &&
          other.createdAt == this.createdAt);
}

class FolderRowsCompanion extends UpdateCompanion<FolderRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> parentId;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const FolderRowsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.parentId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FolderRowsCompanion.insert({
    required String id,
    required String name,
    this.parentId = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<FolderRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? parentId,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (parentId != null) 'parent_id': parentId,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FolderRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? parentId,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return FolderRowsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      createdAt: createdAt ?? this.createdAt,
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
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(
        $FolderRowsTable.$convertercreatedAt.toSql(createdAt.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FolderRowsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('parentId: $parentId, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NotebookRowsTable extends NotebookRows
    with TableInfo<$NotebookRowsTable, NotebookRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotebookRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(minTextLength: 1),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _folderIdMeta = const VerificationMeta(
    'folderId',
  );
  @override
  late final GeneratedColumn<String> folderId = GeneratedColumn<String>(
    'folder_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES folders (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _coverColorValueMeta = const VerificationMeta(
    'coverColorValue',
  );
  @override
  late final GeneratedColumn<int> coverColorValue = GeneratedColumn<int>(
    'cover_color_value',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<PaperTemplate, String> template =
      GeneratedColumn<String>(
        'template',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<PaperTemplate>($NotebookRowsTable.$convertertemplate);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> createdAt =
      GeneratedColumn<int>(
        'created_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($NotebookRowsTable.$convertercreatedAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> updatedAt =
      GeneratedColumn<int>(
        'updated_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($NotebookRowsTable.$converterupdatedAt);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    folderId,
    coverColorValue,
    template,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notebooks';
  @override
  VerificationContext validateIntegrity(
    Insertable<NotebookRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('folder_id')) {
      context.handle(
        _folderIdMeta,
        folderId.isAcceptableOrUnknown(data['folder_id']!, _folderIdMeta),
      );
    }
    if (data.containsKey('cover_color_value')) {
      context.handle(
        _coverColorValueMeta,
        coverColorValue.isAcceptableOrUnknown(
          data['cover_color_value']!,
          _coverColorValueMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_coverColorValueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  NotebookRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NotebookRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      folderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}folder_id'],
      ),
      coverColorValue: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cover_color_value'],
      )!,
      template: $NotebookRowsTable.$convertertemplate.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}template'],
        )!,
      ),
      createdAt: $NotebookRowsTable.$convertercreatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}created_at'],
        )!,
      ),
      updatedAt: $NotebookRowsTable.$converterupdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}updated_at'],
        )!,
      ),
    );
  }

  @override
  $NotebookRowsTable createAlias(String alias) {
    return $NotebookRowsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<PaperTemplate, String, String> $convertertemplate =
      const EnumNameConverter<PaperTemplate>(PaperTemplate.values);
  static TypeConverter<DateTime, int> $convertercreatedAt =
      const EpochMicrosConverter();
  static TypeConverter<DateTime, int> $converterupdatedAt =
      const EpochMicrosConverter();
}

class NotebookRow extends DataClass implements Insertable<NotebookRow> {
  final String id;
  final String title;
  final String? folderId;
  final int coverColorValue;
  final PaperTemplate template;
  final DateTime createdAt;
  final DateTime updatedAt;
  const NotebookRow({
    required this.id,
    required this.title,
    this.folderId,
    required this.coverColorValue,
    required this.template,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || folderId != null) {
      map['folder_id'] = Variable<String>(folderId);
    }
    map['cover_color_value'] = Variable<int>(coverColorValue);
    {
      map['template'] = Variable<String>(
        $NotebookRowsTable.$convertertemplate.toSql(template),
      );
    }
    {
      map['created_at'] = Variable<int>(
        $NotebookRowsTable.$convertercreatedAt.toSql(createdAt),
      );
    }
    {
      map['updated_at'] = Variable<int>(
        $NotebookRowsTable.$converterupdatedAt.toSql(updatedAt),
      );
    }
    return map;
  }

  NotebookRowsCompanion toCompanion(bool nullToAbsent) {
    return NotebookRowsCompanion(
      id: Value(id),
      title: Value(title),
      folderId: folderId == null && nullToAbsent
          ? const Value.absent()
          : Value(folderId),
      coverColorValue: Value(coverColorValue),
      template: Value(template),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory NotebookRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NotebookRow(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      folderId: serializer.fromJson<String?>(json['folderId']),
      coverColorValue: serializer.fromJson<int>(json['coverColorValue']),
      template: $NotebookRowsTable.$convertertemplate.fromJson(
        serializer.fromJson<String>(json['template']),
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'folderId': serializer.toJson<String?>(folderId),
      'coverColorValue': serializer.toJson<int>(coverColorValue),
      'template': serializer.toJson<String>(
        $NotebookRowsTable.$convertertemplate.toJson(template),
      ),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  NotebookRow copyWith({
    String? id,
    String? title,
    Value<String?> folderId = const Value.absent(),
    int? coverColorValue,
    PaperTemplate? template,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => NotebookRow(
    id: id ?? this.id,
    title: title ?? this.title,
    folderId: folderId.present ? folderId.value : this.folderId,
    coverColorValue: coverColorValue ?? this.coverColorValue,
    template: template ?? this.template,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  NotebookRow copyWithCompanion(NotebookRowsCompanion data) {
    return NotebookRow(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      folderId: data.folderId.present ? data.folderId.value : this.folderId,
      coverColorValue: data.coverColorValue.present
          ? data.coverColorValue.value
          : this.coverColorValue,
      template: data.template.present ? data.template.value : this.template,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NotebookRow(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('folderId: $folderId, ')
          ..write('coverColorValue: $coverColorValue, ')
          ..write('template: $template, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    folderId,
    coverColorValue,
    template,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NotebookRow &&
          other.id == this.id &&
          other.title == this.title &&
          other.folderId == this.folderId &&
          other.coverColorValue == this.coverColorValue &&
          other.template == this.template &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class NotebookRowsCompanion extends UpdateCompanion<NotebookRow> {
  final Value<String> id;
  final Value<String> title;
  final Value<String?> folderId;
  final Value<int> coverColorValue;
  final Value<PaperTemplate> template;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const NotebookRowsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.folderId = const Value.absent(),
    this.coverColorValue = const Value.absent(),
    this.template = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NotebookRowsCompanion.insert({
    required String id,
    required String title,
    this.folderId = const Value.absent(),
    required int coverColorValue,
    required PaperTemplate template,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       coverColorValue = Value(coverColorValue),
       template = Value(template),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<NotebookRow> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? folderId,
    Expression<int>? coverColorValue,
    Expression<String>? template,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (folderId != null) 'folder_id': folderId,
      if (coverColorValue != null) 'cover_color_value': coverColorValue,
      if (template != null) 'template': template,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NotebookRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String?>? folderId,
    Value<int>? coverColorValue,
    Value<PaperTemplate>? template,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return NotebookRowsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      folderId: folderId ?? this.folderId,
      coverColorValue: coverColorValue ?? this.coverColorValue,
      template: template ?? this.template,
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
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (folderId.present) {
      map['folder_id'] = Variable<String>(folderId.value);
    }
    if (coverColorValue.present) {
      map['cover_color_value'] = Variable<int>(coverColorValue.value);
    }
    if (template.present) {
      map['template'] = Variable<String>(
        $NotebookRowsTable.$convertertemplate.toSql(template.value),
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(
        $NotebookRowsTable.$convertercreatedAt.toSql(createdAt.value),
      );
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(
        $NotebookRowsTable.$converterupdatedAt.toSql(updatedAt.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotebookRowsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('folderId: $folderId, ')
          ..write('coverColorValue: $coverColorValue, ')
          ..write('template: $template, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PageRowsTable extends PageRows with TableInfo<$PageRowsTable, PageRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PageRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notebookIdMeta = const VerificationMeta(
    'notebookId',
  );
  @override
  late final GeneratedColumn<String> notebookId = GeneratedColumn<String>(
    'notebook_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES notebooks (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _pageIndexMeta = const VerificationMeta(
    'pageIndex',
  );
  @override
  late final GeneratedColumn<int> pageIndex = GeneratedColumn<int>(
    'page_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _strokesMeta = const VerificationMeta(
    'strokes',
  );
  @override
  late final GeneratedColumn<Uint8List> strokes = GeneratedColumn<Uint8List>(
    'strokes',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> updatedAt =
      GeneratedColumn<int>(
        'updated_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($PageRowsTable.$converterupdatedAt);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    notebookId,
    pageIndex,
    strokes,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pages';
  @override
  VerificationContext validateIntegrity(
    Insertable<PageRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('notebook_id')) {
      context.handle(
        _notebookIdMeta,
        notebookId.isAcceptableOrUnknown(data['notebook_id']!, _notebookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_notebookIdMeta);
    }
    if (data.containsKey('page_index')) {
      context.handle(
        _pageIndexMeta,
        pageIndex.isAcceptableOrUnknown(data['page_index']!, _pageIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_pageIndexMeta);
    }
    if (data.containsKey('strokes')) {
      context.handle(
        _strokesMeta,
        strokes.isAcceptableOrUnknown(data['strokes']!, _strokesMeta),
      );
    } else if (isInserting) {
      context.missing(_strokesMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {notebookId, pageIndex},
  ];
  @override
  PageRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PageRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      notebookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notebook_id'],
      )!,
      pageIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page_index'],
      )!,
      strokes: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}strokes'],
      )!,
      updatedAt: $PageRowsTable.$converterupdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}updated_at'],
        )!,
      ),
    );
  }

  @override
  $PageRowsTable createAlias(String alias) {
    return $PageRowsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $converterupdatedAt =
      const EpochMicrosConverter();
}

class PageRow extends DataClass implements Insertable<PageRow> {
  final String id;
  final String notebookId;
  final int pageIndex;

  /// Binary stroke data, see StrokeCodec.
  final Uint8List strokes;
  final DateTime updatedAt;
  const PageRow({
    required this.id,
    required this.notebookId,
    required this.pageIndex,
    required this.strokes,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['notebook_id'] = Variable<String>(notebookId);
    map['page_index'] = Variable<int>(pageIndex);
    map['strokes'] = Variable<Uint8List>(strokes);
    {
      map['updated_at'] = Variable<int>(
        $PageRowsTable.$converterupdatedAt.toSql(updatedAt),
      );
    }
    return map;
  }

  PageRowsCompanion toCompanion(bool nullToAbsent) {
    return PageRowsCompanion(
      id: Value(id),
      notebookId: Value(notebookId),
      pageIndex: Value(pageIndex),
      strokes: Value(strokes),
      updatedAt: Value(updatedAt),
    );
  }

  factory PageRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PageRow(
      id: serializer.fromJson<String>(json['id']),
      notebookId: serializer.fromJson<String>(json['notebookId']),
      pageIndex: serializer.fromJson<int>(json['pageIndex']),
      strokes: serializer.fromJson<Uint8List>(json['strokes']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'notebookId': serializer.toJson<String>(notebookId),
      'pageIndex': serializer.toJson<int>(pageIndex),
      'strokes': serializer.toJson<Uint8List>(strokes),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  PageRow copyWith({
    String? id,
    String? notebookId,
    int? pageIndex,
    Uint8List? strokes,
    DateTime? updatedAt,
  }) => PageRow(
    id: id ?? this.id,
    notebookId: notebookId ?? this.notebookId,
    pageIndex: pageIndex ?? this.pageIndex,
    strokes: strokes ?? this.strokes,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  PageRow copyWithCompanion(PageRowsCompanion data) {
    return PageRow(
      id: data.id.present ? data.id.value : this.id,
      notebookId: data.notebookId.present
          ? data.notebookId.value
          : this.notebookId,
      pageIndex: data.pageIndex.present ? data.pageIndex.value : this.pageIndex,
      strokes: data.strokes.present ? data.strokes.value : this.strokes,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PageRow(')
          ..write('id: $id, ')
          ..write('notebookId: $notebookId, ')
          ..write('pageIndex: $pageIndex, ')
          ..write('strokes: $strokes, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    notebookId,
    pageIndex,
    $driftBlobEquality.hash(strokes),
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PageRow &&
          other.id == this.id &&
          other.notebookId == this.notebookId &&
          other.pageIndex == this.pageIndex &&
          $driftBlobEquality.equals(other.strokes, this.strokes) &&
          other.updatedAt == this.updatedAt);
}

class PageRowsCompanion extends UpdateCompanion<PageRow> {
  final Value<String> id;
  final Value<String> notebookId;
  final Value<int> pageIndex;
  final Value<Uint8List> strokes;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const PageRowsCompanion({
    this.id = const Value.absent(),
    this.notebookId = const Value.absent(),
    this.pageIndex = const Value.absent(),
    this.strokes = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PageRowsCompanion.insert({
    required String id,
    required String notebookId,
    required int pageIndex,
    required Uint8List strokes,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       notebookId = Value(notebookId),
       pageIndex = Value(pageIndex),
       strokes = Value(strokes),
       updatedAt = Value(updatedAt);
  static Insertable<PageRow> custom({
    Expression<String>? id,
    Expression<String>? notebookId,
    Expression<int>? pageIndex,
    Expression<Uint8List>? strokes,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (notebookId != null) 'notebook_id': notebookId,
      if (pageIndex != null) 'page_index': pageIndex,
      if (strokes != null) 'strokes': strokes,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PageRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? notebookId,
    Value<int>? pageIndex,
    Value<Uint8List>? strokes,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return PageRowsCompanion(
      id: id ?? this.id,
      notebookId: notebookId ?? this.notebookId,
      pageIndex: pageIndex ?? this.pageIndex,
      strokes: strokes ?? this.strokes,
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
    if (notebookId.present) {
      map['notebook_id'] = Variable<String>(notebookId.value);
    }
    if (pageIndex.present) {
      map['page_index'] = Variable<int>(pageIndex.value);
    }
    if (strokes.present) {
      map['strokes'] = Variable<Uint8List>(strokes.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(
        $PageRowsTable.$converterupdatedAt.toSql(updatedAt.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PageRowsCompanion(')
          ..write('id: $id, ')
          ..write('notebookId: $notebookId, ')
          ..write('pageIndex: $pageIndex, ')
          ..write('strokes: $strokes, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $FolderRowsTable folderRows = $FolderRowsTable(this);
  late final $NotebookRowsTable notebookRows = $NotebookRowsTable(this);
  late final $PageRowsTable pageRows = $PageRowsTable(this);
  late final Index idxFoldersParentId = Index(
    'idx_folders_parent_id',
    'CREATE INDEX idx_folders_parent_id ON folders (parent_id)',
  );
  late final Index idxNotebooksFolderId = Index(
    'idx_notebooks_folder_id',
    'CREATE INDEX idx_notebooks_folder_id ON notebooks (folder_id)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    folderRows,
    notebookRows,
    pageRows,
    idxFoldersParentId,
    idxNotebooksFolderId,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'folders',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('folders', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'folders',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('notebooks', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'notebooks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('pages', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$FolderRowsTableCreateCompanionBuilder = FolderRowsCompanion Function({
  required String id,
  required String name,
  Value<String?> parentId,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$FolderRowsTableUpdateCompanionBuilder = FolderRowsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String?> parentId,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

final class $$FolderRowsTableReferences
    extends BaseReferences<_$AppDatabase, $FolderRowsTable, FolderRow> {
  $$FolderRowsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $FolderRowsTable _parentIdTable(_$AppDatabase db) =>
      db.folderRows.createAlias('folders__parent_id__folders__id');

  $$FolderRowsTableProcessedTableManager? get parentId {
    final $_column = $_itemColumn<String>('parent_id');
    if ($_column == null) return null;
    final manager = $$FolderRowsTableTableManager(
      $_db,
      $_db.folderRows,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_parentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$NotebookRowsTable, List<NotebookRow>>
  _notebookRowsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.notebookRows,
    aliasName: 'folders__id__notebooks__folder_id',
  );

  $$NotebookRowsTableProcessedTableManager get notebookRowsRefs {
    final manager = $$NotebookRowsTableTableManager(
      $_db,
      $_db.notebookRows,
    ).filter((f) => f.folderId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_notebookRowsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$FolderRowsTableFilterComposer
    extends Composer<_$AppDatabase, $FolderRowsTable> {
  $$FolderRowsTableFilterComposer({
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

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get createdAt =>
      $composableBuilder(
        column: $table.createdAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  $$FolderRowsTableFilterComposer get parentId {
    final $$FolderRowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentId,
      referencedTable: $db.folderRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FolderRowsTableFilterComposer(
            $db: $db,
            $table: $db.folderRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> notebookRowsRefs(
    Expression<bool> Function($$NotebookRowsTableFilterComposer f) f,
  ) {
    final $$NotebookRowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.notebookRows,
      getReferencedColumn: (t) => t.folderId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotebookRowsTableFilterComposer(
            $db: $db,
            $table: $db.notebookRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FolderRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $FolderRowsTable> {
  $$FolderRowsTableOrderingComposer({
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

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$FolderRowsTableOrderingComposer get parentId {
    final $$FolderRowsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentId,
      referencedTable: $db.folderRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FolderRowsTableOrderingComposer(
            $db: $db,
            $table: $db.folderRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FolderRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FolderRowsTable> {
  $$FolderRowsTableAnnotationComposer({
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

  GeneratedColumnWithTypeConverter<DateTime, int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$FolderRowsTableAnnotationComposer get parentId {
    final $$FolderRowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentId,
      referencedTable: $db.folderRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FolderRowsTableAnnotationComposer(
            $db: $db,
            $table: $db.folderRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> notebookRowsRefs<T extends Object>(
    Expression<T> Function($$NotebookRowsTableAnnotationComposer a) f,
  ) {
    final $$NotebookRowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.notebookRows,
      getReferencedColumn: (t) => t.folderId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotebookRowsTableAnnotationComposer(
            $db: $db,
            $table: $db.notebookRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FolderRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FolderRowsTable,
          FolderRow,
          $$FolderRowsTableFilterComposer,
          $$FolderRowsTableOrderingComposer,
          $$FolderRowsTableAnnotationComposer,
          $$FolderRowsTableCreateCompanionBuilder,
          $$FolderRowsTableUpdateCompanionBuilder,
          (FolderRow, $$FolderRowsTableReferences),
          FolderRow,
          PrefetchHooks Function({bool parentId, bool notebookRowsRefs})
        > {
  $$FolderRowsTableTableManager(_$AppDatabase db, $FolderRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FolderRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FolderRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FolderRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FolderRowsCompanion(
                id: id,
                name: name,
                parentId: parentId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> parentId = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => FolderRowsCompanion.insert(
                id: id,
                name: name,
                parentId: parentId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FolderRowsTable, FolderRow>(table),
                  $$FolderRowsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({parentId = false, notebookRowsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (notebookRowsRefs) db.notebookRows,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (parentId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.parentId,
                            referencedTable: $$FolderRowsTableReferences
                                ._parentIdTable(db),
                            referencedColumn: $$FolderRowsTableReferences
                                ._parentIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (notebookRowsRefs)
                        await $_getPrefetchedData<
                          FolderRow,
                          $FolderRowsTable,
                          NotebookRow
                        >(
                          currentTable: table,
                          referencedTable: $$FolderRowsTableReferences
                              ._notebookRowsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$FolderRowsTableReferences(
                                db,
                                table,
                                p0,
                              ).notebookRowsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.folderId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$FolderRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FolderRowsTable,
      FolderRow,
      $$FolderRowsTableFilterComposer,
      $$FolderRowsTableOrderingComposer,
      $$FolderRowsTableAnnotationComposer,
      $$FolderRowsTableCreateCompanionBuilder,
      $$FolderRowsTableUpdateCompanionBuilder,
      (FolderRow, $$FolderRowsTableReferences),
      FolderRow,
      PrefetchHooks Function({bool parentId, bool notebookRowsRefs})
    >;
typedef $$NotebookRowsTableCreateCompanionBuilder =
    NotebookRowsCompanion Function({
      required String id,
      required String title,
      Value<String?> folderId,
      required int coverColorValue,
      required PaperTemplate template,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$NotebookRowsTableUpdateCompanionBuilder =
    NotebookRowsCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String?> folderId,
      Value<int> coverColorValue,
      Value<PaperTemplate> template,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$NotebookRowsTableReferences
    extends BaseReferences<_$AppDatabase, $NotebookRowsTable, NotebookRow> {
  $$NotebookRowsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $FolderRowsTable _folderIdTable(_$AppDatabase db) =>
      db.folderRows.createAlias('notebooks__folder_id__folders__id');

  $$FolderRowsTableProcessedTableManager? get folderId {
    final $_column = $_itemColumn<String>('folder_id');
    if ($_column == null) return null;
    final manager = $$FolderRowsTableTableManager(
      $_db,
      $_db.folderRows,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_folderIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$PageRowsTable, List<PageRow>> _pageRowsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.pageRows,
    aliasName: 'notebooks__id__pages__notebook_id',
  );

  $$PageRowsTableProcessedTableManager get pageRowsRefs {
    final manager = $$PageRowsTableTableManager(
      $_db,
      $_db.pageRows,
    ).filter((f) => f.notebookId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_pageRowsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$NotebookRowsTableFilterComposer
    extends Composer<_$AppDatabase, $NotebookRowsTable> {
  $$NotebookRowsTableFilterComposer({
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

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get coverColorValue => $composableBuilder(
    column: $table.coverColorValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<PaperTemplate, PaperTemplate, String>
  get template => $composableBuilder(
    column: $table.template,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get createdAt =>
      $composableBuilder(
        column: $table.createdAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get updatedAt =>
      $composableBuilder(
        column: $table.updatedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  $$FolderRowsTableFilterComposer get folderId {
    final $$FolderRowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.folderRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FolderRowsTableFilterComposer(
            $db: $db,
            $table: $db.folderRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> pageRowsRefs(
    Expression<bool> Function($$PageRowsTableFilterComposer f) f,
  ) {
    final $$PageRowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.pageRows,
      getReferencedColumn: (t) => t.notebookId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PageRowsTableFilterComposer(
            $db: $db,
            $table: $db.pageRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$NotebookRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $NotebookRowsTable> {
  $$NotebookRowsTableOrderingComposer({
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

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get coverColorValue => $composableBuilder(
    column: $table.coverColorValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get template => $composableBuilder(
    column: $table.template,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$FolderRowsTableOrderingComposer get folderId {
    final $$FolderRowsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.folderRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FolderRowsTableOrderingComposer(
            $db: $db,
            $table: $db.folderRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NotebookRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $NotebookRowsTable> {
  $$NotebookRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get coverColorValue => $composableBuilder(
    column: $table.coverColorValue,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<PaperTemplate, String> get template =>
      $composableBuilder(column: $table.template, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$FolderRowsTableAnnotationComposer get folderId {
    final $$FolderRowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.folderRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FolderRowsTableAnnotationComposer(
            $db: $db,
            $table: $db.folderRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> pageRowsRefs<T extends Object>(
    Expression<T> Function($$PageRowsTableAnnotationComposer a) f,
  ) {
    final $$PageRowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.pageRows,
      getReferencedColumn: (t) => t.notebookId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PageRowsTableAnnotationComposer(
            $db: $db,
            $table: $db.pageRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$NotebookRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NotebookRowsTable,
          NotebookRow,
          $$NotebookRowsTableFilterComposer,
          $$NotebookRowsTableOrderingComposer,
          $$NotebookRowsTableAnnotationComposer,
          $$NotebookRowsTableCreateCompanionBuilder,
          $$NotebookRowsTableUpdateCompanionBuilder,
          (NotebookRow, $$NotebookRowsTableReferences),
          NotebookRow,
          PrefetchHooks Function({bool folderId, bool pageRowsRefs})
        > {
  $$NotebookRowsTableTableManager(_$AppDatabase db, $NotebookRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NotebookRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NotebookRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NotebookRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> folderId = const Value.absent(),
                Value<int> coverColorValue = const Value.absent(),
                Value<PaperTemplate> template = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NotebookRowsCompanion(
                id: id,
                title: title,
                folderId: folderId,
                coverColorValue: coverColorValue,
                template: template,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                Value<String?> folderId = const Value.absent(),
                required int coverColorValue,
                required PaperTemplate template,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => NotebookRowsCompanion.insert(
                id: id,
                title: title,
                folderId: folderId,
                coverColorValue: coverColorValue,
                template: template,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$NotebookRowsTable, NotebookRow>(table),
                  $$NotebookRowsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({folderId = false, pageRowsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (pageRowsRefs) db.pageRows],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (folderId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.folderId,
                        referencedTable: $$NotebookRowsTableReferences
                            ._folderIdTable(db),
                        referencedColumn: $$NotebookRowsTableReferences
                            ._folderIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (pageRowsRefs)
                    await $_getPrefetchedData<
                      NotebookRow,
                      $NotebookRowsTable,
                      PageRow
                    >(
                      currentTable: table,
                      referencedTable: $$NotebookRowsTableReferences
                          ._pageRowsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$NotebookRowsTableReferences(
                            db,
                            table,
                            p0,
                          ).pageRowsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.notebookId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$NotebookRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NotebookRowsTable,
      NotebookRow,
      $$NotebookRowsTableFilterComposer,
      $$NotebookRowsTableOrderingComposer,
      $$NotebookRowsTableAnnotationComposer,
      $$NotebookRowsTableCreateCompanionBuilder,
      $$NotebookRowsTableUpdateCompanionBuilder,
      (NotebookRow, $$NotebookRowsTableReferences),
      NotebookRow,
      PrefetchHooks Function({bool folderId, bool pageRowsRefs})
    >;
typedef $$PageRowsTableCreateCompanionBuilder = PageRowsCompanion Function({
  required String id,
  required String notebookId,
  required int pageIndex,
  required Uint8List strokes,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$PageRowsTableUpdateCompanionBuilder = PageRowsCompanion Function({
  Value<String> id,
  Value<String> notebookId,
  Value<int> pageIndex,
  Value<Uint8List> strokes,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

final class $$PageRowsTableReferences
    extends BaseReferences<_$AppDatabase, $PageRowsTable, PageRow> {
  $$PageRowsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $NotebookRowsTable _notebookIdTable(_$AppDatabase db) =>
      db.notebookRows.createAlias('pages__notebook_id__notebooks__id');

  $$NotebookRowsTableProcessedTableManager get notebookId {
    final $_column = $_itemColumn<String>('notebook_id')!;

    final manager = $$NotebookRowsTableTableManager(
      $_db,
      $_db.notebookRows,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_notebookIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PageRowsTableFilterComposer
    extends Composer<_$AppDatabase, $PageRowsTable> {
  $$PageRowsTableFilterComposer({
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

  ColumnFilters<int> get pageIndex => $composableBuilder(
    column: $table.pageIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get strokes => $composableBuilder(
    column: $table.strokes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get updatedAt =>
      $composableBuilder(
        column: $table.updatedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  $$NotebookRowsTableFilterComposer get notebookId {
    final $$NotebookRowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.notebookId,
      referencedTable: $db.notebookRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotebookRowsTableFilterComposer(
            $db: $db,
            $table: $db.notebookRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PageRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $PageRowsTable> {
  $$PageRowsTableOrderingComposer({
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

  ColumnOrderings<int> get pageIndex => $composableBuilder(
    column: $table.pageIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get strokes => $composableBuilder(
    column: $table.strokes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$NotebookRowsTableOrderingComposer get notebookId {
    final $$NotebookRowsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.notebookId,
      referencedTable: $db.notebookRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotebookRowsTableOrderingComposer(
            $db: $db,
            $table: $db.notebookRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PageRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PageRowsTable> {
  $$PageRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get pageIndex =>
      $composableBuilder(column: $table.pageIndex, builder: (column) => column);

  GeneratedColumn<Uint8List> get strokes =>
      $composableBuilder(column: $table.strokes, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$NotebookRowsTableAnnotationComposer get notebookId {
    final $$NotebookRowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.notebookId,
      referencedTable: $db.notebookRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotebookRowsTableAnnotationComposer(
            $db: $db,
            $table: $db.notebookRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PageRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PageRowsTable,
          PageRow,
          $$PageRowsTableFilterComposer,
          $$PageRowsTableOrderingComposer,
          $$PageRowsTableAnnotationComposer,
          $$PageRowsTableCreateCompanionBuilder,
          $$PageRowsTableUpdateCompanionBuilder,
          (PageRow, $$PageRowsTableReferences),
          PageRow,
          PrefetchHooks Function({bool notebookId})
        > {
  $$PageRowsTableTableManager(_$AppDatabase db, $PageRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PageRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PageRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PageRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> notebookId = const Value.absent(),
                Value<int> pageIndex = const Value.absent(),
                Value<Uint8List> strokes = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PageRowsCompanion(
                id: id,
                notebookId: notebookId,
                pageIndex: pageIndex,
                strokes: strokes,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String notebookId,
                required int pageIndex,
                required Uint8List strokes,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => PageRowsCompanion.insert(
                id: id,
                notebookId: notebookId,
                pageIndex: pageIndex,
                strokes: strokes,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PageRowsTable, PageRow>(table),
                  $$PageRowsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({notebookId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (notebookId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.notebookId,
                        referencedTable: $$PageRowsTableReferences
                            ._notebookIdTable(db),
                        referencedColumn: $$PageRowsTableReferences
                            ._notebookIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PageRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PageRowsTable,
      PageRow,
      $$PageRowsTableFilterComposer,
      $$PageRowsTableOrderingComposer,
      $$PageRowsTableAnnotationComposer,
      $$PageRowsTableCreateCompanionBuilder,
      $$PageRowsTableUpdateCompanionBuilder,
      (PageRow, $$PageRowsTableReferences),
      PageRow,
      PrefetchHooks Function({bool notebookId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$FolderRowsTableTableManager get folderRows =>
      $$FolderRowsTableTableManager(_db, _db.folderRows);
  $$NotebookRowsTableTableManager get notebookRows =>
      $$NotebookRowsTableTableManager(_db, _db.notebookRows);
  $$PageRowsTableTableManager get pageRows =>
      $$PageRowsTableTableManager(_db, _db.pageRows);
}
