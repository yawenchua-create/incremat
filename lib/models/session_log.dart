/// One completed exercise session for a senior (a row of history).
///
/// Same immutable-model pattern as [Senior] (see senior.dart for the full
/// explanation of fromMap / toMap / the defensive casts). Stored at
/// `seniors/{seniorId}/sessions/{id}` in Firestore.
class SessionLog {
  final String id;
  final String seniorId;
  final DateTime timestamp;
  final int repCount;            // total reps done in this session
  final double avgRepTimeSeconds; // average seconds per rep (a speed/quality cue)
  // Seconds to complete the first five reps of the session — the on-mat proxy
  // for the Five Times Sit-to-Stand Test (5XSST). 0 = not measured (fewer than
  // five reps, or a legacy session recorded before this was tracked).
  final double firstFiveRepsSeconds;
  // Provenance: how this session was recorded ('mat' = auto from the device,
  // 'manual' = caregiver entry) and which caregiver uid recorded it.
  final String source;
  final String? recordedBy;
  final bool synced;

  const SessionLog({
    required this.id,
    required this.seniorId,
    required this.timestamp,
    required this.repCount,
    required this.avgRepTimeSeconds,
    this.firstFiveRepsSeconds = 0.0,
    this.source = 'mat',
    this.recordedBy,
    this.synced = false,
  });

  /// A computed/derived getter (no stored field): true when we captured a real
  /// 5-rep time. Lets the UI decide whether to show the 5XSST result.
  bool get hasFiveRepTime => firstFiveRepsSeconds > 0;

  factory SessionLog.fromMap(Map<String, dynamic> map, String id) => SessionLog(
        id: id,
        seniorId: (map['seniorId'] as String?) ?? '',
        timestamp: DateTime.fromMillisecondsSinceEpoch(
            (map['timestamp'] as num?)?.toInt() ?? 0),
        repCount: (map['repCount'] as num?)?.toInt() ?? 0,
        avgRepTimeSeconds: (map['avgRepTimeSeconds'] as num?)?.toDouble() ?? 0.0,
        firstFiveRepsSeconds:
            (map['firstFiveRepsSeconds'] as num?)?.toDouble() ?? 0.0,
        source: (map['source'] as String?) ?? 'mat',
        recordedBy: map['recordedBy'] as String?,
        synced: (map['synced'] as bool?) ?? false,
      );

  Map<String, dynamic> toMap() => {
        'seniorId': seniorId,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'repCount': repCount,
        'avgRepTimeSeconds': avgRepTimeSeconds,
        'firstFiveRepsSeconds': firstFiveRepsSeconds,
        'source': source,
        if (recordedBy != null) 'recordedBy': recordedBy,
        'synced': synced,
      };
}

// Sample data shown only in logged-out demo mode (never to real accounts).
class MockSessionData {
  static const List<int> weeklyReps = [14, 12, 0, 16, 10, 14, 0];

  static const int todayReps = 8;
  static const double avgRepTimeSeconds = 2.6;
  static const double consistencyPercent = 92.0;
  static const int daysActiveThisMonth = 26;
  static const int totalDaysThisMonth = 30;
  static const int totalRepsThisMonth = 1248;
  static const int daysActiveThisWeek = 5;
  static const int daysInWeek = 7;
}
