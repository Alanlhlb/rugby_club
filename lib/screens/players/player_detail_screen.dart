import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/player.dart';
import '../../models/app_user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
import '../../services/image_upload_service.dart';
import 'player_edit_screen.dart';

class PlayerDetailScreen extends StatefulWidget {
  final Player player;
  const PlayerDetailScreen({super.key, required this.player});
  @override
  State<PlayerDetailScreen> createState() => _PlayerDetailScreenState();
}

class _PlayerDetailScreenState extends State<PlayerDetailScreen> {
  late Player _player;
  bool _editing = false;
  late final TextEditingController _injuryController;

  @override
  void initState() {
    super.initState();
    _player = widget.player;
    _injuryController = TextEditingController(text: _player.injuryNotes ?? '');
  }

  @override
  void dispose() {
    _injuryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final canEdit =
        user != null &&
        (user.role == UserRole.admin ||
            user.role == UserRole.coach ||
            user.playerId == _player.id);

    // When not editing, always show the latest data from Provider
    if (!_editing) {
      final latest = context.watch<PlayerProvider>().getPlayerById(_player.id);
      if (latest != null) {
        _player = latest;
        final newNotes = latest.injuryNotes ?? '';
        if (_injuryController.text != newNotes) {
          _injuryController.text = newNotes;
        }
      }
    }
    final isAdminOrCoach =
        user != null &&
        (user.role == UserRole.admin || user.role == UserRole.coach);

    return Scaffold(
      appBar: AppBar(
        title: Text(_player.name),
        actions: [
          if (canEdit)
            IconButton(
              icon: Icon(_editing ? Icons.check : Icons.edit, size: 20),
              onPressed: () async {
                if (_editing) await _save();
                setState(() => _editing = !_editing);
              },
            ),
          if (isAdminOrCoach)
            PopupMenuButton<String>(
              icon: Icon(Icons.adaptive.more),
              onSelected: (v) {
                if (v == 'delete') _deleteConfirm(context);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'delete',
                  child: Text('刪除球員', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // ─── Avatar header ───
          Center(
            child: GestureDetector(
              onTap: _editing ? _pickPhoto : null,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 42,
                    backgroundColor: AppColors.primaryMuted,
                    backgroundImage:
                        _player.photoUrl != null && _player.photoUrl!.isNotEmpty
                        ? (_player.photoUrl!.startsWith('data:')
                              ? MemoryImage(
                                  base64Decode(
                                    _player.photoUrl!.split(',').last,
                                  ),
                                )
                              : NetworkImage(_player.photoUrl!)
                                    as ImageProvider)
                        : null,
                    child: _player.photoUrl == null || _player.photoUrl!.isEmpty
                        ? Text(
                            '${_player.jerseyNumber}',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                            ),
                          )
                        : null,
                  ),
                  if (_editing)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              _player.name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (_player.positions.isNotEmpty && !_editing)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _player.positions.join(', ').toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.textHint,
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          if (_editing)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: OutlinedButton.icon(
                onPressed: () async {
                  final updated = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PlayerEditScreen(player: _player),
                    ),
                  );
                  if (updated == true && mounted) {
                    setState(() => _editing = false);
                  }
                },
                icon: const Icon(Icons.edit, size: 16),
                label: Text(
                  _player.positions.isEmpty
                      ? '設定位置'
                      : '編輯位置: ${_player.positions.join(', ')}',
                ),
              ),
            ),
          const SizedBox(height: 20),

          // ─── Leadership ───
          _section('領導角色', [
            _sw(
              '隊長',
              'C',
              AppColors.secondary,
              _player.isCaptain,
              (v) => setState(() => _player = _player.copyWith(isCaptain: v)),
            ),
            _sw(
              '副隊長',
              'VC',
              AppColors.secondaryLight,
              _player.isViceCaptain,
              (v) =>
                  setState(() => _player = _player.copyWith(isViceCaptain: v)),
            ),
          ]),

          _section('球員狀態', [
            _sw(
              '傷病',
              '⚕',
              AppColors.error,
              _player.isInjured,
              (v) => setState(() => _player = _player.copyWith(isInjured: v)),
            ),
            if (_player.isInjured)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: '傷病備註（例：左膝韌帶拉傷）',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  controller: _injuryController,
                  enabled: _editing,
                  style: const TextStyle(fontSize: 13),
                  onChanged: (v) => _player = _player.copyWith(injuryNotes: v),
                ),
              ),
            _stat('停賽', _player.isSuspended ? '是 (紅牌)' : '否'),
          ]),

          _section('特殊技能', [
            _sw(
              'Kicker',
              'K',
              AppColors.secondary,
              _player.isKicker,
              (v) => setState(() => _player = _player.copyWith(isKicker: v)),
            ),
          ]),

          _section('Lineout 角色', [
            _sw(
              'Thrower',
              'T',
              AppColors.info,
              _player.isLineoutThrower,
              (v) => setState(
                () => _player = _player.copyWith(isLineoutThrower: v),
              ),
            ),
            _sw(
              'Jumper',
              'J',
              AppColors.primary,
              _player.isLineoutJumper,
              (v) => setState(
                () => _player = _player.copyWith(isLineoutJumper: v),
              ),
            ),
            _sw(
              'Lifter',
              'L',
              const Color(0xFFA855F7),
              _player.isLineoutLifter,
              (v) => setState(
                () => _player = _player.copyWith(isLineoutLifter: v),
              ),
            ),
          ]),

          // ─── Stats ───
          _section('統計數據', [
            _stat('達陣數', '${_player.tries}'),
            _stat('轉換', '${_player.conversions}'),
            _stat('罰球', '${_player.penalties}'),
            _stat('落踢', '${_player.dropGoals}'),
            _stat('總得分', '${_player.totalPoints}'),
            _stat('黃牌', '${_player.yellowCards}'),
            _stat('紅牌', '${_player.redCards}'),
            if (_player.eventsTotal > 0)
              _stat(
                '出席率',
                '${((_player.eventsAttended / _player.eventsTotal) * 100).toStringAsFixed(1)}%',
              ),
          ]),

          if (_player.height != null || _player.weight != null)
            _section('身體數據', [
              if (_player.height != null) _stat('身高', '${_player.height} cm'),
              if (_player.weight != null) _stat('體重', '${_player.weight} kg'),
            ]),

          const SizedBox(height: 20),
          _tagsRow(),
        ],
      ),
    );
  }

  // ─── Helpers ───
  Widget _section(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _sw(
    String label,
    String badge,
    Color color,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return ListTile(
      dense: true,
      leading: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: value ? color : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: Text(
            badge,
            style: TextStyle(
              color: value ? Colors.white : AppColors.textHint,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ),
      ),
      title: Text(label, style: const TextStyle(fontSize: 13)),
      trailing: _editing
          ? Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeTrackColor: AppColors.primary,
            )
          : Icon(
              value ? Icons.check_circle : Icons.cancel,
              color: value
                  ? AppColors.success
                  : AppColors.textHint.withAlpha(80),
              size: 22,
            ),
    );
  }

  Widget _stat(String label, String value) {
    return ListTile(
      dense: true,
      title: Text(label, style: const TextStyle(fontSize: 13)),
      trailing: Text(
        value,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _tagsRow() {
    final entries = <MapEntry<String, Color>>[];
    if (_player.isCaptain) entries.add(MapEntry('隊長', AppColors.secondary));
    if (_player.isViceCaptain) {
      entries.add(MapEntry('副隊長', AppColors.secondaryLight));
    }
    if (_player.isKicker) entries.add(MapEntry('Kicker', AppColors.secondary));
    if (_player.isLineoutThrower) {
      entries.add(MapEntry('Thrower', AppColors.info));
    }
    if (_player.isLineoutJumper) {
      entries.add(MapEntry('Jumper', AppColors.primary));
    }
    if (_player.isLineoutLifter) {
      entries.add(MapEntry('Lifter', const Color(0xFFA855F7)));
    }

    if (entries.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '目前標籤',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: entries
              .map(
                (e) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: e.value.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    e.key,
                    style: TextStyle(
                      color: e.value,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Future<void> _pickPhoto() async {
    final pp = context.read<PlayerProvider>();
    final scaffold = ScaffoldMessenger.of(context);
    final url = await ImageUploadService.pickCropAndUpload(
      context: context,
      storagePath: 'player_photos/${_player.id}/photo.jpg',
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
      lockAspectRatio: true,
      cropAspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
    );
    if (url == null || !mounted) return;
    setState(() {
      _player = _player.copyWith(photoUrl: url);
    });
    // Auto-save photoUrl to Firestore immediately
    try {
      await pp.updatePlayer(_player.id, {'photoUrl': url});
      if (mounted) {
        scaffold.showSnackBar(const SnackBar(content: Text('頭像已更新')));
      }
    } catch (e) {
      if (mounted) {
        scaffold.showSnackBar(SnackBar(content: Text('頭像儲存失敗: $e')));
      }
    }
  }

  void _deleteConfirm(BuildContext context) {
    showAdaptiveDialog(
      context: context,
      builder: (ctx) => AlertDialog.adaptive(
        title: const Text('刪除球員'),
        content: Text('確定要刪除「${_player.name}」嗎？此操作無法復原。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final nav = Navigator.of(context);
              final scaffold = ScaffoldMessenger.of(context);
              final pp = context.read<PlayerProvider>();
              Navigator.pop(ctx);
              try {
                await pp.deletePlayer(_player.id);
                if (mounted) nav.pop('deleted');
              } catch (e) {
                if (mounted) {
                  scaffold.showSnackBar(SnackBar(content: Text('刪除失敗: $e')));
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final pp = context.read<PlayerProvider>();
    final data = <String, dynamic>{
      'isCaptain': _player.isCaptain,
      'isViceCaptain': _player.isViceCaptain,
      'isKicker': _player.isKicker,
      'isLineoutThrower': _player.isLineoutThrower,
      'isLineoutJumper': _player.isLineoutJumper,
      'isLineoutLifter': _player.isLineoutLifter,
      'isInjured': _player.isInjured,
      'injuryNotes': _player.injuryNotes ?? '',
      'photoUrl': _player.photoUrl ?? '',
      'positions': _player.positions,
    };
    try {
      await pp.updatePlayer(_player.id, data);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('變更已儲存')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('儲存失敗: $e')));
      }
    }
  }
}
