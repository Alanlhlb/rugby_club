import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/join_request.dart';
import '../models/app_user.dart' show UserRole;
import '../models/player.dart';
import '../models/team.dart';
import '../services/join_request_service.dart';
import '../services/team_service.dart';

class JoinRequestProvider with ChangeNotifier {
  final JoinRequestService _service = JoinRequestService();
  final TeamService _teamService = TeamService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<JoinRequest> _pendingRequests = [];
  List<Team> _searchResults = [];
  int _pendingCount = 0;
  bool _isLoading = false;
  String? _error;
  StreamSubscription? _countSub;

  List<JoinRequest> get pendingRequests => _pendingRequests;
  List<Team> get searchResults => _searchResults;
  int get pendingCount => _pendingCount;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Start listening to pending count for badge
  void listenPendingCount(String teamId) {
    _countSub?.cancel();
    _countSub = _service.streamPendingCount(teamId).listen((c) {
      _pendingCount = c;
      notifyListeners();
    });
  }

  // Search teams
  Future<void> searchTeams(String query) async {
    try {
      _isLoading = true;
      notifyListeners();
      _searchResults = await _teamService.searchTeams(query);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load all teams
  Future<void> loadAllTeams() async {
    try {
      _isLoading = true;
      notifyListeners();
      _searchResults = await _teamService.listAllTeams();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Send join request
  Future<bool> sendJoinRequest({
    required String teamId,
    required String teamName,
    required String userId,
    required String userName,
    required String userEmail,
    required UserRole requestedRole,
  }) async {
    try {
      // Check if user already belongs to a team
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data();
      if (userData != null && userData['teamId'] != null) {
        _error = '您已經屬於一個球隊，請先退出目前球隊再申請';
        notifyListeners();
        return false;
      }

      // Check for existing pending request
      final hasPending = await _service.hasPendingRequest(userId, teamId);
      if (hasPending) {
        _error = '您已向此球隊發送過申請，請等待審批';
        notifyListeners();
        return false;
      }

      await _service.createRequest(
        JoinRequest(
          id: '',
          teamId: teamId,
          teamName: teamName,
          userId: userId,
          userName: userName,
          userEmail: userEmail,
          requestedRole: requestedRole,
          createdAt: DateTime.now(),
        ),
      );
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Load pending requests for a team
  Future<void> loadPendingRequests(String teamId) async {
    try {
      _isLoading = true;
      notifyListeners();
      _pendingRequests = await _service.getPendingRequests(teamId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Approve request: update status, set user teamId + role, create Player if needed
  Future<void> approveRequest(JoinRequest request, String responderId) async {
    try {
      _isLoading = true;
      notifyListeners();

      // 1. Approve the request
      await _service.approveRequest(request.id, responderId);

      // 2. Update user's teamId and role
      await _firestore.collection('users').doc(request.userId).update({
        'teamId': request.teamId,
        'role': request.requestedRole.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 3. If player, auto-create Player record
      if (request.requestedRole == UserRole.player) {
        final playerDoc = await _firestore
            .collection('players')
            .add(
              Player(
                id: '',
                name: request.userName,
                jerseyNumber: 0,
                positions: const [],
                teamId: request.teamId,
                createdAt: DateTime.now(),
              ).toMap(),
            );
        // Link playerId to user
        await _firestore.collection('users').doc(request.userId).update({
          'playerId': playerDoc.id,
        });
      }

      // 4. Refresh list
      _pendingRequests.removeWhere((r) => r.id == request.id);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Reject request
  Future<void> rejectRequest(JoinRequest request, String responderId) async {
    try {
      await _service.rejectRequest(request.id, responderId);
      _pendingRequests.removeWhere((r) => r.id == request.id);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _countSub?.cancel();
    super.dispose();
  }
}
