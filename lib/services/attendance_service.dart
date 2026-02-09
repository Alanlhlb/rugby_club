import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/attendance.dart';

class AttendanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Set Attendance
  Future<void> setAttendance(
    String eventId,
    String playerId,
    AttendanceStatus status, {
    String? reason,
  }) async {
    final attendanceId = '${eventId}_$playerId';

    await _firestore.collection('attendance').doc(attendanceId).set({
      'eventId': eventId,
      'playerId': playerId,
      'status': status.name,
      'reason': reason,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // Batch set attendance for multiple players
  Future<void> batchSetAttendance(
    String eventId,
    Map<String, AttendanceStatus> playerStatuses,
  ) async {
    final batch = _firestore.batch();
    for (final entry in playerStatuses.entries) {
      final docRef = _firestore
          .collection('attendance')
          .doc('${eventId}_${entry.key}');
      batch.set(docRef, {
        'eventId': eventId,
        'playerId': entry.key,
        'status': entry.value.name,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  // Get Attendance
  Future<Attendance?> getAttendance(String eventId, String playerId) async {
    final attendanceId = '${eventId}_$playerId';
    final doc = await _firestore
        .collection('attendance')
        .doc(attendanceId)
        .get();
    if (!doc.exists) return null;
    return Attendance.fromFirestore(doc);
  }

  // Stream Event Attendance
  Stream<List<Attendance>> streamEventAttendance(String eventId) {
    return _firestore
        .collection('attendance')
        .where('eventId', isEqualTo: eventId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Attendance.fromFirestore(doc))
              .toList(),
        );
  }

  // Get Event Attendance (one-time)
  Future<List<Attendance>> getEventAttendance(String eventId) async {
    final snapshot = await _firestore
        .collection('attendance')
        .where('eventId', isEqualTo: eventId)
        .get();

    return snapshot.docs.map((doc) => Attendance.fromFirestore(doc)).toList();
  }

  // Get Player Attendance History
  Future<List<Attendance>> getPlayerAttendance(String playerId) async {
    final snapshot = await _firestore
        .collection('attendance')
        .where('playerId', isEqualTo: playerId)
        .orderBy('timestamp', descending: true)
        .get();

    return snapshot.docs.map((doc) => Attendance.fromFirestore(doc)).toList();
  }

  // Get Attendance by Status
  Future<List<Attendance>> getAttendanceByStatus(
    String eventId,
    AttendanceStatus status,
  ) async {
    final snapshot = await _firestore
        .collection('attendance')
        .where('eventId', isEqualTo: eventId)
        .where('status', isEqualTo: status.name)
        .get();

    return snapshot.docs.map((doc) => Attendance.fromFirestore(doc)).toList();
  }

  // Get Attendance Count
  Future<Map<AttendanceStatus, int>> getAttendanceCount(String eventId) async {
    final attendance = await getEventAttendance(eventId);

    final counts = <AttendanceStatus, int>{
      AttendanceStatus.attending: 0,
      AttendanceStatus.notAttending: 0,
      AttendanceStatus.pending: 0,
      AttendanceStatus.late: 0,
      AttendanceStatus.injured: 0,
    };

    for (var a in attendance) {
      counts[a.status] = (counts[a.status] ?? 0) + 1;
    }

    return counts;
  }
}
