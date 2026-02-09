import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/map_launcher_service.dart';
import '../../core/constants/app_colors.dart';
import '../../models/app_user.dart' show UserRole;
import '../../models/event.dart';
import '../../models/player.dart';
import '../../models/attendance.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/event_provider.dart';
import '../../services/weather_service.dart';
import '../../services/match_service.dart';
import '../../services/event_service.dart';
import '../match/match_engine_screen.dart';
import 'add_event_screen.dart';

class EventDetailScreen extends StatefulWidget {
  final Event event;
  const EventDetailScreen({super.key, required this.event});
  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  String _sortBy = 'name';
  bool _sortAsc = true;
  DayForecast? _weather;
  bool _loadingWeather = true;

  Map<String, AttendanceStatus> get _att =>
      context.watch<EventProvider>().getAttendance(widget.event.id);

  @override
  void initState() {
    super.initState();
    _loadWeather();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EventProvider>().loadAttendance(widget.event.id);
    });
  }

  Future<void> _loadWeather() async {
    final f = await WeatherService().getForecastForDate(widget.event.date);
    if (mounted) {
      setState(() {
        _weather = f;
        _loadingWeather = false;
      });
    }
  }

  Color _evColor(EventType t) {
    switch (t) {
      case EventType.training:
        return AppColors.info;
      case EventType.match:
        return AppColors.primary;
      case EventType.teamBuilding:
        return const Color(0xFFA855F7);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pp = context.watch<PlayerProvider>();
    final auth = context.watch<AuthProvider>();
    final isPlayer = auth.currentUser?.role == UserRole.player;
    final players = _sorted(pp.players);
    final going = _att.values
        .where((v) => v == AttendanceStatus.attending)
        .length;
    final absent = _att.values
        .where((v) => v == AttendanceStatus.notAttending)
        .length;
    final pend = players.length - going - absent;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.event.displayTitle),
        actions: [
          if (!isPlayer) ...[
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: () async {
                final nav = Navigator.of(context);
                final result = await nav.push(
                  MaterialPageRoute(
                    builder: (_) => AddEventScreen(
                      teamId: widget.event.teamId,
                      seasonId: widget.event.seasonId,
                      editEvent: widget.event,
                    ),
                  ),
                );
                if (result == true && mounted) {
                  nav.pop();
                }
              },
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.adaptive.more),
              onSelected: (a) async {
                if (a == 'delete') {
                  _deleteConfirm();
                } else if (a == 'duplicate') {
                  final ep = context.read<EventProvider>();
                  final scaffold = ScaffoldMessenger.of(context);
                  final teamId = widget.event.teamId;
                  final seasonId = widget.event.seasonId;
                  try {
                    await EventService().duplicateEvent(widget.event.id);
                    ep.loadEvents(teamId, seasonId: seasonId);
                    scaffold.showSnackBar(
                      const SnackBar(content: Text('活動已複製（日期延後一週）')),
                    );
                  } catch (e) {
                    scaffold.showSnackBar(SnackBar(content: Text('複製失敗: $e')));
                  }
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'duplicate', child: Text('複製活動')),
                PopupMenuItem(value: 'delete', child: Text('刪除活動')),
              ],
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // ─── Info card ───
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _evColor(widget.event.type).withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.event.type.displayName,
                    style: TextStyle(
                      color: _evColor(widget.event.type),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _infoRow(
                  Icons.calendar_today,
                  DateFormat(
                    'yyyy年M月d日 (E)',
                    'zh_TW',
                  ).format(widget.event.date),
                ),
                const SizedBox(height: 6),
                _infoRow(
                  Icons.access_time,
                  DateFormat.Hm().format(widget.event.date),
                ),
                _weatherWidget(),
                if (widget.event.location != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 16,
                        color: AppColors.textHint,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.event.location!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _openMaps(widget.event.location!),
                        child: const Icon(
                          Icons.directions,
                          size: 20,
                          color: AppColors.info,
                        ),
                      ),
                    ],
                  ),
                ],
                if (widget.event.notes != null &&
                    widget.event.notes!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    widget.event.notes!,
                    style: const TextStyle(
                      color: AppColors.textHint,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ─── Summary row ───
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _statBadge('出席', going, AppColors.success),
                const SizedBox(width: 8),
                _statBadge('缺席', absent, AppColors.error),
                const SizedBox(width: 8),
                _statBadge('待定', pend, AppColors.warning),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // ─── Quick attendance buttons (coach/admin only) ───
          if (!isPlayer)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        context.read<EventProvider>().setBulkAttendance(
                          widget.event.id,
                          players.map((p) => p.id).toList(),
                          AttendanceStatus.attending,
                        );
                      },
                      icon: const Icon(Icons.check_circle, size: 16),
                      label: const Text('全部出席'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.success,
                        side: BorderSide(
                          color: AppColors.success.withAlpha(80),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        context.read<EventProvider>().setBulkAttendance(
                          widget.event.id,
                          players.map((p) => p.id).toList(),
                          AttendanceStatus.pending,
                        );
                      },
                      icon: const Icon(Icons.restart_alt, size: 16),
                      label: const Text('全部待定'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.warning,
                        side: BorderSide(
                          color: AppColors.warning.withAlpha(80),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (!isPlayer) const SizedBox(height: 8),

          // ─── Player self-attendance (player role only) ───
          if (isPlayer) ...[
            Builder(
              builder: (_) {
                final myPlayerId = auth.currentUser?.playerId;
                final myPlayer = myPlayerId != null
                    ? pp.getPlayerById(myPlayerId)
                    : (players.isNotEmpty ? players.first : null);
                if (myPlayer == null) return const SizedBox.shrink();
                return _selfAttendanceCard(myPlayer);
              },
            ),
            const Divider(height: 1),
          ],

          // ─── Attendance sections ───
          Expanded(
            child: ListView(
              children: [
                _attSection(
                  '出席',
                  AttendanceStatus.attending,
                  AppColors.success,
                  Icons.check_circle,
                  players,
                  readOnly: isPlayer,
                ),
                _attSection(
                  '待定',
                  AttendanceStatus.pending,
                  AppColors.warning,
                  Icons.help,
                  players,
                  readOnly: isPlayer,
                ),
                _attSection(
                  '缺席',
                  AttendanceStatus.notAttending,
                  AppColors.error,
                  Icons.cancel,
                  players,
                  readOnly: isPlayer,
                ),
                _attSection(
                  '傷病',
                  AttendanceStatus.injured,
                  const Color(0xFFA855F7),
                  Icons.healing,
                  players,
                  readOnly: isPlayer,
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: widget.event.type == EventType.match && !isPlayer
          ? FloatingActionButton.extended(
              onPressed: _openMatchCenter,
              icon: const Icon(Icons.sports_rugby),
              label: const Text('比賽陣容'),
              backgroundColor: AppColors.primary,
            )
          : null,
    );
  }

  Future<void> _openMatchCenter() async {
    // Check if there's an existing match state for this event
    final ms = MatchService();
    final match = await ms.getLastMatchForEvent(widget.event.id);

    if (!mounted) return;

    // Load players if needed (ensure provider has data)
    final pp = context.read<PlayerProvider>();
    if (pp.players.isEmpty) {
      await pp.loadPlayers(widget.event.teamId);
    }

    Map<int, Player?>? initialLineup;
    if (match != null && match.savedLineup != null) {
      initialLineup = {};
      match.savedLineup!.forEach((k, v) {
        if (v != null) {
          final p = pp.getPlayerById(v);
          initialLineup![k] = p;
        }
      });
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MatchEngineScreen(
          isPreviewMode: match == null || match.isPreview,
          opponent: widget.event.opponent,
          initialLineup: initialLineup,
          eventId: widget.event.id, // We will add this parameter
        ),
      ),
    );
  }

  Widget _infoRow(IconData ic, String text) => Row(
    children: [
      Icon(ic, size: 16, color: AppColors.textHint),
      const SizedBox(width: 8),
      Text(
        text,
        style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
      ),
    ],
  );

  Widget _statBadge(String label, int count, Color c) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: c.withAlpha(18),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: c,
            ),
          ),
          Text(label, style: TextStyle(color: c, fontSize: 11)),
        ],
      ),
    ),
  );

  // ─── Self attendance card (player role) ───
  Widget _selfAttendanceCard(Player me) {
    final myStatus = _att[me.id] ?? AttendanceStatus.pending;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '我的出席狀態',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primaryMuted,
                child: Text(
                  '${me.jerseyNumber}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  me.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _selfBtn(
                '出席',
                Icons.check_circle,
                AppColors.success,
                myStatus == AttendanceStatus.attending,
                () => _setAtt(me.id, AttendanceStatus.attending),
              ),
              const SizedBox(width: 8),
              _selfBtn(
                '待定',
                Icons.help,
                AppColors.warning,
                myStatus == AttendanceStatus.pending,
                () => _setAtt(me.id, AttendanceStatus.pending),
              ),
              const SizedBox(width: 8),
              _selfBtn(
                '缺席',
                Icons.cancel,
                AppColors.error,
                myStatus == AttendanceStatus.notAttending,
                () => _setAtt(me.id, AttendanceStatus.notAttending),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _selfBtn(
    String label,
    IconData icon,
    Color c,
    bool active,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? c.withAlpha(30) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: active ? c : AppColors.divider),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: active ? c : AppColors.textHint),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: active ? c : AppColors.textHint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _attSection(
    String title,
    AttendanceStatus status,
    Color c,
    IconData icon,
    List<Player> all, {
    bool readOnly = false,
  }) {
    final list = all
        .where((p) => (_att[p.id] ?? AttendanceStatus.pending) == status)
        .toList();
    return ExpansionTile(
      initiallyExpanded:
          status == AttendanceStatus.attending ||
          status == AttendanceStatus.pending,
      leading: Icon(icon, color: c, size: 20),
      title: Row(
        children: [
          Text(
            '$title (${list.length})',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: c,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() => _sortAsc = !_sortAsc),
            child: Icon(
              _sortAsc ? Icons.arrow_upward : Icons.arrow_downward,
              size: 16,
              color: AppColors.textHint,
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.sort, size: 16, color: AppColors.textHint),
            onSelected: (v) => setState(() => _sortBy = v),
            itemBuilder: (_) => [
              CheckedPopupMenuItem(
                value: 'name',
                checked: _sortBy == 'name',
                child: const Text('按名字'),
              ),
              CheckedPopupMenuItem(
                value: 'number',
                checked: _sortBy == 'number',
                child: const Text('按號碼'),
              ),
            ],
          ),
        ],
      ),
      children: list.isEmpty
          ? [
              const Padding(
                padding: EdgeInsets.all(14),
                child: Text('無球員', style: TextStyle(color: AppColors.textHint)),
              ),
            ]
          : list
                .map((p) => _playerTile(p, status, c, readOnly: readOnly))
                .toList(),
    );
  }

  Widget _playerTile(
    Player p,
    AttendanceStatus status,
    Color c, {
    bool readOnly = false,
  }) {
    if (readOnly) {
      // Read-only: no swipe, no attendance buttons
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: c.withAlpha(30),
              child: Text(
                '${p.jerseyNumber}',
                style: TextStyle(
                  color: c,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        p.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (p.isCaptain)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Text(
                            'C',
                            style: TextStyle(
                              color: AppColors.secondary,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (p.positions.isNotEmpty)
                    Text(
                      p.positions.first.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textHint,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Dismissible(
      key: Key('p_${p.id}_$status'),
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        color: AppColors.success,
        child: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 6),
            Text(
              '出席',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.error,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              '缺席',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(width: 6),
            Icon(Icons.cancel, color: Colors.white),
          ],
        ),
      ),
      confirmDismiss: (d) async {
        _setAtt(
          p.id,
          d == DismissDirection.startToEnd
              ? AttendanceStatus.attending
              : AttendanceStatus.notAttending,
        );
        return false;
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: c.withAlpha(30),
              child: Text(
                '${p.jerseyNumber}',
                style: TextStyle(
                  color: c,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        p.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (p.isCaptain)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Text(
                            'C',
                            style: TextStyle(
                              color: AppColors.secondary,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (p.positions.isNotEmpty)
                    Text(
                      p.positions.first.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textHint,
                      ),
                    ),
                ],
              ),
            ),
            _attBtn(
              Icons.check_circle,
              status == AttendanceStatus.attending
                  ? AppColors.success
                  : AppColors.textHint.withAlpha(60),
              () => _setAtt(p.id, AttendanceStatus.attending),
            ),
            _attBtn(
              Icons.help,
              status == AttendanceStatus.pending
                  ? AppColors.warning
                  : AppColors.textHint.withAlpha(60),
              () => _setAtt(p.id, AttendanceStatus.pending),
            ),
            _attBtn(
              Icons.cancel,
              status == AttendanceStatus.notAttending
                  ? AppColors.error
                  : AppColors.textHint.withAlpha(60),
              () => _setAtt(p.id, AttendanceStatus.notAttending),
            ),
          ],
        ),
      ),
    );
  }

  Widget _attBtn(IconData ic, Color c, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Icon(ic, size: 18, color: c),
    ),
  );

  void _setAtt(String id, AttendanceStatus s) {
    context.read<EventProvider>().setAttendance(widget.event.id, id, s);
  }

  List<Player> _sorted(List<Player> list) {
    final s = List<Player>.from(list);
    s.sort(
      (a, b) => _sortBy == 'number'
          ? a.jerseyNumber.compareTo(b.jerseyNumber)
          : a.name.compareTo(b.name),
    );
    return _sortAsc ? s : s.reversed.toList();
  }

  Widget _weatherWidget() {
    final days = widget.event.date.difference(DateTime.now()).inDays;
    if (days > 9) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: _loadingWeather
          ? Row(
              children: [
                const Icon(Icons.cloud, size: 16, color: AppColors.textHint),
                const SizedBox(width: 6),
                const Text(
                  '載入天氣…',
                  style: TextStyle(color: AppColors.textHint, fontSize: 12),
                ),
              ],
            )
          : _weather != null
          ? Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Text(
                    _weather!.weatherEmoji,
                    style: const TextStyle(fontSize: 22),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _weather!.forecastWeather,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${_weather!.temperatureRange} · 濕度 ${_weather!.humidityRange}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_weather!.hasRainRisk)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.info,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '降雨 ${_weather!.psr}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            )
          : Row(
              children: const [
                Icon(Icons.cloud_off, size: 16, color: AppColors.textHint),
                SizedBox(width: 6),
                Text(
                  '無法取得天氣預報',
                  style: TextStyle(color: AppColors.textHint, fontSize: 12),
                ),
              ],
            ),
    );
  }

  Future<void> _openMaps(String loc) async {
    final success = await MapLauncherService.openMap(
      latitude: widget.event.latitude,
      longitude: widget.event.longitude,
      query: loc,
    );
    if (!success && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('無法開啟地圖')));
    }
  }

  void _deleteConfirm() {
    showAdaptiveDialog(
      context: context,
      builder: (ctx) => AlertDialog.adaptive(
        title: const Text('刪除活動'),
        content: const Text('確定要刪除此活動嗎？此操作無法撤銷。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context, 'deleted');
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
  }
}
