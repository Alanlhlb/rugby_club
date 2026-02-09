import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/app_user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/team_provider.dart';
import '../../models/player.dart';
import 'player_detail_screen.dart';

class PlayersScreen extends StatefulWidget {
  const PlayersScreen({super.key});
  @override
  State<PlayersScreen> createState() => _PlayersScreenState();
}

class _PlayersScreenState extends State<PlayersScreen> {
  String _search = '';
  String _sort = 'jerseyNumber';
  String? _filter;

  @override
  Widget build(BuildContext context) {
    final pp = context.watch<PlayerProvider>();

    var list = pp.players.where((p) {
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        if (!p.name.toLowerCase().contains(q) &&
            !p.jerseyNumber.toString().contains(q)) {
          return false;
        }
      }
      if (_filter == 'FWD') {
        return p.positions.any((pos) {
          final lp = pos.toLowerCase();
          return lp.contains('prop') ||
              lp.contains('hooker') ||
              lp.contains('lock') ||
              lp.contains('flanker') ||
              lp.contains('eight') ||
              lp.contains('number 8') ||
              lp.contains('back row');
        });
      }
      if (_filter == 'BKS') {
        return p.positions.any((pos) {
          final lp = pos.toLowerCase();
          return lp.contains('half') ||
              lp.contains('centre') ||
              lp.contains('wing') ||
              lp.contains('full-back') ||
              lp.contains('fullback');
        });
      }
      if (_filter == 'Lineout') {
        return p.isLineoutJumper || p.isLineoutLifter || p.isLineoutThrower;
      }
      if (_filter == 'Kicker') return p.isKicker;
      if (_filter == 'Injured') return p.isInjured;
      return true;
    }).toList();

    if (_sort == 'name') {
      list.sort((a, b) => a.name.compareTo(b.name));
    } else if (_sort == 'position') {
      list.sort((a, b) {
        final aPos = _positionOrder(a.primaryPosition);
        final bPos = _positionOrder(b.primaryPosition);
        if (aPos != bPos) return aPos.compareTo(bPos);
        return a.jerseyNumber.compareTo(b.jerseyNumber);
      });
    } else {
      list.sort((a, b) => a.jerseyNumber.compareTo(b.jerseyNumber));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('球員名單'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort, size: 20),
            onSelected: (v) => setState(() => _sort = v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'jerseyNumber', child: Text('按球衣號碼')),
              PopupMenuItem(value: 'name', child: Text('按姓名')),
              PopupMenuItem(value: 'position', child: Text('按位置')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip(null, '全部'),
                  _filterChip('FWD', '前鋒'),
                  _filterChip('BKS', '後衛'),
                  _filterChip('Lineout', 'Lineout'),
                  _filterChip('Kicker', 'Kicker'),
                  _filterChip('Injured', '傷病'),
                ],
              ),
            ),
          ),
          // Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              decoration: const InputDecoration(
                hintText: '搜尋球員…',
                prefixIcon: Icon(Icons.search, size: 20),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          const SizedBox(height: 4),
          // List
          Expanded(
            child: pp.isLoading
                ? const Center(child: CircularProgressIndicator.adaptive())
                : list.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.people_outline,
                          size: 64,
                          color: AppColors.textHint,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '尚無球員',
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
                            onPressed: () => _addDialog(context),
                            icon: const Icon(Icons.person_add, size: 18),
                            label: const Text('立即新增'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: BorderSide(
                                color: AppColors.primary.withAlpha(100),
                              ),
                            ),
                          ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: list.length,
                    itemBuilder: (_, i) => _tile(context, list[i]),
                  ),
          ),
        ],
      ),
      floatingActionButton:
          context.watch<AuthProvider>().currentUser?.role == UserRole.player
          ? null
          : FloatingActionButton.extended(
              heroTag: 'fab_players',
              onPressed: () => _addDialog(context),
              icon: const Icon(Icons.person_add, size: 18),
              label: const Text('新增球員'),
            ),
    );
  }

  Widget _tile(BuildContext context, Player p) {
    final auth = context.watch<AuthProvider>();
    final isAdminOrCoach =
        auth.currentUser != null &&
        (auth.currentUser!.role == UserRole.admin ||
            auth.currentUser!.role == UserRole.coach);

    final avatarColor = p.redCards > 0
        ? AppColors.suspended
        : p.isInjured
        ? AppColors.warning
        : AppColors.primary;

    final tile = Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: avatarColor,
              child: Text(
                '${p.jerseyNumber}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
            if (p.yellowCards > 0 && p.redCards == 0)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 8,
                  height: 11,
                  decoration: BoxDecoration(
                    color: AppColors.yellowCard,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            if (p.redCards > 0)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 8,
                  height: 11,
                  decoration: BoxDecoration(
                    color: AppColors.redCard,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                p.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (p.isCaptain)
              Container(
                margin: const EdgeInsets.only(left: 4),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withAlpha(25),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'C',
                  style: TextStyle(
                    color: AppColors.secondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Wrap(
          spacing: 4,
          runSpacing: 2,
          children: [
            if (p.positions.isNotEmpty)
              Text(
                p.positions
                    .asMap()
                    .entries
                    .map((e) => '${e.key + 1}.${e.value}')
                    .join(' / '),
                style: const TextStyle(color: AppColors.textHint, fontSize: 11),
              ),
            if (p.isLineoutJumper) _tag('Jump', AppColors.info),
            if (p.isLineoutLifter) _tag('Lift', const Color(0xFFA855F7)),
            if (p.isLineoutThrower) _tag('Throw', const Color(0xFF14B8A6)),
            if (p.isKicker) _tag('Kick', AppColors.secondary),
            if (p.isInjured) _tag('Injured', AppColors.error),
          ],
        ),
        trailing: const Icon(
          Icons.chevron_right,
          size: 18,
          color: AppColors.textHint,
        ),
        onTap: () async {
          final scaffold = ScaffoldMessenger.of(context);
          final result = await Navigator.push<String>(
            context,
            MaterialPageRoute(builder: (_) => PlayerDetailScreen(player: p)),
          );
          if (result == 'deleted' && mounted) {
            scaffold.showSnackBar(SnackBar(content: Text('已刪除「${p.name}」')));
          }
        },
      ),
    );

    if (!isAdminOrCoach) return tile;

    return Dismissible(
      key: Key(p.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white, size: 22),
      ),
      confirmDismiss: (_) async {
        return await showAdaptiveDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog.adaptive(
                title: const Text('刪除球員'),
                content: Text('確定要刪除「${p.name}」嗎？此操作無法復原。'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('取消'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('刪除'),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) async {
        final pp = context.read<PlayerProvider>();
        final scaffold = ScaffoldMessenger.of(context);
        try {
          await pp.deletePlayer(p.id);
        } catch (e) {
          if (mounted) {
            scaffold.showSnackBar(SnackBar(content: Text('刪除失敗: $e')));
          }
        }
      },
      child: tile,
    );
  }

  Widget _tag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  int _positionOrder(String position) {
    const order = {
      'Loosehead Prop': 1,
      'Hooker': 2,
      'Tighthead Prop': 3,
      'Lock': 4,
      'Lock (4)': 4,
      'Lock (5)': 5,
      'Blindside Flanker': 6,
      'Openside Flanker': 7,
      'Number 8': 8,
      'Scrum-half': 9,
      'Fly-half': 10,
      'Left Wing': 11,
      'Inside Centre': 12,
      'Outside Centre': 13,
      'Right Wing': 14,
      'Fullback': 15,
    };
    return order[position] ?? 99;
  }

  Widget _filterChip(String? value, String label) {
    final selected = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected,
        selectedColor: AppColors.primary.withAlpha(40),
        checkmarkColor: AppColors.primary,
        onSelected: (_) => setState(() => _filter = value),
      ),
    );
  }

  void _addDialog(BuildContext context) {
    final tp = context.read<TeamProvider>();
    if (tp.currentTeam == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請先在設定中建立球隊')));
      return;
    }

    final name = TextEditingController();
    final jersey = TextEditingController();
    final selectedPositions = <String>[];

    const allPositions = [
      'Loosehead Prop',
      'Hooker',
      'Tighthead Prop',
      'Lock',
      'Blindside Flanker',
      'Openside Flanker',
      'Number 8',
      'Scrum-half',
      'Fly-half',
      'Left Wing',
      'Inside Centre',
      'Outside Centre',
      'Right Wing',
      'Fullback',
    ];

    showAdaptiveDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog.adaptive(
          title: const Text('新增球員'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Material(
                    color: Colors.transparent,
                    child: TextField(
                      controller: name,
                      decoration: const InputDecoration(
                        labelText: '姓名',
                        prefixIcon: Icon(Icons.person, size: 20),
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Material(
                    color: Colors.transparent,
                    child: TextField(
                      controller: jersey,
                      decoration: const InputDecoration(
                        labelText: '球衣號碼',
                        prefixIcon: Icon(Icons.tag, size: 20),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '位置 (選填，按選擇順序為第1→第2→第3位置)',
                    style: TextStyle(fontSize: 12, color: AppColors.textHint),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: allPositions.map((pos) {
                      final idx = selectedPositions.indexOf(pos);
                      final selected = idx >= 0;
                      final posLabel = selected ? '${idx + 1}. $pos' : pos;
                      return FilterChip(
                        label: Text(
                          posLabel,
                          style: const TextStyle(fontSize: 11),
                        ),
                        selected: selected,
                        selectedColor: idx == 0
                            ? AppColors.primary.withAlpha(40)
                            : idx == 1
                            ? AppColors.secondary.withAlpha(40)
                            : AppColors.primaryMuted,
                        checkmarkColor: AppColors.primary,
                        onSelected: (v) {
                          setDialogState(() {
                            if (v) {
                              if (selectedPositions.length < 3) {
                                selectedPositions.add(pos);
                              }
                            } else {
                              selectedPositions.remove(pos);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  if (selectedPositions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (int i = 0; i < selectedPositions.length; i++)
                            Text(
                              '第${i + 1}位置: ${selectedPositions[i]}',
                              style: TextStyle(
                                fontSize: 11,
                                color: i == 0
                                    ? AppColors.primary
                                    : i == 1
                                    ? AppColors.secondary
                                    : AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                if (name.text.trim().isEmpty) {
                  ScaffoldMessenger.of(
                    ctx,
                  ).showSnackBar(const SnackBar(content: Text('請輸入姓名')));
                  return;
                }
                final jerseyNum = int.tryParse(jersey.text) ?? 0;
                if (jerseyNum <= 0) {
                  ScaffoldMessenger.of(
                    ctx,
                  ).showSnackBar(const SnackBar(content: Text('請輸入球衣號碼')));
                  return;
                }
                final pp = ctx.read<PlayerProvider>();
                if (pp.isJerseyNumberTaken(jerseyNum)) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('球衣號碼 $jerseyNum 已被使用')),
                  );
                  return;
                }
                try {
                  await pp.createPlayer(
                    Player(
                      id: '',
                      teamId: tp.currentTeam!.id,
                      name: name.text.trim(),
                      jerseyNumber: jerseyNum,
                      positions: List<String>.from(selectedPositions),
                      seasonId: tp.currentSeason?.id,
                      createdAt: DateTime.now(),
                    ),
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
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
}
