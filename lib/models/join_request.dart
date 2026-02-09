import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_user.dart' show UserRole;

enum JoinRequestStatus {
  pending,
  approved,
  rejected;

  String get displayName {
    switch (this) {
      case JoinRequestStatus.pending:
        return '待審批';
      case JoinRequestStatus.approved:
        return '已批准';
      case JoinRequestStatus.rejected:
        return '已拒絕';
    }
  }
}

class JoinRequest {
  final String id;
  final String teamId;
  final String teamName;
  final String userId;
  final String userName;
  final String userEmail;
  final UserRole requestedRole;
  final JoinRequestStatus status;
  final DateTime createdAt;
  final DateTime? respondedAt;
  final String? respondedBy;

  JoinRequest({
    required this.id,
    required this.teamId,
    required this.teamName,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.requestedRole,
    this.status = JoinRequestStatus.pending,
    required this.createdAt,
    this.respondedAt,
    this.respondedBy,
  });

  factory JoinRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return JoinRequest(
      id: doc.id,
      teamId: data['teamId'] ?? '',
      teamName: data['teamName'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userEmail: data['userEmail'] ?? '',
      requestedRole: UserRole.values.firstWhere(
        (e) => e.name == data['requestedRole'],
        orElse: () => UserRole.player,
      ),
      status: JoinRequestStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => JoinRequestStatus.pending,
      ),
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      respondedAt: data['respondedAt'] != null
          ? (data['respondedAt'] as Timestamp).toDate()
          : null,
      respondedBy: data['respondedBy'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'teamId': teamId,
      'teamName': teamName,
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'requestedRole': requestedRole.name,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'respondedAt':
          respondedAt != null ? Timestamp.fromDate(respondedAt!) : null,
      'respondedBy': respondedBy,
    };
  }
}
