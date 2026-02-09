import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/app_user.dart' show UserRole;
import '../../models/event.dart';
import '../../providers/auth_provider.dart';
import '../../providers/event_provider.dart';
import '../../providers/team_provider.dart';
import 'add_event_screen.dart';
import 'event_detail_screen.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});
  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  bool _showCal = true;
  CalendarFormat _calFmt = CalendarFormat.month;
  DateTime _focused = DateTime.now();
  DateTime? _selected = DateTime.now();
  EventType? _filter;

  List<Event> _getFiltered(BuildContext context) {
    final all = context.watch<EventProvider>().events;
    return _filter == null ? all : all.where((e) => e.type == _filter).toList();
  }

  List<Event> _forDay(DateTime d, List<Event> filtered) =>
      filtered.where((e) => isSameDay(e.date, d)).toList();

  Color _color(EventType t) {
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
    final filtered = _getFiltered(context);
    final dayEvents = _selected != null
        ? _forDay(_selected!, filtered)
        : <Event>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('活動'),
        actions: [
          IconButton(
            icon: Icon(_showCal ? Icons.list : Icons.calendar_month, size: 20),
            onPressed: () => setState(() => _showCal = !_showCal),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SegmentedButton<EventType?>(
              segments: const [
                ButtonSegment(value: null, label: Text('全部')),
                ButtonSegment(value: EventType.match, label: Text('比賽')),
                ButtonSegment(value: EventType.training, label: Text('訓練')),
                ButtonSegment(value: EventType.teamBuilding, label: Text('其他')),
              ],
              selected: {_filter},
              onSelectionChanged: (s) => setState(() => _filter = s.first),
            ),
          ),
          Expanded(
            child: _showCal
                ? _calView(dayEvents, filtered)
                : _listView(filtered),
          ),
        ],
      ),
      floatingActionButton:
          context.watch<AuthProvider>().currentUser?.role == UserRole.player
          ? null
          : FloatingActionButton.extended(
              heroTag: 'fab_events',
              onPressed: () => _addSheet(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('新增活動'),
            ),
    );
  }

  // ─── Calendar view ───
  Widget _calView(List<Event> dayEvents, List<Event> filtered) {
    return Column(
      children: [
        TableCalendar<Event>(
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focused,
          calendarFormat: _calFmt,
          selectedDayPredicate: (d) => isSameDay(_selected, d),
          eventLoader: (d) => _forDay(d, filtered),
          startingDayOfWeek: StartingDayOfWeek.monday,
          calendarStyle: CalendarStyle(
            markersMaxCount: 3,
            markerDecoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            selectedDecoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            todayDecoration: BoxDecoration(
              color: AppColors.primary.withAlpha(60),
              shape: BoxShape.circle,
            ),
            defaultTextStyle: const TextStyle(color: AppColors.textPrimary),
            weekendTextStyle: const TextStyle(color: AppColors.textSecondary),
            outsideTextStyle: const TextStyle(color: AppColors.textHint),
          ),
          daysOfWeekStyle: const DaysOfWeekStyle(
            weekdayStyle: TextStyle(color: AppColors.textHint, fontSize: 12),
            weekendStyle: TextStyle(color: AppColors.textHint, fontSize: 12),
          ),
          headerStyle: const HeaderStyle(
            formatButtonVisible: true,
            titleCentered: true,
            titleTextStyle: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            formatButtonTextStyle: TextStyle(
              color: AppColors.primary,
              fontSize: 12,
            ),
            formatButtonDecoration: BoxDecoration(
              border: Border.fromBorderSide(
                BorderSide(color: AppColors.divider),
              ),
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
            leftChevronIcon: Icon(
              Icons.chevron_left,
              color: AppColors.textSecondary,
              size: 20,
            ),
            rightChevronIcon: Icon(
              Icons.chevron_right,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ),
          onDaySelected: (sel, foc) => setState(() {
            _selected = sel;
            _focused = foc;
          }),
          onFormatChanged: (f) => setState(() => _calFmt = f),
          onPageChanged: (f) => _focused = f,
          calendarBuilders: CalendarBuilders(
            markerBuilder: (_, date, events) {
              if (events.isEmpty) return null;
              return Positioned(
                bottom: 1,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: events
                      .take(3)
                      .map(
                        (e) => Container(
                          width: 5,
                          height: 5,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            color: _color(e.type),
                            shape: BoxShape.circle,
                          ),
                        ),
                      )
                      .toList(),
                ),
              );
            },
          ),
        ),
        const Divider(),
        Expanded(
          child: dayEvents.isEmpty
              ? Center(
                  child: Text(
                    _selected == null ? '選擇日期查看活動' : '當日無活動',
                    style: const TextStyle(color: AppColors.textHint),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: dayEvents.length,
                  itemBuilder: (_, i) => _tile(dayEvents[i]),
                ),
        ),
      ],
    );
  }

  // ─── List view ───
  Widget _listView(List<Event> list) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.event_note, size: 64, color: AppColors.textHint),
            const SizedBox(height: 16),
            const Text(
              '尚無活動',
              style: TextStyle(
                color: AppColors.textHint,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            if (context.watch<AuthProvider>().currentUser?.role !=
                UserRole.player)
              OutlinedButton.icon(
                onPressed: () => _addSheet(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('立即新增'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary.withAlpha(100)),
                ),
              ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (_, i) => _tile(list[i]),
    );
  }

  // ─── Event tile ───
  Widget _tile(Event e) {
    final c = _color(e.type);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => EventDetailScreen(event: e)),
          );
          if (result == 'deleted' && mounted) {
            context.read<EventProvider>().removeEvent(e.id);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: c.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${e.date.day}',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: c,
                      ),
                    ),
                    Text(
                      DateFormat('MMM').format(e.date),
                      style: TextStyle(fontSize: 10, color: c),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.displayTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${DateFormat.Hm().format(e.date)} · ${e.location ?? "地點待定"}',
                      style: const TextStyle(
                        color: AppColors.textHint,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: AppColors.textHint,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Add sheet ───
  void _addSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.sports_rugby,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                title: const Text('比賽'),
                subtitle: const Text('安排一場比賽', style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _navAdd(EventType.match);
                },
              ),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.info.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.fitness_center,
                    color: AppColors.info,
                    size: 20,
                  ),
                ),
                title: const Text('訓練'),
                subtitle: const Text('安排團隊訓練', style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _navAdd(EventType.training);
                },
              ),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFA855F7).withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.groups,
                    color: Color(0xFFA855F7),
                    size: 20,
                  ),
                ),
                title: const Text('其他活動'),
                subtitle: const Text('聚會、會議等', style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _navAdd(EventType.teamBuilding);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _navAdd(EventType type) async {
    final tp = context.read<TeamProvider>();
    final teamId = tp.currentTeam?.id ?? '';
    final seasonId = tp.currentSeason?.id;

    await Navigator.push<Event>(
      context,
      MaterialPageRoute(
        builder: (_) => AddEventScreen(
          initialType: type,
          teamId: teamId,
          seasonId: seasonId,
          initialDate: _selected,
        ),
      ),
    );
    // Event is already saved to Firestore by AddEventScreen
  }
}
