import '../core/utils/chair_stand.dart';

/// One 30-Second Chair Stand Test result, kept as history for the monthly trend.
/// `final` fields + a `const` constructor = an immutable value object: once
/// built, it never changes (you make a new one instead of editing it).
class ChairStandResult {
  final int reps;
  final DateTime at;
  const ChairStandResult(this.reps, this.at);
}

/// The core domain model for an elderly person being cared for ("a senior").
///
/// This is a classic Flutter immutable model with three companion methods you'll
/// see on almost every model in this app:
///   • [Senior.fromMap]  — build one FROM a Firestore document (deserialize)
///   • [toMap]           — turn one INTO a Firestore document (serialize)
///   • [copyWith]        — make a modified copy (since fields are `final`)
class Senior {
  // All fields are `final` → immutable. `String?` (with `?`) means the value is
  // nullable; a plain `String` can never be null.
  final String id;                 // Firestore document id (not stored in the doc)
  final String name;
  final int age;
  final Sex sex;
  final int dailyRepGoal;          // target reps/day the caregiver set
  final int consistencyThreshold;  // min active days/week to count as "consistent"
  final String? joinCode;          // credential used to pair caregivers — sensitive
  final String? primaryCaregiverId;
  final String? photoUrl;
  // Latest 30-Second Chair Stand Test result (reps in 30s) and when it was
  // taken. null = never tested.
  final int? chairStandReps;
  final DateTime? chairStandTestAt;
  // Full history of test results (oldest → newest) for the monthly trend.
  final List<ChairStandResult> chairStandHistory;

  const Senior({
    required this.id,
    required this.name,
    required this.age,
    this.sex = Sex.unspecified,
    required this.dailyRepGoal,
    this.consistencyThreshold = 4,
    this.joinCode,
    this.primaryCaregiverId,
    this.photoUrl,
    this.chairStandReps,
    this.chairStandTestAt,
    this.chairStandHistory = const [],
  });

  // A `factory` constructor builds a Senior from a raw Firestore map. Firestore
  // hands back `Map<String, dynamic>` (untyped JSON-like data), so every field
  // is defensively cast and given a fallback:
  //   `(map['age'] as num?)?.toInt() ?? 0`
  //    = read 'age', treat it as a nullable number, convert to int, and if it's
  //      missing/null default to 0. This stops a malformed document from
  //      crashing the app.
  factory Senior.fromMap(Map<String, dynamic> map, String id) => Senior(
        id: id, // the document id is passed in separately by the repository
        name: (map['name'] as String?) ?? '',
        age: (map['age'] as num?)?.toInt() ?? 0,
        sex: sexFromName(map['sex'] as String?),
        dailyRepGoal: (map['dailyRepGoal'] as num?)?.toInt() ?? 25,
        consistencyThreshold: (map['consistencyThreshold'] as num?)?.toInt() ?? 4,
        joinCode: map['joinCode'] as String?,
        primaryCaregiverId: map['primaryCaregiverId'] as String?,
        photoUrl: map['photoUrl'] as String?,
        chairStandReps: (map['chairStandReps'] as num?)?.toInt(),
        chairStandTestAt: (map['chairStandTestAt'] as num?) != null
            ? DateTime.fromMillisecondsSinceEpoch(
                (map['chairStandTestAt'] as num).toInt())
            : null,
        // Dates are stored as "milliseconds since 1970" (an int) because
        // Firestore can't store a Dart DateTime directly; we convert back here.
        // The history list is rebuilt item-by-item: .whereType<Map>() filters
        // out anything that isn't a map, .map(...) converts each to a
        // ChairStandResult, .toList() materialises it, and the cascade
        // `..sort(...)` sorts oldest→newest in place before returning.
        chairStandHistory: ((map['chairStandHistory'] as List?) ?? [])
            .whereType<Map>()
            .map((e) => ChairStandResult(
                  (e['reps'] as num?)?.toInt() ?? 0,
                  DateTime.fromMillisecondsSinceEpoch(
                      (e['at'] as num?)?.toInt() ?? 0),
                ))
            .toList()
          ..sort((a, b) => a.at.compareTo(b.at)),
      );

  // The reverse of fromMap: produce the map we write to Firestore. Note `id`
  // is NOT included (it's the document's key, not a field), and the
  // `if (x != null) 'key': x` entries only add optional fields when they exist,
  // keeping documents tidy.
  Map<String, dynamic> toMap() => {
        'name': name,
        'age': age,
        'sex': sex.name, // store the enum as its string name, e.g. "female"
        'dailyRepGoal': dailyRepGoal,
        'consistencyThreshold': consistencyThreshold,
        if (joinCode != null) 'joinCode': joinCode,
        if (primaryCaregiverId != null) 'primaryCaregiverId': primaryCaregiverId,
        if (photoUrl != null) 'photoUrl': photoUrl,
        if (chairStandReps != null) 'chairStandReps': chairStandReps,
        if (chairStandTestAt != null)
          'chairStandTestAt': chairStandTestAt!.millisecondsSinceEpoch,
        'chairStandHistory': chairStandHistory
            .map((r) => {'reps': r.reps, 'at': r.at.millisecondsSinceEpoch})
            .toList(),
      };

  // Because every field is `final`, you can't mutate a Senior. copyWith returns
  // a NEW Senior identical to this one except for the named fields you pass.
  // Pattern: `field: newValue ?? this.field` keeps the old value when the
  // argument is omitted (null). e.g. `betty.copyWith(age: 72)`.
  Senior copyWith({
    String? name,
    int? age,
    Sex? sex,
    int? dailyRepGoal,
    int? consistencyThreshold,
    String? joinCode,
    String? primaryCaregiverId,
    String? photoUrl,
    int? chairStandReps,
    DateTime? chairStandTestAt,
    List<ChairStandResult>? chairStandHistory,
  }) =>
      Senior(
        id: id,
        name: name ?? this.name,
        age: age ?? this.age,
        sex: sex ?? this.sex,
        dailyRepGoal: dailyRepGoal ?? this.dailyRepGoal,
        consistencyThreshold: consistencyThreshold ?? this.consistencyThreshold,
        joinCode: joinCode ?? this.joinCode,
        primaryCaregiverId: primaryCaregiverId ?? this.primaryCaregiverId,
        photoUrl: photoUrl ?? this.photoUrl,
        chairStandReps: chairStandReps ?? this.chairStandReps,
        chairStandTestAt: chairStandTestAt ?? this.chairStandTestAt,
        chairStandHistory: chairStandHistory ?? this.chairStandHistory,
      );
}

// Demo data used only in logged-out/demo mode so the UI has something to show
// without a real account. Never written to real caregiver accounts.
class MockSeniors {
  static final betty = Senior(
    id: 'senior_betty_001',
    name: 'Betty',
    age: 71,
    dailyRepGoal: 25,
    consistencyThreshold: 4,
    joinCode: 'ROSE-4821',
  );

  static final List<Senior> all = List.unmodifiable([betty]);
}
