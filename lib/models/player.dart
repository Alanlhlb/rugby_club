import 'package:cloud_firestore/cloud_firestore.dart';

class Player {
  final String id;
  final String name;
  final int jerseyNumber;
  final String? photoUrl;
  final DateTime? birthday;
  final List<String> positions;
  final String status;
  final double? height;
  final double? weight;
  final List<String> roles;

  // Leadership Tags
  final bool isCaptain;
  final bool isViceCaptain;

  // Lineout Tags
  final bool isLineoutJumper;
  final bool isLineoutLifter;
  final bool isLineoutThrower;

  // Other Tags
  final bool isKicker;

  // Disciplinary
  final int yellowCards;
  final int redCards;
  final DateTime? suspendedUntil;
  final bool isInjured;
  final String? injuryNotes;

  // Scoring Stats
  final int tries;
  final int conversions;
  final int penalties;
  final int dropGoals;

  // Attendance Stats
  final int eventsAttended;
  final int eventsTotal;

  // Metadata
  final String teamId;
  final String? seasonId;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Player({
    required this.id,
    required this.name,
    required this.jerseyNumber,
    this.photoUrl,
    this.birthday,
    required this.positions,
    this.status = 'active',
    this.height,
    this.weight,
    this.roles = const [],
    this.isCaptain = false,
    this.isViceCaptain = false,
    this.isLineoutJumper = false,
    this.isLineoutLifter = false,
    this.isLineoutThrower = false,
    this.isKicker = false,
    this.yellowCards = 0,
    this.redCards = 0,
    this.suspendedUntil,
    this.isInjured = false,
    this.injuryNotes,
    this.tries = 0,
    this.conversions = 0,
    this.penalties = 0,
    this.dropGoals = 0,
    this.eventsAttended = 0,
    this.eventsTotal = 0,
    required this.teamId,
    this.seasonId,
    required this.createdAt,
    this.updatedAt,
  });

  // Computed Properties
  int get totalPoints =>
      (tries * 5) + (conversions * 2) + (penalties * 3) + (dropGoals * 3);

  int? get age {
    if (birthday == null) return null;
    final now = DateTime.now();
    int age = now.year - birthday!.year;
    if (now.month < birthday!.month ||
        (now.month == birthday!.month && now.day < birthday!.day)) {
      age--;
    }
    return age;
  }

  bool get hasBirthdaySoon {
    if (birthday == null) return false;
    final now = DateTime.now();
    final nextBirthday = DateTime(now.year, birthday!.month, birthday!.day);
    final daysUntil = nextBirthday.difference(now).inDays;
    return daysUntil >= 0 && daysUntil <= 7;
  }

  bool get isSuspended {
    if (suspendedUntil == null) return false;
    return DateTime.now().isBefore(suspendedUntil!);
  }

  double get attendanceRate {
    if (eventsTotal == 0) return 0.0;
    return eventsAttended / eventsTotal;
  }

  List<String> get tags {
    List<String> result = [];
    if (isCaptain) result.add('Cap');
    if (isViceCaptain) result.add('Vice');
    if (isLineoutJumper) result.add('Jump');
    if (isLineoutLifter) result.add('Lift');
    if (isLineoutThrower) result.add('Throw');
    if (isKicker) result.add('Kick');
    if (isInjured) result.add('🩹');
    if (isSuspended) result.add('⛔');
    return result;
  }

  List<String> get lineoutTags {
    List<String> result = [];
    if (isLineoutJumper) result.add('Jump');
    if (isLineoutLifter) result.add('Lift');
    if (isLineoutThrower) result.add('Throw');
    return result;
  }

  String get tagsLabel => tags.join(' • ');

  String get primaryPosition => positions.isNotEmpty ? positions.first : 'N/A';

  // Firestore Conversion
  factory Player.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Player(
      id: doc.id,
      name: data['name'] ?? '',
      jerseyNumber: data['jerseyNumber'] ?? 0,
      photoUrl: data['photoUrl'],
      birthday: data['birthday'] != null
          ? (data['birthday'] as Timestamp).toDate()
          : null,
      positions: List<String>.from(data['positions'] ?? []),
      status: data['status'] ?? 'active',
      height: data['height']?.toDouble(),
      weight: data['weight']?.toDouble(),
      roles: List<String>.from(data['roles'] ?? []),
      isCaptain: data['isCaptain'] ?? false,
      isViceCaptain: data['isViceCaptain'] ?? false,
      isLineoutJumper: data['isLineoutJumper'] ?? false,
      isLineoutLifter: data['isLineoutLifter'] ?? false,
      isLineoutThrower: data['isLineoutThrower'] ?? false,
      isKicker: data['isKicker'] ?? false,
      yellowCards: data['yellowCards'] ?? 0,
      redCards: data['redCards'] ?? 0,
      suspendedUntil: data['suspendedUntil'] != null
          ? (data['suspendedUntil'] as Timestamp).toDate()
          : null,
      isInjured: data['isInjured'] ?? false,
      injuryNotes: data['injuryNotes'],
      tries: data['tries'] ?? 0,
      conversions: data['conversions'] ?? 0,
      penalties: data['penalties'] ?? 0,
      dropGoals: data['dropGoals'] ?? 0,
      eventsAttended: data['eventsAttended'] ?? 0,
      eventsTotal: data['eventsTotal'] ?? 0,
      teamId: data['teamId'] ?? '',
      seasonId: data['seasonId'],
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
      'name': name,
      'jerseyNumber': jerseyNumber,
      'photoUrl': photoUrl,
      'birthday': birthday != null ? Timestamp.fromDate(birthday!) : null,
      'positions': positions,
      'status': status,
      'height': height,
      'weight': weight,
      'roles': roles,
      'isCaptain': isCaptain,
      'isViceCaptain': isViceCaptain,
      'isLineoutJumper': isLineoutJumper,
      'isLineoutLifter': isLineoutLifter,
      'isLineoutThrower': isLineoutThrower,
      'isKicker': isKicker,
      'yellowCards': yellowCards,
      'redCards': redCards,
      'suspendedUntil': suspendedUntil != null
          ? Timestamp.fromDate(suspendedUntil!)
          : null,
      'isInjured': isInjured,
      'injuryNotes': injuryNotes,
      'tries': tries,
      'conversions': conversions,
      'penalties': penalties,
      'dropGoals': dropGoals,
      'eventsAttended': eventsAttended,
      'eventsTotal': eventsTotal,
      'teamId': teamId,
      'seasonId': seasonId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  Player copyWith({
    String? name,
    int? jerseyNumber,
    String? photoUrl,
    DateTime? birthday,
    List<String>? positions,
    String? status,
    double? height,
    double? weight,
    List<String>? roles,
    bool? isCaptain,
    bool? isViceCaptain,
    bool? isLineoutJumper,
    bool? isLineoutLifter,
    bool? isLineoutThrower,
    bool? isKicker,
    int? yellowCards,
    int? redCards,
    DateTime? suspendedUntil,
    bool? isInjured,
    String? injuryNotes,
    int? tries,
    int? conversions,
    int? penalties,
    int? dropGoals,
    int? eventsAttended,
    int? eventsTotal,
    String? seasonId,
    DateTime? updatedAt,
  }) {
    return Player(
      id: id,
      name: name ?? this.name,
      jerseyNumber: jerseyNumber ?? this.jerseyNumber,
      photoUrl: photoUrl ?? this.photoUrl,
      birthday: birthday ?? this.birthday,
      positions: positions ?? this.positions,
      status: status ?? this.status,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      roles: roles ?? this.roles,
      isCaptain: isCaptain ?? this.isCaptain,
      isViceCaptain: isViceCaptain ?? this.isViceCaptain,
      isLineoutJumper: isLineoutJumper ?? this.isLineoutJumper,
      isLineoutLifter: isLineoutLifter ?? this.isLineoutLifter,
      isLineoutThrower: isLineoutThrower ?? this.isLineoutThrower,
      isKicker: isKicker ?? this.isKicker,
      yellowCards: yellowCards ?? this.yellowCards,
      redCards: redCards ?? this.redCards,
      suspendedUntil: suspendedUntil ?? this.suspendedUntil,
      isInjured: isInjured ?? this.isInjured,
      injuryNotes: injuryNotes ?? this.injuryNotes,
      tries: tries ?? this.tries,
      conversions: conversions ?? this.conversions,
      penalties: penalties ?? this.penalties,
      dropGoals: dropGoals ?? this.dropGoals,
      eventsAttended: eventsAttended ?? this.eventsAttended,
      eventsTotal: eventsTotal ?? this.eventsTotal,
      teamId: teamId,
      seasonId: seasonId ?? this.seasonId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  static Player empty() {
    return Player(
      id: '',
      name: '',
      jerseyNumber: 0,
      positions: [],
      teamId: '',
      createdAt: DateTime.now(),
    );
  }
}
