import '../core/utils/chair_stand.dart';

/// One 30-Second Chair Stand Test result, kept as history for the monthly trend.
class ChairStandResult {
  final int reps;
  final DateTime at;
  const ChairStandResult(this.reps, this.at);
}

class Senior {
  final String id;
  final String name;
  final int age;
  final Sex sex;
  final int dailyRepGoal;
  final int consistencyThreshold;
  final String? joinCode;
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

  factory Senior.fromMap(Map<String, dynamic> map, String id) => Senior(
        id: id,
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

  Map<String, dynamic> toMap() => {
        'name': name,
        'age': age,
        'sex': sex.name,
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
