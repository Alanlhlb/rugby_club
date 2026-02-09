import 'package:cloud_firestore/cloud_firestore.dart';

enum MatchMode {
  official,
  preview;

  String get displayName {
    switch (this) {
      case MatchMode.official:
        return 'Official';
      case MatchMode.preview:
        return 'Preview';
    }
  }
}

enum MatchStatus {
  lineupPending,
  previewReady,
  officialReady,
  inProgress,
  completed;

  String get displayName {
    switch (this) {
      case MatchStatus.lineupPending:
        return '等待報名';
      case MatchStatus.previewReady:
        return '預覽名單';
      case MatchStatus.officialReady:
        return '正式名單';
      case MatchStatus.inProgress:
        return '比賽中';
      case MatchStatus.completed:
        return '已完成';
    }
  }
}

class MatchEvent {
  final String type;
  final String? playerId;
  final int minute;
  final String? notes;
  final DateTime timestamp;

  MatchEvent({
    required this.type,
    this.playerId,
    required this.minute,
    this.notes,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'playerId': playerId,
      'minute': minute,
      'notes': notes,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory MatchEvent.fromMap(Map<String, dynamic> map) {
    return MatchEvent(
      type: map['type'] ?? '',
      playerId: map['playerId'],
      minute: map['minute'] ?? 0,
      notes: map['notes'],
      timestamp: map['timestamp'] != null
          ? (map['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}

class MatchState {
  final String id;
  final String eventId;
  final String teamId;
  final String? seasonId;
  final MatchMode mode;
  final MatchStatus status;

  // Position Slots (0-14 for 15 players)
  final Map<int, String?> positionSlots;

  // Suspended Players
  final Map<String, bool> suspendedPlayers;

  // Yellow Card Timers
  final Map<String, DateTime> yellowCardTimers;

  // Match Events
  final List<MatchEvent> events;

  // Scores
  final int ourScore;
  final int opponentScore;

  // Time
  final DateTime? startTime;
  final DateTime? endTime;
  final bool isPaused;
  final DateTime? pausedAt;

  // Completion
  final bool isCompleted;

  // Saved Lineup
  final Map<int, String?>? savedLineup;

  final DateTime createdAt;
  final DateTime? updatedAt;

  MatchState({
    required this.id,
    required this.eventId,
    required this.teamId,
    this.seasonId,
    this.mode = MatchMode.preview,
    this.status = MatchStatus.lineupPending,
    Map<int, String?>? positionSlots,
    Map<String, bool>? suspendedPlayers,
    Map<String, DateTime>? yellowCardTimers,
    List<MatchEvent>? events,
    this.ourScore = 0,
    this.opponentScore = 0,
    this.startTime,
    this.endTime,
    this.isPaused = false,
    this.pausedAt,
    this.isCompleted = false,
    this.savedLineup,
    required this.createdAt,
    this.updatedAt,
  }) : positionSlots = positionSlots ?? {},
       suspendedPlayers = suspendedPlayers ?? {},
       yellowCardTimers = yellowCardTimers ?? {},
       events = events ?? [];

  // Computed Properties
  List<String> get onFieldPlayerIds {
    return positionSlots.values
        .where((id) => id != null)
        .cast<String>()
        .toList();
  }

  int get onFieldCount => onFieldPlayerIds.length;

  bool get isOfficial => mode == MatchMode.official;

  bool get isPreview => mode == MatchMode.preview;

  Duration? get matchDuration {
    if (startTime == null) return null;
    final end = endTime ?? (isPaused ? pausedAt : DateTime.now());
    if (end == null) return null;
    return end.difference(startTime!);
  }

  // Firestore Conversion
  factory MatchState.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    Map<int, String?> slots = {};
    if (data['positionSlots'] != null) {
      final slotsData = data['positionSlots'] as Map<String, dynamic>;
      slotsData.forEach((key, value) {
        slots[int.parse(key)] = value as String?;
      });
    }

    Map<String, bool> suspended = {};
    if (data['suspendedPlayers'] != null) {
      suspended = Map<String, bool>.from(data['suspendedPlayers']);
    }

    Map<String, DateTime> timers = {};
    if (data['yellowCardTimers'] != null) {
      final timersData = data['yellowCardTimers'] as Map<String, dynamic>;
      timersData.forEach((key, value) {
        timers[key] = (value as Timestamp).toDate();
      });
    }

    List<MatchEvent> matchEvents = [];
    if (data['events'] != null) {
      matchEvents = (data['events'] as List)
          .map((e) => MatchEvent.fromMap(e as Map<String, dynamic>))
          .toList();
    }

    Map<int, String?>? savedLineup;
    if (data['savedLineup'] != null) {
      savedLineup = {};
      final lineupData = data['savedLineup'] as Map<String, dynamic>;
      lineupData.forEach((key, value) {
        savedLineup![int.parse(key)] = value as String?;
      });
    }

    return MatchState(
      id: doc.id,
      eventId: data['eventId'] ?? '',
      teamId: data['teamId'] ?? '',
      seasonId: data['seasonId'],
      mode: MatchMode.values.firstWhere(
        (e) => e.name == data['mode'],
        orElse: () => MatchMode.preview,
      ),
      status: MatchStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => (data['isCompleted'] == true)
            ? MatchStatus.completed
            : MatchStatus.lineupPending,
      ),
      positionSlots: slots,
      suspendedPlayers: suspended,
      yellowCardTimers: timers,
      events: matchEvents,
      ourScore: data['ourScore'] ?? 0,
      opponentScore: data['opponentScore'] ?? 0,
      startTime: data['startTime'] != null
          ? (data['startTime'] as Timestamp).toDate()
          : null,
      endTime: data['endTime'] != null
          ? (data['endTime'] as Timestamp).toDate()
          : null,
      isPaused: data['isPaused'] ?? false,
      pausedAt: data['pausedAt'] != null
          ? (data['pausedAt'] as Timestamp).toDate()
          : null,
      isCompleted: data['isCompleted'] ?? false,
      savedLineup: savedLineup,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    Map<String, dynamic> slotsMap = {};
    positionSlots.forEach((key, value) {
      slotsMap[key.toString()] = value;
    });

    Map<String, dynamic> timersMap = {};
    yellowCardTimers.forEach((key, value) {
      timersMap[key] = Timestamp.fromDate(value);
    });

    Map<String, dynamic>? savedLineupMap;
    if (savedLineup != null) {
      savedLineupMap = {};
      savedLineup!.forEach((key, value) {
        savedLineupMap![key.toString()] = value;
      });
    }

    return {
      'eventId': eventId,
      'teamId': teamId,
      'seasonId': seasonId,
      'mode': mode.name,
      'status': status.name,
      'positionSlots': slotsMap,
      'suspendedPlayers': suspendedPlayers,
      'yellowCardTimers': timersMap,
      'events': events.map((e) => e.toMap()).toList(),
      'ourScore': ourScore,
      'opponentScore': opponentScore,
      'startTime': startTime != null ? Timestamp.fromDate(startTime!) : null,
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'isPaused': isPaused,
      'pausedAt': pausedAt != null ? Timestamp.fromDate(pausedAt!) : null,
      'isCompleted': isCompleted,
      'savedLineup': savedLineupMap,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  Map<String, dynamic> toOfflineMap() {
    Map<String, dynamic> slotsMap = {};
    positionSlots.forEach((key, value) {
      slotsMap[key.toString()] = value;
    });

    Map<String, String> timersMap = {};
    yellowCardTimers.forEach((key, value) {
      timersMap[key] = value.toIso8601String();
    });

    Map<String, dynamic>? savedLineupMap;
    if (savedLineup != null) {
      savedLineupMap = {};
      savedLineup!.forEach((key, value) {
        savedLineupMap![key.toString()] = value;
      });
    }

    return {
      'id': id,
      'eventId': eventId,
      'teamId': teamId,
      'seasonId': seasonId,
      'mode': mode.name,
      'status': status.name,
      'positionSlots': slotsMap,
      'suspendedPlayers': suspendedPlayers,
      'yellowCardTimers': timersMap,
      'events': events
          .map(
            (e) => {
              'type': e.type,
              'playerId': e.playerId,
              'minute': e.minute,
              'notes': e.notes,
              'timestamp': e.timestamp.toIso8601String(),
            },
          )
          .toList(),
      'ourScore': ourScore,
      'opponentScore': opponentScore,
      'startTime': startTime?.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'isPaused': isPaused,
      'pausedAt': pausedAt?.toIso8601String(),
      'isCompleted': isCompleted,
      'savedLineup': savedLineupMap,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory MatchState.fromOfflineMap(Map<String, dynamic> data) {
    Map<int, String?> slots = {};
    if (data['positionSlots'] != null) {
      (data['positionSlots'] as Map<String, dynamic>).forEach((key, value) {
        slots[int.parse(key)] = value as String?;
      });
    }

    Map<String, bool> suspended = {};
    if (data['suspendedPlayers'] != null) {
      suspended = Map<String, bool>.from(data['suspendedPlayers']);
    }

    Map<String, DateTime> timers = {};
    if (data['yellowCardTimers'] != null) {
      (data['yellowCardTimers'] as Map<String, dynamic>).forEach((key, value) {
        timers[key] = DateTime.parse(value as String);
      });
    }

    List<MatchEvent> matchEvents = [];
    if (data['events'] != null) {
      matchEvents = (data['events'] as List).map((e) {
        final m = e as Map<String, dynamic>;
        return MatchEvent(
          type: m['type'] ?? '',
          playerId: m['playerId'],
          minute: m['minute'] ?? 0,
          notes: m['notes'],
          timestamp: m['timestamp'] != null
              ? DateTime.parse(m['timestamp'])
              : DateTime.now(),
        );
      }).toList();
    }

    Map<int, String?>? savedLineup;
    if (data['savedLineup'] != null) {
      savedLineup = {};
      (data['savedLineup'] as Map<String, dynamic>).forEach((key, value) {
        savedLineup![int.parse(key)] = value as String?;
      });
    }

    return MatchState(
      id: data['id'] ?? '',
      eventId: data['eventId'] ?? '',
      teamId: data['teamId'] ?? '',
      seasonId: data['seasonId'],
      mode: MatchMode.values.firstWhere(
        (e) => e.name == data['mode'],
        orElse: () => MatchMode.preview,
      ),
      status: MatchStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => (data['isCompleted'] == true)
            ? MatchStatus.completed
            : MatchStatus.lineupPending,
      ),
      positionSlots: slots,
      suspendedPlayers: suspended,
      yellowCardTimers: timers,
      events: matchEvents,
      ourScore: data['ourScore'] ?? 0,
      opponentScore: data['opponentScore'] ?? 0,
      startTime: data['startTime'] != null
          ? DateTime.parse(data['startTime'])
          : null,
      endTime: data['endTime'] != null ? DateTime.parse(data['endTime']) : null,
      isPaused: data['isPaused'] ?? false,
      pausedAt: data['pausedAt'] != null
          ? DateTime.parse(data['pausedAt'])
          : null,
      isCompleted: data['isCompleted'] ?? false,
      savedLineup: savedLineup,
      createdAt: data['createdAt'] != null
          ? DateTime.parse(data['createdAt'])
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? DateTime.parse(data['updatedAt'])
          : null,
    );
  }

  MatchState copyWith({
    MatchMode? mode,
    MatchStatus? status,
    Map<int, String?>? positionSlots,
    Map<String, bool>? suspendedPlayers,
    Map<String, DateTime>? yellowCardTimers,
    List<MatchEvent>? events,
    int? ourScore,
    int? opponentScore,
    DateTime? startTime,
    DateTime? endTime,
    bool? isPaused,
    DateTime? pausedAt,
    bool? isCompleted,
    Map<int, String?>? savedLineup,
    DateTime? updatedAt,
  }) {
    return MatchState(
      id: id,
      eventId: eventId,
      teamId: teamId,
      seasonId: seasonId,
      mode: mode ?? this.mode,
      status: status ?? this.status,
      positionSlots: positionSlots ?? this.positionSlots,
      suspendedPlayers: suspendedPlayers ?? this.suspendedPlayers,
      yellowCardTimers: yellowCardTimers ?? this.yellowCardTimers,
      events: events ?? this.events,
      ourScore: ourScore ?? this.ourScore,
      opponentScore: opponentScore ?? this.opponentScore,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isPaused: isPaused ?? this.isPaused,
      pausedAt: pausedAt ?? this.pausedAt,
      isCompleted: isCompleted ?? this.isCompleted,
      savedLineup: savedLineup ?? this.savedLineup,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
