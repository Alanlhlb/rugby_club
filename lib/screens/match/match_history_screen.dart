import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/team_provider.dart';
import '../../services/match_service.dart';
import '../../services/event_service.dart';
import '../../services/share_service.dart';

class MatchHistoryScreen extends StatefulWidget {
  const MatchHistoryScreen({super.key});
  @override
  State<MatchHistoryScreen> createState() => _MatchHistoryScreenState();
}

class _MatchHistoryScreenState extends State<MatchHistoryScreen> {
  String _filter = 'all';
  List<MatchRecord> _matches = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMatches();
  }

  Future<void> _loadMatches() async {
    final tp = context.read<TeamProvider>();
    if (tp.currentTeam == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final matchService = MatchService();
      final eventService = EventService();
      final teamId = tp.currentTeam!.id;
      // Query completed matches for this team
      final states = await matchService.getCompletedMatches(teamId);
      final records = <MatchRecord>[];
      for (final s in states) {
        String opponent = '對手';
        String location = '';
        if (s.eventId.isNotEmpty) {
          try {
            final event = await eventService.getEvent(s.eventId);
            if (event != null) {
              opponent = event.opponent ?? '對手';
              location = event.location ?? '';
            }
          } catch (_) {}
        }
        records.add(
          MatchRecord(
            id: s.id,
            date: s.startTime ?? s.createdAt,
            opponent: opponent,
            homeScore: s.ourScore,
            awayScore: s.opponentScore,
            location: location,
            isHome: true,
          ),
        );
      }
      setState(() {
        _matches = records;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  List<MatchRecord> get _filtered {
    switch (_filter) {
      case 'wins':
        return _matches.where((m) => m.result == MatchResult.win).toList();
      case 'losses':
        return _matches.where((m) => m.result == MatchResult.loss).toList();
      case 'draws':
        return _matches.where((m) => m.result == MatchResult.draw).toList();
      default:
        return _matches;
    }
  }

  @override
  Widget build(BuildContext context) {
    final wins = _matches.where((m) => m.result == MatchResult.win).length;
    final losses = _matches.where((m) => m.result == MatchResult.loss).length;
    final draws = _matches.where((m) => m.result == MatchResult.draw).length;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('比賽記錄')),
        body: const Center(child: CircularProgressIndicator.adaptive()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('比賽記錄'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list, size: 20),
            onSelected: (v) => setState(() => _filter = v),
            itemBuilder: (_) => [
              CheckedPopupMenuItem(
                value: 'all',
                checked: _filter == 'all',
                child: const Text('全部'),
              ),
              CheckedPopupMenuItem(
                value: 'wins',
                checked: _filter == 'wins',
                child: const Text('勝場'),
              ),
              CheckedPopupMenuItem(
                value: 'losses',
                checked: _filter == 'losses',
                child: const Text('敗場'),
              ),
              CheckedPopupMenuItem(
                value: 'draws',
                checked: _filter == 'draws',
                child: const Text('平局'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _sumBox('總場次', '${_matches.length}', AppColors.info),
                const SizedBox(width: 8),
                _sumBox('勝', '$wins', AppColors.success),
                const SizedBox(width: 8),
                _sumBox('敗', '$losses', AppColors.error),
                const SizedBox(width: 8),
                _sumBox('平', '$draws', AppColors.warning),
              ],
            ),
          ),
          Expanded(
            child: _filtered.isEmpty
                ? const Center(
                    child: Text(
                      '沒有符合條件的比賽',
                      style: TextStyle(color: AppColors.textHint),
                    ),
                  )
                : ListView.builder(
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) => _matchTile(_filtered[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _sumBox(String label, String value, Color c) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: c.withAlpha(18),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            value,
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

  Widget _matchTile(MatchRecord m) {
    final tp = context.read<TeamProvider>();
    final teamName = tp.currentTeam?.name ?? '我們';
    final teamLogo = tp.currentTeam?.logoUrl;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _details(m),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('yyyy/MM/dd (E)', 'zh_TW').format(m.date),
                    style: const TextStyle(
                      color: AppColors.textHint,
                      fontSize: 11,
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 12,
                        color: AppColors.textHint,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        m.location,
                        style: const TextStyle(
                          color: AppColors.textHint,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        if (m.isHome && teamLogo != null && teamLogo.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: CircleAvatar(
                              radius: 14,
                              backgroundImage: NetworkImage(teamLogo),
                            ),
                          ),
                        Text(
                          m.isHome ? teamName : m.opponent,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${m.isHome ? m.homeScore : m.awayScore}',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: m.isHome
                                ? AppColors.primary
                                : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: m.resultColor.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      m.resultText,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: m.resultColor,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        if (!m.isHome &&
                            teamLogo != null &&
                            teamLogo.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: CircleAvatar(
                              radius: 14,
                              backgroundImage: NetworkImage(teamLogo),
                            ),
                          ),
                        Text(
                          m.isHome ? m.opponent : teamName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${m.isHome ? m.awayScore : m.homeScore}',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: !m.isHome
                                ? AppColors.primary
                                : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: (m.isHome ? AppColors.info : AppColors.warning)
                      .withAlpha(15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  m.isHome ? '主場' : '客場',
                  style: TextStyle(
                    fontSize: 10,
                    color: m.isHome ? AppColors.info : AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _details(MatchRecord m) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (ctx, sc) => Container(
          decoration: BoxDecoration(
            color: AppColors.scaffoldBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle and Header
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              // Toolbar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.adaptive.share,
                        color: AppColors.primary,
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        final teamName =
                            context.read<TeamProvider>().currentTeam?.name ??
                            '我們';
                        ShareService.shareMatchResult(
                          context: context,
                          teamName: teamName,
                          opponent: m.opponent,
                          homeScore: m.homeScore,
                          awayScore: m.awayScore,
                          matchDate: m.date,
                        );
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: sc,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  children: [
                    Text(
                      'vs ${m.opponent}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      DateFormat('yyyy年MM月dd日').format(m.date),
                      style: const TextStyle(
                        color: AppColors.textHint,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${m.homeScore}',
                          style: const TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 14),
                          child: Text(
                            '-',
                            style: TextStyle(
                              fontSize: 44,
                              color: AppColors.textHint,
                            ),
                          ),
                        ),
                        Text(
                          '${m.awayScore}',
                          style: const TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _detailRow('地點', m.location),
                    _detailRow('主/客', m.isHome ? '主場' : '客場'),
                    _detailRow('結果', m.resultText),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: const Center(
                        child: Text(
                          '暫無比賽詳細數據',
                          style: TextStyle(
                            color: AppColors.textHint,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
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

enum MatchResult { win, loss, draw }

class MatchRecord {
  final String id;
  final DateTime date;
  final String opponent;
  final int homeScore;
  final int awayScore;
  final String location;
  final bool isHome;

  MatchRecord({
    required this.id,
    required this.date,
    required this.opponent,
    required this.homeScore,
    required this.awayScore,
    required this.location,
    required this.isHome,
  });

  MatchResult get result {
    final ourScore = isHome ? homeScore : awayScore;
    final theirScore = isHome ? awayScore : homeScore;

    if (ourScore > theirScore) return MatchResult.win;
    if (ourScore < theirScore) return MatchResult.loss;
    return MatchResult.draw;
  }

  String get resultText {
    switch (result) {
      case MatchResult.win:
        return '勝';
      case MatchResult.loss:
        return '敗';
      case MatchResult.draw:
        return '平';
    }
  }

  Color get resultColor {
    switch (result) {
      case MatchResult.win:
        return Colors.green;
      case MatchResult.loss:
        return Colors.red;
      case MatchResult.draw:
        return Colors.orange;
    }
  }
}
