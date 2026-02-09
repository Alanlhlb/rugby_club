import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/event_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/team_provider.dart';
import '../../providers/player_provider.dart';
import '../../models/app_user.dart' show UserRole;
import '../../models/event.dart';
import '../../services/weather_service.dart';
import '../../widgets/player_stats_card.dart';
import '../players/players_screen.dart';
import '../events/events_screen.dart';
import '../events/add_event_screen.dart';
import '../events/event_detail_screen.dart';
import '../matches/matches_screen.dart';
import '../settings/settings_screen.dart';
import '../match/match_engine_screen.dart';
import '../statistics/statistics_screen.dart';
import '../match/match_history_screen.dart';
import '../onboarding/onboarding_screen.dart';
import '../players/player_edit_screen.dart';

// ═══════════════════════════════════════════════════
//  HOME SHELL  (bottom nav + pages)
// ═══════════════════════════════════════════════════
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _redirecting = false;

  List<Widget> _pages(bool isPlayer) {
    if (isPlayer) {
      return const [
        DashboardTab(),
        PlayersScreen(),
        EventsScreen(),
        MatchesScreen(),
        _MyProfileTab(),
        SettingsScreen(),
      ];
    }
    return const [
      DashboardTab(),
      PlayersScreen(),
      EventsScreen(),
      MatchesScreen(),
      SettingsScreen(),
    ];
  }

  List<NavigationDestination> _destinations(bool isPlayer) {
    if (isPlayer) {
      return const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: '總覽',
        ),
        NavigationDestination(
          icon: Icon(Icons.people_outlined),
          selectedIcon: Icon(Icons.people),
          label: '隊友',
        ),
        NavigationDestination(
          icon: Icon(Icons.event_outlined),
          selectedIcon: Icon(Icons.event),
          label: '活動',
        ),
        NavigationDestination(
          icon: Icon(Icons.sports_rugby_outlined),
          selectedIcon: Icon(Icons.sports_rugby),
          label: '比賽',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outlined),
          selectedIcon: Icon(Icons.person),
          label: '我的',
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: '設定',
        ),
      ];
    }
    return const [
      NavigationDestination(
        icon: Icon(Icons.dashboard_outlined),
        selectedIcon: Icon(Icons.dashboard),
        label: '總覽',
      ),
      NavigationDestination(
        icon: Icon(Icons.people_outlined),
        selectedIcon: Icon(Icons.people),
        label: '球員',
      ),
      NavigationDestination(
        icon: Icon(Icons.event_outlined),
        selectedIcon: Icon(Icons.event),
        label: '活動',
      ),
      NavigationDestination(
        icon: Icon(Icons.sports_rugby_outlined),
        selectedIcon: Icon(Icons.sports_rugby),
        label: '比賽',
      ),
      NavigationDestination(
        icon: Icon(Icons.settings_outlined),
        selectedIcon: Icon(Icons.settings),
        label: '設定',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final tp = context.watch<TeamProvider>();

    // Safety: redirect to onboarding if user has no team
    if (tp.currentTeam == null && !tp.isLoading && !_redirecting) {
      _redirecting = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const OnboardingScreen()),
          );
        }
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator.adaptive()),
      );
    }

    final isPlayer = auth.currentUser?.role == UserRole.player;
    final pages = _pages(isPlayer);
    // Clamp index if role changed and tabs reduced
    if (_currentIndex >= pages.length) {
      _currentIndex = 0;
    }
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        height: 64,
        destinations: _destinations(isPlayer),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
//  DASHBOARD TAB
// ═══════════════════════════════════════════════════
class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});
  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  DayForecast? _todayWeather;
  bool _isLoadingWeather = true;

  @override
  void initState() {
    super.initState();
    _loadWeather();
  }

  Future<void> _loadWeather() async {
    final weatherService = WeatherService();
    final forecast = await weatherService.getForecastForDate(DateTime.now());
    if (mounted) {
      setState(() {
        _todayWeather = forecast;
        _isLoadingWeather = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final team = context.watch<TeamProvider>();
    final players = context.watch<PlayerProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(team.currentTeam?.name ?? 'Rugby Club'),
        actions: [
          if (team.currentSeason != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Chip(
                label: Text(
                  team.currentSeason!.name,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.primary,
                  ),
                ),
                backgroundColor: AppColors.primaryMuted,
                side: BorderSide.none,
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            ),
        ],
      ),
      body: RefreshIndicator.adaptive(
        color: AppColors.primary,
        onRefresh: () async {
          if (team.currentTeam != null) {
            final teamId = team.currentTeam!.id;
            final seasonId = team.currentSeason?.id;
            await Future.wait([
              team.loadTeam(teamId),
              players.loadPlayers(teamId, seasonId: seasonId),
              context.read<EventProvider>().loadEvents(
                teamId,
                seasonId: seasonId,
              ),
            ]);
            _loadWeather();
          }
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _weatherCard(),
            const SizedBox(height: 16),
            _statRow(team, players),
            const SizedBox(height: 24),
            _section('快速操作'),
            const SizedBox(height: 10),
            _quickActions(context),
            const SizedBox(height: 24),
            _section('即將活動'),
            const SizedBox(height: 10),
            ...context
                .watch<EventProvider>()
                .upcomingEvents
                .take(3)
                .map((e) => _eventTile(context, e)),
            const SizedBox(height: 24),
            _section('本季統計'),
            const SizedBox(height: 10),
            _seasonStats(players),
          ],
        ),
      ),
    );
  }

  // ─── section header ───
  Widget _section(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }

  // ─── stat row ───
  Widget _statRow(TeamProvider team, PlayerProvider players) {
    return Row(
      children: [
        _stat(Icons.people, '球員', '${players.players.length}', AppColors.info),
        const SizedBox(width: 10),
        _stat(
          Icons.sports_rugby,
          '比賽',
          '${team.currentTeam?.totalMatches ?? 0}',
          AppColors.primary,
        ),
        const SizedBox(width: 10),
        _stat(
          Icons.emoji_events,
          '勝場',
          '${team.currentTeam?.matchesWon ?? 0}',
          AppColors.secondary,
        ),
      ],
    );
  }

  Widget _stat(IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppColors.textHint),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label, VoidCallback onTap) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: AppColors.textSecondary),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: onTap,
    );
  }

  // ─── event tile ───
  Widget _eventTile(BuildContext context, Event event) {
    final color = _eventColor(event.type);
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
            MaterialPageRoute(builder: (_) => EventDetailScreen(event: event)),
          );
          if (!context.mounted) return;
          if (result == 'deleted') {
            context.read<EventProvider>().removeEvent(event.id);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_eventIcon(event.type), color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.displayTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${DateFormat('MM/dd (E)').format(event.date)} ${DateFormat.Hm().format(event.date)}',
                      style: const TextStyle(
                        color: AppColors.textHint,
                        fontSize: 12,
                      ),
                    ),
                    if (event.location != null)
                      Text(
                        event.location!,
                        style: const TextStyle(
                          color: AppColors.textHint,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _daysUntil(event.date),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _eventColor(EventType t) {
    switch (t) {
      case EventType.training:
        return AppColors.info;
      case EventType.match:
        return AppColors.primary;
      case EventType.teamBuilding:
        return const Color(0xFFA855F7);
    }
  }

  IconData _eventIcon(EventType t) {
    switch (t) {
      case EventType.training:
        return Icons.fitness_center;
      case EventType.match:
        return Icons.sports_rugby;
      case EventType.teamBuilding:
        return Icons.groups;
    }
  }

  String _daysUntil(DateTime d) {
    final diff = d.difference(DateTime.now()).inDays;
    if (diff == 0) return '今天';
    if (diff == 1) return '明天';
    return '$diff天後';
  }

  // ─── weather ───
  Widget _weatherCard() {
    if (_isLoadingWeather) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator.adaptive(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(AppColors.textHint),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              '載入天氣中…',
              style: TextStyle(color: AppColors.textHint, fontSize: 13),
            ),
          ],
        ),
      );
    }
    if (_todayWeather == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.info.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                _todayWeather!.weatherEmoji,
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '今日天氣',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    fontSize: 13,
                  ),
                ),
                Text(
                  _todayWeather!.temperatureRange,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _todayWeather!.forecastWeather.length > 10
                    ? '${_todayWeather!.forecastWeather.substring(0, 10)}…'
                    : _todayWeather!.forecastWeather,
                style: const TextStyle(color: AppColors.textHint, fontSize: 11),
              ),
              if (_todayWeather!.hasRainRisk)
                Text(
                  '降雨 ${_todayWeather!.psr}',
                  style: const TextStyle(color: AppColors.info, fontSize: 10),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── quick actions (role-aware) ───
  Widget _quickActions(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final isPlayer = auth.currentUser?.role == UserRole.player;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (!isPlayer)
          _chip(Icons.person_add, '新增球員', () {
            final s = context.findAncestorStateOfType<_HomeScreenState>();
            s?.setState(() => s._currentIndex = 1);
          }),
        if (!isPlayer)
          _chip(Icons.event_note, '新增活動', () async {
            final tp = context.read<TeamProvider>();
            await Navigator.push<Event>(
              context,
              MaterialPageRoute(
                builder: (_) => AddEventScreen(
                  teamId: tp.currentTeam?.id ?? '',
                  seasonId: tp.currentSeason?.id,
                ),
              ),
            );
            // Event is already saved to Firestore by AddEventScreen
          }),
        if (!isPlayer)
          _chip(
            Icons.sports,
            '開始比賽',
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const MatchEngineScreen(isPreviewMode: true),
              ),
            ),
          ),
        _chip(Icons.groups, isPlayer ? '隊友名單' : '球員管理', () {
          final s = context.findAncestorStateOfType<_HomeScreenState>();
          s?.setState(() => s._currentIndex = 1);
        }),
        _chip(
          Icons.bar_chart,
          '統計數據',
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const StatisticsScreen()),
          ),
        ),
        _chip(
          Icons.history,
          '比賽記錄',
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MatchHistoryScreen()),
          ),
        ),
      ],
    );
  }

  // ─── season stats ───
  Widget _seasonStats(PlayerProvider pp) {
    // Build real top scorers from player data
    final topScorers =
        pp.players
            .where((p) => p.totalPoints > 0)
            .map(
              (p) => PlayerStats(
                playerId: p.id,
                playerName: p.name,
                jerseyNumber: p.jerseyNumber,
                totalPoints: p.totalPoints,
              ),
            )
            .toList()
          ..sort((a, b) => b.totalPoints.compareTo(a.totalPoints));

    // Build real iron men from player data
    final ironMen =
        pp.players
            .where((p) => p.eventsAttended > 0)
            .map(
              (p) => PlayerStats(
                playerId: p.id,
                playerName: p.name,
                jerseyNumber: p.jerseyNumber,
                appearances: p.eventsAttended,
              ),
            )
            .toList()
          ..sort((a, b) => b.appearances.compareTo(a.appearances));

    if (topScorers.isEmpty && ironMen.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: const Center(
          child: Text('尚無統計數據', style: TextStyle(color: AppColors.textHint)),
        ),
      );
    }

    return Column(
      children: [
        if (topScorers.isNotEmpty)
          TopScorerCard(topScorers: topScorers.take(3).toList()),
        if (ironMen.isNotEmpty) ...[
          const SizedBox(height: 10),
          IronManCard(ironMen: ironMen.take(3).toList()),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════
//  MY PROFILE TAB  (player role only)
// ═══════════════════════════════════════════════════
class _MyProfileTab extends StatelessWidget {
  const _MyProfileTab();

  @override
  Widget build(BuildContext context) {
    final players = context.watch<PlayerProvider>();
    final auth = context.watch<AuthProvider>();
    final myPlayerId = auth.currentUser?.playerId;

    final myPlayer = myPlayerId != null
        ? players.getPlayerById(myPlayerId)
        : (players.players.isNotEmpty ? players.players.first : null);

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的資料'),
        actions: [
          if (myPlayer != null)
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              tooltip: '編輯資料',
              onPressed: () async {
                final updated = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PlayerEditScreen(player: myPlayer),
                  ),
                );
                if (updated == true && context.mounted) {
                  final tp = context.read<TeamProvider>();
                  final pp = context.read<PlayerProvider>();
                  if (tp.currentTeam != null) {
                    pp.loadPlayers(
                      tp.currentTeam!.id,
                      seasonId: tp.currentSeason?.id,
                    );
                  }
                }
              },
            ),
        ],
      ),
      body: myPlayer == null
          ? const Center(
              child: Text(
                '尚未綁定球員資料',
                style: TextStyle(color: AppColors.textHint),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ─── Avatar + Name ───
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: AppColors.primaryMuted,
                        backgroundImage:
                            myPlayer.photoUrl != null &&
                                myPlayer.photoUrl!.isNotEmpty
                            ? NetworkImage(myPlayer.photoUrl!) as ImageProvider
                            : null,
                        child:
                            myPlayer.photoUrl == null ||
                                myPlayer.photoUrl!.isEmpty
                            ? Text(
                                '${myPlayer.jerseyNumber}',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        myPlayer.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        myPlayer.positions.join(' / '),
                        style: const TextStyle(
                          color: AppColors.textHint,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ─── Badges ───
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: [
                    if (myPlayer.isCaptain)
                      _badge('隊長', Icons.star, const Color(0xFFFFD700)),
                    if (myPlayer.isViceCaptain)
                      _badge('副隊長', Icons.star_half, const Color(0xFFB0BEC5)),
                    if (myPlayer.isKicker)
                      _badge(
                        'Kicker',
                        Icons.sports_rugby,
                        const Color(0xFFFF6F00),
                      ),
                    if (myPlayer.isLineoutThrower)
                      _badge(
                        'Thrower',
                        Icons.sports_handball,
                        const Color(0xFF00BCD4),
                      ),
                    if (myPlayer.isLineoutJumper)
                      _badge('Jumper', Icons.height, const Color(0xFF4CAF50)),
                    if (myPlayer.isLineoutLifter)
                      _badge(
                        'Lifter',
                        Icons.fitness_center,
                        const Color(0xFFA855F7),
                      ),
                  ],
                ),
                const SizedBox(height: 24),

                // ─── Stats ───
                _sectionHeader('本季數據'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    children: [
                      _statRow('達陣', '${myPlayer.tries}'),
                      _statRow('轉換', '${myPlayer.conversions}'),
                      _statRow('罰球', '${myPlayer.penalties}'),
                      _statRow('落踢', '${myPlayer.dropGoals}'),
                      const Divider(height: 16),
                      _statRow('黃牌', '${myPlayer.yellowCards}'),
                      _statRow('紅牌', '${myPlayer.redCards}'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ─── Status ───
                _sectionHeader('狀態'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    children: [
                      _statRow('傷病', myPlayer.isInjured ? '是' : '否'),
                      if (myPlayer.injuryNotes != null &&
                          myPlayer.injuryNotes!.isNotEmpty)
                        _statRow('傷病備註', myPlayer.injuryNotes!),
                      _statRow('停賽', myPlayer.isSuspended ? '是' : '否'),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _badge(String label, IconData icon, Color color) {
    return Chip(
      avatar: Icon(icon, size: 14, color: color),
      label: Text(label, style: TextStyle(fontSize: 11, color: color)),
      backgroundColor: color.withAlpha(20),
      side: BorderSide(color: color.withAlpha(60)),
      padding: const EdgeInsets.symmetric(horizontal: 2),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.primary,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.textHint, fontSize: 13),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
