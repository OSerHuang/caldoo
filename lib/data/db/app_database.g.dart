// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSetting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class AppSetting extends DataClass implements Insertable<AppSetting> {
  /// Preference name, e.g. `notice_seen`.
  final String key;

  /// Preference value, stored as text (callers parse as needed).
  final String value;
  const AppSetting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(key: Value(key), value: Value(value));
  }

  factory AppSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSetting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  AppSetting copyWith({String? key, String? value}) =>
      AppSetting(key: key ?? this.key, value: value ?? this.value);
  AppSetting copyWithCompanion(AppSettingsCompanion data) {
    return AppSetting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSetting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSetting &&
          other.key == this.key &&
          other.value == this.value);
}

class AppSettingsCompanion extends UpdateCompanion<AppSetting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const AppSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<AppSetting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return AppSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UserProfilesTable extends UserProfiles
    with TableInfo<$UserProfilesTable, UserProfileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  late final GeneratedColumnWithTypeConverter<Sex, String> sex =
      GeneratedColumn<String>(
        'sex',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<Sex>($UserProfilesTable.$convertersex);
  static const VerificationMeta _birthDateMeta = const VerificationMeta(
    'birthDate',
  );
  @override
  late final GeneratedColumn<DateTime> birthDate = GeneratedColumn<DateTime>(
    'birth_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _heightCmMeta = const VerificationMeta(
    'heightCm',
  );
  @override
  late final GeneratedColumn<double> heightCm = GeneratedColumn<double>(
    'height_cm',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _weightKgMeta = const VerificationMeta(
    'weightKg',
  );
  @override
  late final GeneratedColumn<double> weightKg = GeneratedColumn<double>(
    'weight_kg',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bmrKcalOverrideMeta = const VerificationMeta(
    'bmrKcalOverride',
  );
  @override
  late final GeneratedColumn<int> bmrKcalOverride = GeneratedColumn<int>(
    'bmr_kcal_override',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sex,
    birthDate,
    heightCm,
    weightKg,
    bmrKcalOverride,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_profile';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserProfileRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('birth_date')) {
      context.handle(
        _birthDateMeta,
        birthDate.isAcceptableOrUnknown(data['birth_date']!, _birthDateMeta),
      );
    } else if (isInserting) {
      context.missing(_birthDateMeta);
    }
    if (data.containsKey('height_cm')) {
      context.handle(
        _heightCmMeta,
        heightCm.isAcceptableOrUnknown(data['height_cm']!, _heightCmMeta),
      );
    } else if (isInserting) {
      context.missing(_heightCmMeta);
    }
    if (data.containsKey('weight_kg')) {
      context.handle(
        _weightKgMeta,
        weightKg.isAcceptableOrUnknown(data['weight_kg']!, _weightKgMeta),
      );
    } else if (isInserting) {
      context.missing(_weightKgMeta);
    }
    if (data.containsKey('bmr_kcal_override')) {
      context.handle(
        _bmrKcalOverrideMeta,
        bmrKcalOverride.isAcceptableOrUnknown(
          data['bmr_kcal_override']!,
          _bmrKcalOverrideMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserProfileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserProfileRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sex: $UserProfilesTable.$convertersex.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}sex'],
        )!,
      ),
      birthDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}birth_date'],
      )!,
      heightCm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}height_cm'],
      )!,
      weightKg: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}weight_kg'],
      )!,
      bmrKcalOverride: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bmr_kcal_override'],
      ),
    );
  }

  @override
  $UserProfilesTable createAlias(String alias) {
    return $UserProfilesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<Sex, String, String> $convertersex =
      const EnumNameConverter<Sex>(Sex.values);
}

class UserProfileRow extends DataClass implements Insertable<UserProfileRow> {
  /// Fixed primary key of the single profile row; always `0`.
  final int id;

  /// Biological sex (see [Sex]); stored as the enum name.
  final Sex sex;

  /// Birthday as a canonical date-only value (UTC midnight, see
  /// [canonicalBirthDate]). The age is derived from it at use time, so it never
  /// goes stale and never needs a yearly edit.
  final DateTime birthDate;

  /// Height in centimetres.
  final double heightCm;

  /// Weight in kilograms (editable; BMR recomputes on change).
  final double weightKg;

  /// User-set basal metabolic rate override in **whole kcal/day**.
  ///
  /// `NULL` means "derive it": the profile has no activity-level column, so the
  /// engine falls back to the Mifflin-St Jeor estimate from the anthropometrics
  /// above. A user who knows their own BMR can pin it here and it wins. Energy
  /// is integer-only, so this is an INTEGER column.
  final int? bmrKcalOverride;
  const UserProfileRow({
    required this.id,
    required this.sex,
    required this.birthDate,
    required this.heightCm,
    required this.weightKg,
    this.bmrKcalOverride,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    {
      map['sex'] = Variable<String>(
        $UserProfilesTable.$convertersex.toSql(sex),
      );
    }
    map['birth_date'] = Variable<DateTime>(birthDate);
    map['height_cm'] = Variable<double>(heightCm);
    map['weight_kg'] = Variable<double>(weightKg);
    if (!nullToAbsent || bmrKcalOverride != null) {
      map['bmr_kcal_override'] = Variable<int>(bmrKcalOverride);
    }
    return map;
  }

  UserProfilesCompanion toCompanion(bool nullToAbsent) {
    return UserProfilesCompanion(
      id: Value(id),
      sex: Value(sex),
      birthDate: Value(birthDate),
      heightCm: Value(heightCm),
      weightKg: Value(weightKg),
      bmrKcalOverride: bmrKcalOverride == null && nullToAbsent
          ? const Value.absent()
          : Value(bmrKcalOverride),
    );
  }

  factory UserProfileRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserProfileRow(
      id: serializer.fromJson<int>(json['id']),
      sex: $UserProfilesTable.$convertersex.fromJson(
        serializer.fromJson<String>(json['sex']),
      ),
      birthDate: serializer.fromJson<DateTime>(json['birthDate']),
      heightCm: serializer.fromJson<double>(json['heightCm']),
      weightKg: serializer.fromJson<double>(json['weightKg']),
      bmrKcalOverride: serializer.fromJson<int?>(json['bmrKcalOverride']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sex': serializer.toJson<String>(
        $UserProfilesTable.$convertersex.toJson(sex),
      ),
      'birthDate': serializer.toJson<DateTime>(birthDate),
      'heightCm': serializer.toJson<double>(heightCm),
      'weightKg': serializer.toJson<double>(weightKg),
      'bmrKcalOverride': serializer.toJson<int?>(bmrKcalOverride),
    };
  }

  UserProfileRow copyWith({
    int? id,
    Sex? sex,
    DateTime? birthDate,
    double? heightCm,
    double? weightKg,
    Value<int?> bmrKcalOverride = const Value.absent(),
  }) => UserProfileRow(
    id: id ?? this.id,
    sex: sex ?? this.sex,
    birthDate: birthDate ?? this.birthDate,
    heightCm: heightCm ?? this.heightCm,
    weightKg: weightKg ?? this.weightKg,
    bmrKcalOverride: bmrKcalOverride.present
        ? bmrKcalOverride.value
        : this.bmrKcalOverride,
  );
  UserProfileRow copyWithCompanion(UserProfilesCompanion data) {
    return UserProfileRow(
      id: data.id.present ? data.id.value : this.id,
      sex: data.sex.present ? data.sex.value : this.sex,
      birthDate: data.birthDate.present ? data.birthDate.value : this.birthDate,
      heightCm: data.heightCm.present ? data.heightCm.value : this.heightCm,
      weightKg: data.weightKg.present ? data.weightKg.value : this.weightKg,
      bmrKcalOverride: data.bmrKcalOverride.present
          ? data.bmrKcalOverride.value
          : this.bmrKcalOverride,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserProfileRow(')
          ..write('id: $id, ')
          ..write('sex: $sex, ')
          ..write('birthDate: $birthDate, ')
          ..write('heightCm: $heightCm, ')
          ..write('weightKg: $weightKg, ')
          ..write('bmrKcalOverride: $bmrKcalOverride')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, sex, birthDate, heightCm, weightKg, bmrKcalOverride);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserProfileRow &&
          other.id == this.id &&
          other.sex == this.sex &&
          other.birthDate == this.birthDate &&
          other.heightCm == this.heightCm &&
          other.weightKg == this.weightKg &&
          other.bmrKcalOverride == this.bmrKcalOverride);
}

class UserProfilesCompanion extends UpdateCompanion<UserProfileRow> {
  final Value<int> id;
  final Value<Sex> sex;
  final Value<DateTime> birthDate;
  final Value<double> heightCm;
  final Value<double> weightKg;
  final Value<int?> bmrKcalOverride;
  const UserProfilesCompanion({
    this.id = const Value.absent(),
    this.sex = const Value.absent(),
    this.birthDate = const Value.absent(),
    this.heightCm = const Value.absent(),
    this.weightKg = const Value.absent(),
    this.bmrKcalOverride = const Value.absent(),
  });
  UserProfilesCompanion.insert({
    this.id = const Value.absent(),
    required Sex sex,
    required DateTime birthDate,
    required double heightCm,
    required double weightKg,
    this.bmrKcalOverride = const Value.absent(),
  }) : sex = Value(sex),
       birthDate = Value(birthDate),
       heightCm = Value(heightCm),
       weightKg = Value(weightKg);
  static Insertable<UserProfileRow> custom({
    Expression<int>? id,
    Expression<String>? sex,
    Expression<DateTime>? birthDate,
    Expression<double>? heightCm,
    Expression<double>? weightKg,
    Expression<int>? bmrKcalOverride,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sex != null) 'sex': sex,
      if (birthDate != null) 'birth_date': birthDate,
      if (heightCm != null) 'height_cm': heightCm,
      if (weightKg != null) 'weight_kg': weightKg,
      if (bmrKcalOverride != null) 'bmr_kcal_override': bmrKcalOverride,
    });
  }

  UserProfilesCompanion copyWith({
    Value<int>? id,
    Value<Sex>? sex,
    Value<DateTime>? birthDate,
    Value<double>? heightCm,
    Value<double>? weightKg,
    Value<int?>? bmrKcalOverride,
  }) {
    return UserProfilesCompanion(
      id: id ?? this.id,
      sex: sex ?? this.sex,
      birthDate: birthDate ?? this.birthDate,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      bmrKcalOverride: bmrKcalOverride ?? this.bmrKcalOverride,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sex.present) {
      map['sex'] = Variable<String>(
        $UserProfilesTable.$convertersex.toSql(sex.value),
      );
    }
    if (birthDate.present) {
      map['birth_date'] = Variable<DateTime>(birthDate.value);
    }
    if (heightCm.present) {
      map['height_cm'] = Variable<double>(heightCm.value);
    }
    if (weightKg.present) {
      map['weight_kg'] = Variable<double>(weightKg.value);
    }
    if (bmrKcalOverride.present) {
      map['bmr_kcal_override'] = Variable<int>(bmrKcalOverride.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserProfilesCompanion(')
          ..write('id: $id, ')
          ..write('sex: $sex, ')
          ..write('birthDate: $birthDate, ')
          ..write('heightCm: $heightCm, ')
          ..write('weightKg: $weightKg, ')
          ..write('bmrKcalOverride: $bmrKcalOverride')
          ..write(')'))
        .toString();
  }
}

class $FoodsTable extends Foods with TableInfo<$FoodsTable, FoodRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FoodsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _brandMeta = const VerificationMeta('brand');
  @override
  late final GeneratedColumn<String> brand = GeneratedColumn<String>(
    'brand',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _barcodeMeta = const VerificationMeta(
    'barcode',
  );
  @override
  late final GeneratedColumn<String> barcode = GeneratedColumn<String>(
    'barcode',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _aliasesMeta = const VerificationMeta(
    'aliases',
  );
  @override
  late final GeneratedColumn<String> aliases = GeneratedColumn<String>(
    'aliases',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _servingsMeta = const VerificationMeta(
    'servings',
  );
  @override
  late final GeneratedColumn<String> servings = GeneratedColumn<String>(
    'servings',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<FoodStatus?, String> status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<FoodStatus?>($FoodsTable.$converterstatusn);
  @override
  late final GeneratedColumnWithTypeConverter<MeasureBasis?, String> basis =
      GeneratedColumn<String>(
        'basis',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<MeasureBasis?>($FoodsTable.$converterbasisn);
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<FoodSource, String> source =
      GeneratedColumn<String>(
        'source',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<FoodSource>($FoodsTable.$convertersource);
  static const VerificationMeta _kcalMeta = const VerificationMeta('kcal');
  @override
  late final GeneratedColumn<int> kcal = GeneratedColumn<int>(
    'kcal',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _carbGMeta = const VerificationMeta('carbG');
  @override
  late final GeneratedColumn<double> carbG = GeneratedColumn<double>(
    'carb_g',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _proteinGMeta = const VerificationMeta(
    'proteinG',
  );
  @override
  late final GeneratedColumn<double> proteinG = GeneratedColumn<double>(
    'protein_g',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fatGMeta = const VerificationMeta('fatG');
  @override
  late final GeneratedColumn<double> fatG = GeneratedColumn<double>(
    'fat_g',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sugarGMeta = const VerificationMeta('sugarG');
  @override
  late final GeneratedColumn<double> sugarG = GeneratedColumn<double>(
    'sugar_g',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _saturatedFatGMeta = const VerificationMeta(
    'saturatedFatG',
  );
  @override
  late final GeneratedColumn<double> saturatedFatG = GeneratedColumn<double>(
    'saturated_fat_g',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sodiumMgMeta = const VerificationMeta(
    'sodiumMg',
  );
  @override
  late final GeneratedColumn<double> sodiumMg = GeneratedColumn<double>(
    'sodium_mg',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    brand,
    barcode,
    aliases,
    servings,
    status,
    basis,
    notes,
    source,
    kcal,
    carbG,
    proteinG,
    fatG,
    sugarG,
    saturatedFatG,
    sodiumMg,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'foods';
  @override
  VerificationContext validateIntegrity(
    Insertable<FoodRow> instance, {
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
    if (data.containsKey('brand')) {
      context.handle(
        _brandMeta,
        brand.isAcceptableOrUnknown(data['brand']!, _brandMeta),
      );
    }
    if (data.containsKey('barcode')) {
      context.handle(
        _barcodeMeta,
        barcode.isAcceptableOrUnknown(data['barcode']!, _barcodeMeta),
      );
    }
    if (data.containsKey('aliases')) {
      context.handle(
        _aliasesMeta,
        aliases.isAcceptableOrUnknown(data['aliases']!, _aliasesMeta),
      );
    }
    if (data.containsKey('servings')) {
      context.handle(
        _servingsMeta,
        servings.isAcceptableOrUnknown(data['servings']!, _servingsMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('kcal')) {
      context.handle(
        _kcalMeta,
        kcal.isAcceptableOrUnknown(data['kcal']!, _kcalMeta),
      );
    }
    if (data.containsKey('carb_g')) {
      context.handle(
        _carbGMeta,
        carbG.isAcceptableOrUnknown(data['carb_g']!, _carbGMeta),
      );
    }
    if (data.containsKey('protein_g')) {
      context.handle(
        _proteinGMeta,
        proteinG.isAcceptableOrUnknown(data['protein_g']!, _proteinGMeta),
      );
    }
    if (data.containsKey('fat_g')) {
      context.handle(
        _fatGMeta,
        fatG.isAcceptableOrUnknown(data['fat_g']!, _fatGMeta),
      );
    }
    if (data.containsKey('sugar_g')) {
      context.handle(
        _sugarGMeta,
        sugarG.isAcceptableOrUnknown(data['sugar_g']!, _sugarGMeta),
      );
    }
    if (data.containsKey('saturated_fat_g')) {
      context.handle(
        _saturatedFatGMeta,
        saturatedFatG.isAcceptableOrUnknown(
          data['saturated_fat_g']!,
          _saturatedFatGMeta,
        ),
      );
    }
    if (data.containsKey('sodium_mg')) {
      context.handle(
        _sodiumMgMeta,
        sodiumMg.isAcceptableOrUnknown(data['sodium_mg']!, _sodiumMgMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FoodRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FoodRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      brand: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}brand'],
      ),
      barcode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}barcode'],
      ),
      aliases: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}aliases'],
      ),
      servings: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}servings'],
      ),
      status: $FoodsTable.$converterstatusn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        ),
      ),
      basis: $FoodsTable.$converterbasisn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}basis'],
        ),
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      source: $FoodsTable.$convertersource.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}source'],
        )!,
      ),
      kcal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}kcal'],
      ),
      carbG: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}carb_g'],
      ),
      proteinG: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}protein_g'],
      ),
      fatG: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}fat_g'],
      ),
      sugarG: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}sugar_g'],
      ),
      saturatedFatG: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}saturated_fat_g'],
      ),
      sodiumMg: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}sodium_mg'],
      ),
    );
  }

  @override
  $FoodsTable createAlias(String alias) {
    return $FoodsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<FoodStatus, String, String> $converterstatus =
      const EnumNameConverter<FoodStatus>(FoodStatus.values);
  static JsonTypeConverter2<FoodStatus?, String?, String?> $converterstatusn =
      JsonTypeConverter2.asNullable($converterstatus);
  static JsonTypeConverter2<MeasureBasis, String, String> $converterbasis =
      const EnumNameConverter<MeasureBasis>(MeasureBasis.values);
  static JsonTypeConverter2<MeasureBasis?, String?, String?> $converterbasisn =
      JsonTypeConverter2.asNullable($converterbasis);
  static JsonTypeConverter2<FoodSource, String, String> $convertersource =
      const EnumNameConverter<FoodSource>(FoodSource.values);
}

class FoodRow extends DataClass implements Insertable<FoodRow> {
  /// UUID of the food.
  final String id;
  final String name;
  final String? brand;

  /// Optional barcode; the column exists for phase 2, there is no scanner UI.
  final String? barcode;

  /// Structured aliases, serialized as a JSON array (`["泡面","小饼干"]`).
  /// Nullable: legacy rows keep their aliases in [notes] until edited.
  final String? aliases;

  /// Structured servings, serialized as a JSON array of
  /// `{label, amount, unit}` objects. Nullable for legacy rows (same reason as
  /// [aliases]).
  final String? servings;

  /// `active` (NULL reads as active) or `archived`: archived foods are skipped
  /// by matching but kept for history.
  final FoodStatus? status;

  /// `per100g` (NULL reads as per-100 g) or `per100ml`.
  final MeasureBasis? basis;

  /// Free-form user supplement: remarks, or a legacy alias/serving that has
  /// not been structured yet. Nullable — blank stays `NULL`, never `''`.
  final String? notes;

  /// Where the nutrient values came from; stored as the enum name.
  final FoodSource source;

  /// Per-100 g energy in **whole kcal** (canonical energy unit — never kJ and
  /// never fractional: every energy value in the app is an integer).
  final int? kcal;

  /// Per-100 g carbohydrate in grams.
  final double? carbG;

  /// Per-100 g protein in grams.
  final double? proteinG;

  /// Per-100 g fat in grams.
  final double? fatG;

  /// Per-100 g sugar in grams (GB 28050 optional declaration).
  final double? sugarG;

  /// Per-100 g saturated fat in grams (GB 28050 optional declaration).
  final double? saturatedFatG;

  /// Per-100 g sodium in mg — the canonical salt/sodium value on a food.
  final double? sodiumMg;
  const FoodRow({
    required this.id,
    required this.name,
    this.brand,
    this.barcode,
    this.aliases,
    this.servings,
    this.status,
    this.basis,
    this.notes,
    required this.source,
    this.kcal,
    this.carbG,
    this.proteinG,
    this.fatG,
    this.sugarG,
    this.saturatedFatG,
    this.sodiumMg,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || brand != null) {
      map['brand'] = Variable<String>(brand);
    }
    if (!nullToAbsent || barcode != null) {
      map['barcode'] = Variable<String>(barcode);
    }
    if (!nullToAbsent || aliases != null) {
      map['aliases'] = Variable<String>(aliases);
    }
    if (!nullToAbsent || servings != null) {
      map['servings'] = Variable<String>(servings);
    }
    if (!nullToAbsent || status != null) {
      map['status'] = Variable<String>(
        $FoodsTable.$converterstatusn.toSql(status),
      );
    }
    if (!nullToAbsent || basis != null) {
      map['basis'] = Variable<String>(
        $FoodsTable.$converterbasisn.toSql(basis),
      );
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    {
      map['source'] = Variable<String>(
        $FoodsTable.$convertersource.toSql(source),
      );
    }
    if (!nullToAbsent || kcal != null) {
      map['kcal'] = Variable<int>(kcal);
    }
    if (!nullToAbsent || carbG != null) {
      map['carb_g'] = Variable<double>(carbG);
    }
    if (!nullToAbsent || proteinG != null) {
      map['protein_g'] = Variable<double>(proteinG);
    }
    if (!nullToAbsent || fatG != null) {
      map['fat_g'] = Variable<double>(fatG);
    }
    if (!nullToAbsent || sugarG != null) {
      map['sugar_g'] = Variable<double>(sugarG);
    }
    if (!nullToAbsent || saturatedFatG != null) {
      map['saturated_fat_g'] = Variable<double>(saturatedFatG);
    }
    if (!nullToAbsent || sodiumMg != null) {
      map['sodium_mg'] = Variable<double>(sodiumMg);
    }
    return map;
  }

  FoodsCompanion toCompanion(bool nullToAbsent) {
    return FoodsCompanion(
      id: Value(id),
      name: Value(name),
      brand: brand == null && nullToAbsent
          ? const Value.absent()
          : Value(brand),
      barcode: barcode == null && nullToAbsent
          ? const Value.absent()
          : Value(barcode),
      aliases: aliases == null && nullToAbsent
          ? const Value.absent()
          : Value(aliases),
      servings: servings == null && nullToAbsent
          ? const Value.absent()
          : Value(servings),
      status: status == null && nullToAbsent
          ? const Value.absent()
          : Value(status),
      basis: basis == null && nullToAbsent
          ? const Value.absent()
          : Value(basis),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      source: Value(source),
      kcal: kcal == null && nullToAbsent ? const Value.absent() : Value(kcal),
      carbG: carbG == null && nullToAbsent
          ? const Value.absent()
          : Value(carbG),
      proteinG: proteinG == null && nullToAbsent
          ? const Value.absent()
          : Value(proteinG),
      fatG: fatG == null && nullToAbsent ? const Value.absent() : Value(fatG),
      sugarG: sugarG == null && nullToAbsent
          ? const Value.absent()
          : Value(sugarG),
      saturatedFatG: saturatedFatG == null && nullToAbsent
          ? const Value.absent()
          : Value(saturatedFatG),
      sodiumMg: sodiumMg == null && nullToAbsent
          ? const Value.absent()
          : Value(sodiumMg),
    );
  }

  factory FoodRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FoodRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      brand: serializer.fromJson<String?>(json['brand']),
      barcode: serializer.fromJson<String?>(json['barcode']),
      aliases: serializer.fromJson<String?>(json['aliases']),
      servings: serializer.fromJson<String?>(json['servings']),
      status: $FoodsTable.$converterstatusn.fromJson(
        serializer.fromJson<String?>(json['status']),
      ),
      basis: $FoodsTable.$converterbasisn.fromJson(
        serializer.fromJson<String?>(json['basis']),
      ),
      notes: serializer.fromJson<String?>(json['notes']),
      source: $FoodsTable.$convertersource.fromJson(
        serializer.fromJson<String>(json['source']),
      ),
      kcal: serializer.fromJson<int?>(json['kcal']),
      carbG: serializer.fromJson<double?>(json['carbG']),
      proteinG: serializer.fromJson<double?>(json['proteinG']),
      fatG: serializer.fromJson<double?>(json['fatG']),
      sugarG: serializer.fromJson<double?>(json['sugarG']),
      saturatedFatG: serializer.fromJson<double?>(json['saturatedFatG']),
      sodiumMg: serializer.fromJson<double?>(json['sodiumMg']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'brand': serializer.toJson<String?>(brand),
      'barcode': serializer.toJson<String?>(barcode),
      'aliases': serializer.toJson<String?>(aliases),
      'servings': serializer.toJson<String?>(servings),
      'status': serializer.toJson<String?>(
        $FoodsTable.$converterstatusn.toJson(status),
      ),
      'basis': serializer.toJson<String?>(
        $FoodsTable.$converterbasisn.toJson(basis),
      ),
      'notes': serializer.toJson<String?>(notes),
      'source': serializer.toJson<String>(
        $FoodsTable.$convertersource.toJson(source),
      ),
      'kcal': serializer.toJson<int?>(kcal),
      'carbG': serializer.toJson<double?>(carbG),
      'proteinG': serializer.toJson<double?>(proteinG),
      'fatG': serializer.toJson<double?>(fatG),
      'sugarG': serializer.toJson<double?>(sugarG),
      'saturatedFatG': serializer.toJson<double?>(saturatedFatG),
      'sodiumMg': serializer.toJson<double?>(sodiumMg),
    };
  }

  FoodRow copyWith({
    String? id,
    String? name,
    Value<String?> brand = const Value.absent(),
    Value<String?> barcode = const Value.absent(),
    Value<String?> aliases = const Value.absent(),
    Value<String?> servings = const Value.absent(),
    Value<FoodStatus?> status = const Value.absent(),
    Value<MeasureBasis?> basis = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    FoodSource? source,
    Value<int?> kcal = const Value.absent(),
    Value<double?> carbG = const Value.absent(),
    Value<double?> proteinG = const Value.absent(),
    Value<double?> fatG = const Value.absent(),
    Value<double?> sugarG = const Value.absent(),
    Value<double?> saturatedFatG = const Value.absent(),
    Value<double?> sodiumMg = const Value.absent(),
  }) => FoodRow(
    id: id ?? this.id,
    name: name ?? this.name,
    brand: brand.present ? brand.value : this.brand,
    barcode: barcode.present ? barcode.value : this.barcode,
    aliases: aliases.present ? aliases.value : this.aliases,
    servings: servings.present ? servings.value : this.servings,
    status: status.present ? status.value : this.status,
    basis: basis.present ? basis.value : this.basis,
    notes: notes.present ? notes.value : this.notes,
    source: source ?? this.source,
    kcal: kcal.present ? kcal.value : this.kcal,
    carbG: carbG.present ? carbG.value : this.carbG,
    proteinG: proteinG.present ? proteinG.value : this.proteinG,
    fatG: fatG.present ? fatG.value : this.fatG,
    sugarG: sugarG.present ? sugarG.value : this.sugarG,
    saturatedFatG: saturatedFatG.present
        ? saturatedFatG.value
        : this.saturatedFatG,
    sodiumMg: sodiumMg.present ? sodiumMg.value : this.sodiumMg,
  );
  FoodRow copyWithCompanion(FoodsCompanion data) {
    return FoodRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      brand: data.brand.present ? data.brand.value : this.brand,
      barcode: data.barcode.present ? data.barcode.value : this.barcode,
      aliases: data.aliases.present ? data.aliases.value : this.aliases,
      servings: data.servings.present ? data.servings.value : this.servings,
      status: data.status.present ? data.status.value : this.status,
      basis: data.basis.present ? data.basis.value : this.basis,
      notes: data.notes.present ? data.notes.value : this.notes,
      source: data.source.present ? data.source.value : this.source,
      kcal: data.kcal.present ? data.kcal.value : this.kcal,
      carbG: data.carbG.present ? data.carbG.value : this.carbG,
      proteinG: data.proteinG.present ? data.proteinG.value : this.proteinG,
      fatG: data.fatG.present ? data.fatG.value : this.fatG,
      sugarG: data.sugarG.present ? data.sugarG.value : this.sugarG,
      saturatedFatG: data.saturatedFatG.present
          ? data.saturatedFatG.value
          : this.saturatedFatG,
      sodiumMg: data.sodiumMg.present ? data.sodiumMg.value : this.sodiumMg,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FoodRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('brand: $brand, ')
          ..write('barcode: $barcode, ')
          ..write('aliases: $aliases, ')
          ..write('servings: $servings, ')
          ..write('status: $status, ')
          ..write('basis: $basis, ')
          ..write('notes: $notes, ')
          ..write('source: $source, ')
          ..write('kcal: $kcal, ')
          ..write('carbG: $carbG, ')
          ..write('proteinG: $proteinG, ')
          ..write('fatG: $fatG, ')
          ..write('sugarG: $sugarG, ')
          ..write('saturatedFatG: $saturatedFatG, ')
          ..write('sodiumMg: $sodiumMg')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    brand,
    barcode,
    aliases,
    servings,
    status,
    basis,
    notes,
    source,
    kcal,
    carbG,
    proteinG,
    fatG,
    sugarG,
    saturatedFatG,
    sodiumMg,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FoodRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.brand == this.brand &&
          other.barcode == this.barcode &&
          other.aliases == this.aliases &&
          other.servings == this.servings &&
          other.status == this.status &&
          other.basis == this.basis &&
          other.notes == this.notes &&
          other.source == this.source &&
          other.kcal == this.kcal &&
          other.carbG == this.carbG &&
          other.proteinG == this.proteinG &&
          other.fatG == this.fatG &&
          other.sugarG == this.sugarG &&
          other.saturatedFatG == this.saturatedFatG &&
          other.sodiumMg == this.sodiumMg);
}

class FoodsCompanion extends UpdateCompanion<FoodRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> brand;
  final Value<String?> barcode;
  final Value<String?> aliases;
  final Value<String?> servings;
  final Value<FoodStatus?> status;
  final Value<MeasureBasis?> basis;
  final Value<String?> notes;
  final Value<FoodSource> source;
  final Value<int?> kcal;
  final Value<double?> carbG;
  final Value<double?> proteinG;
  final Value<double?> fatG;
  final Value<double?> sugarG;
  final Value<double?> saturatedFatG;
  final Value<double?> sodiumMg;
  final Value<int> rowid;
  const FoodsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.brand = const Value.absent(),
    this.barcode = const Value.absent(),
    this.aliases = const Value.absent(),
    this.servings = const Value.absent(),
    this.status = const Value.absent(),
    this.basis = const Value.absent(),
    this.notes = const Value.absent(),
    this.source = const Value.absent(),
    this.kcal = const Value.absent(),
    this.carbG = const Value.absent(),
    this.proteinG = const Value.absent(),
    this.fatG = const Value.absent(),
    this.sugarG = const Value.absent(),
    this.saturatedFatG = const Value.absent(),
    this.sodiumMg = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FoodsCompanion.insert({
    required String id,
    required String name,
    this.brand = const Value.absent(),
    this.barcode = const Value.absent(),
    this.aliases = const Value.absent(),
    this.servings = const Value.absent(),
    this.status = const Value.absent(),
    this.basis = const Value.absent(),
    this.notes = const Value.absent(),
    required FoodSource source,
    this.kcal = const Value.absent(),
    this.carbG = const Value.absent(),
    this.proteinG = const Value.absent(),
    this.fatG = const Value.absent(),
    this.sugarG = const Value.absent(),
    this.saturatedFatG = const Value.absent(),
    this.sodiumMg = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       source = Value(source);
  static Insertable<FoodRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? brand,
    Expression<String>? barcode,
    Expression<String>? aliases,
    Expression<String>? servings,
    Expression<String>? status,
    Expression<String>? basis,
    Expression<String>? notes,
    Expression<String>? source,
    Expression<int>? kcal,
    Expression<double>? carbG,
    Expression<double>? proteinG,
    Expression<double>? fatG,
    Expression<double>? sugarG,
    Expression<double>? saturatedFatG,
    Expression<double>? sodiumMg,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (brand != null) 'brand': brand,
      if (barcode != null) 'barcode': barcode,
      if (aliases != null) 'aliases': aliases,
      if (servings != null) 'servings': servings,
      if (status != null) 'status': status,
      if (basis != null) 'basis': basis,
      if (notes != null) 'notes': notes,
      if (source != null) 'source': source,
      if (kcal != null) 'kcal': kcal,
      if (carbG != null) 'carb_g': carbG,
      if (proteinG != null) 'protein_g': proteinG,
      if (fatG != null) 'fat_g': fatG,
      if (sugarG != null) 'sugar_g': sugarG,
      if (saturatedFatG != null) 'saturated_fat_g': saturatedFatG,
      if (sodiumMg != null) 'sodium_mg': sodiumMg,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FoodsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? brand,
    Value<String?>? barcode,
    Value<String?>? aliases,
    Value<String?>? servings,
    Value<FoodStatus?>? status,
    Value<MeasureBasis?>? basis,
    Value<String?>? notes,
    Value<FoodSource>? source,
    Value<int?>? kcal,
    Value<double?>? carbG,
    Value<double?>? proteinG,
    Value<double?>? fatG,
    Value<double?>? sugarG,
    Value<double?>? saturatedFatG,
    Value<double?>? sodiumMg,
    Value<int>? rowid,
  }) {
    return FoodsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      barcode: barcode ?? this.barcode,
      aliases: aliases ?? this.aliases,
      servings: servings ?? this.servings,
      status: status ?? this.status,
      basis: basis ?? this.basis,
      notes: notes ?? this.notes,
      source: source ?? this.source,
      kcal: kcal ?? this.kcal,
      carbG: carbG ?? this.carbG,
      proteinG: proteinG ?? this.proteinG,
      fatG: fatG ?? this.fatG,
      sugarG: sugarG ?? this.sugarG,
      saturatedFatG: saturatedFatG ?? this.saturatedFatG,
      sodiumMg: sodiumMg ?? this.sodiumMg,
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
    if (brand.present) {
      map['brand'] = Variable<String>(brand.value);
    }
    if (barcode.present) {
      map['barcode'] = Variable<String>(barcode.value);
    }
    if (aliases.present) {
      map['aliases'] = Variable<String>(aliases.value);
    }
    if (servings.present) {
      map['servings'] = Variable<String>(servings.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $FoodsTable.$converterstatusn.toSql(status.value),
      );
    }
    if (basis.present) {
      map['basis'] = Variable<String>(
        $FoodsTable.$converterbasisn.toSql(basis.value),
      );
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(
        $FoodsTable.$convertersource.toSql(source.value),
      );
    }
    if (kcal.present) {
      map['kcal'] = Variable<int>(kcal.value);
    }
    if (carbG.present) {
      map['carb_g'] = Variable<double>(carbG.value);
    }
    if (proteinG.present) {
      map['protein_g'] = Variable<double>(proteinG.value);
    }
    if (fatG.present) {
      map['fat_g'] = Variable<double>(fatG.value);
    }
    if (sugarG.present) {
      map['sugar_g'] = Variable<double>(sugarG.value);
    }
    if (saturatedFatG.present) {
      map['saturated_fat_g'] = Variable<double>(saturatedFatG.value);
    }
    if (sodiumMg.present) {
      map['sodium_mg'] = Variable<double>(sodiumMg.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FoodsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('brand: $brand, ')
          ..write('barcode: $barcode, ')
          ..write('aliases: $aliases, ')
          ..write('servings: $servings, ')
          ..write('status: $status, ')
          ..write('basis: $basis, ')
          ..write('notes: $notes, ')
          ..write('source: $source, ')
          ..write('kcal: $kcal, ')
          ..write('carbG: $carbG, ')
          ..write('proteinG: $proteinG, ')
          ..write('fatG: $fatG, ')
          ..write('sugarG: $sugarG, ')
          ..write('saturatedFatG: $saturatedFatG, ')
          ..write('sodiumMg: $sodiumMg, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MealsTable extends Meals with TableInfo<$MealsTable, MealRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MealsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<MealType, String> mealType =
      GeneratedColumn<String>(
        'meal_type',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<MealType>($MealsTable.$convertermealType);
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
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
  @override
  List<GeneratedColumn> get $columns => [id, timestamp, mealType, note, notes];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meals';
  @override
  VerificationContext validateIntegrity(
    Insertable<MealRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MealRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MealRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}timestamp'],
      )!,
      mealType: $MealsTable.$convertermealType.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}meal_type'],
        )!,
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
    );
  }

  @override
  $MealsTable createAlias(String alias) {
    return $MealsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<MealType, String, String> $convertermealType =
      const EnumNameConverter<MealType>(MealType.values);
}

class MealRow extends DataClass implements Insertable<MealRow> {
  /// UUID of the meal.
  final String id;

  /// The instant the meal is attributed to.
  final DateTime timestamp;

  /// Breakfast / lunch / dinner / snack; stored as the enum name.
  final MealType mealType;

  /// Optional free-text note.
  final String? note;

  /// Optional free-text notes (added in schema v2 by task 33).
  ///
  /// This column is the schema change that introduces the genuine v1 -> v2
  /// migration: it is **nullable**, so the migration is a pure additive
  /// `ALTER TABLE meals ADD COLUMN notes TEXT` that cannot fail on existing
  /// rows and preserves every v1 meal. `note` above is the original v1 column
  /// and is left untouched, so the v1 snapshot in `drift_schemas/` stays
  /// authoritative for `migrateAndValidate`.
  final String? notes;
  const MealRow({
    required this.id,
    required this.timestamp,
    required this.mealType,
    this.note,
    this.notes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['timestamp'] = Variable<DateTime>(timestamp);
    {
      map['meal_type'] = Variable<String>(
        $MealsTable.$convertermealType.toSql(mealType),
      );
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    return map;
  }

  MealsCompanion toCompanion(bool nullToAbsent) {
    return MealsCompanion(
      id: Value(id),
      timestamp: Value(timestamp),
      mealType: Value(mealType),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
    );
  }

  factory MealRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MealRow(
      id: serializer.fromJson<String>(json['id']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      mealType: $MealsTable.$convertermealType.fromJson(
        serializer.fromJson<String>(json['mealType']),
      ),
      note: serializer.fromJson<String?>(json['note']),
      notes: serializer.fromJson<String?>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'mealType': serializer.toJson<String>(
        $MealsTable.$convertermealType.toJson(mealType),
      ),
      'note': serializer.toJson<String?>(note),
      'notes': serializer.toJson<String?>(notes),
    };
  }

  MealRow copyWith({
    String? id,
    DateTime? timestamp,
    MealType? mealType,
    Value<String?> note = const Value.absent(),
    Value<String?> notes = const Value.absent(),
  }) => MealRow(
    id: id ?? this.id,
    timestamp: timestamp ?? this.timestamp,
    mealType: mealType ?? this.mealType,
    note: note.present ? note.value : this.note,
    notes: notes.present ? notes.value : this.notes,
  );
  MealRow copyWithCompanion(MealsCompanion data) {
    return MealRow(
      id: data.id.present ? data.id.value : this.id,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      mealType: data.mealType.present ? data.mealType.value : this.mealType,
      note: data.note.present ? data.note.value : this.note,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MealRow(')
          ..write('id: $id, ')
          ..write('timestamp: $timestamp, ')
          ..write('mealType: $mealType, ')
          ..write('note: $note, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, timestamp, mealType, note, notes);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MealRow &&
          other.id == this.id &&
          other.timestamp == this.timestamp &&
          other.mealType == this.mealType &&
          other.note == this.note &&
          other.notes == this.notes);
}

class MealsCompanion extends UpdateCompanion<MealRow> {
  final Value<String> id;
  final Value<DateTime> timestamp;
  final Value<MealType> mealType;
  final Value<String?> note;
  final Value<String?> notes;
  final Value<int> rowid;
  const MealsCompanion({
    this.id = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.mealType = const Value.absent(),
    this.note = const Value.absent(),
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MealsCompanion.insert({
    required String id,
    required DateTime timestamp,
    required MealType mealType,
    this.note = const Value.absent(),
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       timestamp = Value(timestamp),
       mealType = Value(mealType);
  static Insertable<MealRow> custom({
    Expression<String>? id,
    Expression<DateTime>? timestamp,
    Expression<String>? mealType,
    Expression<String>? note,
    Expression<String>? notes,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (timestamp != null) 'timestamp': timestamp,
      if (mealType != null) 'meal_type': mealType,
      if (note != null) 'note': note,
      if (notes != null) 'notes': notes,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MealsCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? timestamp,
    Value<MealType>? mealType,
    Value<String?>? note,
    Value<String?>? notes,
    Value<int>? rowid,
  }) {
    return MealsCompanion(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      mealType: mealType ?? this.mealType,
      note: note ?? this.note,
      notes: notes ?? this.notes,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (mealType.present) {
      map['meal_type'] = Variable<String>(
        $MealsTable.$convertermealType.toSql(mealType.value),
      );
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MealsCompanion(')
          ..write('id: $id, ')
          ..write('timestamp: $timestamp, ')
          ..write('mealType: $mealType, ')
          ..write('note: $note, ')
          ..write('notes: $notes, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MealItemsTable extends MealItems
    with TableInfo<$MealItemsTable, MealItemRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MealItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mealIdMeta = const VerificationMeta('mealId');
  @override
  late final GeneratedColumn<String> mealId = GeneratedColumn<String>(
    'meal_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES meals (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _foodIdMeta = const VerificationMeta('foodId');
  @override
  late final GeneratedColumn<String> foodId = GeneratedColumn<String>(
    'food_id',
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
  static const VerificationMeta _gramsMeta = const VerificationMeta('grams');
  @override
  late final GeneratedColumn<double> grams = GeneratedColumn<double>(
    'grams',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kcalMeta = const VerificationMeta('kcal');
  @override
  late final GeneratedColumn<int> kcal = GeneratedColumn<int>(
    'kcal',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _carbGMeta = const VerificationMeta('carbG');
  @override
  late final GeneratedColumn<double> carbG = GeneratedColumn<double>(
    'carb_g',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _proteinGMeta = const VerificationMeta(
    'proteinG',
  );
  @override
  late final GeneratedColumn<double> proteinG = GeneratedColumn<double>(
    'protein_g',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fatGMeta = const VerificationMeta('fatG');
  @override
  late final GeneratedColumn<double> fatG = GeneratedColumn<double>(
    'fat_g',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _saltGMeta = const VerificationMeta('saltG');
  @override
  late final GeneratedColumn<double> saltG = GeneratedColumn<double>(
    'salt_g',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<FoodSource, String> source =
      GeneratedColumn<String>(
        'source',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<FoodSource>($MealItemsTable.$convertersource);
  static const VerificationMeta _confidenceMeta = const VerificationMeta(
    'confidence',
  );
  @override
  late final GeneratedColumn<double> confidence = GeneratedColumn<double>(
    'confidence',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    mealId,
    foodId,
    name,
    grams,
    kcal,
    carbG,
    proteinG,
    fatG,
    saltG,
    source,
    confidence,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meal_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<MealItemRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('meal_id')) {
      context.handle(
        _mealIdMeta,
        mealId.isAcceptableOrUnknown(data['meal_id']!, _mealIdMeta),
      );
    } else if (isInserting) {
      context.missing(_mealIdMeta);
    }
    if (data.containsKey('food_id')) {
      context.handle(
        _foodIdMeta,
        foodId.isAcceptableOrUnknown(data['food_id']!, _foodIdMeta),
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
    if (data.containsKey('grams')) {
      context.handle(
        _gramsMeta,
        grams.isAcceptableOrUnknown(data['grams']!, _gramsMeta),
      );
    } else if (isInserting) {
      context.missing(_gramsMeta);
    }
    if (data.containsKey('kcal')) {
      context.handle(
        _kcalMeta,
        kcal.isAcceptableOrUnknown(data['kcal']!, _kcalMeta),
      );
    } else if (isInserting) {
      context.missing(_kcalMeta);
    }
    if (data.containsKey('carb_g')) {
      context.handle(
        _carbGMeta,
        carbG.isAcceptableOrUnknown(data['carb_g']!, _carbGMeta),
      );
    } else if (isInserting) {
      context.missing(_carbGMeta);
    }
    if (data.containsKey('protein_g')) {
      context.handle(
        _proteinGMeta,
        proteinG.isAcceptableOrUnknown(data['protein_g']!, _proteinGMeta),
      );
    } else if (isInserting) {
      context.missing(_proteinGMeta);
    }
    if (data.containsKey('fat_g')) {
      context.handle(
        _fatGMeta,
        fatG.isAcceptableOrUnknown(data['fat_g']!, _fatGMeta),
      );
    } else if (isInserting) {
      context.missing(_fatGMeta);
    }
    if (data.containsKey('salt_g')) {
      context.handle(
        _saltGMeta,
        saltG.isAcceptableOrUnknown(data['salt_g']!, _saltGMeta),
      );
    } else if (isInserting) {
      context.missing(_saltGMeta);
    }
    if (data.containsKey('confidence')) {
      context.handle(
        _confidenceMeta,
        confidence.isAcceptableOrUnknown(data['confidence']!, _confidenceMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MealItemRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MealItemRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      mealId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meal_id'],
      )!,
      foodId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}food_id'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      grams: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}grams'],
      )!,
      kcal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}kcal'],
      )!,
      carbG: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}carb_g'],
      )!,
      proteinG: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}protein_g'],
      )!,
      fatG: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}fat_g'],
      )!,
      saltG: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}salt_g'],
      )!,
      source: $MealItemsTable.$convertersource.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}source'],
        )!,
      ),
      confidence: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}confidence'],
      ),
    );
  }

  @override
  $MealItemsTable createAlias(String alias) {
    return $MealItemsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<FoodSource, String, String> $convertersource =
      const EnumNameConverter<FoodSource>(FoodSource.values);
}

class MealItemRow extends DataClass implements Insertable<MealItemRow> {
  /// UUID of the item.
  final String id;

  /// Owning meal; deleted with its parent (cascade).
  final String mealId;

  /// Optional back-link to a saved [Foods] row; no FK on purpose (see above).
  final String? foodId;
  final String name;

  /// Consumed weight in grams.
  final double grams;

  /// Energy in **whole kcal** (canonical, integer-only).
  final int kcal;

  /// Carbohydrate in grams.
  final double carbG;

  /// Protein in grams.
  final double proteinG;

  /// Fat in grams.
  final double fatG;

  /// Salt in grams — the display unit carried on the item.
  final double saltG;

  /// Per-item provenance (`label` when a saved label food was applied).
  final FoodSource source;

  /// AI self-reported confidence (0..1), when the provider returned one.
  final double? confidence;
  const MealItemRow({
    required this.id,
    required this.mealId,
    this.foodId,
    required this.name,
    required this.grams,
    required this.kcal,
    required this.carbG,
    required this.proteinG,
    required this.fatG,
    required this.saltG,
    required this.source,
    this.confidence,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['meal_id'] = Variable<String>(mealId);
    if (!nullToAbsent || foodId != null) {
      map['food_id'] = Variable<String>(foodId);
    }
    map['name'] = Variable<String>(name);
    map['grams'] = Variable<double>(grams);
    map['kcal'] = Variable<int>(kcal);
    map['carb_g'] = Variable<double>(carbG);
    map['protein_g'] = Variable<double>(proteinG);
    map['fat_g'] = Variable<double>(fatG);
    map['salt_g'] = Variable<double>(saltG);
    {
      map['source'] = Variable<String>(
        $MealItemsTable.$convertersource.toSql(source),
      );
    }
    if (!nullToAbsent || confidence != null) {
      map['confidence'] = Variable<double>(confidence);
    }
    return map;
  }

  MealItemsCompanion toCompanion(bool nullToAbsent) {
    return MealItemsCompanion(
      id: Value(id),
      mealId: Value(mealId),
      foodId: foodId == null && nullToAbsent
          ? const Value.absent()
          : Value(foodId),
      name: Value(name),
      grams: Value(grams),
      kcal: Value(kcal),
      carbG: Value(carbG),
      proteinG: Value(proteinG),
      fatG: Value(fatG),
      saltG: Value(saltG),
      source: Value(source),
      confidence: confidence == null && nullToAbsent
          ? const Value.absent()
          : Value(confidence),
    );
  }

  factory MealItemRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MealItemRow(
      id: serializer.fromJson<String>(json['id']),
      mealId: serializer.fromJson<String>(json['mealId']),
      foodId: serializer.fromJson<String?>(json['foodId']),
      name: serializer.fromJson<String>(json['name']),
      grams: serializer.fromJson<double>(json['grams']),
      kcal: serializer.fromJson<int>(json['kcal']),
      carbG: serializer.fromJson<double>(json['carbG']),
      proteinG: serializer.fromJson<double>(json['proteinG']),
      fatG: serializer.fromJson<double>(json['fatG']),
      saltG: serializer.fromJson<double>(json['saltG']),
      source: $MealItemsTable.$convertersource.fromJson(
        serializer.fromJson<String>(json['source']),
      ),
      confidence: serializer.fromJson<double?>(json['confidence']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'mealId': serializer.toJson<String>(mealId),
      'foodId': serializer.toJson<String?>(foodId),
      'name': serializer.toJson<String>(name),
      'grams': serializer.toJson<double>(grams),
      'kcal': serializer.toJson<int>(kcal),
      'carbG': serializer.toJson<double>(carbG),
      'proteinG': serializer.toJson<double>(proteinG),
      'fatG': serializer.toJson<double>(fatG),
      'saltG': serializer.toJson<double>(saltG),
      'source': serializer.toJson<String>(
        $MealItemsTable.$convertersource.toJson(source),
      ),
      'confidence': serializer.toJson<double?>(confidence),
    };
  }

  MealItemRow copyWith({
    String? id,
    String? mealId,
    Value<String?> foodId = const Value.absent(),
    String? name,
    double? grams,
    int? kcal,
    double? carbG,
    double? proteinG,
    double? fatG,
    double? saltG,
    FoodSource? source,
    Value<double?> confidence = const Value.absent(),
  }) => MealItemRow(
    id: id ?? this.id,
    mealId: mealId ?? this.mealId,
    foodId: foodId.present ? foodId.value : this.foodId,
    name: name ?? this.name,
    grams: grams ?? this.grams,
    kcal: kcal ?? this.kcal,
    carbG: carbG ?? this.carbG,
    proteinG: proteinG ?? this.proteinG,
    fatG: fatG ?? this.fatG,
    saltG: saltG ?? this.saltG,
    source: source ?? this.source,
    confidence: confidence.present ? confidence.value : this.confidence,
  );
  MealItemRow copyWithCompanion(MealItemsCompanion data) {
    return MealItemRow(
      id: data.id.present ? data.id.value : this.id,
      mealId: data.mealId.present ? data.mealId.value : this.mealId,
      foodId: data.foodId.present ? data.foodId.value : this.foodId,
      name: data.name.present ? data.name.value : this.name,
      grams: data.grams.present ? data.grams.value : this.grams,
      kcal: data.kcal.present ? data.kcal.value : this.kcal,
      carbG: data.carbG.present ? data.carbG.value : this.carbG,
      proteinG: data.proteinG.present ? data.proteinG.value : this.proteinG,
      fatG: data.fatG.present ? data.fatG.value : this.fatG,
      saltG: data.saltG.present ? data.saltG.value : this.saltG,
      source: data.source.present ? data.source.value : this.source,
      confidence: data.confidence.present
          ? data.confidence.value
          : this.confidence,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MealItemRow(')
          ..write('id: $id, ')
          ..write('mealId: $mealId, ')
          ..write('foodId: $foodId, ')
          ..write('name: $name, ')
          ..write('grams: $grams, ')
          ..write('kcal: $kcal, ')
          ..write('carbG: $carbG, ')
          ..write('proteinG: $proteinG, ')
          ..write('fatG: $fatG, ')
          ..write('saltG: $saltG, ')
          ..write('source: $source, ')
          ..write('confidence: $confidence')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    mealId,
    foodId,
    name,
    grams,
    kcal,
    carbG,
    proteinG,
    fatG,
    saltG,
    source,
    confidence,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MealItemRow &&
          other.id == this.id &&
          other.mealId == this.mealId &&
          other.foodId == this.foodId &&
          other.name == this.name &&
          other.grams == this.grams &&
          other.kcal == this.kcal &&
          other.carbG == this.carbG &&
          other.proteinG == this.proteinG &&
          other.fatG == this.fatG &&
          other.saltG == this.saltG &&
          other.source == this.source &&
          other.confidence == this.confidence);
}

class MealItemsCompanion extends UpdateCompanion<MealItemRow> {
  final Value<String> id;
  final Value<String> mealId;
  final Value<String?> foodId;
  final Value<String> name;
  final Value<double> grams;
  final Value<int> kcal;
  final Value<double> carbG;
  final Value<double> proteinG;
  final Value<double> fatG;
  final Value<double> saltG;
  final Value<FoodSource> source;
  final Value<double?> confidence;
  final Value<int> rowid;
  const MealItemsCompanion({
    this.id = const Value.absent(),
    this.mealId = const Value.absent(),
    this.foodId = const Value.absent(),
    this.name = const Value.absent(),
    this.grams = const Value.absent(),
    this.kcal = const Value.absent(),
    this.carbG = const Value.absent(),
    this.proteinG = const Value.absent(),
    this.fatG = const Value.absent(),
    this.saltG = const Value.absent(),
    this.source = const Value.absent(),
    this.confidence = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MealItemsCompanion.insert({
    required String id,
    required String mealId,
    this.foodId = const Value.absent(),
    required String name,
    required double grams,
    required int kcal,
    required double carbG,
    required double proteinG,
    required double fatG,
    required double saltG,
    required FoodSource source,
    this.confidence = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       mealId = Value(mealId),
       name = Value(name),
       grams = Value(grams),
       kcal = Value(kcal),
       carbG = Value(carbG),
       proteinG = Value(proteinG),
       fatG = Value(fatG),
       saltG = Value(saltG),
       source = Value(source);
  static Insertable<MealItemRow> custom({
    Expression<String>? id,
    Expression<String>? mealId,
    Expression<String>? foodId,
    Expression<String>? name,
    Expression<double>? grams,
    Expression<int>? kcal,
    Expression<double>? carbG,
    Expression<double>? proteinG,
    Expression<double>? fatG,
    Expression<double>? saltG,
    Expression<String>? source,
    Expression<double>? confidence,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (mealId != null) 'meal_id': mealId,
      if (foodId != null) 'food_id': foodId,
      if (name != null) 'name': name,
      if (grams != null) 'grams': grams,
      if (kcal != null) 'kcal': kcal,
      if (carbG != null) 'carb_g': carbG,
      if (proteinG != null) 'protein_g': proteinG,
      if (fatG != null) 'fat_g': fatG,
      if (saltG != null) 'salt_g': saltG,
      if (source != null) 'source': source,
      if (confidence != null) 'confidence': confidence,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MealItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? mealId,
    Value<String?>? foodId,
    Value<String>? name,
    Value<double>? grams,
    Value<int>? kcal,
    Value<double>? carbG,
    Value<double>? proteinG,
    Value<double>? fatG,
    Value<double>? saltG,
    Value<FoodSource>? source,
    Value<double?>? confidence,
    Value<int>? rowid,
  }) {
    return MealItemsCompanion(
      id: id ?? this.id,
      mealId: mealId ?? this.mealId,
      foodId: foodId ?? this.foodId,
      name: name ?? this.name,
      grams: grams ?? this.grams,
      kcal: kcal ?? this.kcal,
      carbG: carbG ?? this.carbG,
      proteinG: proteinG ?? this.proteinG,
      fatG: fatG ?? this.fatG,
      saltG: saltG ?? this.saltG,
      source: source ?? this.source,
      confidence: confidence ?? this.confidence,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (mealId.present) {
      map['meal_id'] = Variable<String>(mealId.value);
    }
    if (foodId.present) {
      map['food_id'] = Variable<String>(foodId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (grams.present) {
      map['grams'] = Variable<double>(grams.value);
    }
    if (kcal.present) {
      map['kcal'] = Variable<int>(kcal.value);
    }
    if (carbG.present) {
      map['carb_g'] = Variable<double>(carbG.value);
    }
    if (proteinG.present) {
      map['protein_g'] = Variable<double>(proteinG.value);
    }
    if (fatG.present) {
      map['fat_g'] = Variable<double>(fatG.value);
    }
    if (saltG.present) {
      map['salt_g'] = Variable<double>(saltG.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(
        $MealItemsTable.$convertersource.toSql(source.value),
      );
    }
    if (confidence.present) {
      map['confidence'] = Variable<double>(confidence.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MealItemsCompanion(')
          ..write('id: $id, ')
          ..write('mealId: $mealId, ')
          ..write('foodId: $foodId, ')
          ..write('name: $name, ')
          ..write('grams: $grams, ')
          ..write('kcal: $kcal, ')
          ..write('carbG: $carbG, ')
          ..write('proteinG: $proteinG, ')
          ..write('fatG: $fatG, ')
          ..write('saltG: $saltG, ')
          ..write('source: $source, ')
          ..write('confidence: $confidence, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DailyExercisesTable extends DailyExercises
    with TableInfo<$DailyExercisesTable, DailyExerciseRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DailyExercisesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dayKeyMeta = const VerificationMeta('dayKey');
  @override
  late final GeneratedColumn<DateTime> dayKey = GeneratedColumn<DateTime>(
    'day_key',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kcalMeta = const VerificationMeta('kcal');
  @override
  late final GeneratedColumn<int> kcal = GeneratedColumn<int>(
    'kcal',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [dayKey, kcal];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'daily_exercises';
  @override
  VerificationContext validateIntegrity(
    Insertable<DailyExerciseRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('day_key')) {
      context.handle(
        _dayKeyMeta,
        dayKey.isAcceptableOrUnknown(data['day_key']!, _dayKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_dayKeyMeta);
    }
    if (data.containsKey('kcal')) {
      context.handle(
        _kcalMeta,
        kcal.isAcceptableOrUnknown(data['kcal']!, _kcalMeta),
      );
    } else if (isInserting) {
      context.missing(_kcalMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {dayKey};
  @override
  DailyExerciseRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DailyExerciseRow(
      dayKey: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}day_key'],
      )!,
      kcal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}kcal'],
      )!,
    );
  }

  @override
  $DailyExercisesTable createAlias(String alias) {
    return $DailyExercisesTable(attachedDatabase, alias);
  }
}

class DailyExerciseRow extends DataClass
    implements Insertable<DailyExerciseRow> {
  /// Date-only local-day key; one row per day.
  final DateTime dayKey;

  /// Burn in **whole kcal** for that day (integer-only).
  final int kcal;
  const DailyExerciseRow({required this.dayKey, required this.kcal});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['day_key'] = Variable<DateTime>(dayKey);
    map['kcal'] = Variable<int>(kcal);
    return map;
  }

  DailyExercisesCompanion toCompanion(bool nullToAbsent) {
    return DailyExercisesCompanion(dayKey: Value(dayKey), kcal: Value(kcal));
  }

  factory DailyExerciseRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DailyExerciseRow(
      dayKey: serializer.fromJson<DateTime>(json['dayKey']),
      kcal: serializer.fromJson<int>(json['kcal']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'dayKey': serializer.toJson<DateTime>(dayKey),
      'kcal': serializer.toJson<int>(kcal),
    };
  }

  DailyExerciseRow copyWith({DateTime? dayKey, int? kcal}) =>
      DailyExerciseRow(dayKey: dayKey ?? this.dayKey, kcal: kcal ?? this.kcal);
  DailyExerciseRow copyWithCompanion(DailyExercisesCompanion data) {
    return DailyExerciseRow(
      dayKey: data.dayKey.present ? data.dayKey.value : this.dayKey,
      kcal: data.kcal.present ? data.kcal.value : this.kcal,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DailyExerciseRow(')
          ..write('dayKey: $dayKey, ')
          ..write('kcal: $kcal')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(dayKey, kcal);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DailyExerciseRow &&
          other.dayKey == this.dayKey &&
          other.kcal == this.kcal);
}

class DailyExercisesCompanion extends UpdateCompanion<DailyExerciseRow> {
  final Value<DateTime> dayKey;
  final Value<int> kcal;
  final Value<int> rowid;
  const DailyExercisesCompanion({
    this.dayKey = const Value.absent(),
    this.kcal = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DailyExercisesCompanion.insert({
    required DateTime dayKey,
    required int kcal,
    this.rowid = const Value.absent(),
  }) : dayKey = Value(dayKey),
       kcal = Value(kcal);
  static Insertable<DailyExerciseRow> custom({
    Expression<DateTime>? dayKey,
    Expression<int>? kcal,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (dayKey != null) 'day_key': dayKey,
      if (kcal != null) 'kcal': kcal,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DailyExercisesCompanion copyWith({
    Value<DateTime>? dayKey,
    Value<int>? kcal,
    Value<int>? rowid,
  }) {
    return DailyExercisesCompanion(
      dayKey: dayKey ?? this.dayKey,
      kcal: kcal ?? this.kcal,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (dayKey.present) {
      map['day_key'] = Variable<DateTime>(dayKey.value);
    }
    if (kcal.present) {
      map['kcal'] = Variable<int>(kcal.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DailyExercisesCompanion(')
          ..write('dayKey: $dayKey, ')
          ..write('kcal: $kcal, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  late final $UserProfilesTable userProfiles = $UserProfilesTable(this);
  late final $FoodsTable foods = $FoodsTable(this);
  late final $MealsTable meals = $MealsTable(this);
  late final $MealItemsTable mealItems = $MealItemsTable(this);
  late final $DailyExercisesTable dailyExercises = $DailyExercisesTable(this);
  late final UserProfileDao userProfileDao = UserProfileDao(
    this as AppDatabase,
  );
  late final FoodDao foodDao = FoodDao(this as AppDatabase);
  late final MealDao mealDao = MealDao(this as AppDatabase);
  late final ExerciseDao exerciseDao = ExerciseDao(this as AppDatabase);
  late final AppSettingsDao appSettingsDao = AppSettingsDao(
    this as AppDatabase,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    appSettings,
    userProfiles,
    foods,
    meals,
    mealItems,
    dailyExercises,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'meals',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('meal_items', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$AppSettingsTableCreateCompanionBuilder =
    AppSettingsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$AppSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AppSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSettingsTable,
          AppSetting,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
          $$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (
            AppSetting,
            BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
          ),
          AppSetting,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableManager(_$AppDatabase db, $AppSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => AppSettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AppSettingsTable, AppSetting>(table),
                  BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppSettingsTable,
      AppSetting,
      $$AppSettingsTableFilterComposer,
      $$AppSettingsTableOrderingComposer,
      $$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (
        AppSetting,
        BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
      ),
      AppSetting,
      PrefetchHooks Function()
    >;
typedef $$UserProfilesTableCreateCompanionBuilder =
    UserProfilesCompanion Function({
      Value<int> id,
      required Sex sex,
      required DateTime birthDate,
      required double heightCm,
      required double weightKg,
      Value<int?> bmrKcalOverride,
    });
typedef $$UserProfilesTableUpdateCompanionBuilder =
    UserProfilesCompanion Function({
      Value<int> id,
      Value<Sex> sex,
      Value<DateTime> birthDate,
      Value<double> heightCm,
      Value<double> weightKg,
      Value<int?> bmrKcalOverride,
    });

class $$UserProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $UserProfilesTable> {
  $$UserProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Sex, Sex, String> get sex =>
      $composableBuilder(
        column: $table.sex,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<DateTime> get birthDate => $composableBuilder(
    column: $table.birthDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get heightCm => $composableBuilder(
    column: $table.heightCm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get weightKg => $composableBuilder(
    column: $table.weightKg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bmrKcalOverride => $composableBuilder(
    column: $table.bmrKcalOverride,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UserProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $UserProfilesTable> {
  $$UserProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sex => $composableBuilder(
    column: $table.sex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get birthDate => $composableBuilder(
    column: $table.birthDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get heightCm => $composableBuilder(
    column: $table.heightCm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get weightKg => $composableBuilder(
    column: $table.weightKg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bmrKcalOverride => $composableBuilder(
    column: $table.bmrKcalOverride,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserProfilesTable> {
  $$UserProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Sex, String> get sex =>
      $composableBuilder(column: $table.sex, builder: (column) => column);

  GeneratedColumn<DateTime> get birthDate =>
      $composableBuilder(column: $table.birthDate, builder: (column) => column);

  GeneratedColumn<double> get heightCm =>
      $composableBuilder(column: $table.heightCm, builder: (column) => column);

  GeneratedColumn<double> get weightKg =>
      $composableBuilder(column: $table.weightKg, builder: (column) => column);

  GeneratedColumn<int> get bmrKcalOverride => $composableBuilder(
    column: $table.bmrKcalOverride,
    builder: (column) => column,
  );
}

class $$UserProfilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserProfilesTable,
          UserProfileRow,
          $$UserProfilesTableFilterComposer,
          $$UserProfilesTableOrderingComposer,
          $$UserProfilesTableAnnotationComposer,
          $$UserProfilesTableCreateCompanionBuilder,
          $$UserProfilesTableUpdateCompanionBuilder,
          (
            UserProfileRow,
            BaseReferences<_$AppDatabase, $UserProfilesTable, UserProfileRow>,
          ),
          UserProfileRow,
          PrefetchHooks Function()
        > {
  $$UserProfilesTableTableManager(_$AppDatabase db, $UserProfilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<Sex> sex = const Value.absent(),
                Value<DateTime> birthDate = const Value.absent(),
                Value<double> heightCm = const Value.absent(),
                Value<double> weightKg = const Value.absent(),
                Value<int?> bmrKcalOverride = const Value.absent(),
              }) => UserProfilesCompanion(
                id: id,
                sex: sex,
                birthDate: birthDate,
                heightCm: heightCm,
                weightKg: weightKg,
                bmrKcalOverride: bmrKcalOverride,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required Sex sex,
                required DateTime birthDate,
                required double heightCm,
                required double weightKg,
                Value<int?> bmrKcalOverride = const Value.absent(),
              }) => UserProfilesCompanion.insert(
                id: id,
                sex: sex,
                birthDate: birthDate,
                heightCm: heightCm,
                weightKg: weightKg,
                bmrKcalOverride: bmrKcalOverride,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$UserProfilesTable, UserProfileRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $UserProfilesTable,
                    UserProfileRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserProfilesTable,
      UserProfileRow,
      $$UserProfilesTableFilterComposer,
      $$UserProfilesTableOrderingComposer,
      $$UserProfilesTableAnnotationComposer,
      $$UserProfilesTableCreateCompanionBuilder,
      $$UserProfilesTableUpdateCompanionBuilder,
      (
        UserProfileRow,
        BaseReferences<_$AppDatabase, $UserProfilesTable, UserProfileRow>,
      ),
      UserProfileRow,
      PrefetchHooks Function()
    >;
typedef $$FoodsTableCreateCompanionBuilder = FoodsCompanion Function({
  required String id,
  required String name,
  Value<String?> brand,
  Value<String?> barcode,
  Value<String?> aliases,
  Value<String?> servings,
  Value<FoodStatus?> status,
  Value<MeasureBasis?> basis,
  Value<String?> notes,
  required FoodSource source,
  Value<int?> kcal,
  Value<double?> carbG,
  Value<double?> proteinG,
  Value<double?> fatG,
  Value<double?> sugarG,
  Value<double?> saturatedFatG,
  Value<double?> sodiumMg,
  Value<int> rowid,
});
typedef $$FoodsTableUpdateCompanionBuilder = FoodsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String?> brand,
  Value<String?> barcode,
  Value<String?> aliases,
  Value<String?> servings,
  Value<FoodStatus?> status,
  Value<MeasureBasis?> basis,
  Value<String?> notes,
  Value<FoodSource> source,
  Value<int?> kcal,
  Value<double?> carbG,
  Value<double?> proteinG,
  Value<double?> fatG,
  Value<double?> sugarG,
  Value<double?> saturatedFatG,
  Value<double?> sodiumMg,
  Value<int> rowid,
});

class $$FoodsTableFilterComposer extends Composer<_$AppDatabase, $FoodsTable> {
  $$FoodsTableFilterComposer({
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

  ColumnFilters<String> get brand => $composableBuilder(
    column: $table.brand,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get barcode => $composableBuilder(
    column: $table.barcode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get aliases => $composableBuilder(
    column: $table.aliases,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get servings => $composableBuilder(
    column: $table.servings,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<FoodStatus?, FoodStatus, String> get status =>
      $composableBuilder(
        column: $table.status,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<MeasureBasis?, MeasureBasis, String>
  get basis => $composableBuilder(
    column: $table.basis,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<FoodSource, FoodSource, String> get source =>
      $composableBuilder(
        column: $table.source,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get kcal => $composableBuilder(
    column: $table.kcal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get carbG => $composableBuilder(
    column: $table.carbG,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get proteinG => $composableBuilder(
    column: $table.proteinG,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get fatG => $composableBuilder(
    column: $table.fatG,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get sugarG => $composableBuilder(
    column: $table.sugarG,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get saturatedFatG => $composableBuilder(
    column: $table.saturatedFatG,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get sodiumMg => $composableBuilder(
    column: $table.sodiumMg,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FoodsTableOrderingComposer
    extends Composer<_$AppDatabase, $FoodsTable> {
  $$FoodsTableOrderingComposer({
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

  ColumnOrderings<String> get brand => $composableBuilder(
    column: $table.brand,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get barcode => $composableBuilder(
    column: $table.barcode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get aliases => $composableBuilder(
    column: $table.aliases,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get servings => $composableBuilder(
    column: $table.servings,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get basis => $composableBuilder(
    column: $table.basis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get kcal => $composableBuilder(
    column: $table.kcal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get carbG => $composableBuilder(
    column: $table.carbG,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get proteinG => $composableBuilder(
    column: $table.proteinG,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get fatG => $composableBuilder(
    column: $table.fatG,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get sugarG => $composableBuilder(
    column: $table.sugarG,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get saturatedFatG => $composableBuilder(
    column: $table.saturatedFatG,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get sodiumMg => $composableBuilder(
    column: $table.sodiumMg,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FoodsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FoodsTable> {
  $$FoodsTableAnnotationComposer({
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

  GeneratedColumn<String> get brand =>
      $composableBuilder(column: $table.brand, builder: (column) => column);

  GeneratedColumn<String> get barcode =>
      $composableBuilder(column: $table.barcode, builder: (column) => column);

  GeneratedColumn<String> get aliases =>
      $composableBuilder(column: $table.aliases, builder: (column) => column);

  GeneratedColumn<String> get servings =>
      $composableBuilder(column: $table.servings, builder: (column) => column);

  GeneratedColumnWithTypeConverter<FoodStatus?, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumnWithTypeConverter<MeasureBasis?, String> get basis =>
      $composableBuilder(column: $table.basis, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumnWithTypeConverter<FoodSource, String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<int> get kcal =>
      $composableBuilder(column: $table.kcal, builder: (column) => column);

  GeneratedColumn<double> get carbG =>
      $composableBuilder(column: $table.carbG, builder: (column) => column);

  GeneratedColumn<double> get proteinG =>
      $composableBuilder(column: $table.proteinG, builder: (column) => column);

  GeneratedColumn<double> get fatG =>
      $composableBuilder(column: $table.fatG, builder: (column) => column);

  GeneratedColumn<double> get sugarG =>
      $composableBuilder(column: $table.sugarG, builder: (column) => column);

  GeneratedColumn<double> get saturatedFatG => $composableBuilder(
    column: $table.saturatedFatG,
    builder: (column) => column,
  );

  GeneratedColumn<double> get sodiumMg =>
      $composableBuilder(column: $table.sodiumMg, builder: (column) => column);
}

class $$FoodsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FoodsTable,
          FoodRow,
          $$FoodsTableFilterComposer,
          $$FoodsTableOrderingComposer,
          $$FoodsTableAnnotationComposer,
          $$FoodsTableCreateCompanionBuilder,
          $$FoodsTableUpdateCompanionBuilder,
          (FoodRow, BaseReferences<_$AppDatabase, $FoodsTable, FoodRow>),
          FoodRow,
          PrefetchHooks Function()
        > {
  $$FoodsTableTableManager(_$AppDatabase db, $FoodsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FoodsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FoodsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FoodsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> brand = const Value.absent(),
                Value<String?> barcode = const Value.absent(),
                Value<String?> aliases = const Value.absent(),
                Value<String?> servings = const Value.absent(),
                Value<FoodStatus?> status = const Value.absent(),
                Value<MeasureBasis?> basis = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<FoodSource> source = const Value.absent(),
                Value<int?> kcal = const Value.absent(),
                Value<double?> carbG = const Value.absent(),
                Value<double?> proteinG = const Value.absent(),
                Value<double?> fatG = const Value.absent(),
                Value<double?> sugarG = const Value.absent(),
                Value<double?> saturatedFatG = const Value.absent(),
                Value<double?> sodiumMg = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FoodsCompanion(
                id: id,
                name: name,
                brand: brand,
                barcode: barcode,
                aliases: aliases,
                servings: servings,
                status: status,
                basis: basis,
                notes: notes,
                source: source,
                kcal: kcal,
                carbG: carbG,
                proteinG: proteinG,
                fatG: fatG,
                sugarG: sugarG,
                saturatedFatG: saturatedFatG,
                sodiumMg: sodiumMg,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> brand = const Value.absent(),
                Value<String?> barcode = const Value.absent(),
                Value<String?> aliases = const Value.absent(),
                Value<String?> servings = const Value.absent(),
                Value<FoodStatus?> status = const Value.absent(),
                Value<MeasureBasis?> basis = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                required FoodSource source,
                Value<int?> kcal = const Value.absent(),
                Value<double?> carbG = const Value.absent(),
                Value<double?> proteinG = const Value.absent(),
                Value<double?> fatG = const Value.absent(),
                Value<double?> sugarG = const Value.absent(),
                Value<double?> saturatedFatG = const Value.absent(),
                Value<double?> sodiumMg = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FoodsCompanion.insert(
                id: id,
                name: name,
                brand: brand,
                barcode: barcode,
                aliases: aliases,
                servings: servings,
                status: status,
                basis: basis,
                notes: notes,
                source: source,
                kcal: kcal,
                carbG: carbG,
                proteinG: proteinG,
                fatG: fatG,
                sugarG: sugarG,
                saturatedFatG: saturatedFatG,
                sodiumMg: sodiumMg,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FoodsTable, FoodRow>(table),
                  BaseReferences<_$AppDatabase, $FoodsTable, FoodRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FoodsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FoodsTable,
      FoodRow,
      $$FoodsTableFilterComposer,
      $$FoodsTableOrderingComposer,
      $$FoodsTableAnnotationComposer,
      $$FoodsTableCreateCompanionBuilder,
      $$FoodsTableUpdateCompanionBuilder,
      (FoodRow, BaseReferences<_$AppDatabase, $FoodsTable, FoodRow>),
      FoodRow,
      PrefetchHooks Function()
    >;
typedef $$MealsTableCreateCompanionBuilder = MealsCompanion Function({
  required String id,
  required DateTime timestamp,
  required MealType mealType,
  Value<String?> note,
  Value<String?> notes,
  Value<int> rowid,
});
typedef $$MealsTableUpdateCompanionBuilder = MealsCompanion Function({
  Value<String> id,
  Value<DateTime> timestamp,
  Value<MealType> mealType,
  Value<String?> note,
  Value<String?> notes,
  Value<int> rowid,
});

final class $$MealsTableReferences
    extends BaseReferences<_$AppDatabase, $MealsTable, MealRow> {
  $$MealsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$MealItemsTable, List<MealItemRow>>
  _mealItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.mealItems,
    aliasName: 'meals__id__meal_items__meal_id',
  );

  $$MealItemsTableProcessedTableManager get mealItemsRefs {
    final manager = $$MealItemsTableTableManager(
      $_db,
      $_db.mealItems,
    ).filter((f) => f.mealId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_mealItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$MealsTableFilterComposer extends Composer<_$AppDatabase, $MealsTable> {
  $$MealsTableFilterComposer({
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

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<MealType, MealType, String> get mealType =>
      $composableBuilder(
        column: $table.mealType,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> mealItemsRefs(
    Expression<bool> Function($$MealItemsTableFilterComposer f) f,
  ) {
    final $$MealItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mealItems,
      getReferencedColumn: (t) => t.mealId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MealItemsTableFilterComposer(
            $db: $db,
            $table: $db.mealItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MealsTableOrderingComposer
    extends Composer<_$AppDatabase, $MealsTable> {
  $$MealsTableOrderingComposer({
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

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mealType => $composableBuilder(
    column: $table.mealType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MealsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MealsTable> {
  $$MealsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumnWithTypeConverter<MealType, String> get mealType =>
      $composableBuilder(column: $table.mealType, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  Expression<T> mealItemsRefs<T extends Object>(
    Expression<T> Function($$MealItemsTableAnnotationComposer a) f,
  ) {
    final $$MealItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mealItems,
      getReferencedColumn: (t) => t.mealId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MealItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.mealItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MealsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MealsTable,
          MealRow,
          $$MealsTableFilterComposer,
          $$MealsTableOrderingComposer,
          $$MealsTableAnnotationComposer,
          $$MealsTableCreateCompanionBuilder,
          $$MealsTableUpdateCompanionBuilder,
          (MealRow, $$MealsTableReferences),
          MealRow,
          PrefetchHooks Function({bool mealItemsRefs})
        > {
  $$MealsTableTableManager(_$AppDatabase db, $MealsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MealsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MealsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MealsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> timestamp = const Value.absent(),
                Value<MealType> mealType = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MealsCompanion(
                id: id,
                timestamp: timestamp,
                mealType: mealType,
                note: note,
                notes: notes,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required DateTime timestamp,
                required MealType mealType,
                Value<String?> note = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MealsCompanion.insert(
                id: id,
                timestamp: timestamp,
                mealType: mealType,
                note: note,
                notes: notes,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MealsTable, MealRow>(table),
                  $$MealsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({mealItemsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (mealItemsRefs) db.mealItems],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (mealItemsRefs)
                    await $_getPrefetchedData<
                      MealRow,
                      $MealsTable,
                      MealItemRow
                    >(
                      currentTable: table,
                      referencedTable: $$MealsTableReferences
                          ._mealItemsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$MealsTableReferences(db, table, p0).mealItemsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.mealId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$MealsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MealsTable,
      MealRow,
      $$MealsTableFilterComposer,
      $$MealsTableOrderingComposer,
      $$MealsTableAnnotationComposer,
      $$MealsTableCreateCompanionBuilder,
      $$MealsTableUpdateCompanionBuilder,
      (MealRow, $$MealsTableReferences),
      MealRow,
      PrefetchHooks Function({bool mealItemsRefs})
    >;
typedef $$MealItemsTableCreateCompanionBuilder = MealItemsCompanion Function({
  required String id,
  required String mealId,
  Value<String?> foodId,
  required String name,
  required double grams,
  required int kcal,
  required double carbG,
  required double proteinG,
  required double fatG,
  required double saltG,
  required FoodSource source,
  Value<double?> confidence,
  Value<int> rowid,
});
typedef $$MealItemsTableUpdateCompanionBuilder = MealItemsCompanion Function({
  Value<String> id,
  Value<String> mealId,
  Value<String?> foodId,
  Value<String> name,
  Value<double> grams,
  Value<int> kcal,
  Value<double> carbG,
  Value<double> proteinG,
  Value<double> fatG,
  Value<double> saltG,
  Value<FoodSource> source,
  Value<double?> confidence,
  Value<int> rowid,
});

final class $$MealItemsTableReferences
    extends BaseReferences<_$AppDatabase, $MealItemsTable, MealItemRow> {
  $$MealItemsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MealsTable _mealIdTable(_$AppDatabase db) =>
      db.meals.createAlias('meal_items__meal_id__meals__id');

  $$MealsTableProcessedTableManager get mealId {
    final $_column = $_itemColumn<String>('meal_id')!;

    final manager = $$MealsTableTableManager(
      $_db,
      $_db.meals,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_mealIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MealItemsTableFilterComposer
    extends Composer<_$AppDatabase, $MealItemsTable> {
  $$MealItemsTableFilterComposer({
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

  ColumnFilters<String> get foodId => $composableBuilder(
    column: $table.foodId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get grams => $composableBuilder(
    column: $table.grams,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get kcal => $composableBuilder(
    column: $table.kcal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get carbG => $composableBuilder(
    column: $table.carbG,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get proteinG => $composableBuilder(
    column: $table.proteinG,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get fatG => $composableBuilder(
    column: $table.fatG,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get saltG => $composableBuilder(
    column: $table.saltG,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<FoodSource, FoodSource, String> get source =>
      $composableBuilder(
        column: $table.source,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnFilters(column),
  );

  $$MealsTableFilterComposer get mealId {
    final $$MealsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mealId,
      referencedTable: $db.meals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MealsTableFilterComposer(
            $db: $db,
            $table: $db.meals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MealItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $MealItemsTable> {
  $$MealItemsTableOrderingComposer({
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

  ColumnOrderings<String> get foodId => $composableBuilder(
    column: $table.foodId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get grams => $composableBuilder(
    column: $table.grams,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get kcal => $composableBuilder(
    column: $table.kcal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get carbG => $composableBuilder(
    column: $table.carbG,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get proteinG => $composableBuilder(
    column: $table.proteinG,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get fatG => $composableBuilder(
    column: $table.fatG,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get saltG => $composableBuilder(
    column: $table.saltG,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnOrderings(column),
  );

  $$MealsTableOrderingComposer get mealId {
    final $$MealsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mealId,
      referencedTable: $db.meals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MealsTableOrderingComposer(
            $db: $db,
            $table: $db.meals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MealItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MealItemsTable> {
  $$MealItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get foodId =>
      $composableBuilder(column: $table.foodId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get grams =>
      $composableBuilder(column: $table.grams, builder: (column) => column);

  GeneratedColumn<int> get kcal =>
      $composableBuilder(column: $table.kcal, builder: (column) => column);

  GeneratedColumn<double> get carbG =>
      $composableBuilder(column: $table.carbG, builder: (column) => column);

  GeneratedColumn<double> get proteinG =>
      $composableBuilder(column: $table.proteinG, builder: (column) => column);

  GeneratedColumn<double> get fatG =>
      $composableBuilder(column: $table.fatG, builder: (column) => column);

  GeneratedColumn<double> get saltG =>
      $composableBuilder(column: $table.saltG, builder: (column) => column);

  GeneratedColumnWithTypeConverter<FoodSource, String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => column,
  );

  $$MealsTableAnnotationComposer get mealId {
    final $$MealsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mealId,
      referencedTable: $db.meals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MealsTableAnnotationComposer(
            $db: $db,
            $table: $db.meals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MealItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MealItemsTable,
          MealItemRow,
          $$MealItemsTableFilterComposer,
          $$MealItemsTableOrderingComposer,
          $$MealItemsTableAnnotationComposer,
          $$MealItemsTableCreateCompanionBuilder,
          $$MealItemsTableUpdateCompanionBuilder,
          (MealItemRow, $$MealItemsTableReferences),
          MealItemRow,
          PrefetchHooks Function({bool mealId})
        > {
  $$MealItemsTableTableManager(_$AppDatabase db, $MealItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MealItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MealItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MealItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> mealId = const Value.absent(),
                Value<String?> foodId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<double> grams = const Value.absent(),
                Value<int> kcal = const Value.absent(),
                Value<double> carbG = const Value.absent(),
                Value<double> proteinG = const Value.absent(),
                Value<double> fatG = const Value.absent(),
                Value<double> saltG = const Value.absent(),
                Value<FoodSource> source = const Value.absent(),
                Value<double?> confidence = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MealItemsCompanion(
                id: id,
                mealId: mealId,
                foodId: foodId,
                name: name,
                grams: grams,
                kcal: kcal,
                carbG: carbG,
                proteinG: proteinG,
                fatG: fatG,
                saltG: saltG,
                source: source,
                confidence: confidence,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String mealId,
                Value<String?> foodId = const Value.absent(),
                required String name,
                required double grams,
                required int kcal,
                required double carbG,
                required double proteinG,
                required double fatG,
                required double saltG,
                required FoodSource source,
                Value<double?> confidence = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MealItemsCompanion.insert(
                id: id,
                mealId: mealId,
                foodId: foodId,
                name: name,
                grams: grams,
                kcal: kcal,
                carbG: carbG,
                proteinG: proteinG,
                fatG: fatG,
                saltG: saltG,
                source: source,
                confidence: confidence,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MealItemsTable, MealItemRow>(table),
                  $$MealItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({mealId = false}) {
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
                    if (mealId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.mealId,
                        referencedTable: $$MealItemsTableReferences
                            ._mealIdTable(db),
                        referencedColumn: $$MealItemsTableReferences
                            ._mealIdTable(db)
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

typedef $$MealItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MealItemsTable,
      MealItemRow,
      $$MealItemsTableFilterComposer,
      $$MealItemsTableOrderingComposer,
      $$MealItemsTableAnnotationComposer,
      $$MealItemsTableCreateCompanionBuilder,
      $$MealItemsTableUpdateCompanionBuilder,
      (MealItemRow, $$MealItemsTableReferences),
      MealItemRow,
      PrefetchHooks Function({bool mealId})
    >;
typedef $$DailyExercisesTableCreateCompanionBuilder =
    DailyExercisesCompanion Function({
      required DateTime dayKey,
      required int kcal,
      Value<int> rowid,
    });
typedef $$DailyExercisesTableUpdateCompanionBuilder =
    DailyExercisesCompanion Function({
      Value<DateTime> dayKey,
      Value<int> kcal,
      Value<int> rowid,
    });

class $$DailyExercisesTableFilterComposer
    extends Composer<_$AppDatabase, $DailyExercisesTable> {
  $$DailyExercisesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get dayKey => $composableBuilder(
    column: $table.dayKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get kcal => $composableBuilder(
    column: $table.kcal,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DailyExercisesTableOrderingComposer
    extends Composer<_$AppDatabase, $DailyExercisesTable> {
  $$DailyExercisesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get dayKey => $composableBuilder(
    column: $table.dayKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get kcal => $composableBuilder(
    column: $table.kcal,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DailyExercisesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DailyExercisesTable> {
  $$DailyExercisesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get dayKey =>
      $composableBuilder(column: $table.dayKey, builder: (column) => column);

  GeneratedColumn<int> get kcal =>
      $composableBuilder(column: $table.kcal, builder: (column) => column);
}

class $$DailyExercisesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DailyExercisesTable,
          DailyExerciseRow,
          $$DailyExercisesTableFilterComposer,
          $$DailyExercisesTableOrderingComposer,
          $$DailyExercisesTableAnnotationComposer,
          $$DailyExercisesTableCreateCompanionBuilder,
          $$DailyExercisesTableUpdateCompanionBuilder,
          (
            DailyExerciseRow,
            BaseReferences<
              _$AppDatabase,
              $DailyExercisesTable,
              DailyExerciseRow
            >,
          ),
          DailyExerciseRow,
          PrefetchHooks Function()
        > {
  $$DailyExercisesTableTableManager(
    _$AppDatabase db,
    $DailyExercisesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DailyExercisesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DailyExercisesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DailyExercisesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<DateTime> dayKey = const Value.absent(),
                Value<int> kcal = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DailyExercisesCompanion(
                dayKey: dayKey,
                kcal: kcal,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required DateTime dayKey,
                required int kcal,
                Value<int> rowid = const Value.absent(),
              }) => DailyExercisesCompanion.insert(
                dayKey: dayKey,
                kcal: kcal,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DailyExercisesTable, DailyExerciseRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $DailyExercisesTable,
                    DailyExerciseRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DailyExercisesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DailyExercisesTable,
      DailyExerciseRow,
      $$DailyExercisesTableFilterComposer,
      $$DailyExercisesTableOrderingComposer,
      $$DailyExercisesTableAnnotationComposer,
      $$DailyExercisesTableCreateCompanionBuilder,
      $$DailyExercisesTableUpdateCompanionBuilder,
      (
        DailyExerciseRow,
        BaseReferences<_$AppDatabase, $DailyExercisesTable, DailyExerciseRow>,
      ),
      DailyExerciseRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
  $$UserProfilesTableTableManager get userProfiles =>
      $$UserProfilesTableTableManager(_db, _db.userProfiles);
  $$FoodsTableTableManager get foods =>
      $$FoodsTableTableManager(_db, _db.foods);
  $$MealsTableTableManager get meals =>
      $$MealsTableTableManager(_db, _db.meals);
  $$MealItemsTableTableManager get mealItems =>
      $$MealItemsTableTableManager(_db, _db.mealItems);
  $$DailyExercisesTableTableManager get dailyExercises =>
      $$DailyExercisesTableTableManager(_db, _db.dailyExercises);
}
