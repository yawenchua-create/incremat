class SessionLog {
  final String id;
  final String seniorId;
  final DateTime timestamp;
  final int repCount;
  final double avgRepTimeSeconds;
  final bool synced;

  const SessionLog({
    required this.id,
    required this.seniorId,
    required this.timestamp,
    required this.repCount,
    required this.avgRepTimeSeconds,
    this.synced = false,
  });

  factory SessionLog.fromMap(Map<String, dynamic> map, String id) => SessionLog(
        id: id,
        seniorId: (map['seniorId'] as String?) ?? '',
        timestamp: DateTime.fromMillisecondsSinceEpoch(
            (map['timestamp'] as num?)?.toInt() ?? 0),
        repCount: (map['repCount'] as num?)?.toInt() ?? 0,
        avgRepTimeSeconds: (map['avgRepTimeSeconds'] as num?)?.toDouble() ?? 0.0,
        synced: (map['synced'] as bool?) ?? false,
      );

  Map<String, dynamic> toMap() => {
        'seniorId': seniorId,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'repCount': repCount,
        'avgRepTimeSeconds': avgRepTimeSeconds,
        'synced': synced,
      };
}

// Mock weekly rep data matching the design spec
class MockSessionData {
  static const List<int> mobilityScoresW1toW12 = [
    57, 59, 62, 64, 65, 66, 74, 75, 76, 80, 83, 89,
  ];

  static const List<int> weeklyReps = [14, 12, 0, 16, 10, 14, 0];

  static const int todayReps = 8;
  static const double avgRepTimeSeconds = 2.6;
  static const double consistencyPercent = 92.0;
  static const int daysActiveThisMonth = 26;
  static const int totalDaysThisMonth = 30;
  static const int totalRepsThisMonth = 1248;
  static const double speedImprovementSeconds = -0.8;
  static const int daysActiveThisWeek = 5;
  static const int daysInWeek = 7;
  static const double overallImprovementPercent = 28.0;
}
