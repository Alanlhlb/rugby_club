import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/team.dart';

class TeamService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create Team
  Future<String> createTeam(Team team) async {
    final doc = await _firestore.collection('teams').add(team.toMap());
    return doc.id;
  }

  // Get Team
  Future<Team?> getTeam(String teamId) async {
    final doc = await _firestore.collection('teams').doc(teamId).get();
    if (!doc.exists) return null;
    return Team.fromFirestore(doc);
  }

  // Stream Team
  Stream<Team?> streamTeam(String teamId) {
    return _firestore
        .collection('teams')
        .doc(teamId)
        .snapshots()
        .map((doc) => doc.exists ? Team.fromFirestore(doc) : null);
  }

  // Update Team
  Future<void> updateTeam(String teamId, Map<String, dynamic> data) async {
    await _firestore.collection('teams').doc(teamId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // List all teams
  Future<List<Team>> listAllTeams() async {
    final snap = await _firestore.collection('teams').orderBy('name').get();
    return snap.docs.map((d) => Team.fromFirestore(d)).toList();
  }

  // Search teams by name prefix
  Future<List<Team>> searchTeams(String query) async {
    if (query.isEmpty) return listAllTeams();
    final end =
        query.substring(0, query.length - 1) +
        String.fromCharCode(query.codeUnitAt(query.length - 1) + 1);
    final snap = await _firestore
        .collection('teams')
        .where('name', isGreaterThanOrEqualTo: query)
        .where('name', isLessThan: end)
        .orderBy('name')
        .get();
    return snap.docs.map((d) => Team.fromFirestore(d)).toList();
  }

  // Set Current Season
  Future<void> setCurrentSeason(
    String teamId,
    String seasonId,
    String seasonName,
  ) async {
    await _firestore.collection('teams').doc(teamId).update({
      'currentSeasonId': seasonId,
      'currentSeasonName': seasonName,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
