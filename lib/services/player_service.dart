import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/player.dart';

class PlayerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create Player
  Future<String> createPlayer(Player player) async {
    final doc = await _firestore.collection('players').add(player.toMap());
    return doc.id;
  }

  // Get Player
  Future<Player?> getPlayer(String playerId) async {
    final doc = await _firestore.collection('players').doc(playerId).get();
    if (!doc.exists) return null;
    return Player.fromFirestore(doc);
  }

  // Stream Team Players
  Stream<List<Player>> streamTeamPlayers(String teamId, {String? seasonId}) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('players')
        .where('teamId', isEqualTo: teamId);
    if (seasonId != null) {
      query = query.where('seasonId', isEqualTo: seasonId);
    }
    return query
        .orderBy('jerseyNumber')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Player.fromFirestore(doc)).toList(),
        );
  }

  // Get Team Players (one-time)
  Future<List<Player>> getTeamPlayers(String teamId, {String? seasonId}) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection('players')
        .where('teamId', isEqualTo: teamId);
    if (seasonId != null) {
      query = query.where('seasonId', isEqualTo: seasonId);
    }
    final snapshot = await query.orderBy('jerseyNumber').get();
    return snapshot.docs.map((doc) => Player.fromFirestore(doc)).toList();
  }

  // Update Player
  Future<void> updatePlayer(String playerId, Map<String, dynamic> data) async {
    await _firestore.collection('players').doc(playerId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Delete Player
  Future<void> deletePlayer(String playerId) async {
    await _firestore.collection('players').doc(playerId).delete();
  }

  // Update Player Stats
  Future<void> updatePlayerStats(
    String playerId, {
    int? tries,
    int? conversions,
    int? penalties,
    int? dropGoals,
    int? yellowCards,
    int? redCards,
  }) async {
    final updates = <String, dynamic>{};

    if (tries != null) {
      updates['tries'] = FieldValue.increment(tries);
    }
    if (conversions != null) {
      updates['conversions'] = FieldValue.increment(conversions);
    }
    if (penalties != null) {
      updates['penalties'] = FieldValue.increment(penalties);
    }
    if (dropGoals != null) {
      updates['dropGoals'] = FieldValue.increment(dropGoals);
    }
    if (yellowCards != null) {
      updates['yellowCards'] = FieldValue.increment(yellowCards);
    }
    if (redCards != null) {
      updates['redCards'] = FieldValue.increment(redCards);
    }

    if (updates.isNotEmpty) {
      updates['updatedAt'] = FieldValue.serverTimestamp();
      await _firestore.collection('players').doc(playerId).update(updates);
    }
  }

  // Update Attendance Stats
  Future<void> updateAttendanceStats(
    String playerId, {
    required bool attended,
  }) async {
    await _firestore.collection('players').doc(playerId).update({
      'eventsTotal': FieldValue.increment(1),
      if (attended) 'eventsAttended': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Get Players by Position
  Future<List<Player>> getPlayersByPosition(
    String teamId,
    String position,
  ) async {
    final snapshot = await _firestore
        .collection('players')
        .where('teamId', isEqualTo: teamId)
        .where('positions', arrayContains: position)
        .get();

    return snapshot.docs.map((doc) => Player.fromFirestore(doc)).toList();
  }
}
