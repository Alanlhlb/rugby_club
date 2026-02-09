import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/player.dart';
import '../../providers/player_provider.dart';
import '../../providers/team_provider.dart';
import '../../widgets/player_stats_card.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});
  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('統計數據'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: '總覽'),
            Tab(text: '得分榜'),
            Tab(text: '出席率'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [_overview(), _scoring(), _attendance()],
      ),
    );
  }

  // ─── Overview ───
  Widget _overview() {
    final team = context.watch<TeamProvider>();
    final pp = context.watch<PlayerProvider>();
    final t = team.currentTeam;
    final wins = t?.matchesWon ?? 0;
    final losses = t?.matchesLost ?? 0;
    final draws = t?.matchesDrawn ?? 0;
    final totalMatches = t?.totalMatches ?? 0;
    final scored = t?.totalScored ?? 0;
    final conceded = t?.totalConceded ?? 0;
    final totalTries = pp.players.fold<int>(0, (s, p) => s + p.tries);
    final totalAtt = pp.players.isEmpty
        ? 0.0
        : pp.players.fold<double>(0, (s, p) => s + p.attendanceRate) /
              pp.players.length;

    // Scoring breakdown from real player data
    final triesPoints = pp.players.fold<int>(0, (s, p) => s + p.tries) * 5;
    final convPoints = pp.players.fold<int>(0, (s, p) => s + p.conversions) * 2;
    final penPoints = pp.players.fold<int>(0, (s, p) => s + p.penalties) * 3;
    final dropPoints = pp.players.fold<int>(0, (s, p) => s + p.dropGoals) * 3;
    final totalPoints = triesPoints + convPoints + penPoints + dropPoints;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _card(
          '本季總覽',
          Column(
            children: [
              Row(
                children: [
                  _box('比賽', '$totalMatches', AppColors.info),
                  _box('勝場', '$wins', AppColors.success),
                  _box('敗場', '$losses', AppColors.error),
                  _box('平局', '$draws', AppColors.warning),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _box('得分', '$scored', AppColors.primary),
                  _box('失分', '$conceded', AppColors.textHint),
                  _box('達陣', '$totalTries', const Color(0xFFA855F7)),
                  _box(
                    '出席',
                    '${(totalAtt * 100).toInt()}%',
                    const Color(0xFF14B8A6),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _card(
          '得分分布',
          totalPoints == 0
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      '尚無得分數據',
                      style: TextStyle(color: AppColors.textHint),
                    ),
                  ),
                )
              : Column(
                  children: [
                    _bar('達陣', triesPoints, totalPoints, AppColors.success),
                    _bar('轉換', convPoints, totalPoints, AppColors.info),
                    _bar('罰球', penPoints, totalPoints, AppColors.warning),
                    _bar(
                      '落踢',
                      dropPoints,
                      totalPoints,
                      const Color(0xFFA855F7),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        _card(
          '勝敗記錄',
          totalMatches == 0
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      '尚無比賽記錄',
                      style: TextStyle(color: AppColors.textHint),
                    ),
                  ),
                )
              : Row(
                  children: [
                    Expanded(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: CustomPaint(
                          painter: _PieChartPainter(
                            wins: wins,
                            losses: losses,
                            draws: draws,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _legend('勝', wins, AppColors.success),
                        _legend('敗', losses, AppColors.error),
                        _legend('平', draws, AppColors.warning),
                      ],
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  // ─── Scoring ───
  Widget _scoring() {
    final pp = context.watch<PlayerProvider>();
    final topScorers = _realTopScorers(pp.players);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [TopScorerCard(topScorers: topScorers)],
    );
  }

  List<PlayerStats> _realTopScorers(List<Player> players) {
    final list = players
        .where((p) => p.totalPoints > 0)
        .map(
          (p) => PlayerStats(
            playerId: p.id,
            playerName: p.name,
            jerseyNumber: p.jerseyNumber,
            totalPoints: p.totalPoints,
            tries: p.tries,
            conversions: p.conversions,
            penalties: p.penalties,
            dropGoals: p.dropGoals,
          ),
        )
        .toList();
    list.sort((a, b) => b.totalPoints.compareTo(a.totalPoints));
    return list.take(10).toList();
  }

  List<PlayerStats> _realIronMen(List<Player> players) {
    final list = players
        .where((p) => p.eventsAttended > 0)
        .map(
          (p) => PlayerStats(
            playerId: p.id,
            playerName: p.name,
            jerseyNumber: p.jerseyNumber,
            appearances: p.eventsAttended,
          ),
        )
        .toList();
    list.sort((a, b) => b.appearances.compareTo(a.appearances));
    return list.take(10).toList();
  }

  // ─── Attendance ───
  Widget _attendance() {
    final pp = context.watch<PlayerProvider>();
    final players = pp.players;
    final avgAtt = players.isEmpty
        ? 0.0
        : players.fold<double>(0, (s, p) => s + p.attendanceRate) /
              players.length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _card(
          '團隊出席率',
          players.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      '尚無出席數據',
                      style: TextStyle(color: AppColors.textHint),
                    ),
                  ),
                )
              : Column(children: [_attBar('平均出席率', avgAtt, AppColors.info)]),
        ),
        const SizedBox(height: 12),
        IronManCard(
          ironMen: _realIronMen(context.read<PlayerProvider>().players),
        ),
        const SizedBox(height: 12),
        _card(
          '個人出席排名',
          players.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      '尚無數據',
                      style: TextStyle(color: AppColors.textHint),
                    ),
                  ),
                )
              : Column(children: _buildAttendanceRanking(players)),
        ),
      ],
    );
  }

  List<Widget> _buildAttendanceRanking(List<Player> players) {
    final ranked = players.where((p) => p.eventsTotal > 0).toList()
      ..sort((a, b) => b.attendanceRate.compareTo(a.attendanceRate));
    if (ranked.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: Text('尚無出席記錄', style: TextStyle(color: AppColors.textHint)),
          ),
        ),
      ];
    }
    return ranked.take(10).map((p) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.primaryMuted,
              child: Text(
                '${p.jerseyNumber}',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(p.name, style: const TextStyle(fontSize: 13))),
            Text(
              '${(p.attendanceRate * 100).toInt()}%',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  // ─── Helpers ───
  Widget _card(String title, Widget child) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _box(String label, String value, Color c) => Expanded(
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: c.withAlpha(18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: c,
            ),
          ),
          Text(label, style: TextStyle(fontSize: 10, color: c)),
        ],
      ),
    ),
  );

  Widget _bar(String label, int value, int total, Color c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                '$value 分',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Stack(
            children: [
              Container(
                height: 16,
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              FractionallySizedBox(
                widthFactor: value / total,
                child: Container(
                  height: 16,
                  decoration: BoxDecoration(
                    color: c,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(String label, int v, Color c) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$label: $v',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    ),
  );

  Widget _attBar(String label, double pct, Color c) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              '${(pct * 100).toInt()}%',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: AppColors.surfaceLight,
            valueColor: AlwaysStoppedAnimation(c),
            minHeight: 7,
          ),
        ),
      ],
    ),
  );
}

class _PieChartPainter extends CustomPainter {
  final int wins, losses, draws;
  _PieChartPainter({
    required this.wins,
    required this.losses,
    required this.draws,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total = wins + losses + draws;
    if (total == 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    final p = Paint()..style = PaintingStyle.fill;
    double angle = -90 * 3.14159 / 180;

    for (final entry in [
      (wins, AppColors.success),
      (losses, AppColors.error),
      (draws, AppColors.warning),
    ]) {
      p.color = entry.$2;
      final sweep = (entry.$1 / total) * 2 * 3.14159;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        angle,
        sweep,
        true,
        p,
      );
      angle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
