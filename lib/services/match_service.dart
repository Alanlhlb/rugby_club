import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/match_state.dart';

class MatchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create Match
  Future<String> createMatch(MatchState match) async {
    final doc = await _firestore.collection('matches').add(match.toMap());
    return doc.id;
  }

  // Get Match
  Future<MatchState?> getMatch(String matchId) async {
    final doc = await _firestore.collection('matches').doc(matchId).get();
    if (!doc.exists) return null;
    return MatchState.fromFirestore(doc);
  }

  // Stream Match
  Stream<MatchState?> streamMatch(String matchId) {
    return _firestore
        .collection('matches')
        .doc(matchId)
        .snapshots()
        .map((doc) => doc.exists ? MatchState.fromFirestore(doc) : null);
  }

  // Update Match
  Future<void> updateMatch(String matchId, Map<String, dynamic> data) async {
    await _firestore.collection('matches').doc(matchId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Convert Preview to Official
  Future<void> convertToOfficial(String matchId) async {
    await _firestore.collection('matches').doc(matchId).update({
      'mode': MatchMode.official.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Get Event Matches
  Future<List<MatchState>> getEventMatches(String eventId) async {
    final snapshot = await _firestore
        .collection('matches')
        .where('eventId', isEqualTo: eventId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) => MatchState.fromFirestore(doc)).toList();
  }

  // Get Last Match for Event
  Future<MatchState?> getLastMatchForEvent(String eventId) async {
    final snapshot = await _firestore
        .collection('matches')
        .where('eventId', isEqualTo: eventId)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return MatchState.fromFirestore(snapshot.docs.first);
  }

  // Save Match Offline
  Future<void> saveMatchOffline(String matchId, MatchState match) async {
    final prefs = await SharedPreferences.getInstance();
    final matchData = json.encode(match.toOfflineMap());
    await prefs.setString('offline_match_$matchId', matchData);
  }

  // Load Match Offline
  Future<MatchState?> loadMatchOffline(String matchId) async {
    final prefs = await SharedPreferences.getInstance();
    final matchData = prefs.getString('offline_match_$matchId');
    if (matchData == null) return null;

    try {
      final data = json.decode(matchData) as Map<String, dynamic>;
      return MatchState.fromOfflineMap(data);
    } catch (e) {
      return null;
    }
  }

  // Sync Offline Matches
  Future<void> syncOfflineMatches() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('offline_match_'));

    for (var key in keys) {
      final matchId = key.replaceFirst('offline_match_', '');
      final matchData = prefs.getString(key);
      if (matchData != null) {
        try {
          final data = json.decode(matchData) as Map<String, dynamic>;
          await _firestore.collection('matches').doc(matchId).set(data);
          await prefs.remove(key);
        } catch (e) {
          // Log error but continue
        }
      }
    }
  }

  // Get Completed Matches for team
  Future<List<MatchState>> getCompletedMatches(String teamId) async {
    final snapshot = await _firestore
        .collection('matches')
        .where('teamId', isEqualTo: teamId)
        .where('isCompleted', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) => MatchState.fromFirestore(doc)).toList();
  }

  // Get all matches for a team (ordered by creation date)
  Future<List<MatchState>> getMatchesForTeam(String teamId) async {
    final snapshot = await _firestore
        .collection('matches')
        .where('teamId', isEqualTo: teamId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) => MatchState.fromFirestore(doc)).toList();
  }

  // Update match status
  Future<void> updateMatchStatus(String matchId, MatchStatus status) async {
    await _firestore.collection('matches').doc(matchId).update({
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Delete Match
  Future<void> deleteMatch(String matchId) async {
    await _firestore.collection('matches').doc(matchId).delete();

    // Also remove offline copy
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('offline_match_$matchId');
  }
}
