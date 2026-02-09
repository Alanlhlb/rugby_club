import 'package:cloud_firestore/cloud_firestore.dart';

class Season {
  final String id;
  final String teamId;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final int totalMatches;
  final int matchesWon;
  final int matchesLost;
  final int matchesDrawn;
  final int totalScored;
  final int totalConceded;
  final DateTime createdAt;

  Season({
    required this.id,
    required this.teamId,
    required this.name,
    required this.startDate,
    required this.endDate,
    this.isActive = false,
    this.totalMatches = 0,
    this.matchesWon = 0,
    this.matchesLost = 0,
    this.matchesDrawn = 0,
    this.totalScored = 0,
    this.totalConceded = 0,
    required this.createdAt,
  });

  // Computed Properties
  bool get isCurrentSeason {
    final now = DateTime.now();
    return now.isAfter(startDate) && now.isBefore(endDate);
  }

  double get winRate => totalMatches > 0 ? matchesWon / totalMatches : 0.0;

  int get pointDifference => totalScored - totalConceded;

  String get period {
    final start = '${startDate.month}/${startDate.year}';
    final end = '${endDate.month}/${endDate.year}';
    return '$start - $end';
  }

  // Firestore Conversion
  factory Season.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Season(
      id: doc.id,
      teamId: data['teamId'] ?? '',
      name: data['name'] ?? '',
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      isActive: data['isActive'] ?? false,
      totalMatches: data['totalMatches'] ?? 0,
      matchesWon: data['matchesWon'] ?? 0,
      matchesLost: data['matchesLost'] ?? 0,
      matchesDrawn: data['matchesDrawn'] ?? 0,
      totalScored: data['totalScored'] ?? 0,
      totalConceded: data['totalConceded'] ?? 0,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'teamId': teamId,
      'name': name,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'isActive': isActive,
      'totalMatches': totalMatches,
      'matchesWon': matchesWon,
      'matchesLost': matchesLost,
      'matchesDrawn': matchesDrawn,
      'totalScored': totalScored,
      'totalConceded': totalConceded,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Season copyWith({
    String? name,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
    int? totalMatches,
    int? matchesWon,
    int? matchesLost,
    int? matchesDrawn,
    int? totalScored,
    int? totalConceded,
  }) {
    return Season(
      id: id,
      teamId: teamId,
      name: name ?? this.name,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
      totalMatches: totalMatches ?? this.totalMatches,
      matchesWon: matchesWon ?? this.matchesWon,
      matchesLost: matchesLost ?? this.matchesLost,
      matchesDrawn: matchesDrawn ?? this.matchesDrawn,
      totalScored: totalScored ?? this.totalScored,
      totalConceded: totalConceded ?? this.totalConceded,
      createdAt: createdAt,
    );
  }
}
