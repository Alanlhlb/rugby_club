import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/season.dart';

class SeasonService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create Season
  Future<String> createSeason(Season season) async {
    final doc = await _firestore.collection('seasons').add(season.toMap());
    return doc.id;
  }

  // Get Season
  Future<Season?> getSeason(String seasonId) async {
    final doc = await _firestore.collection('seasons').doc(seasonId).get();
    if (!doc.exists) return null;
    return Season.fromFirestore(doc);
  }

  // Stream Team Seasons
  Stream<List<Season>> streamTeamSeasons(String teamId) {
    return _firestore
        .collection('seasons')
        .where('teamId', isEqualTo: teamId)
        .orderBy('startDate', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Season.fromFirestore(doc)).toList(),
        );
  }

  // Get Team Seasons (one-time)
  Future<List<Season>> getTeamSeasons(String teamId) async {
    final snapshot = await _firestore
        .collection('seasons')
        .where('teamId', isEqualTo: teamId)
        .orderBy('startDate', descending: true)
        .get();

    return snapshot.docs.map((doc) => Season.fromFirestore(doc)).toList();
  }

  // Get Active Season
  Future<Season?> getActiveSeason(String teamId) async {
    final snapshot = await _firestore
        .collection('seasons')
        .where('teamId', isEqualTo: teamId)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return Season.fromFirestore(snapshot.docs.first);
  }

  // Update Season
  Future<void> updateSeason(String seasonId, Map<String, dynamic> data) async {
    await _firestore.collection('seasons').doc(seasonId).update(data);
  }

  // Set Active Season
  Future<void> setActiveSeason(String teamId, String seasonId) async {
    final batch = _firestore.batch();

    // Deactivate all seasons
    final seasons = await getTeamSeasons(teamId);
    for (var season in seasons) {
      batch.update(_firestore.collection('seasons').doc(season.id), {
        'isActive': false,
      });
    }

    // Activate selected season
    batch.update(_firestore.collection('seasons').doc(seasonId), {
      'isActive': true,
    });

    await batch.commit();
  }

  // Update Season Stats
  Future<void> updateSeasonStats(
    String seasonId, {
    int? scored,
    int? conceded,
    bool? won,
    bool? lost,
    bool? drawn,
  }) async {
    final updates = <String, dynamic>{};

    if (scored != null) {
      updates['totalScored'] = FieldValue.increment(scored);
    }
    if (conceded != null) {
      updates['totalConceded'] = FieldValue.increment(conceded);
    }
    if (won == true) {
      updates['matchesWon'] = FieldValue.increment(1);
      updates['totalMatches'] = FieldValue.increment(1);
    }
    if (lost == true) {
      updates['matchesLost'] = FieldValue.increment(1);
      updates['totalMatches'] = FieldValue.increment(1);
    }
    if (drawn == true) {
      updates['matchesDrawn'] = FieldValue.increment(1);
      updates['totalMatches'] = FieldValue.increment(1);
    }

    if (updates.isNotEmpty) {
      await _firestore.collection('seasons').doc(seasonId).update(updates);
    }
  }
}
