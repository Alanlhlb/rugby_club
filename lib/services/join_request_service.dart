import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/join_request.dart';

class JoinRequestService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  CollectionReference get _col => _firestore.collection('join_requests');

  // Create a join request
  Future<String> createRequest(JoinRequest request) async {
    final doc = await _col.add(request.toMap());
    return doc.id;
  }

  // Get pending requests for a team (for admin/coach approval)
  Future<List<JoinRequest>> getPendingRequests(String teamId) async {
    final snap = await _col
        .where('teamId', isEqualTo: teamId)
        .where('status', isEqualTo: JoinRequestStatus.pending.name)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((d) => JoinRequest.fromFirestore(d)).toList();
  }

  // Stream pending requests count for badge
  Stream<int> streamPendingCount(String teamId) {
    return _col
        .where('teamId', isEqualTo: teamId)
        .where('status', isEqualTo: JoinRequestStatus.pending.name)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  // Check if user already has a pending request for a team
  Future<bool> hasPendingRequest(String userId, String teamId) async {
    final snap = await _col
        .where('userId', isEqualTo: userId)
        .where('teamId', isEqualTo: teamId)
        .where('status', isEqualTo: JoinRequestStatus.pending.name)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  // Approve a request
  Future<void> approveRequest(String requestId, String responderId) async {
    await _col.doc(requestId).update({
      'status': JoinRequestStatus.approved.name,
      'respondedAt': FieldValue.serverTimestamp(),
      'respondedBy': responderId,
    });
  }

  // Reject a request
  Future<void> rejectRequest(String requestId, String responderId) async {
    await _col.doc(requestId).update({
      'status': JoinRequestStatus.rejected.name,
      'respondedAt': FieldValue.serverTimestamp(),
      'respondedBy': responderId,
    });
  }
}
