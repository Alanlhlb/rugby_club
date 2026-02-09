import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/app_user.dart' show UserRole;
import '../../models/player.dart';
import '../../models/team.dart';
import '../../providers/team_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/event_provider.dart';
import '../../providers/join_request_provider.dart';
import '../auth/login_screen.dart';
import '../home/home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pc = PageController();
  int _page = 0;
  final _teamName = TextEditingController();
  final _seasonName = TextEditingController();
  final _teamIdCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  DateTime _start = DateTime.now();
  DateTime _end = DateTime.now().add(const Duration(days: 365));
  bool _loading = false;
  bool _isJoinPath = false; // false = create, true = join

  @override
  void dispose() {
    _pc.dispose();
    _teamName.dispose();
    _seasonName.dispose();
    _teamIdCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < 2) {
      _pc.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prev() {
    if (_page > 0) {
      _pc.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _complete() async {
    setState(() => _loading = true);
    try {
      final tp = context.read<TeamProvider>();
      final auth = context.read<AuthProvider>();
      final pp = context.read<PlayerProvider>();
      final ep = context.read<EventProvider>();

      if (_isJoinPath) {
        // ── Join existing team ──
        final teamId = _teamIdCtrl.text.trim();
        if (teamId.isEmpty) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('請輸入球隊 ID')));
          setState(() => _loading = false);
          return;
        }
        await tp.loadTeam(teamId);
        if (tp.currentTeam == null) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('找不到此球隊，請檢查 ID')));
          }
          setState(() => _loading = false);
          return;
        }
        // Update user's teamId
        await auth.updateUserTeam(teamId);
      } else {
        // ── Create new team ──
        if (_teamName.text.trim().isEmpty) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('請輸入球隊名稱')));
          _pc.jumpToPage(1);
          setState(() => _loading = false);
          return;
        }
        final teamId = await tp.createTeam(
          _teamName.text.trim(),
          auth.firebaseUser?.uid ?? '',
        );
        // Update user's teamId
        await auth.updateUserTeam(teamId);
        if (_seasonName.text.trim().isNotEmpty && tp.currentTeam != null) {
          await tp.createSeason(
            tp.currentTeam!.id,
            _seasonName.text.trim(),
            _start,
            _end,
          );
        }
      }

      // If user is a player, auto-create a Player record and link playerId
      final user = auth.currentUser;
      if (user != null &&
          user.role == UserRole.player &&
          tp.currentTeam != null) {
        final playerId = await pp.createPlayer(
          Player(
            id: '',
            name: user.name,
            jerseyNumber: 0,
            positions: const [],
            teamId: tp.currentTeam!.id,
            seasonId: tp.currentSeason?.id,
            createdAt: DateTime.now(),
          ),
        );
        await auth.updateProfile({'playerId': playerId});
      }

      // Load players & events for the new/joined team
      if (tp.currentTeam != null) {
        final teamId = tp.currentTeam!.id;
        final seasonId = tp.currentSeason?.id;
        await Future.wait([
          pp.loadPlayers(teamId, seasonId: seasonId),
          ep.loadEvents(teamId, seasonId: seasonId),
        ]);
      }

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('設定失敗: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    final auth = context.read<AuthProvider>();
    await auth.signOut();
    if (mounted) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Progress + Back to login
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, size: 20),
                    tooltip: '返回登入',
                    onPressed: () {
                      if (_page > 0) {
                        _prev();
                      } else {
                        _logout();
                      }
                    },
                  ),
                  ...List.generate(
                    _isJoinPath ? 2 : 3,
                    (i) => Expanded(
                      child: Container(
                        height: 3,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: i <= _page
                              ? AppColors.primary
                              : AppColors.divider,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pc,
                onPageChanged: (p) => setState(() => _page = p),
                physics: const NeverScrollableScrollPhysics(),
                children: _isJoinPath
                    ? [_welcomePage(), _joinTeamPage()]
                    : [_welcomePage(), _teamPage(), _seasonPage()],
              ),
            ),
            // Nav buttons
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  if (_page > 0)
                    TextButton(
                      onPressed: () {
                        if (_page == 1 && _isJoinPath) {
                          _prev();
                          Future.delayed(const Duration(milliseconds: 350), () {
                            if (mounted) setState(() => _isJoinPath = false);
                          });
                        } else {
                          _prev();
                        }
                      },
                      child: const Text('返回'),
                    ),
                  const Spacer(),
                  if (_isJoinPath && _page == 1)
                    // Join path: final page
                    ElevatedButton(
                      onPressed: _loading ? null : _complete,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 12,
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator.adaptive(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text('加入球隊'),
                    )
                  else if (!_isJoinPath && _page < 2)
                    ElevatedButton(
                      onPressed: (_page == 1 && _teamName.text.trim().isEmpty)
                          ? null
                          : _next,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 12,
                        ),
                      ),
                      child: const Text('下一步'),
                    )
                  else if (!_isJoinPath && _page == 2)
                    ElevatedButton(
                      onPressed: _loading ? null : _complete,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 12,
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator.adaptive(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text('完成設定'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _welcomePage() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppColors.primaryMuted,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.sports_rugby,
              size: 44,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '歡迎使用 Rugby Club',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '請選擇您的身份',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 36),
          // ─── Create Team option ───
          _pathOption(
            icon: Icons.add_circle_outline,
            color: AppColors.primary,
            title: '建立新球隊',
            subtitle: '我是管理員/教練，要建立新球隊',
            onTap: () {
              setState(() => _isJoinPath = false);
              _next();
            },
          ),
          const SizedBox(height: 14),
          // ─── Join Team option ───
          _pathOption(
            icon: Icons.group_add,
            color: const Color(0xFF1565C0),
            title: '加入現有球隊',
            subtitle: '我已有球隊 ID，要加入球隊',
            onTap: () {
              setState(() => _isJoinPath = true);
              context.read<JoinRequestProvider>().loadAllTeams();
              _next();
            },
          ),
        ],
      ),
    );
  }

  Widget _pathOption({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(color: color.withAlpha(60)),
          borderRadius: BorderRadius.circular(16),
          color: color.withAlpha(10),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textHint,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.adaptive.arrow_forward, color: color, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _joinTeamPage() {
    final jrp = context.watch<JoinRequestProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '加入現有球隊',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '輸入球隊 ID 直接加入，或瀏覽球隊發送申請',
                style: TextStyle(color: AppColors.textHint),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _teamIdCtrl,
                decoration: const InputDecoration(
                  labelText: '球隊 ID',
                  hintText: '貼上球隊管理員提供的 ID',
                  prefixIcon: Icon(Icons.vpn_key, size: 20),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              const Text(
                '瀏覽球隊',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: '搜尋球隊名稱...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            jrp.loadAllTeams();
                            setState(() {});
                          },
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                onChanged: (q) {
                  if (q.isEmpty) {
                    jrp.loadAllTeams();
                  } else {
                    jrp.searchTeams(q);
                  }
                  setState(() {});
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: jrp.isLoading
              ? const Center(child: CircularProgressIndicator.adaptive())
              : jrp.searchResults.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.groups,
                        size: 48,
                        color: AppColors.textHint,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '尚無球隊',
                        style: TextStyle(color: AppColors.textHint),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => jrp.loadAllTeams(),
                        child: const Text('載入所有球隊'),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: jrp.searchResults.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _teamCard(jrp.searchResults[i]),
                ),
        ),
      ],
    );
  }

  Widget _teamCard(Team team) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primaryMuted,
            backgroundImage: team.logoUrl != null && team.logoUrl!.isNotEmpty
                ? NetworkImage(team.logoUrl!)
                : null,
            child: team.logoUrl == null || team.logoUrl!.isEmpty
                ? Text(
                    team.name.isNotEmpty ? team.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  team.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  team.level.displayName,
                  style: const TextStyle(
                    color: AppColors.textHint,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          FilledButton.tonal(
            onPressed: () => _showRequestDialog(team),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: const Text('申請加入'),
          ),
        ],
      ),
    );
  }

  Future<void> _showRequestDialog(Team team) async {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) return;

    UserRole selectedRole = user.role;

    final confirmed = await showAdaptiveDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog.adaptive(
              title: Text('申請加入 ${team.name}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('選擇您的角色：'),
                  const SizedBox(height: 12),
                  SegmentedButton<UserRole>(
                    segments: const [
                      ButtonSegment(
                        value: UserRole.player,
                        label: Text('Player'),
                        icon: Icon(Icons.person, size: 16),
                      ),
                      ButtonSegment(
                        value: UserRole.coach,
                        label: Text('Coach'),
                        icon: Icon(Icons.sports, size: 16),
                      ),
                    ],
                    selected: {selectedRole},
                    onSelectionChanged: (s) {
                      setDialogState(() => selectedRole = s.first);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('發送申請'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final jrp = context.read<JoinRequestProvider>();
    final scaffold = ScaffoldMessenger.of(context);

    final ok = await jrp.sendJoinRequest(
      teamId: team.id,
      teamName: team.name,
      userId: user.id,
      userName: user.name,
      userEmail: user.email,
      requestedRole: selectedRole,
    );

    if (ok) {
      scaffold.showSnackBar(const SnackBar(content: Text('申請已發送，等待球隊管理員審批')));
    } else {
      scaffold.showSnackBar(SnackBar(content: Text(jrp.error ?? '發送失敗')));
      jrp.clearError();
    }
  }

  Widget _teamPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          const Text(
            '建立您的球隊',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text('為您的球隊取一個名稱', style: TextStyle(color: AppColors.textHint)),
          const SizedBox(height: 28),
          TextField(
            controller: _teamName,
            decoration: const InputDecoration(
              labelText: '球隊名稱',
              hintText: '例如：香港橄欖球會',
              prefixIcon: Icon(Icons.shield, size: 20),
            ),
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),
          _infoBox(
            Icons.info_outline,
            AppColors.info,
            '您可以稍後在設定中修改球隊名稱和邀請其他管理員',
          ),
        ],
      ),
    );
  }

  Widget _seasonPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          const Text(
            '建立球季',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '設定您的第一個球季（選填）',
            style: TextStyle(color: AppColors.textHint),
          ),
          const SizedBox(height: 28),
          TextField(
            controller: _seasonName,
            decoration: const InputDecoration(
              labelText: '球季名稱',
              hintText: '例如：2024-2025 賽季',
              prefixIcon: Icon(Icons.calendar_today, size: 20),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _datePicker('開始日期', _start, () async {
                  final p = await showDatePicker(
                    context: context,
                    initialDate: _start,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (p != null) setState(() => _start = p);
                }),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _datePicker('結束日期', _end, () async {
                  final p = await showDatePicker(
                    context: context,
                    initialDate: _end,
                    firstDate: _start,
                    lastDate: DateTime(2030),
                  );
                  if (p != null) setState(() => _end = p);
                }),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _infoBox(
            Icons.lightbulb_outline,
            AppColors.secondary,
            '您可以跳過此步驟，稍後再建立球季',
          ),
        ],
      ),
    );
  }

  Widget _infoBox(IconData icon, Color color, String text) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(color: color, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _datePicker(String label, DateTime date, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.divider),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: AppColors.textHint, fontSize: 11),
            ),
            const SizedBox(height: 4),
            Text(
              '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
