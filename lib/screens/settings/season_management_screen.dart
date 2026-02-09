import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/team_provider.dart';
import '../../providers/player_provider.dart';
import '../../models/season.dart';

class SeasonManagementScreen extends StatefulWidget {
  const SeasonManagementScreen({super.key});
  @override
  State<SeasonManagementScreen> createState() => _SeasonManagementScreenState();
}

class _SeasonManagementScreenState extends State<SeasonManagementScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('球季管理')),
      body: Consumer<TeamProvider>(
        builder: (context, prov, _) {
          final seasons = prov.seasons;
          final cur = prov.currentSeason;
          if (seasons.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 64,
                    color: AppColors.textHint,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    '尚無球季',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '點擊下方按鈕新增第一個球季',
                    style: TextStyle(color: AppColors.textHint, fontSize: 12),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: seasons.length,
            itemBuilder: (_, i) {
              final s = seasons[i];
              final active = s.id == cur?.id;
              return _seasonCard(s, active);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_seasons',
        onPressed: () => _addDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('新增球季'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _seasonCard(Season s, bool active) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active ? AppColors.primary : AppColors.divider,
          width: active ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _detailSheet(s),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      s.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (active)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '使用中',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                s.period,
                style: const TextStyle(color: AppColors.textHint, fontSize: 12),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _mini('比賽', '${s.totalMatches}', null),
                  const SizedBox(width: 14),
                  _mini('勝', '${s.matchesWon}', AppColors.success),
                  const SizedBox(width: 14),
                  _mini('敗', '${s.matchesLost}', AppColors.error),
                  const Spacer(),
                  if (!active)
                    TextButton(
                      onPressed: () => _activate(s),
                      child: const Text(
                        '設為使用中',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mini(String label, String value, Color? c) => Column(
    children: [
      Text(
        value,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: c ?? AppColors.textPrimary,
        ),
      ),
      Text(
        label,
        style: const TextStyle(fontSize: 10, color: AppColors.textHint),
      ),
    ],
  );

  void _addDialog(BuildContext context) {
    final nc = TextEditingController();
    DateTime start = DateTime.now();
    DateTime end = DateTime.now().add(const Duration(days: 365));
    showAdaptiveDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog.adaptive(
          title: const Text('新增球季'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Material(
                color: Colors.transparent,
                child: TextField(
                  controller: nc,
                  decoration: const InputDecoration(
                    labelText: '球季名稱',
                    hintText: '例如: 2024-25 賽季',
                    prefixIcon: Icon(Icons.label, size: 20),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today, size: 20),
                title: const Text('開始日期', style: TextStyle(fontSize: 13)),
                subtitle: Text(
                  '${start.year}/${start.month}/${start.day}',
                  style: const TextStyle(fontSize: 12),
                ),
                onTap: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: start,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (d != null) setS(() => start = d);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event, size: 20),
                title: const Text('結束日期', style: TextStyle(fontSize: 13)),
                subtitle: Text(
                  '${end.year}/${end.month}/${end.day}',
                  style: const TextStyle(fontSize: 12),
                ),
                onTap: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: end,
                    firstDate: start,
                    lastDate: DateTime(2030),
                  );
                  if (d != null) setS(() => end = d);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                if (nc.text.trim().isEmpty) {
                  ScaffoldMessenger.of(
                    ctx,
                  ).showSnackBar(const SnackBar(content: Text('請輸入球季名稱')));
                  return;
                }
                final tp = context.read<TeamProvider>();
                if (tp.currentTeam == null) return;
                final pp = context.read<PlayerProvider>();
                try {
                  final newSeasonId = await tp.createSeason(
                    tp.currentTeam!.id,
                    nc.text.trim(),
                    start,
                    end,
                  );
                  // Reload players for the new season (will be empty)
                  await pp.loadPlayers(
                    tp.currentTeam!.id,
                    seasonId: newSeasonId,
                  );
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('球季已新增，球員名單已重置')),
                    );
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text('新增失敗: $e')));
                  }
                }
              },
              child: const Text('新增'),
            ),
          ],
        ),
      ),
    );
  }

  void _detailSheet(Season s) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, sc) => SingleChildScrollView(
          controller: sc,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        s.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (s.isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '使用中',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  s.period,
                  style: const TextStyle(
                    color: AppColors.textHint,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  '球季統計',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    children: [
                      _row('總比賽', '${s.totalMatches}'),
                      _row('勝場', '${s.matchesWon}'),
                      _row('敗場', '${s.matchesLost}'),
                      _row('平局', '${s.matchesDrawn}'),
                      _row('勝率', '${(s.winRate * 100).toStringAsFixed(1)}%'),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Divider(color: AppColors.divider, height: 1),
                      ),
                      _row('總得分', '${s.totalScored}'),
                      _row('總失分', '${s.totalConceded}'),
                      _row(
                        '分差',
                        '${s.pointDifference > 0 ? '+' : ''}${s.pointDifference}',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
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

  Future<void> _activate(Season s) async {
    final tp = context.read<TeamProvider>();
    final pp = context.read<PlayerProvider>();
    try {
      await tp.setActiveSeason(s.id);
      // Reload players for the newly active season
      if (tp.currentTeam != null) {
        await pp.loadPlayers(tp.currentTeam!.id, seasonId: s.id);
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('已切換至 ${s.name}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('切換失敗: $e')));
      }
    }
  }
}
