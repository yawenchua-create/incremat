class Senior {
  final String id;
  final String name;
  final int age;
  final int dailyRepGoal;
  final String? photoUrl;

  const Senior({
    required this.id,
    required this.name,
    required this.age,
    required this.dailyRepGoal,
    this.photoUrl,
  });

  factory Senior.fromMap(Map<String, dynamic> map, String id) => Senior(
        id: id,
        name: (map['name'] as String?) ?? '',
        age: (map['age'] as num?)?.toInt() ?? 0,
        dailyRepGoal: (map['dailyRepGoal'] as num?)?.toInt() ?? 25,
        photoUrl: map['photoUrl'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'age': age,
        'dailyRepGoal': dailyRepGoal,
        if (photoUrl != null) 'photoUrl': photoUrl,
      };

  Senior copyWith({
    String? name,
    int? age,
    int? dailyRepGoal,
    String? photoUrl,
  }) =>
      Senior(
        id: id,
        name: name ?? this.name,
        age: age ?? this.age,
        dailyRepGoal: dailyRepGoal ?? this.dailyRepGoal,
        photoUrl: photoUrl ?? this.photoUrl,
      );
}

// Mock data matching the design spec
class MockSeniors {
  static final betty = Senior(
    id: 'senior_betty_001',
    name: 'Betty',
    age: 71,
    dailyRepGoal: 25,
  );

  static final List<Senior> all = List.unmodifiable([betty]);
}
