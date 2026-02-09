import 'package:flutter/foundation.dart';
import '../models/team.dart';
import '../models/season.dart';
import '../services/team_service.dart';
import '../services/season_service.dart';

class TeamProvider with ChangeNotifier {
  final TeamService _teamService = TeamService();
  final SeasonService _seasonService = SeasonService();

  Team? _currentTeam;
  Season? _currentSeason;
  List<Season> _seasons = [];
  bool _isLoading = false;
  String? _error;
  Team? get currentTeam => _currentTeam;
  Season? get currentSeason => _currentSeason;
  List<Season> get seasons => _seasons;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasTeam => _currentTeam != null;

  Future<void> loadTeam(String teamId) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Parallelize fetching team and seasons
      final results = await Future.wait([
        _teamService.getTeam(teamId),
        _seasonService.getTeamSeasons(teamId),
      ]);

      _currentTeam = results[0] as Team?;
      _seasons = results[1] as List<Season>;

      // Try to find current season in the list first
      if (_currentTeam?.currentSeasonId != null) {
        try {
          _currentSeason = _seasons.firstWhere(
            (s) => s.id == _currentTeam!.currentSeasonId,
          );
        } catch (_) {
          // Fallback if not found in list (rare)
          _currentSeason = await _seasonService.getSeason(
            _currentTeam!.currentSeasonId!,
          );
        }
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String> createTeamFromObject(Team team) async {
    try {
      _isLoading = true;
      notifyListeners();

      final teamId = await _teamService.createTeam(team);
      await loadTeam(teamId);

      _isLoading = false;
      notifyListeners();
      return teamId;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<String> createTeam(String name, String ownerId) async {
    final team = Team(
      id: '',
      name: name,
      primaryColor: '#1B5E20',
      secondaryColor: '#FF6F00',
      level: TeamLevel.amateur,
      createdAt: DateTime.now(),
    );
    return createTeamFromObject(team);
  }

  Future<void> updateTeam(Map<String, dynamic> data) async {
    if (_currentTeam == null) return;

    try {
      await _teamService.updateTeam(_currentTeam!.id, data);
      await loadTeam(_currentTeam!.id);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<String> createSeasonFromObject(Season season) async {
    if (_currentTeam == null) throw Exception('No team loaded');

    try {
      final seasonId = await _seasonService.createSeason(season);

      // Set as active season
      await _seasonService.setActiveSeason(_currentTeam!.id, seasonId);
      await _teamService.setCurrentSeason(
        _currentTeam!.id,
        seasonId,
        season.name,
      );

      await loadTeam(_currentTeam!.id);
      return seasonId;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<String> createSeason(
    String teamId,
    String name,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final season = Season(
      id: '',
      teamId: teamId,
      name: name,
      startDate: startDate,
      endDate: endDate,
      isActive: true,
      createdAt: DateTime.now(),
    );
    return createSeasonFromObject(season);
  }

  Future<void> setActiveSeason(String seasonId) async {
    if (_currentTeam == null) return;

    try {
      final season = _seasons.firstWhere((s) => s.id == seasonId);
      await _seasonService.setActiveSeason(_currentTeam!.id, seasonId);
      await _teamService.setCurrentSeason(
        _currentTeam!.id,
        seasonId,
        season.name,
      );
      await loadTeam(_currentTeam!.id);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
