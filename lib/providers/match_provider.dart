import 'package:flutter/foundation.dart';
import '../models/match_state.dart';
import '../models/player.dart';
import '../services/match_service.dart';

class MatchProvider with ChangeNotifier {
  final MatchService _matchService = MatchService();

  MatchState? _currentMatch;
  List<Player> _availablePlayers = [];
  bool _isLoading = false;
  String? _error;

  MatchState? get currentMatch => _currentMatch;
  List<Player> get availablePlayers => _availablePlayers;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // On-field players
  List<Player> get onFieldPlayers {
    if (_currentMatch == null) return [];
    final playerIds = _currentMatch!.onFieldPlayerIds;
    return _availablePlayers.where((p) => playerIds.contains(p.id)).toList();
  }

  // Bench players (enrolled but not on field)
  List<Player> get benchPlayers {
    if (_currentMatch == null) return [];
    final onFieldIds = _currentMatch!.onFieldPlayerIds;
    return _availablePlayers.where((p) => !onFieldIds.contains(p.id)).toList();
  }

  // Initialize match
  Future<void> initializeMatch(
    String eventId,
    String teamId,
    List<Player> enrolledPlayers, {
    String? seasonId,
    MatchMode mode = MatchMode.preview,
  }) async {
    try {
      _isLoading = true;
      _availablePlayers = enrolledPlayers;
      notifyListeners();

      _currentMatch = MatchState(
        id: '',
        eventId: eventId,
        teamId: teamId,
        seasonId: seasonId,
        mode: mode,
        createdAt: DateTime.now(),
      );

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load existing match
  Future<void> loadMatch(String matchId, List<Player> allPlayers) async {
    try {
      _isLoading = true;
      _availablePlayers = allPlayers;
      notifyListeners();

      _currentMatch = await _matchService.getMatch(matchId);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Assign player to position
  void assignPlayerToPosition(int position, String? playerId) {
    if (_currentMatch == null) return;

    final newSlots = Map<int, String?>.from(_currentMatch!.positionSlots);
    newSlots[position] = playerId;

    _currentMatch = _currentMatch!.copyWith(
      positionSlots: newSlots,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
  }

  // Swap players
  void swapPlayers(int position1, int position2) {
    if (_currentMatch == null) return;

    final newSlots = Map<int, String?>.from(_currentMatch!.positionSlots);
    final temp = newSlots[position1];
    newSlots[position1] = newSlots[position2];
    newSlots[position2] = temp;

    _currentMatch = _currentMatch!.copyWith(
      positionSlots: newSlots,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
  }

  // Remove player from position
  void removePlayerFromPosition(int position) {
    assignPlayerToPosition(position, null);
  }

  // Start match
  void startMatch() {
    if (_currentMatch == null) return;

    _currentMatch = _currentMatch!.copyWith(
      startTime: DateTime.now(),
      isPaused: false,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
  }

  // Pause match
  void pauseMatch() {
    if (_currentMatch == null || _currentMatch!.isPaused) return;

    _currentMatch = _currentMatch!.copyWith(
      isPaused: true,
      pausedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    notifyListeners();
  }

  // Resume match
  void resumeMatch() {
    if (_currentMatch == null || !_currentMatch!.isPaused) return;

    _currentMatch = _currentMatch!.copyWith(
      isPaused: false,
      pausedAt: null,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
  }

  // End match
  void endMatch() {
    if (_currentMatch == null) return;

    _currentMatch = _currentMatch!.copyWith(
      endTime: DateTime.now(),
      isCompleted: true,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
  }

  // Update score
  void updateScore(int ourScore, int opponentScore) {
    if (_currentMatch == null) return;

    _currentMatch = _currentMatch!.copyWith(
      ourScore: ourScore,
      opponentScore: opponentScore,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
  }

  // Add match event
  void addMatchEvent(MatchEvent event) {
    if (_currentMatch == null) return;

    final newEvents = List<MatchEvent>.from(_currentMatch!.events)..add(event);

    _currentMatch = _currentMatch!.copyWith(
      events: newEvents,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
  }

  // Give yellow card
  void giveYellowCard(String playerId) {
    if (_currentMatch == null) return;

    final newTimers = Map<String, DateTime>.from(_currentMatch!.yellowCardTimers);
    newTimers[playerId] = DateTime.now();

    _currentMatch = _currentMatch!.copyWith(
      yellowCardTimers: newTimers,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
  }

  // Remove yellow card (after 10 minutes)
  void removeYellowCard(String playerId) {
    if (_currentMatch == null) return;

    final newTimers = Map<String, DateTime>.from(_currentMatch!.yellowCardTimers);
    newTimers.remove(playerId);

    _currentMatch = _currentMatch!.copyWith(
      yellowCardTimers: newTimers,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
  }

  // Suspend player (red card)
  void suspendPlayer(String playerId) {
    if (_currentMatch == null) return;

    final newSuspended = Map<String, bool>.from(_currentMatch!.suspendedPlayers);
    newSuspended[playerId] = true;

    _currentMatch = _currentMatch!.copyWith(
      suspendedPlayers: newSuspended,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
  }

  // Convert to official
  Future<void> convertToOfficial() async {
    if (_currentMatch == null || _currentMatch!.id.isEmpty) return;

    try {
      await _matchService.convertToOfficial(_currentMatch!.id);
      _currentMatch = _currentMatch!.copyWith(
        mode: MatchMode.official,
        updatedAt: DateTime.now(),
      );
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // Save match
  Future<String> saveMatch() async {
    if (_currentMatch == null) throw Exception('No match to save');

    try {
      _isLoading = true;
      notifyListeners();

      String matchId;
      if (_currentMatch!.id.isEmpty) {
        matchId = await _matchService.createMatch(_currentMatch!);
      } else {
        await _matchService.updateMatch(_currentMatch!.id, _currentMatch!.toMap());
        matchId = _currentMatch!.id;
      }

      _isLoading = false;
      notifyListeners();
      return matchId;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // Save match offline
  Future<void> saveMatchOffline() async {
    if (_currentMatch == null || _currentMatch!.id.isEmpty) return;

    try {
      await _matchService.saveMatchOffline(_currentMatch!.id, _currentMatch!);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // Load lineup
  void loadLineup(Map<int, String?> lineup) {
    if (_currentMatch == null) return;

    _currentMatch = _currentMatch!.copyWith(
      positionSlots: lineup,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
  }

  // Save current lineup
  void saveCurrentLineup() {
    if (_currentMatch == null) return;

    _currentMatch = _currentMatch!.copyWith(
      savedLineup: Map.from(_currentMatch!.positionSlots),
      updatedAt: DateTime.now(),
    );
    notifyListeners();
  }

  // Clear match
  void clearMatch() {
    _currentMatch = null;
    _availablePlayers = [];
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
