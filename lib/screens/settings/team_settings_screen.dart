import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/team_provider.dart';
import '../../models/team.dart';
import '../../services/image_upload_service.dart';

class TeamSettingsScreen extends StatefulWidget {
  const TeamSettingsScreen({super.key});
  @override
  State<TeamSettingsScreen> createState() => _TeamSettingsScreenState();
}

class _TeamSettingsScreenState extends State<TeamSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _name;
  late String _primary;
  late String _secondary;
  late TeamLevel _level;
  String? _logoUrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final t = context.read<TeamProvider>().currentTeam;
    _name = TextEditingController(text: t?.name ?? '');
    _primary = t?.primaryColor ?? '#1B5E20';
    _secondary = t?.secondaryColor ?? '#FF6F00';
    _level = t?.level ?? TeamLevel.amateur;
    _logoUrl = t?.logoUrl;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final tp = context.read<TeamProvider>();
      await tp.updateTeam({
        'name': _name.text.trim(),
        'primaryColor': _primary,
        'secondaryColor': _secondary,
        'level': _level.name,
        if (_logoUrl != null) 'logoUrl': _logoUrl,
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('設定已儲存')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('儲存失敗: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('球隊設定'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                  )
                : const Text('儲存'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickLogo,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 46,
                      backgroundColor: Color(
                        int.parse(_primary.replaceFirst('#', '0xFF')),
                      ),
                      backgroundImage: _logoUrl != null && _logoUrl!.isNotEmpty
                          ? NetworkImage(_logoUrl!) as ImageProvider
                          : null,
                      child: _logoUrl == null || _logoUrl!.isEmpty
                          ? const Icon(
                              Icons.shield,
                              size: 44,
                              color: Colors.white,
                            )
                          : null,
                    ),
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
            const SizedBox(height: 20),

            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: '球隊名稱',
                prefixIcon: Icon(Icons.shield, size: 20),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '請輸入球隊名稱' : null,
            ),
            const SizedBox(height: 14),

            DropdownButtonFormField<TeamLevel>(
              initialValue: _level,
              decoration: const InputDecoration(
                labelText: '球隊級別',
                prefixIcon: Icon(Icons.emoji_events, size: 20),
              ),
              items: TeamLevel.values
                  .map(
                    (l) =>
                        DropdownMenuItem(value: l, child: Text(l.displayName)),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _level = v);
              },
            ),
            const SizedBox(height: 20),

            _label('球隊顏色'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _ColorPickerTile(
                    label: '主色',
                    color: _primary,
                    onColorChanged: (c) => setState(() => _primary = c),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ColorPickerTile(
                    label: '副色',
                    color: _secondary,
                    onColorChanged: (c) => setState(() => _secondary = c),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            _label('球隊統計'),
            const SizedBox(height: 8),
            Consumer<TeamProvider>(
              builder: (_, prov, _) {
                final t = prov.currentTeam;
                if (t == null) return const SizedBox.shrink();
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    children: [
                      _stat('總比賽', '${t.totalMatches}'),
                      _stat('勝場', '${t.matchesWon}'),
                      _stat('敗場', '${t.matchesLost}'),
                      _stat('平局', '${t.matchesDrawn}'),
                      _stat('勝率', '${(t.winRate * 100).toStringAsFixed(1)}%'),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Divider(color: AppColors.divider, height: 1),
                      ),
                      _stat('總得分', '${t.totalScored}'),
                      _stat('總失分', '${t.totalConceded}'),
                      _stat(
                        '分差',
                        '${t.pointDifference > 0 ? '+' : ''}${t.pointDifference}',
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Divider(color: AppColors.divider, height: 1),
                      ),
                      _stat(
                        '轉換成功率',
                        '${(t.conversionRate * 100).toStringAsFixed(1)}%',
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickLogo() async {
    final tp = context.read<TeamProvider>();
    final teamId = tp.currentTeam?.id;
    if (teamId == null) return;

    final url = await ImageUploadService.pickCropAndUpload(
      context: context,
      storagePath: 'team_logos/$teamId/logo.jpg',
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
      lockAspectRatio: true,
      cropAspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
    );
    if (url == null) return;
    setState(() => _logoUrl = url);
  }

  Widget _label(String t) => Text(
    t,
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: AppColors.primary,
      letterSpacing: 0.5,
    ),
  );

  Widget _stat(String label, String value) => Padding(
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
}

class _ColorPickerTile extends StatelessWidget {
  final String label;
  final String color;
  final ValueChanged<String> onColorChanged;
  const _ColorPickerTile({
    required this.label,
    required this.color,
    required this.onColorChanged,
  });

  static const List<String> _presets = [
    '#1B5E20',
    '#2E7D32',
    '#388E3C',
    '#1565C0',
    '#1976D2',
    '#2196F3',
    '#C62828',
    '#D32F2F',
    '#E53935',
    '#F57C00',
    '#FF9800',
    '#FFB74D',
    '#6A1B9A',
    '#7B1FA2',
    '#9C27B0',
    '#212121',
    '#424242',
    '#616161',
    '#000000',
    '#FFFFFF',
    '#FFD700',
  ];

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _pick(context),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.card,
          border: Border.all(color: AppColors.divider),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Color(int.parse(color.replaceFirst('#', '0xFF'))),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.divider),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textHint,
                    ),
                  ),
                  Text(
                    color.toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _pick(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '選擇$label',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _presets.map((c) {
                  final sel = c == color;
                  return InkWell(
                    onTap: () {
                      onColorChanged(c);
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Color(int.parse(c.replaceFirst('#', '0xFF'))),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: sel ? AppColors.primary : AppColors.divider,
                          width: sel ? 3 : 1,
                        ),
                      ),
                      child: sel
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 18,
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
