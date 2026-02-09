import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/app_user.dart' show UserRole;
import '../../providers/auth_provider.dart';
import '../../providers/team_provider.dart';
import '../../providers/join_request_provider.dart';
import '../../widgets/season_selector.dart';
import '../auth/login_screen.dart';
import '../onboarding/onboarding_screen.dart';
import 'team_settings_screen.dart';
import 'season_management_screen.dart';
import 'join_requests_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final teamId = context.read<TeamProvider>().currentTeam?.id;
      if (teamId != null) {
        context.read<JoinRequestProvider>().listenPendingCount(teamId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final team = context.watch<TeamProvider>();
    final role = auth.currentUser?.role ?? UserRole.player;
    final isAdminOrCoach = role == UserRole.admin || role == UserRole.coach;

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          // ─── Profile header ───
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.primaryMuted,
                  child: Text(
                    (auth.currentUser?.name ?? 'U')[0].toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        auth.currentUser?.name ?? '未登入',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (auth.firebaseUser?.email != null) ...[
                        const SizedBox(height: 1),
                        Text(
                          auth.firebaseUser!.email!,
                          style: const TextStyle(
                            color: AppColors.textHint,
                            fontSize: 11,
                          ),
                        ),
                      ],
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            team.currentTeam?.name ?? '尚未加入球隊',
                            style: const TextStyle(
                              color: AppColors.textHint,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryMuted,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              role.displayName,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ─── Team info (all roles) ───
          if (team.currentTeam != null) ...[
            _header('球隊資訊'),
            ListTile(
              leading: const Icon(Icons.vpn_key, size: 20),
              title: const Text('球隊 ID', style: TextStyle(fontSize: 14)),
              subtitle: Text(
                team.currentTeam!.id,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textHint,
                  fontFamily: 'monospace',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                icon: const Icon(
                  Icons.copy,
                  size: 18,
                  color: AppColors.primary,
                ),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: team.currentTeam!.id));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('球隊 ID 已複製，可分享給隊友加入')),
                  );
                },
              ),
            ),
          ],

          // ─── Team management (admin / coach) ───
          if (isAdminOrCoach) ...[
            _header('球隊管理'),
            _tile(
              Icons.shield,
              '球隊資訊',
              '修改球隊名稱、顏色',
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TeamSettingsScreen()),
              ),
            ),
            if (team.currentSeason != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: SeasonSelector(
                  seasons: team.seasons,
                  currentSeason: team.currentSeason,
                  onSeasonChanged: (s) => team.setActiveSeason(s.id),
                ),
              ),
            _tile(
              Icons.calendar_today,
              '球季管理',
              '新增或編輯球季',
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SeasonManagementScreen(),
                ),
              ),
            ),
            Builder(
              builder: (context) {
                final jrp = context.watch<JoinRequestProvider>();
                final pendingCount = jrp.pendingCount;
                return ListTile(
                  leading: Badge(
                    isLabelVisible: pendingCount > 0,
                    label: Text('$pendingCount'),
                    child: const Icon(Icons.person_add, size: 20),
                  ),
                  title: const Text('加入申請', style: TextStyle(fontSize: 14)),
                  subtitle: Text(
                    pendingCount > 0 ? '$pendingCount 個待審批申請' : '暫無申請',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textHint,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const JoinRequestsScreen(),
                    ),
                  ),
                );
              },
            ),
          ],

          const SizedBox(height: 20),

          // ─── Leave team ───
          if (team.currentTeam != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton.icon(
                onPressed: () => _leaveTeamConfirm(context),
                icon: const Icon(
                  Icons.exit_to_app,
                  color: Colors.orange,
                  size: 18,
                ),
                label: const Text(
                  '退出球隊',
                  style: TextStyle(color: Colors.orange),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.orange),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

          const SizedBox(height: 12),

          // ─── Logout ───
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              onPressed: () => _logoutConfirm(context),
              icon: const Icon(Icons.logout, color: AppColors.error, size: 18),
              label: const Text('登出', style: TextStyle(color: AppColors.error)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.error),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── helpers ───
  Widget _header(String t) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    child: Text(
      t,
      style: const TextStyle(
        color: AppColors.primary,
        fontWeight: FontWeight.w700,
        fontSize: 12,
        letterSpacing: 0.5,
      ),
    ),
  );

  Widget _tile(IconData icon, String title, String? sub, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, size: 20),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      subtitle: sub != null
          ? Text(sub, style: const TextStyle(fontSize: 11))
          : null,
      trailing: const Icon(
        Icons.chevron_right,
        size: 18,
        color: AppColors.textHint,
      ),
      onTap: onTap,
    );
  }

  void _leaveTeamConfirm(BuildContext context) {
    final nav = Navigator.of(context);
    showAdaptiveDialog(
      context: context,
      builder: (ctx) => AlertDialog.adaptive(
        title: const Text('退出球隊'),
        content: const Text('確定要退出目前的球隊嗎？退出後需要重新加入或建立球隊。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final auth = context.read<AuthProvider>();
              await auth.leaveTeam();
              nav.pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                (_) => false,
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('退出'),
          ),
        ],
      ),
    );
  }

  void _logoutConfirm(BuildContext context) {
    final nav = Navigator.of(context);
    final auth = context.read<AuthProvider>();
    showAdaptiveDialog(
      context: context,
      builder: (ctx) => AlertDialog.adaptive(
        title: const Text('確認登出'),
        content: const Text('您確定要登出嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await auth.signOut();
              nav.pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
              );
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('登出'),
          ),
        ],
      ),
    );
  }
}
