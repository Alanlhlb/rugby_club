import 'package:flutter/foundation.dart';
import '../models/event.dart';
import '../models/attendance.dart';
import '../services/event_service.dart';
import '../services/attendance_service.dart';

class EventProvider with ChangeNotifier {
  final EventService _eventService = EventService();
  final AttendanceService _attendanceService = AttendanceService();

  List<Event> _events = [];
  bool _isLoading = false;
  String? _error;
  String? _currentTeamId;
  String? _currentSeasonId;

  // Attendance: eventId -> { playerId -> status }
  final Map<String, Map<String, AttendanceStatus>> _attendance = {};

  List<Event> get events => _events;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<Event> get upcomingEvents {
    final now = DateTime.now();
    return _events.where((e) => e.date.isAfter(now)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  List<Event> get pastEvents {
    final now = DateTime.now();
    return _events.where((e) => e.date.isBefore(now)).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  List<Event> eventsForDay(DateTime day) {
    return _events
        .where(
          (e) =>
              e.date.year == day.year &&
              e.date.month == day.month &&
              e.date.day == day.day,
        )
        .toList();
  }

  List<Event> filteredEvents(EventType? filter) {
    if (filter == null) return _events;
    return _events.where((e) => e.type == filter).toList();
  }

  // --- Attendance ---
  Map<String, AttendanceStatus> getAttendance(String eventId) {
    return _attendance[eventId] ?? {};
  }

  void setAttendance(String eventId, String playerId, AttendanceStatus status) {
    _attendance.putIfAbsent(eventId, () => {});
    _attendance[eventId]![playerId] = status;
    notifyListeners();
    _attendanceService.setAttendance(eventId, playerId, status);
  }

  void setBulkAttendance(
    String eventId,
    List<String> playerIds,
    AttendanceStatus status,
  ) {
    _attendance.putIfAbsent(eventId, () => {});
    final map = <String, AttendanceStatus>{};
    for (final id in playerIds) {
      _attendance[eventId]![id] = status;
      map[id] = status;
    }
    notifyListeners();
    _attendanceService.batchSetAttendance(eventId, map);
  }

  Future<void> loadAttendance(String eventId) async {
    try {
      final records = await _attendanceService.getEventAttendance(eventId);
      final map = <String, AttendanceStatus>{};
      for (final r in records) {
        map[r.playerId] = r.status;
      }
      _attendance[eventId] = map;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // --- CRUD ---
  Future<void> addEvent(Event event) async {
    await _createEventFirestore(event);
  }

  Future<void> updateEvent(String eventId, Map<String, dynamic> data) async {
    try {
      _isLoading = true;
      notifyListeners();
      await _eventService.updateEvent(eventId, data);
      if (_currentTeamId != null) {
        await loadEvents(_currentTeamId!, seasonId: _currentSeasonId);
      }
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> removeEvent(String eventId) async {
    await deleteEventFirestore(eventId);
  }

  Future<void> _createEventFirestore(Event event) async {
    try {
      _isLoading = true;
      notifyListeners();
      await _eventService.createEvent(event);
      if (_currentTeamId != null) {
        await loadEvents(_currentTeamId!, seasonId: _currentSeasonId);
      }
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadEvents(String teamId, {String? seasonId}) async {
    try {
      _isLoading = true;
      _currentTeamId = teamId;
      if (seasonId != null) _currentSeasonId = seasonId;
      notifyListeners();

      final results = await Future.wait([
        _eventService.getUpcomingEvents(teamId, seasonId: seasonId),
        _eventService.getPastEvents(teamId, seasonId: seasonId),
      ]);

      final upcoming = results[0];
      final past = results[1];

      _events = [...upcoming, ...past];
      _events.sort((a, b) => a.date.compareTo(b.date));

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteEventFirestore(String eventId) async {
    try {
      await _eventService.deleteEvent(eventId);
      _events.removeWhere((e) => e.id == eventId);
      _attendance.remove(eventId);
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
}
