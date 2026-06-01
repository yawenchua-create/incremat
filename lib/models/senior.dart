class Senior {
  final String id;
  final String name;
  final int age;
  final int dailyRepGoal;
  final int consistencyThreshold;
  final String? joinCode;
  final String? primaryCaregiverId;
  final String? photoUrl;

  const Senior({
    required this.id,
    required this.name,
    required this.age,
    required this.dailyRepGoal,
    this.consistencyThreshold = 4,
    this.joinCode,
    this.primaryCaregiverId,
    this.photoUrl,
  });

  factory Senior.fromMap(Map<String, dynamic> map, String id) => Senior(
        id: id,
        name: (map['name'] as String?) ?? '',
        age: (map['age'] as num?)?.toInt() ?? 0,
        dailyRepGoal: (map['dailyRepGoal'] as num?)?.toInt() ?? 25,
        consistencyThreshold: (map['consistencyThreshold'] as num?)?.toInt() ?? 4,
        joinCode: map['joinCode'] as String?,
        primaryCaregiverId: map['primaryCaregiverId'] as String?,
        photoUrl: map['photoUrl'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'age': age,
        'dailyRepGoal': dailyRepGoal,
        'consistencyThreshold': consistencyThreshold,
        if (joinCode != null) 'joinCode': joinCode,
        if (primaryCaregiverId != null) 'primaryCaregiverId': primaryCaregiverId,
        if (photoUrl != null) 'photoUrl': photoUrl,
      };

  Senior copyWith({
    String? name,
    int? age,
    int? dailyRepGoal,
    int? consistencyThreshold,
    String? joinCode,
    String? primaryCaregiverId,
    String? photoUrl,
  }) =>
      Senior(
        id: id,
        name: name ?? this.name,
        age: age ?? this.age,
        dailyRepGoal: dailyRepGoal ?? this.dailyRepGoal,
        consistencyThreshold: consistencyThreshold ?? this.consistencyThreshold,
        joinCode: joinCode ?? this.joinCode,
        primaryCaregiverId: primaryCaregiverId ?? this.primaryCaregiverId,
        photoUrl: photoUrl ?? this.photoUrl,
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
