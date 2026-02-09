import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../models/join_request.dart';
import '../../providers/auth_provider.dart';
import '../../providers/team_provider.dart';
import '../../providers/join_request_provider.dart';

class JoinRequestsScreen extends StatefulWidget {
  const JoinRequestsScreen({super.key});
  @override
  State<JoinRequestsScreen> createState() => _JoinRequestsScreenState();
}

class _JoinRequestsScreenState extends State<JoinRequestsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final teamId = context.read<TeamProvider>().currentTeam?.id;
      if (teamId != null) {
        context.read<JoinRequestProvider>().loadPendingRequests(teamId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final jrp = context.watch<JoinRequestProvider>();
    final requests = jrp.pendingRequests;

    return Scaffold(
      appBar: AppBar(title: const Text('加入申請')),
      body: jrp.isLoading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : requests.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inbox, size: 48, color: AppColors.textHint),
                      SizedBox(height: 8),
                      Text(
                        '暫無待審批的申請',
                        style: TextStyle(color: AppColors.textHint),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: requests.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _requestCard(requests[i]),
                ),
    );
  }

  Widget _requestCard(JoinRequest request) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primaryMuted,
                child: Text(
                  request.userName.isNotEmpty
                      ? request.userName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.userName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      request.userEmail,
                      style: const TextStyle(
                        color: AppColors.textHint,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: request.requestedRole.name == 'coach'
                      ? AppColors.secondary.withAlpha(30)
                      : AppColors.info.withAlpha(30),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  request.requestedRole.displayName,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: request.requestedRole.name == 'coach'
                        ? AppColors.secondary
                        : AppColors.info,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '申請時間：${DateFormat('yyyy/MM/dd HH:mm').format(request.createdAt)}',
            style: const TextStyle(color: AppColors.textHint, fontSize: 11),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _reject(request),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: BorderSide(color: AppColors.error.withAlpha(80)),
                  ),
                  child: const Text('拒絕'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () => _approve(request),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.success,
                  ),
                  child: const Text('批准'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _approve(JoinRequest request) async {
    final auth = context.read<AuthProvider>();
    final jrp = context.read<JoinRequestProvider>();
    final scaffold = ScaffoldMessenger.of(context);
    final responderId = auth.firebaseUser?.uid ?? '';

    final confirmed = await showAdaptiveDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog.adaptive(
        title: const Text('確認批准'),
        content: Text(
          '批准 ${request.userName} 以 ${request.requestedRole.displayName} 身份加入球隊？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('批准'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await jrp.approveRequest(request, responderId);
    scaffold.showSnackBar(
      SnackBar(content: Text('已批准 ${request.userName} 的加入申請')),
    );
  }

  Future<void> _reject(JoinRequest request) async {
    final auth = context.read<AuthProvider>();
    final jrp = context.read<JoinRequestProvider>();
    final scaffold = ScaffoldMessenger.of(context);
    final responderId = auth.firebaseUser?.uid ?? '';

    final confirmed = await showAdaptiveDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog.adaptive(
        title: const Text('確認拒絕'),
        content: Text('拒絕 ${request.userName} 的加入申請？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('拒絕'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await jrp.rejectRequest(request, responderId);
    scaffold.showSnackBar(
      SnackBar(content: Text('已拒絕 ${request.userName} 的加入申請')),
    );
  }
}
