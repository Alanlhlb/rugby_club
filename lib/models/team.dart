import 'package:cloud_firestore/cloud_firestore.dart';

enum TeamLevel {
  professional,
  semiPro,
  amateur,
  youth,
  school;

  String get displayName {
    switch (this) {
      case TeamLevel.professional:
        return 'Professional';
      case TeamLevel.semiPro:
        return 'Semi-Pro';
      case TeamLevel.amateur:
        return 'Amateur';
      case TeamLevel.youth:
        return 'Youth';
      case TeamLevel.school:
        return 'School';
    }
  }
}

class Team {
  final String id;
  final String name;
  final String? logoUrl;
  final String primaryColor;
  final String secondaryColor;
  final TeamLevel level;
  final String? currentSeasonId;
  final String? currentSeasonName;
  final int totalScored;
  final int totalConceded;
  final int matchesWon;
  final int matchesLost;
  final int matchesDrawn;
  final int conversionAttempts;
  final int conversionSuccess;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Team({
    required this.id,
    required this.name,
    this.logoUrl,
    required this.primaryColor,
    required this.secondaryColor,
    required this.level,
    this.currentSeasonId,
    this.currentSeasonName,
    this.totalScored = 0,
    this.totalConceded = 0,
    this.matchesWon = 0,
    this.matchesLost = 0,
    this.matchesDrawn = 0,
    this.conversionAttempts = 0,
    this.conversionSuccess = 0,
    required this.createdAt,
    this.updatedAt,
  });

  // Computed Properties
  int get totalMatches => matchesWon + matchesLost + matchesDrawn;

  double get winRate => totalMatches > 0 ? matchesWon / totalMatches : 0.0;

  double get conversionRate =>
      conversionAttempts > 0 ? conversionSuccess / conversionAttempts : 0.0;

  int get pointDifference => totalScored - totalConceded;

  // Firestore Conversion
  factory Team.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Team(
      id: doc.id,
      name: data['name'] ?? '',
      logoUrl: data['logoUrl'],
      primaryColor: data['primaryColor'] ?? '#1B5E20',
      secondaryColor: data['secondaryColor'] ?? '#FF6F00',
      level: TeamLevel.values.firstWhere(
        (e) => e.name == data['level'],
        orElse: () => TeamLevel.amateur,
      ),
      currentSeasonId: data['currentSeasonId'],
      currentSeasonName: data['currentSeasonName'],
      totalScored: data['totalScored'] ?? 0,
      totalConceded: data['totalConceded'] ?? 0,
      matchesWon: data['matchesWon'] ?? 0,
      matchesLost: data['matchesLost'] ?? 0,
      matchesDrawn: data['matchesDrawn'] ?? 0,
      conversionAttempts: data['conversionAttempts'] ?? 0,
      conversionSuccess: data['conversionSuccess'] ?? 0,
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
      'logoUrl': logoUrl,
      'primaryColor': primaryColor,
      'secondaryColor': secondaryColor,
      'level': level.name,
      'currentSeasonId': currentSeasonId,
      'currentSeasonName': currentSeasonName,
      'totalScored': totalScored,
      'totalConceded': totalConceded,
      'matchesWon': matchesWon,
      'matchesLost': matchesLost,
      'matchesDrawn': matchesDrawn,
      'conversionAttempts': conversionAttempts,
      'conversionSuccess': conversionSuccess,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  Team copyWith({
    String? name,
    String? logoUrl,
    String? primaryColor,
    String? secondaryColor,
    TeamLevel? level,
    String? currentSeasonId,
    String? currentSeasonName,
    int? totalScored,
    int? totalConceded,
    int? matchesWon,
    int? matchesLost,
    int? matchesDrawn,
    int? conversionAttempts,
    int? conversionSuccess,
    DateTime? updatedAt,
  }) {
    return Team(
      id: id,
      name: name ?? this.name,
      logoUrl: logoUrl ?? this.logoUrl,
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      level: level ?? this.level,
      currentSeasonId: currentSeasonId ?? this.currentSeasonId,
      currentSeasonName: currentSeasonName ?? this.currentSeasonName,
      totalScored: totalScored ?? this.totalScored,
      totalConceded: totalConceded ?? this.totalConceded,
      matchesWon: matchesWon ?? this.matchesWon,
      matchesLost: matchesLost ?? this.matchesLost,
      matchesDrawn: matchesDrawn ?? this.matchesDrawn,
      conversionAttempts: conversionAttempts ?? this.conversionAttempts,
      conversionSuccess: conversionSuccess ?? this.conversionSuccess,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
