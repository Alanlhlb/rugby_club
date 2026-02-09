import 'package:cloud_firestore/cloud_firestore.dart';

enum AttendanceStatus {
  attending,
  notAttending,
  pending,
  late,
  injured;

  String get displayName {
    switch (this) {
      case AttendanceStatus.attending:
        return '出席';
      case AttendanceStatus.notAttending:
        return '缺席';
      case AttendanceStatus.pending:
        return '待定';
      case AttendanceStatus.late:
        return '遲到';
      case AttendanceStatus.injured:
        return '傷病';
    }
  }
}

class Attendance {
  final String id;
  final String eventId;
  final String playerId;
  final AttendanceStatus status;
  final String? reason;
  final DateTime timestamp;

  Attendance({
    required this.id,
    required this.eventId,
    required this.playerId,
    required this.status,
    this.reason,
    required this.timestamp,
  });

  // Firestore Conversion
  factory Attendance.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Attendance(
      id: doc.id,
      eventId: data['eventId'] ?? '',
      playerId: data['playerId'] ?? '',
      status: AttendanceStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => AttendanceStatus.pending,
      ),
      reason: data['reason'],
      timestamp: data['timestamp'] != null
          ? (data['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId,
      'playerId': playerId,
      'status': status.name,
      'reason': reason,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  Attendance copyWith({
    AttendanceStatus? status,
    String? reason,
    DateTime? timestamp,
  }) {
    return Attendance(
      id: id,
      eventId: eventId,
      playerId: playerId,
      status: status ?? this.status,
      reason: reason ?? this.reason,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
