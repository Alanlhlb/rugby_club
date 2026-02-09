import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/event.dart';

class EventService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create Event
  Future<String> createEvent(Event event) async {
    final doc = await _firestore.collection('events').add(event.toMap());
    return doc.id;
  }

  // Get Event
  Future<Event?> getEvent(String eventId) async {
    final doc = await _firestore.collection('events').doc(eventId).get();
    if (!doc.exists) return null;
    return Event.fromFirestore(doc);
  }

  // Stream Team Events
  Stream<List<Event>> streamTeamEvents(String teamId, {String? seasonId}) {
    Query query = _firestore
        .collection('events')
        .where('teamId', isEqualTo: teamId)
        .orderBy('date', descending: true);

    if (seasonId != null) {
      query = query.where('seasonId', isEqualTo: seasonId);
    }

    return query.snapshots().map(
      (snapshot) =>
          snapshot.docs.map((doc) => Event.fromFirestore(doc)).toList(),
    );
  }

  // Get Upcoming Events
  Future<List<Event>> getUpcomingEvents(
    String teamId, {
    String? seasonId,
  }) async {
    Query query = _firestore
        .collection('events')
        .where('teamId', isEqualTo: teamId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.now())
        .orderBy('date');

    if (seasonId != null) {
      query = query.where('seasonId', isEqualTo: seasonId);
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => Event.fromFirestore(doc)).toList();
  }

  // Get Past Events
  Future<List<Event>> getPastEvents(String teamId, {String? seasonId}) async {
    Query query = _firestore
        .collection('events')
        .where('teamId', isEqualTo: teamId)
        .where('date', isLessThan: Timestamp.now())
        .orderBy('date', descending: true);

    if (seasonId != null) {
      query = query.where('seasonId', isEqualTo: seasonId);
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => Event.fromFirestore(doc)).toList();
  }

  // Update Event
  Future<void> updateEvent(String eventId, Map<String, dynamic> data) async {
    await _firestore.collection('events').doc(eventId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Delete Event
  Future<void> deleteEvent(String eventId) async {
    // Delete related attendance records
    final attendanceSnapshot = await _firestore
        .collection('attendance')
        .where('eventId', isEqualTo: eventId)
        .get();

    final batch = _firestore.batch();
    for (var doc in attendanceSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // Delete event
    batch.delete(_firestore.collection('events').doc(eventId));

    await batch.commit();
  }

  // Duplicate Event
  Future<String> duplicateEvent(String eventId) async {
    final event = await getEvent(eventId);
    if (event == null) throw Exception('Event not found');

    final newEvent = Event(
      id: '',
      teamId: event.teamId,
      seasonId: event.seasonId,
      date: event.date.add(const Duration(days: 7)),
      type: event.type,
      opponent: event.opponent,
      location: event.location,
      latitude: event.latitude,
      longitude: event.longitude,
      isFriendly: event.isFriendly,
      votingDeadline: event.votingDeadline?.add(const Duration(days: 7)),
      notes: event.notes,
      createdAt: DateTime.now(),
    );

    return await createEvent(newEvent);
  }
}
