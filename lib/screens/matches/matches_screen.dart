import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/app_user.dart';
import '../../models/event.dart';
import '../../models/attendance.dart';
import '../../models/match_state.dart';
import '../../models/player.dart';
import '../../providers/auth_provider.dart';
import '../../providers/event_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/team_provider.dart';
import '../../services/match_service.dart';
import '../match/match_engine_screen.dart';
import '../events/event_detail_screen.dart';

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  final MatchService _matchService = MatchService();

  // eventId -> MatchState (latest match for each event)
  Map<String, MatchState?> _matchStates = {};
  // All matches loaded from Firestore (for standalone matches without events)
  List<MatchState> _allMatches = [];
  bool _loadingMatches = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMatchStates());
  }

  Future<void> _loadMatchStates() async {
    final tp = context.read<TeamProvider>();
    final teamId = tp.currentTeam?.id;
    if (teamId == null) return;

    setState(() => _loadingMatches = true);

    try {
      final matches = await _matchService.getMatchesForTeam(teamId);
      final map = <String, MatchState?>{};
      for (final m in matches) {
        if (m.eventId.isNotEmpty && !map.containsKey(m.eventId)) {
          map[m.eventId] = m;
        }
      }
      if (mounted) {
        setState(() {
          _matchStates = map;
          _allMatches = matches;
          _loadingMatches = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to load match states: $e');
      if (mounted) setState(() => _loadingMatches = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final ep = context.watch<EventProvider>();
    final isCoach =
        auth.currentUser?.role == UserRole.admin ||
        auth.currentUser?.role == UserRole.coach;

    final now = DateTime.now();
    final matchEvents = ep.events
        .where((e) => e.type == EventType.match)
        .toList();
    final upcoming = matchEvents.where((e) => e.date.isAfter(now)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final past = matchEvents.where((e) => e.date.isBefore(now)).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('比賽'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              onPressed: _loadMatchStates,
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: '即將到來'),
              Tab(text: '歷史記錄'),
            ],
          ),
        ),
        body: _loadingMatches
            ? const Center(child: CircularProgressIndicator.adaptive())
            : TabBarView(
                children: [
                  upcoming.isEmpty
                      ? _empty(
                          '沒有即將到來的比賽',
                          '請在「活動」頁面創建比賽活動',
                          Icons.sports_rugby_outlined,
                        )
                      : RefreshIndicator.adaptive(
                          onRefresh: _loadMatchStates,
                          child: _matchList(
                            context,
                            upcoming,
                            isUpcoming: true,
                            isCoach: isCoach,
                          ),
                        ),
                  past.isEmpty && _standaloneMatches.isEmpty
                      ? _empty('沒有比賽記錄', null, Icons.history)
                      : RefreshIndicator.adaptive(
                          onRefresh: _loadMatchStates,
                          child: _historyList(context, past, isCoach: isCoach),
                        ),
                ],
              ),
      ),
    );
  }

  // ─── Standalone matches (completed matches without a corresponding Event) ───
  List<MatchState> get _standaloneMatches {
    final ep = context.read<EventProvider>();
    final eventIds = ep.events.map((e) => e.id).toSet();
    return _allMatches
        .where((m) => m.eventId.isEmpty || !eventIds.contains(m.eventId))
        .where((m) => m.isCompleted)
        .toList();
  }

  // ─── History list (events + standalone matches) ───
  Widget _historyList(
    BuildContext context,
    List<Event> pastEvents, {
    required bool isCoach,
  }) {
    final standalone = _standaloneMatches;
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        // Event-based matches
        for (final event in pastEvents)
          _matchCard(
            context,
            event,
            _matchStates[event.id],
            isUpcoming: false,
            isCoach: isCoach,
          ),
        // Standalone matches (no event)
        if (standalone.isNotEmpty) ...[
          if (pastEvents.isNotEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Divider(),
            ),
          for (final match in standalone)
            _standaloneMatchCard(context, match, isCoach: isCoach),
        ],
      ],
    );
  }

  // ─── Standalone match card (no Event) ───
  Widget _standaloneMatchCard(
    BuildContext context,
    MatchState matchState, {
    required bool isCoach,
  }) {
    final date = matchState.createdAt;
    final dateStr =
        '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
    final timeStr =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.textHint.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.sports_rugby,
                    color: AppColors.textHint,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        matchState.mode == MatchMode.preview ? '練習賽' : '正式比賽',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$dateStr $timeStr',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
                ),
                _statusBadge(MatchStatus.completed, AppColors.textHint),
              ],
            ),
            const SizedBox(height: 10),
            _scoreRow(matchState),
          ],
        ),
      ),
    );
  }

  // ─── Match list ───
  Widget _matchList(
    BuildContext context,
    List<Event> events, {
    required bool isUpcoming,
    required bool isCoach,
  }) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        final matchState = _matchStates[event.id];
        return _matchCard(
          context,
          event,
          matchState,
          isUpcoming: isUpcoming,
          isCoach: isCoach,
        );
      },
    );
  }

  // ─── Single match card ───
  Widget _matchCard(
    BuildContext context,
    Event event,
    MatchState? matchState, {
    required bool isUpcoming,
    required bool isCoach,
  }) {
    final date = event.date;
    final dateStr =
        '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
    final timeStr =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    final status = _resolveStatus(event, matchState);
    final statusColor = _statusColor(status);

    // Attendance counts
    final att = context.watch<EventProvider>().getAttendance(event.id);
    final going = att.values
        .where((v) => v == AttendanceStatus.attending)
        .length;
    final absent = att.values
        .where((v) => v == AttendanceStatus.notAttending)
        .length;
    final pending =
        context.watch<PlayerProvider>().players.length - going - absent;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _onCardTap(context, event, matchState, isCoach),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Row 1: Title + Status badge ──
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.sports_rugby,
                      color: statusColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.opponent != null && event.opponent!.isNotEmpty
                              ? 'vs ${event.opponent}'
                              : '比賽',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$dateStr $timeStr',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _statusBadge(status, statusColor),
                ],
              ),

              // ── Row 2: Location + match type ──
              if (event.location != null && event.location!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      size: 14,
                      color: AppColors.textHint,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        event.location!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textHint,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (event.isFriendly)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withAlpha(15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '友誼賽',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.secondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ],

              const SizedBox(height: 10),

              // ── Row 3: Score (if completed) OR Attendance summary ──
              if (status == MatchStatus.completed && matchState != null) ...[
                _scoreRow(matchState),
              ] else ...[
                _attendanceRow(going, absent, pending),
              ],

              // ── Row 4: Action buttons ──
              const SizedBox(height: 10),
              _actionRow(context, event, matchState, status, isCoach),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Resolve effective status ───
  MatchStatus _resolveStatus(Event event, MatchState? matchState) {
    if (matchState != null) {
      return matchState.status;
    }
    // No match record yet → lineup pending (waiting for attendance)
    return MatchStatus.lineupPending;
  }

  Color _statusColor(MatchStatus status) {
    switch (status) {
      case MatchStatus.lineupPending:
        return AppColors.warning;
      case MatchStatus.previewReady:
        return AppColors.info;
      case MatchStatus.officialReady:
        return AppColors.primary;
      case MatchStatus.inProgress:
        return Colors.orange;
      case MatchStatus.completed:
        return AppColors.textHint;
    }
  }

  Widget _statusBadge(MatchStatus status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  // ─── Score row for completed matches ───
  Widget _scoreRow(MatchState matchState) {
    final our = matchState.ourScore;
    final opp = matchState.opponentScore;
    final isWin = our > opp;
    final isDraw = our == opp;
    final resultText = isWin ? '勝' : (isDraw ? '平' : '負');
    final resultColor = isWin
        ? AppColors.success
        : (isDraw ? AppColors.warning : AppColors.error);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: resultColor.withAlpha(12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$our',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: resultColor,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '-',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w300,
                color: AppColors.textHint,
              ),
            ),
          ),
          Text(
            '$opp',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: resultColor.withAlpha(25),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              resultText,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: resultColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Attendance summary row ───
  Widget _attendanceRow(int going, int absent, int pending) {
    return Row(
      children: [
        _attChip('出席', going, AppColors.success),
        const SizedBox(width: 8),
        _attChip('缺席', absent, AppColors.error),
        const SizedBox(width: 8),
        _attChip('待定', pending, AppColors.warning),
      ],
    );
  }

  Widget _attChip(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: color.withAlpha(12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(label, style: TextStyle(color: color, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  // ─── Action buttons row ───
  Widget _actionRow(
    BuildContext context,
    Event event,
    MatchState? matchState,
    MatchStatus status,
    bool isCoach,
  ) {
    switch (status) {
      case MatchStatus.lineupPending:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _goToEventDetail(context, event),
                icon: const Icon(Icons.how_to_reg, size: 16),
                label: const Text('報名 / 出席'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: () =>
                    _openMatchEngine(context, event, matchState, preview: true),
                icon: Icon(
                  isCoach ? Icons.edit_note : Icons.visibility,
                  size: 16,
                ),
                label: Text(isCoach ? 'Preview 陣容' : '查看陣容'),
              ),
            ),
          ],
        );

      case MatchStatus.previewReady:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () =>
                    _openMatchEngine(context, event, matchState, preview: true),
                icon: const Icon(Icons.visibility, size: 16),
                label: const Text('查看名單'),
              ),
            ),
            if (isCoach) ...[
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _openMatchEngine(
                    context,
                    event,
                    matchState,
                    preview: false,
                  ),
                  icon: const Icon(Icons.check_circle, size: 16),
                  label: const Text('確認正式'),
                ),
              ),
            ],
          ],
        );

      case MatchStatus.officialReady:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () =>
                    _openMatchEngine(context, event, matchState, preview: true),
                icon: const Icon(Icons.list_alt, size: 16),
                label: const Text('查看正式名單'),
              ),
            ),
            if (isCoach) ...[
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _openMatchEngine(
                    context,
                    event,
                    matchState,
                    preview: false,
                  ),
                  icon: const Icon(Icons.play_arrow, size: 16),
                  label: const Text('開始比賽'),
                ),
              ),
            ],
          ],
        );

      case MatchStatus.inProgress:
        if (isCoach) {
          return SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () =>
                  _openMatchEngine(context, event, matchState, preview: false),
              icon: const Icon(Icons.sports_rugby, size: 16),
              label: const Text('進入比賽'),
              style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            ),
          );
        }
        // Players can view in-progress match (read-only)
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () =>
                _openMatchEngine(context, event, matchState, preview: true),
            icon: const Icon(Icons.visibility, size: 16),
            label: const Text('查看比賽'),
          ),
        );

      case MatchStatus.completed:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () =>
                    _openMatchEngine(context, event, matchState, preview: true),
                icon: const Icon(Icons.bar_chart, size: 16),
                label: const Text('查看詳情'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _goToEventDetail(context, event),
                icon: const Icon(Icons.event, size: 16),
                label: const Text('活動詳情'),
              ),
            ),
          ],
        );
    }
  }

  // ─── Navigation helpers ───
  void _goToEventDetail(BuildContext context, Event event) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EventDetailScreen(event: event)),
    );
  }

  Future<void> _openMatchEngine(
    BuildContext context,
    Event event,
    MatchState? matchState, {
    required bool preview,
  }) async {
    final pp = context.read<PlayerProvider>();
    final nav = Navigator.of(context);

    if (pp.players.isEmpty) {
      await pp.loadPlayers(event.teamId);
    }

    Map<int, Player?>? initialLineup;
    if (matchState != null && matchState.savedLineup != null) {
      initialLineup = {};
      matchState.savedLineup!.forEach((k, v) {
        if (v != null) {
          final p = pp.getPlayerById(v);
          initialLineup![k] = p;
        }
      });
    } else if (matchState != null && matchState.positionSlots.isNotEmpty) {
      initialLineup = {};
      matchState.positionSlots.forEach((k, v) {
        if (v != null) {
          final p = pp.getPlayerById(v);
          initialLineup![k] = p;
        }
      });
    }

    if (!mounted) return;
    await nav.push(
      MaterialPageRoute(
        builder: (_) => MatchEngineScreen(
          isPreviewMode: preview,
          opponent: event.opponent,
          initialLineup: initialLineup,
          eventId: event.id,
        ),
      ),
    );

    // Reload match states after returning
    _loadMatchStates();
  }

  // ─── Card tap handler ───
  void _onCardTap(
    BuildContext context,
    Event event,
    MatchState? matchState,
    bool isCoach,
  ) {
    if (matchState?.status == MatchStatus.completed) {
      _openMatchEngine(context, event, matchState, preview: true);
    } else {
      _goToEventDetail(context, event);
    }
  }

  // ─── Empty state ───
  Widget _empty(String title, String? sub, IconData icon) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: AppColors.textHint),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
            ),
          ),
          if (sub != null) ...[
            const SizedBox(height: 4),
            Text(
              sub,
              style: const TextStyle(color: AppColors.textHint, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
