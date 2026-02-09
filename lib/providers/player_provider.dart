import 'package:flutter/foundation.dart';
import '../models/player.dart';
import '../services/player_service.dart';

class PlayerProvider with ChangeNotifier {
  final PlayerService _playerService = PlayerService();

  List<Player> _players = [];
  bool _isLoading = false;
  String? _error;
  String? _currentTeamId;
  String? _currentSeasonId;

  List<Player> get players => _players;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Filtered Lists
  List<Player> get forwards => _players.where((p) {
    final positions = p.positions;
    return positions.any(
      (pos) =>
          pos.contains('Prop') ||
          pos.contains('Hooker') ||
          pos.contains('Lock') ||
          pos.contains('Flanker') ||
          pos.contains('Eight'),
    );
  }).toList();

  List<Player> get backs => _players.where((p) {
    final positions = p.positions;
    return positions.any(
      (pos) =>
          pos.contains('half') ||
          pos.contains('Wing') ||
          pos.contains('Centre') ||
          pos.contains('Full-back'),
    );
  }).toList();

  List<Player> get activePlayers =>
      _players.where((p) => p.status == 'active').toList();
  List<Player> get injuredPlayers =>
      _players.where((p) => p.isInjured).toList();
  List<Player> get suspendedPlayers =>
      _players.where((p) => p.isSuspended).toList();

  // Lineout Specialists
  List<Player> get lineoutJumpers =>
      _players.where((p) => p.isLineoutJumper).toList();
  List<Player> get lineoutLifters =>
      _players.where((p) => p.isLineoutLifter).toList();
  List<Player> get lineoutThrowers =>
      _players.where((p) => p.isLineoutThrower).toList();

  Future<void> loadPlayers(String teamId, {String? seasonId}) async {
    try {
      _isLoading = true;
      _currentTeamId = teamId;
      if (seasonId != null) _currentSeasonId = seasonId;
      notifyListeners();

      _players = await _playerService.getTeamPlayers(
        teamId,
        seasonId: _currentSeasonId,
      );

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Stream<List<Player>> streamPlayers(String teamId, {String? seasonId}) {
    _currentTeamId = teamId;
    if (seasonId != null) _currentSeasonId = seasonId;
    return _playerService.streamTeamPlayers(teamId, seasonId: _currentSeasonId);
  }

  Future<String> createPlayer(Player player) async {
    try {
      final playerId = await _playerService.createPlayer(player);
      // Use the player's teamId to ensure we always reload correctly
      final teamId = _currentTeamId ?? player.teamId;
      if (teamId.isNotEmpty) {
        _currentTeamId = teamId;
        await loadPlayers(
          teamId,
          seasonId: _currentSeasonId ?? player.seasonId,
        );
      }
      return playerId;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  void setSeasonId(String? seasonId) {
    _currentSeasonId = seasonId;
  }

  Future<void> updatePlayer(String playerId, Map<String, dynamic> data) async {
    try {
      await _playerService.updatePlayer(playerId, data);
      if (_currentTeamId != null) {
        await loadPlayers(_currentTeamId!, seasonId: _currentSeasonId);
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> deletePlayer(String playerId) async {
    try {
      await _playerService.deletePlayer(playerId);
      if (_currentTeamId != null) {
        await loadPlayers(_currentTeamId!, seasonId: _currentSeasonId);
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Player? getPlayerById(String playerId) {
    try {
      return _players.firstWhere((p) => p.id == playerId);
    } catch (e) {
      return null;
    }
  }

  List<Player> getPlayersByPosition(String position) {
    return _players.where((p) => p.positions.contains(position)).toList();
  }

  List<Player> searchPlayers(String query) {
    final lowerQuery = query.toLowerCase();
    return _players
        .where(
          (p) =>
              p.name.toLowerCase().contains(lowerQuery) ||
              p.jerseyNumber.toString().contains(query) ||
              p.positions.any((pos) => pos.toLowerCase().contains(lowerQuery)),
        )
        .toList();
  }

  bool isJerseyNumberTaken(int jerseyNumber, {String? excludePlayerId}) {
    if (jerseyNumber == 0) return false;
    return _players.any(
      (p) => p.jerseyNumber == jerseyNumber && p.id != excludePlayerId,
    );
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
