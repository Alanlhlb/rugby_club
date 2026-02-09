import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/player.dart';
import '../../providers/player_provider.dart';

class PlayerEditScreen extends StatefulWidget {
  final Player player;
  const PlayerEditScreen({super.key, required this.player});
  @override
  State<PlayerEditScreen> createState() => _PlayerEditScreenState();
}

class _PlayerEditScreenState extends State<PlayerEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _name;
  late TextEditingController _jersey;
  late TextEditingController _height;
  late TextEditingController _weight;
  late TextEditingController _injuryNotes;
  late List<String> _positions;
  late bool _isInjured;
  late bool _isCaptain;
  late bool _isViceCaptain;
  late bool _isKicker;
  late bool _isLineoutJumper;
  late bool _isLineoutLifter;
  late bool _isLineoutThrower;
  bool _saving = false;

  static const _numberedPositions = {
    1: 'Loosehead Prop',
    2: 'Hooker',
    3: 'Tighthead Prop',
    4: 'Lock (4)',
    5: 'Lock (5)',
    6: 'Blindside Flanker',
    7: 'Openside Flanker',
    8: 'Number 8',
    9: 'Scrum-half',
    10: 'Fly-half',
    11: 'Left Wing',
    12: 'Inside Centre',
    13: 'Outside Centre',
    14: 'Right Wing',
    15: 'Fullback',
  };

  @override
  void initState() {
    super.initState();
    final p = widget.player;
    _name = TextEditingController(text: p.name);
    _jersey = TextEditingController(
      text: p.jerseyNumber == 0 ? '' : '${p.jerseyNumber}',
    );
    _height = TextEditingController(
      text: p.height != null ? '${p.height}' : '',
    );
    _weight = TextEditingController(
      text: p.weight != null ? '${p.weight}' : '',
    );
    _injuryNotes = TextEditingController(text: p.injuryNotes ?? '');
    _positions = List<String>.from(p.positions);
    _isInjured = p.isInjured;
    _isCaptain = p.isCaptain;
    _isViceCaptain = p.isViceCaptain;
    _isKicker = p.isKicker;
    _isLineoutJumper = p.isLineoutJumper;
    _isLineoutLifter = p.isLineoutLifter;
    _isLineoutThrower = p.isLineoutThrower;
  }

  @override
  void dispose() {
    _name.dispose();
    _jersey.dispose();
    _height.dispose();
    _weight.dispose();
    _injuryNotes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final pp = context.read<PlayerProvider>();
    final jerseyNum = int.tryParse(_jersey.text.trim()) ?? 0;
    if (jerseyNum != 0 &&
        pp.isJerseyNumberTaken(jerseyNum, excludePlayerId: widget.player.id)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('球衣號碼 $jerseyNum 已被使用')));
      return;
    }
    setState(() => _saving = true);
    try {
      final data = <String, dynamic>{
        'name': _name.text.trim(),
        'jerseyNumber': jerseyNum,
        'positions': _positions,
        'height': _height.text.trim().isNotEmpty
            ? double.tryParse(_height.text.trim())
            : null,
        'weight': _weight.text.trim().isNotEmpty
            ? double.tryParse(_weight.text.trim())
            : null,
        'isInjured': _isInjured,
        'injuryNotes': _injuryNotes.text.trim().isNotEmpty
            ? _injuryNotes.text.trim()
            : null,
        'isCaptain': _isCaptain,
        'isViceCaptain': _isViceCaptain,
        'isKicker': _isKicker,
        'isLineoutJumper': _isLineoutJumper,
        'isLineoutLifter': _isLineoutLifter,
        'isLineoutThrower': _isLineoutThrower,
      };
      await context.read<PlayerProvider>().updatePlayer(widget.player.id, data);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('資料已更新')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('更新失敗: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('編輯資料'),
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
            // ─── Basic Info ───
            _label('基本資料'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: '姓名',
                prefixIcon: Icon(Icons.person, size: 20),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '請輸入姓名' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _jersey,
              decoration: const InputDecoration(
                labelText: '背號',
                prefixIcon: Icon(Icons.tag, size: 20),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _height,
                    decoration: const InputDecoration(
                      labelText: '身高 (cm)',
                      prefixIcon: Icon(Icons.height, size: 20),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _weight,
                    decoration: const InputDecoration(
                      labelText: '體重 (kg)',
                      prefixIcon: Icon(Icons.fitness_center, size: 20),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ─── Positions ───
            _label('位置'),
            const SizedBox(height: 8),
            _positionDropdown(0, '第一位置', AppColors.primary),
            const SizedBox(height: 12),
            _positionDropdown(1, '第二位置', AppColors.secondary),
            const SizedBox(height: 12),
            _positionDropdown(2, '第三位置', AppColors.textSecondary),
            const SizedBox(height: 24),

            // ─── Tags ───
            _label('標籤'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                children: [
                  _tagSwitch(
                    '隊長',
                    Icons.star,
                    const Color(0xFFFFD700),
                    _isCaptain,
                    (v) {
                      setState(() {
                        _isCaptain = v;
                        if (v) _isViceCaptain = false;
                      });
                    },
                  ),
                  _tagSwitch(
                    '副隊長',
                    Icons.star_half,
                    const Color(0xFFB0BEC5),
                    _isViceCaptain,
                    (v) {
                      setState(() {
                        _isViceCaptain = v;
                        if (v) _isCaptain = false;
                      });
                    },
                  ),
                  const Divider(height: 16),
                  _tagSwitch(
                    'Kicker',
                    Icons.sports_rugby,
                    const Color(0xFFFF6F00),
                    _isKicker,
                    (v) {
                      setState(() => _isKicker = v);
                    },
                  ),
                  _tagSwitch(
                    'Lineout Thrower',
                    Icons.sports_handball,
                    const Color(0xFF00BCD4),
                    _isLineoutThrower,
                    (v) {
                      setState(() => _isLineoutThrower = v);
                    },
                  ),
                  _tagSwitch(
                    'Lineout Jumper',
                    Icons.height,
                    const Color(0xFF4CAF50),
                    _isLineoutJumper,
                    (v) {
                      setState(() => _isLineoutJumper = v);
                    },
                  ),
                  _tagSwitch(
                    'Lineout Lifter',
                    Icons.fitness_center,
                    const Color(0xFFA855F7),
                    _isLineoutLifter,
                    (v) {
                      setState(() => _isLineoutLifter = v);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ─── Injury ───
            _label('傷病狀態'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                children: [
                  SwitchListTile.adaptive(
                    title: const Text('傷病中', style: TextStyle(fontSize: 14)),
                    value: _isInjured,
                    onChanged: (v) => setState(() => _isInjured = v),
                    activeTrackColor: AppColors.error,
                    secondary: Icon(
                      Icons.healing,
                      size: 20,
                      color: _isInjured ? AppColors.error : AppColors.textHint,
                    ),
                  ),
                  if (_isInjured)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: TextFormField(
                        controller: _injuryNotes,
                        decoration: const InputDecoration(
                          labelText: '傷病備註',
                          hintText: '描述傷病情況',
                          prefixIcon: Icon(Icons.notes, size: 20),
                        ),
                        maxLines: 2,
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

  Widget _positionDropdown(int index, String label, Color color) {
    // Get current value for this position slot
    final currentValue = index < _positions.length ? _positions[index] : null;

    final resolvedValue =
        currentValue != null && _numberedPositions.containsValue(currentValue)
        ? currentValue
        : null;

    return DropdownButtonFormField<String>(
      key: ValueKey('pos_${index}_$resolvedValue'),
      initialValue: resolvedValue,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: color, fontWeight: FontWeight.w600),
        prefixIcon: Icon(
          index == 0
              ? Icons.looks_one
              : index == 1
              ? Icons.looks_two
              : Icons.looks_3,
          size: 20,
          color: color,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
      ),
      items: [
        const DropdownMenuItem<String>(
          value: null,
          child: Text('未設定', style: TextStyle(color: AppColors.textHint)),
        ),
        ..._numberedPositions.entries.map((e) {
          return DropdownMenuItem<String>(
            value: e.value,
            child: Text(
              '${e.key}. ${e.value}',
              style: const TextStyle(fontSize: 14),
            ),
          );
        }),
      ],
      onChanged: (value) {
        setState(() {
          if (value == null) {
            // Remove this position and shift remaining ones
            if (index < _positions.length) {
              _positions.removeAt(index);
            }
          } else {
            // Remove duplicate if this position is already selected elsewhere
            _positions.remove(value);
            if (index < _positions.length) {
              _positions[index] = value;
            } else {
              // Fill gaps if needed
              while (_positions.length < index) {
                _positions.add('');
              }
              _positions.add(value);
            }
            // Clean up empty entries
            _positions.removeWhere((p) => p.isEmpty);
          }
        });
      },
    );
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

  Widget _tagSwitch(
    String label,
    IconData icon,
    Color color,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 18, color: value ? color : AppColors.textHint),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: value ? AppColors.textPrimary : AppColors.textSecondary,
                fontWeight: value ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: color,
          ),
        ],
      ),
    );
  }
}
