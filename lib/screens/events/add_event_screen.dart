import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:geocoding/geocoding.dart';
import '../../core/constants/venues.dart';
import '../../services/map_launcher_service.dart';
import '../../core/constants/app_colors.dart';
import '../../models/event.dart';
import '../../providers/event_provider.dart';

class AddEventScreen extends StatefulWidget {
  final EventType initialType;
  final String teamId;
  final String? seasonId;
  final Event? editEvent;
  final DateTime? initialDate;
  const AddEventScreen({
    super.key,
    this.initialType = EventType.training,
    required this.teamId,
    this.seasonId,
    this.editEvent,
    this.initialDate,
  });

  bool get isEditing => editEvent != null;
  @override
  State<AddEventScreen> createState() => _AddEventScreenState();
}

class _AddEventScreenState extends State<AddEventScreen> {
  final _formKey = GlobalKey<FormState>();
  late EventType _type;
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _time = const TimeOfDay(hour: 19, minute: 0);
  final _opponent = TextEditingController();
  final _location = TextEditingController();
  final _notes = TextEditingController();
  bool _friendly = true;
  bool _saving = false;
  double? _latitude;
  double? _longitude;

  // Autocomplete controller reference for syncing location text
  TextEditingController? _autoCompleteController;

  @override
  void initState() {
    super.initState();
    if (widget.editEvent != null) {
      final e = widget.editEvent!;
      _type = e.type;
      _date = e.date;
      _time = TimeOfDay(hour: e.date.hour, minute: e.date.minute);
      _opponent.text = e.opponent ?? '';
      _location.text = e.location ?? '';
      _notes.text = e.notes ?? '';
      _friendly = e.isFriendly;
      _latitude = e.latitude;
      _longitude = e.longitude;
    } else {
      _type = widget.initialType;
      if (widget.initialDate != null) {
        _date = widget.initialDate!;
      }
    }
  }

  Event? _getLastEventOfType(EventType type) {
    final ep = context.read<EventProvider>();
    final sorted = ep.events.where((e) => e.type == type).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return sorted.isNotEmpty ? sorted.first : null;
  }

  void _applyLastSettings() {
    final last = _getLastEventOfType(_type);
    if (last == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('找不到上次同類型活動的設定')));
      return;
    }
    setState(() {
      _time = TimeOfDay(hour: last.date.hour, minute: last.date.minute);
      if (last.location != null && last.location!.isNotEmpty) {
        _location.text = last.location!;
        _autoCompleteController?.text = last.location!;
      }
      _latitude = last.latitude;
      _longitude = last.longitude;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已套用上次設定')));
  }

  @override
  void dispose() {
    _opponent.dispose();
    _location.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final dt = DateTime(
        _date.year,
        _date.month,
        _date.day,
        _time.hour,
        _time.minute,
      );

      if (widget.isEditing) {
        // Update existing event
        final data = <String, dynamic>{
          'date': dt,
          'type': _type.name,
          'opponent': _type == EventType.match ? _opponent.text.trim() : null,
          'location': _location.text.trim().isNotEmpty
              ? _location.text.trim()
              : null,
          'latitude': _latitude,
          'longitude': _longitude,
          'isFriendly': _friendly,
          'notes': _notes.text.trim().isNotEmpty ? _notes.text.trim() : null,
        };
        await context.read<EventProvider>().updateEvent(
          widget.editEvent!.id,
          data,
        );
        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('活動已更新')));
        }
      } else {
        // Create new event — write to Firestore directly
        final event = Event(
          id: '',
          teamId: widget.teamId,
          seasonId: widget.seasonId,
          date: dt,
          type: _type,
          opponent: _type == EventType.match ? _opponent.text.trim() : null,
          location: _location.text.trim().isNotEmpty
              ? _location.text.trim()
              : null,
          latitude: _latitude,
          longitude: _longitude,
          isFriendly: _friendly,
          notes: _notes.text.trim().isNotEmpty ? _notes.text.trim() : null,
          createdAt: DateTime.now(),
        );
        await context.read<EventProvider>().addEvent(event);
        if (mounted) {
          Navigator.pop(context, event);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('活動已建立')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('建立失敗: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? '編輯活動' : '新增活動'),
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
            _label('活動類型'),
            const SizedBox(height: 8),
            SegmentedButton<EventType>(
              segments: const [
                ButtonSegment(
                  value: EventType.match,
                  label: Text('比賽'),
                  icon: Icon(Icons.sports_rugby, size: 18),
                ),
                ButtonSegment(
                  value: EventType.training,
                  label: Text('訓練'),
                  icon: Icon(Icons.fitness_center, size: 18),
                ),
                ButtonSegment(
                  value: EventType.teamBuilding,
                  label: Text('活動'),
                  icon: Icon(Icons.groups, size: 18),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (t) => setState(() => _type = t.first),
            ),
            const SizedBox(height: 20),

            _label('日期與時間'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(DateFormat('yyyy/MM/dd').format(_date)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.access_time, size: 16),
                    label: Text(_time.format(context)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _applyLastSettings,
                icon: const Icon(Icons.history, size: 16),
                label: const Text('沿用上次設定（時間、地點）'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.info,
                  side: BorderSide(color: AppColors.info.withAlpha(80)),
                ),
              ),
            ),
            const SizedBox(height: 20),

            if (_type == EventType.match) ...[
              _label('比賽資訊'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _opponent,
                decoration: const InputDecoration(
                  labelText: '對手名稱',
                  prefixIcon: Icon(Icons.shield, size: 20),
                ),
                validator: (v) =>
                    (_type == EventType.match &&
                        (v == null || v.trim().isEmpty))
                    ? '請輸入對手名稱'
                    : null,
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                child: SwitchListTile.adaptive(
                  title: const Text('友誼賽', style: TextStyle(fontSize: 14)),
                  subtitle: Text(
                    _friendly ? '此為友誼賽' : '此為正式比賽',
                    style: const TextStyle(fontSize: 11),
                  ),
                  value: _friendly,
                  onChanged: (v) => setState(() => _friendly = v),
                  activeTrackColor: AppColors.primary,
                ),
              ),
              const SizedBox(height: 20),
            ],

            _label('地點'),
            const SizedBox(height: 8),
            Autocomplete<Venue>(
              optionsBuilder: (textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return const Iterable.empty();
                }
                final q = textEditingValue.text.toLowerCase();
                return kVenues.where((v) => v.searchText.contains(q));
              },
              displayStringForOption: (v) => v.displayName,
              onSelected: (v) {
                _location.text = v.displayName;
                setState(() {
                  _latitude = v.latitude;
                  _longitude = v.longitude;
                });
              },
              fieldViewBuilder: (ctx, controller, focusNode, onSubmit) {
                _autoCompleteController = controller;
                return TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    labelText: '活動地點',
                    hintText: '輸入地點名稱搜尋',
                    prefixIcon: const Icon(Icons.location_on, size: 20),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (controller.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.search, size: 20),
                            tooltip: '搜尋地點座標',
                            onPressed: () {
                              _location.text = controller.text;
                              _geocodeLocation();
                            },
                          ),
                      ],
                    ),
                  ),
                  onChanged: (v) {
                    _location.text = v;
                    setState(() {});
                  },
                );
              },
              optionsViewBuilder: (ctx, onSelected, options) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(8),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxHeight: 200,
                        maxWidth: 360,
                      ),
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (_, i) {
                          final opt = options.elementAt(i);
                          return ListTile(
                            dense: true,
                            leading: const Icon(
                              Icons.location_on,
                              size: 16,
                              color: AppColors.textHint,
                            ),
                            title: Text(
                              opt.displayName,
                              style: const TextStyle(fontSize: 13),
                            ),
                            onTap: () => onSelected(opt),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
            if (_latitude != null && _longitude != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  children: [
                    Icon(Icons.map, size: 18, color: AppColors.success),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '座標: ${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _openInMaps,
                      child: const Icon(
                        Icons.open_in_new,
                        size: 18,
                        color: AppColors.info,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() {
                        _latitude = null;
                        _longitude = null;
                      }),
                      child: const Icon(
                        Icons.close,
                        size: 18,
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),

            _label('備註'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notes,
              decoration: const InputDecoration(
                labelText: '備註 (選填)',
                prefixIcon: Icon(Icons.notes, size: 20),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
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

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _time);
    if (t != null) setState(() => _time = t);
  }

  Future<void> _geocodeLocation() async {
    final query = _location.text.trim();
    if (query.isEmpty) return;
    try {
      final locations = await locationFromAddress(query);
      if (locations.isNotEmpty && mounted) {
        setState(() {
          _latitude = locations.first.latitude;
          _longitude = locations.first.longitude;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已找到地點座標')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('找不到該地點的座標')));
      }
    }
  }

  Future<void> _openInMaps() async {
    if (_latitude == null || _longitude == null) return;
    final success = await MapLauncherService.openMap(
      latitude: _latitude,
      longitude: _longitude,
      query: _location.text.trim().isNotEmpty ? _location.text.trim() : null,
    );
    if (!success && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('無法開啟地圖')));
    }
  }
}
