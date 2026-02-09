import 'package:cloud_firestore/cloud_firestore.dart';

enum EventType {
  match,
  training,
  teamBuilding;

  String get displayName {
    switch (this) {
      case EventType.match:
        return 'Match';
      case EventType.training:
        return 'Training';
      case EventType.teamBuilding:
        return 'Team Building';
    }
  }

  String get icon {
    switch (this) {
      case EventType.match:
        return '🏉';
      case EventType.training:
        return '🏋️';
      case EventType.teamBuilding:
        return '🎉';
    }
  }
}

class Event {
  final String id;
  final String teamId;
  final String? seasonId;
  final DateTime date;
  final EventType type;
  final String? opponent;
  final String? location;
  final double? latitude;
  final double? longitude;
  final bool isFriendly;
  final DateTime? votingDeadline;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Event({
    required this.id,
    required this.teamId,
    this.seasonId,
    required this.date,
    required this.type,
    this.opponent,
    this.location,
    this.latitude,
    this.longitude,
    this.isFriendly = true,
    this.votingDeadline,
    this.notes,
    required this.createdAt,
    this.updatedAt,
  });

  // Computed Properties
  bool get hasCoordinates => latitude != null && longitude != null;

  bool get isVotingOpen {
    if (votingDeadline == null) return true;
    return DateTime.now().isBefore(votingDeadline!);
  }

  bool get isMatch => type == EventType.match;

  String get matchTypeLabel {
    if (!isMatch) return '';
    return isFriendly ? 'Friendly' : 'Official';
  }

  String get displayTitle {
    switch (type) {
      case EventType.match:
        return opponent != null ? 'vs $opponent' : 'Match';
      case EventType.training:
        return 'Training';
      case EventType.teamBuilding:
        return 'Team Building';
    }
  }

  String get displaySubtitle {
    final parts = <String>[];
    if (location != null) parts.add(location!);
    if (isMatch && !isFriendly) parts.add('Official');
    return parts.join(' • ');
  }

  // Firestore Conversion
  factory Event.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Event(
      id: doc.id,
      teamId: data['teamId'] ?? '',
      seasonId: data['seasonId'],
      date: (data['date'] as Timestamp).toDate(),
      type: EventType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => EventType.training,
      ),
      opponent: data['opponent'],
      location: data['location'],
      latitude: data['latitude']?.toDouble(),
      longitude: data['longitude']?.toDouble(),
      isFriendly: data['isFriendly'] ?? true,
      votingDeadline: data['votingDeadline'] != null
          ? (data['votingDeadline'] as Timestamp).toDate()
          : null,
      notes: data['notes'],
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'teamId': teamId,
      'seasonId': seasonId,
      'date': Timestamp.fromDate(date),
      'type': type.name,
      'opponent': opponent,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'isFriendly': isFriendly,
      'votingDeadline': votingDeadline != null
          ? Timestamp.fromDate(votingDeadline!)
          : null,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  Event copyWith({
    String? seasonId,
    DateTime? date,
    EventType? type,
    String? opponent,
    String? location,
    double? latitude,
    double? longitude,
    bool? isFriendly,
    DateTime? votingDeadline,
    String? notes,
    DateTime? updatedAt,
  }) {
    return Event(
      id: id,
      teamId: teamId,
      seasonId: seasonId ?? this.seasonId,
      date: date ?? this.date,
      type: type ?? this.type,
      opponent: opponent ?? this.opponent,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isFriendly: isFriendly ?? this.isFriendly,
      votingDeadline: votingDeadline ?? this.votingDeadline,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
