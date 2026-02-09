import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import '../../providers/player_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/event_provider.dart';
import '../../providers/team_provider.dart';
import '../../models/player.dart';
import '../../models/app_user.dart';
import '../../models/attendance.dart';
import '../../models/match_state.dart';
import '../../services/auto_fill_service.dart';
import '../../services/share_service.dart';
import '../../services/match_service.dart';
import '../../services/season_service.dart';
import '../../widgets/rugby_pitch_background.dart';
import '../../widgets/fifa_style_card.dart';
import '../../widgets/lineout_checker.dart';

enum MatchPhase { firstHalf, halfTime, secondHalf, fullTime }

enum MatchActionType {
  substitution,
  fieldSwap,
  fieldMove,
  tryScore,
  conversion,
  penalty,
  dropGoal,
  yellowCard,
  redCard,
}

class MatchAction {
  final MatchActionType type;
  final DateTime timestamp;
  final int minute;
  final Map<String, dynamic> data;

  MatchAction({
    required this.type,
    required this.timestamp,
    required this.minute,
    required this.data,
  });
}

/// Match Engine Screen - Pitch View with Right Side Action Bar
class MatchEngineScreen extends StatefulWidget {
  final bool isPreviewMode;
  final String? opponent;
  final Map<int, Player?>? initialLineup;
  final String? eventId;

  const MatchEngineScreen({
    super.key,
    this.isPreviewMode = true,
    this.opponent,
    this.initialLineup,
    this.eventId,
  });

  @override
  State<MatchEngineScreen> createState() => _MatchEngineScreenState();
}

class _MatchEngineScreenState extends State<MatchEngineScreen> {
  // Lineup state
  final Map<int, Player?> _onField = {};
  final List<Player> _bench = [];
  final List<Player> _available = [];

  // Match state
  int _homeScore = 0;
  int _awayScore = 0;
  int _elapsedSeconds = 0;
  bool _isTimerRunning = false;
  MatchPhase _phase = MatchPhase.firstHalf;
  Timer? _timer;

  // UI state
  bool _isAvailableExpanded = true;
  bool _canControl = false;
  bool _isActionRailExpanded = true;

  // Match-specific player states (tracks cards given during this match)
  final Map<String, int> _matchYellowCards = {};
  final Map<String, int> _matchRedCards = {};

  // Positions locked due to red card (no substitution allowed)
  // Maps position → the player who got the red card
  final Map<int, Player> _redCardLockedPositions = {};

  // Yellow card timers
  final Map<String, Timer> _yellowCardTimers = {};
  final Map<String, int> _yellowCardSecondsRemaining = {};

  // Action history for undo
  final List<MatchAction> _actionHistory = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialLineup != null) {
      _onField.addAll(widget.initialLineup!);
    }
    _loadPlayers();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = context.read<AuthProvider>().currentUser;
    _canControl =
        user != null &&
        (user.role == UserRole.admin || user.role == UserRole.coach);
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var timer in _yellowCardTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  void _loadPlayers() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final playerProvider = context.read<PlayerProvider>();
      final eventProvider = context.read<EventProvider>();

      // Get attendance map if eventId is present
      Map<String, AttendanceStatus>? attendance;
      if (widget.eventId != null) {
        attendance = eventProvider.getAttendance(widget.eventId!);
      }

      final onFieldIds = _onField.values
          .where((p) => p != null)
          .map((p) => p!.id)
          .toSet();

      setState(() {
        _bench.clear();
        _available.clear();

        for (var player in playerProvider.players) {
          if (onFieldIds.contains(player.id)) continue;
          if (player.isInjured || player.redCards > 0) continue;

          // If we have attendance data, only show attending/pending players
          // or players who are explicitly in the lineup/bench (handled above)
          if (attendance != null) {
            final status = attendance[player.id];
            if (status == AttendanceStatus.notAttending) continue;
          }

          if (_bench.length < 8) {
            _bench.add(player);
          } else {
            _available.add(player);
          }
        }
      });
    });
  }

  // ═════════════════════════════════════════════════
  //  SCAFFOLD
  // ═════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _confirmExit();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0E13),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0B0E13),
          elevation: 0,
          title: Text(
            widget.isPreviewMode ? '陣容編排' : 'vs ${widget.opponent ?? "對手"}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          actions: [
            if (widget.isPreviewMode)
              Container(
                margin: const EdgeInsets.only(right: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '練習',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.list_alt, size: 20),
              onPressed: _showMatchEvents,
            ),
            if (_canControl)
              PopupMenuButton<String>(
                icon: Icon(Icons.adaptive.more),
                onSelected: _handleMenuAction,
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'autofill', child: Text('智能填充陣容')),
                  const PopupMenuItem(
                    value: 'check_lineout',
                    child: Text('檢查 Lineout'),
                  ),
                  const PopupMenuItem(
                    value: 'share_lineout',
                    child: Text('分享陣容'),
                  ),
                  const PopupMenuItem(value: 'clear', child: Text('清除陣容')),
                  const PopupMenuItem(value: 'load', child: Text('載入陣容')),
                  const PopupMenuItem(value: 'save', child: Text('儲存陣容')),
                  if (widget.isPreviewMode)
                    const PopupMenuItem(
                      value: 'convert',
                      child: Text('轉為正式比賽'),
                    ),
                  const PopupMenuItem(value: 'end', child: Text('結束比賽')),
                ],
              ),
          ],
        ),
        body: Column(
          children: [
            _buildScorebar(),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _buildPitch()),
                  _buildActionRail(),
                ],
              ),
            ),
            _buildPlayerPanel(),
          ],
        ),
      ),
    );
  }

  void _confirmExit() {
    final hasActivity =
        _actionHistory.isNotEmpty || _onField.values.any((p) => p != null);
    if (!hasActivity) {
      Navigator.of(context).pop();
      return;
    }
    showAdaptiveDialog(
      context: context,
      builder: (ctx) => AlertDialog.adaptive(
        title: const Text('離開比賽'),
        content: const Text('比賽資料尚未儲存，確定要離開嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('繼續比賽'),
          ),
          if (_canControl && _onField.values.any((p) => p != null))
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _saveCurrentLineup().then((_) {
                  if (mounted) Navigator.of(context).pop();
                });
              },
              style: TextButton.styleFrom(foregroundColor: Colors.orange),
              child: const Text('儲存名單並離開'),
            ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('不儲存離開'),
          ),
        ],
      ),
    );
  }

  String _phaseLabel(MatchPhase phase) {
    switch (phase) {
      case MatchPhase.firstHalf:
        return '上半場';
      case MatchPhase.halfTime:
        return '中場休息';
      case MatchPhase.secondHalf:
        return '下半場';
      case MatchPhase.fullTime:
        return '全場結束';
    }
  }

  Color _phaseColor(MatchPhase phase) {
    switch (phase) {
      case MatchPhase.firstHalf:
        return const Color(0xFF2E7D32);
      case MatchPhase.halfTime:
        return const Color(0xFFE65100);
      case MatchPhase.secondHalf:
        return const Color(0xFF1565C0);
      case MatchPhase.fullTime:
        return const Color(0xFFC62828);
    }
  }

  // ═════════════════════════════════════════════════
  //  SCORE BAR  (compact, dark)
  // ═════════════════════════════════════════════════
  Widget _buildScorebar() {
    return Container(
      height: 62,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D1117), Color(0xFF161B22), Color(0xFF0D1117)],
          stops: [0.0, 0.5, 1.0],
        ),
        border: Border(
          bottom: BorderSide(color: Color(0xFF21262D), width: 0.5),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          // Home side
          Expanded(
            child: GestureDetector(
              onTap: _canControl ? () => _showScoreDialog(true) : null,
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'HOME',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          color: Colors.white30,
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        '$_homeScore',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Centre: Timer + Phase
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: _canControl ? _toggleTimer : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _isTimerRunning
                        ? const Color(0xFF1B5E20)
                        : const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _isTimerRunning
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFF30363D),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isTimerRunning ? Icons.pause : Icons.play_arrow,
                        size: 12,
                        color: _isTimerRunning
                            ? Colors.white70
                            : Colors.white38,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _displayTime(),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 2),
              GestureDetector(
                onTap: _canControl ? _showPhaseControl : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: _phaseColor(_phase).withAlpha(40),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: _phaseColor(_phase).withAlpha(80),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    _phaseLabel(_phase),
                    style: TextStyle(
                      fontSize: 9,
                      color: _phaseColor(_phase),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Away side
          Expanded(
            child: GestureDetector(
              onTap: _canControl ? () => _showScoreDialog(false) : null,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        widget.opponent?.toUpperCase() ?? 'AWAY',
                        style: const TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          color: Colors.white30,
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        '$_awayScore',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 6,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE65100),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════
  //  PITCH
  // ═════════════════════════════════════════════════
  Widget _buildPitch() {
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final h = box.maxHeight;
        final card = (w / 6.2).clamp(42.0, 62.0);

        return Stack(
          children: [
            const Positioned.fill(child: RugbyPitchBackground()),
            ..._slots(w, h, card),
          ],
        );
      },
    );
  }

  List<Widget> _slots(double w, double h, double card) {
    final slotH = card * 1.3;
    final positions = <int, Offset>{
      15: Offset(0.50, 0.08),
      14: Offset(0.86, 0.18),
      11: Offset(0.14, 0.18),
      13: Offset(0.72, 0.29),
      12: Offset(0.28, 0.29),
      10: Offset(0.50, 0.39),
      9: Offset(0.42, 0.49),
      8: Offset(0.50, 0.58),
      7: Offset(0.78, 0.58),
      6: Offset(0.22, 0.58),
      5: Offset(0.68, 0.70),
      4: Offset(0.32, 0.70),
      3: Offset(0.74, 0.86),
      2: Offset(0.50, 0.86),
      1: Offset(0.26, 0.86),
    };

    return positions.entries.map((e) {
      final cx = w * e.value.dx;
      final cy = h * e.value.dy;
      return Positioned(
        left: cx - card / 2,
        top: cy - slotH / 2 + slotH * 0.15,
        child: _slot(e.key, _onField[e.key], card),
      );
    }).toList();
  }

  /// Wraps a player card with a position label and optional yellow-card timer
  Widget _filledSlot(
    int pos,
    Player player,
    double size, {
    bool isSelected = false,
  }) {
    final yellowRemaining = _yellowCardSecondsRemaining[player.id];
    final hasYellowTimer = yellowRemaining != null && yellowRemaining > 0;
    return SizedBox(
      width: size,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              FifaStyleCard(
                player: player,
                size: size,
                isSelected: isSelected,
                rarity: _getPlayerRarity(player),
                matchYellowCards: _matchYellowCards[player.id] ?? 0,
                matchRedCards: _matchRedCards[player.id] ?? 0,
              ),
              if (hasYellowTimer)
                Positioned(
                  bottom: -2,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.yellow.shade800,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(180),
                            blurRadius: 3,
                          ),
                        ],
                      ),
                      child: Text(
                        _formatTime(yellowRemaining),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          // Position label below card
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0xFF0B0E13),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _getPositionName(pos),
              style: TextStyle(
                color: Colors.white70,
                fontSize: size * 0.12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _slot(int pos, Player? player, double size) {
    // Read-only view
    if (!_canControl) {
      if (player != null) {
        return _filledSlot(pos, player, size);
      }
      return _emptySlot(pos, size, false);
    }

    return DragTarget<Object>(
      onWillAcceptWithDetails: (d) =>
          d.data is Player || (d.data is Map<String, String> && player != null),
      onAcceptWithDetails: (d) {
        if (d.data is Player) {
          _assignPlayerToPosition(d.data as Player, pos);
        } else if (d.data is Map<String, String> && player != null) {
          _handleActionDrop(d.data as Map<String, String>, player);
        }
      },
      builder: (context, candidates, _) {
        final lit = candidates.isNotEmpty;
        if (player != null) {
          return Draggable<Player>(
            data: player,
            feedback: Material(
              color: Colors.transparent,
              child: FifaStyleCard(
                player: player,
                size: size,
                rarity: _getPlayerRarity(player),
                matchYellowCards: _matchYellowCards[player.id] ?? 0,
                matchRedCards: _matchRedCards[player.id] ?? 0,
              ),
            ),
            childWhenDragging: _emptySlot(pos, size, false),
            onDragStarted: () => HapticFeedback.lightImpact(),
            child: GestureDetector(
              onDoubleTap: () => _showPlayerActions(player),
              child: _filledSlot(pos, player, size, isSelected: lit),
            ),
          );
        }
        return _emptySlot(pos, size, lit);
      },
    );
  }

  void _handleActionDrop(Map<String, String> data, Player player) {
    switch (data['type']) {
      case 'TRY':
        _recordTry(player);
        break;
      case 'DROP':
        _recordDropGoal(player);
        break;
      case 'YELLOW':
        _giveYellowCard(player);
        break;
      case 'RED':
        _giveRedCard(player);
        break;
    }
    HapticFeedback.mediumImpact();
  }

  Widget _emptySlot(int pos, double size, bool lit) {
    final lockedPlayer = _redCardLockedPositions[pos];
    final locked = lockedPlayer != null;
    final accent = locked
        ? Colors.red.shade700
        : lit
        ? const Color(0xFF4CAF50)
        : const Color(0xFF3E6B48);
    return SizedBox(
      width: size,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size * 1.18,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: locked
                  ? const Color(0xFF2A0A0A).withAlpha(220)
                  : const Color(0xFF152115).withAlpha(220),
              border: Border.all(color: accent, width: lit ? 2 : 1),
            ),
            child: locked
                ? Stack(
                    children: [
                      // Greyed-out player info
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${lockedPlayer.jerseyNumber}',
                              style: TextStyle(
                                color: Colors.red.shade300,
                                fontSize: size * 0.24,
                                fontWeight: FontWeight.w900,
                                height: 1.0,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              lockedPlayer.name,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: TextStyle(
                                color: Colors.red.shade200,
                                fontSize: size * 0.11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Red card overlay
                      Positioned(
                        top: 2,
                        right: 2,
                        child: Container(
                          width: size * 0.12,
                          height: size * 0.16,
                          decoration: BoxDecoration(
                            color: Colors.red.shade700,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: Icon(
                      Icons.add_rounded,
                      color: _canControl
                          ? accent
                          : Colors.transparent, // Hide add icon if read-only
                      size: size * 0.35,
                    ),
                  ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0xFF0B0E13),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              locked ? '🟥 ${_getPositionName(pos)}' : _getPositionName(pos),
              style: TextStyle(
                color: locked ? Colors.red.shade300 : Colors.white70,
                fontSize: size * 0.12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _assignPlayerToPosition(Player player, int position) {
    // Block substitution into red-card-locked positions
    if (_redCardLockedPositions.containsKey(position)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('此位置因紅牌已鎖定，不可換人'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Check if player is already on field
    int? currentPos;
    for (int i = 1; i <= 15; i++) {
      if (_onField[i]?.id == player.id) {
        currentPos = i;
        break;
      }
    }

    final existingPlayer = _onField[position];

    if (currentPos != null) {
      // Field ↔ Field swap
      _recordAction(MatchActionType.fieldSwap, {
        'position1': position,
        'position2': currentPos,
        'player1': existingPlayer,
        'player2': player,
      });
      setState(() {
        _onField[currentPos!] = existingPlayer;
        _onField[position] = player;
      });
    } else if (_bench.contains(player) || _available.contains(player)) {
      final fromBench = _bench.contains(player);
      if (existingPlayer != null) {
        // Bench/Available → Field substitution (swap with existing)
        _recordAction(MatchActionType.substitution, {
          'position1': position,
          'position2': null,
          'player1': existingPlayer,
          'player2': player,
          'fromAvailable': !fromBench,
        });
      } else {
        // Bench/Available → Empty position
        _recordAction(MatchActionType.fieldMove, {
          'fromPos': null,
          'toPos': position,
          'player': player,
          'fromAvailable': !fromBench,
        });
      }
      setState(() {
        if (fromBench) {
          _bench.remove(player);
        } else {
          _available.remove(player);
        }
        if (existingPlayer != null) {
          _bench.add(existingPlayer);
        }
        _onField[position] = player;
      });
    }

    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${player.name} → ${_getPositionName(position)}'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  // ═════════════════════════════════════════════════
  //  ACTION RAIL (right-side vertical navigation)
  // ═════════════════════════════════════════════════
  Widget _buildActionRail() {
    if (!_canControl) return const SizedBox.shrink();

    // Collapsed state: just a toggle button
    if (!_isActionRailExpanded) {
      return GestureDetector(
        onTap: () => setState(() => _isActionRailExpanded = true),
        child: Container(
          width: 24,
          color: const Color(0xFF101418),
          child: const Center(
            child: Icon(Icons.chevron_left, color: Colors.white38, size: 18),
          ),
        ),
      );
    }

    return Container(
      width: 52,
      color: const Color(0xFF101418),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          // Collapse button
          GestureDetector(
            onTap: () => setState(() => _isActionRailExpanded = false),
            child: const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Icon(Icons.chevron_right, color: Colors.white38, size: 18),
            ),
          ),
          _railAction(
            Icons.sports_rugby,
            'Try',
            const Color(0xFF2E7D32),
            _showTryScorer,
            'TRY',
          ),
          const SizedBox(height: 6),
          _railAction(
            Icons.arrow_upward,
            'Drop',
            const Color(0xFF4527A0),
            _showDropGoalKicker,
            'DROP',
          ),
          const SizedBox(height: 8),
          Container(width: 28, height: 1, color: Colors.white12),
          const SizedBox(height: 8),
          _railCard(Colors.yellow.shade700, _showYellowCardPicker, 'YELLOW'),
          const SizedBox(height: 6),
          _railCard(Colors.red.shade700, _showRedCardPicker, 'RED'),
          const Spacer(),
          // Undo
          GestureDetector(
            onTap: _actionHistory.isNotEmpty ? _undo : null,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _actionHistory.isNotEmpty
                    ? const Color(0xFF2E2E2E)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.undo,
                    size: 18,
                    color: _actionHistory.isNotEmpty
                        ? Colors.white70
                        : Colors.white24,
                  ),
                  if (_actionHistory.isNotEmpty)
                    Text(
                      '${_actionHistory.length}',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 9,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _railAction(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
    String actionType,
  ) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 8,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
    return Draggable<Map<String, String>>(
      data: {'type': actionType},
      feedback: Material(color: Colors.transparent, child: content),
      childWhenDragging: Opacity(opacity: 0.25, child: content),
      onDragStarted: () => HapticFeedback.lightImpact(),
      child: GestureDetector(onTap: onTap, child: content),
    );
  }

  Widget _railCard(Color color, VoidCallback onTap, String actionType) {
    final content = Container(
      width: 22,
      height: 30,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
        boxShadow: [BoxShadow(color: color.withAlpha(80), blurRadius: 4)],
      ),
    );
    return Draggable<Map<String, String>>(
      data: {'type': actionType},
      feedback: Material(color: Colors.transparent, child: content),
      childWhenDragging: Opacity(opacity: 0.25, child: content),
      onDragStarted: () => HapticFeedback.lightImpact(),
      child: GestureDetector(onTap: onTap, child: content),
    );
  }

  // ═════════════════════════════════════════════════
  //  PLAYER PANEL (merged bench + available)
  // ═════════════════════════════════════════════════
  Widget _buildPlayerPanel() {
    final allPlayers = [..._bench, ..._available];
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      height: _isAvailableExpanded ? 150 : 36,
      color: const Color(0xFF0B0E13),
      child: Column(
        children: [
          GestureDetector(
            onTap: () =>
                setState(() => _isAvailableExpanded = !_isAvailableExpanded),
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(
                    _isAvailableExpanded
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_up,
                    color: Colors.white38,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '替補 ${_bench.length}',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_available.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(
                      '可用 ${_available.length}',
                      style: const TextStyle(
                        color: Colors.white30,
                        fontSize: 11,
                      ),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    '拖拽至球場 ↑',
                    style: TextStyle(color: Colors.white24, fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
          if (_isAvailableExpanded)
            Expanded(
              child: allPlayers.isEmpty
                  ? const Center(
                      child: Text(
                        '— 無可用球員 —',
                        style: TextStyle(color: Colors.white24, fontSize: 12),
                      ),
                    )
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      itemCount: allPlayers.length,
                      itemBuilder: (_, i) {
                        final p = allPlayers[i];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _canControl
                              ? Draggable<Player>(
                                  data: p,
                                  feedback: Material(
                                    color: Colors.transparent,
                                    child: FifaStyleCard(
                                      player: p,
                                      size: 58,
                                      rarity: _getPlayerRarity(p),
                                    ),
                                  ),
                                  childWhenDragging: Opacity(
                                    opacity: 0.25,
                                    child: FifaStyleCard(
                                      player: p,
                                      size: 58,
                                      rarity: _getPlayerRarity(p),
                                    ),
                                  ),
                                  onDragStarted: () =>
                                      HapticFeedback.lightImpact(),
                                  child: _playerCardContent(p),
                                )
                              : _playerCardContent(p), // Read-only view
                        );
                      },
                    ),
            ),
        ],
      ),
    );
  }

  Widget _playerCardContent(Player p) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FifaStyleCard(
          player: p,
          size: 58,
          rarity: _getPlayerRarity(p),
          matchYellowCards: _matchYellowCards[p.id] ?? 0,
          matchRedCards: _matchRedCards[p.id] ?? 0,
        ),
      ],
    );
  }

  // === Player Actions (double-tap on field player) ===
  void _showPlayerActions(Player player) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16213E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              player.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _actionChip(Icons.sports_rugby, 'Try', Colors.green, () {
                  Navigator.pop(context);
                  _recordTry(player);
                }),
                _actionChip(Icons.gps_fixed, 'Penalty', Colors.orange, () {
                  Navigator.pop(context);
                  _recordPenalty(player);
                }),
                _actionChip(Icons.arrow_upward, 'Drop Kick', Colors.purple, () {
                  Navigator.pop(context);
                  _recordDropGoal(player);
                }),
                _actionChip(Icons.square, '黃牌', Colors.yellow.shade700, () {
                  Navigator.pop(context);
                  _giveYellowCard(player);
                }),
                _actionChip(Icons.square, '紅牌', Colors.red, () {
                  Navigator.pop(context);
                  _giveRedCard(player);
                }),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _actionChip(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // === Action Pickers ===
  void _showTryScorer() {
    _showPlayerPicker('Select Try Scorer', (player) {
      _recordTry(player);
    });
  }

  void _showDropGoalKicker() {
    _showPlayerPicker('Select Drop Kick', (player) {
      _recordDropGoal(player);
    });
  }

  void _showYellowCardPicker() {
    _showPlayerPicker('給黃牌', (player) {
      _giveYellowCard(player);
    });
  }

  void _showRedCardPicker() {
    _showPlayerPicker('給紅牌', (player) {
      _giveRedCard(player);
    });
  }

  void _showPlayerPicker(String title, Function(Player) onSelect) {
    final onFieldPlayers = <Player>[];
    for (int i = 1; i <= 15; i++) {
      if (_onField[i] != null) onFieldPlayers.add(_onField[i]!);
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16213E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: onFieldPlayers.length,
                itemBuilder: (context, index) {
                  final player = onFieldPlayers[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        onSelect(player);
                      },
                      child: FifaStyleCard(
                        player: player,
                        size: 60,
                        rarity: _getPlayerRarity(player),
                        matchYellowCards: _matchYellowCards[player.id] ?? 0,
                        matchRedCards: _matchRedCards[player.id] ?? 0,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // === Undo Logic ===

  void _recordAction(MatchActionType type, Map<String, dynamic> data) {
    _actionHistory.add(
      MatchAction(
        type: type,
        timestamp: DateTime.now(),
        minute: _elapsedSeconds ~/ 60,
        data: data,
      ),
    );
  }

  void _undo() {
    if (_actionHistory.isEmpty) return;

    final lastAction = _actionHistory.removeLast();

    setState(() {
      switch (lastAction.type) {
        case MatchActionType.substitution:
        case MatchActionType.fieldSwap:
          // Reverse the swap
          final pos1 = lastAction.data['position1'] as int;
          final pos2 = lastAction.data['position2'] as int?;
          final player1 = lastAction.data['player1'] as Player;
          final player2 = lastAction.data['player2'] as Player?;

          if (pos2 != null) {
            _onField[pos1] = player1;
            _onField[pos2] = player2;
          } else {
            // Bench/Available substitution
            final fromAvailable =
                lastAction.data['fromAvailable'] as bool? ?? false;
            _onField[pos1] = player1;
            _bench.remove(player1);
            if (player2 != null) {
              if (fromAvailable) {
                _available.add(player2);
              } else {
                _bench.add(player2);
              }
            }
          }
          break;

        case MatchActionType.fieldMove:
          final fromPos = lastAction.data['fromPos'] as int?;
          final toPos = lastAction.data['toPos'] as int;
          final player = lastAction.data['player'] as Player;

          _onField[toPos] = null;
          if (fromPos != null) {
            _onField[fromPos] = player;
          } else {
            final fromAvailable =
                lastAction.data['fromAvailable'] as bool? ?? false;
            if (fromAvailable) {
              _available.add(player);
            } else {
              _bench.add(player);
            }
          }
          break;

        case MatchActionType.tryScore:
          if (lastAction.data['manual'] == true) {
            // Manual score adjustment — restore exact old scores
            _homeScore = lastAction.data['oldHome'] as int;
            _awayScore = lastAction.data['oldAway'] as int;
          } else {
            _homeScore -= 5;
          }
          break;

        case MatchActionType.conversion:
          _homeScore -= 2;
          break;

        case MatchActionType.penalty:
        case MatchActionType.dropGoal:
          _homeScore -= 3;
          break;

        case MatchActionType.yellowCard:
          final playerId = lastAction.data['playerId'] as String;
          _matchYellowCards[playerId] = (_matchYellowCards[playerId] ?? 1) - 1;
          if (_matchYellowCards[playerId]! <= 0) {
            _matchYellowCards.remove(playerId);
          }
          _yellowCardTimers[playerId]?.cancel();
          _yellowCardTimers.remove(playerId);
          _yellowCardSecondsRemaining.remove(playerId);
          break;

        case MatchActionType.redCard:
          final playerId = lastAction.data['playerId'] as String;
          final position = lastAction.data['position'] as int;
          final player = lastAction.data['player'] as Player;

          _matchRedCards[playerId] = (_matchRedCards[playerId] ?? 1) - 1;
          if (_matchRedCards[playerId]! <= 0) {
            _matchRedCards.remove(playerId);
          }
          _onField[position] = player;
          _redCardLockedPositions.remove(position); // unlock
          break;
      }
    });

    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已撤銷上一個操作'), duration: Duration(seconds: 1)),
    );
  }

  // === Yellow card active check ===
  bool _hasActiveYellowCard(Player player) {
    final remaining = _yellowCardSecondsRemaining[player.id];
    return remaining != null && remaining > 0;
  }

  bool _blockIfYellowCarded(Player player) {
    if (_hasActiveYellowCard(player)) {
      final mins = (_yellowCardSecondsRemaining[player.id]! / 60).ceil();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${player.name} is sin-binned (${mins}min left)'),
          duration: const Duration(seconds: 2),
        ),
      );
      return true;
    }
    return false;
  }

  // === Scoring Actions ===

  void _recordTry(Player player) {
    if (_blockIfYellowCarded(player)) return;
    _recordAction(MatchActionType.tryScore, {'playerId': player.id});

    setState(() {
      _homeScore += 5;
    });

    HapticFeedback.mediumImpact();

    // After try, directly show kicker picker for conversion
    // Prioritise kickers at the top of the list
    final onFieldPlayers = <Player>[];
    for (int i = 1; i <= 15; i++) {
      if (_onField[i] != null) onFieldPlayers.add(_onField[i]!);
    }
    // Sort: kickers first
    onFieldPlayers.sort((a, b) {
      if (a.isKicker && !b.isKicker) return -1;
      if (!a.isKicker && b.isKicker) return 1;
      return 0;
    });

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16213E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${player.name} Try! +5',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Select kicker for Conversion',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: onFieldPlayers.length,
                itemBuilder: (_, i) {
                  final p = onFieldPlayers[i];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        _showConversionResult(p);
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FifaStyleCard(
                            player: p,
                            size: 60,
                            rarity: _getPlayerRarity(p),
                            matchYellowCards: _matchYellowCards[p.id] ?? 0,
                            matchRedCards: _matchRedCards[p.id] ?? 0,
                          ),
                          if (p.isKicker)
                            const Text(
                              '⭐ Kicker',
                              style: TextStyle(
                                color: Colors.amber,
                                fontSize: 9,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Skip Conversion',
                style: TextStyle(color: Colors.white38),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showConversionResult(Player kicker) {
    showAdaptiveDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog.adaptive(
        title: Text('${kicker.name} Conversion'),
        content: const Text('Conversion successful?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('未進'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _recordConversion(kicker);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.green),
            child: const Text('進了 +2'),
          ),
        ],
      ),
    );
  }

  void _recordConversion(Player kicker) {
    if (_blockIfYellowCarded(kicker)) return;
    _recordAction(MatchActionType.conversion, {'playerId': kicker.id});

    setState(() {
      _homeScore += 2;
    });

    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${kicker.name} Conversion 成功 +2'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _recordPenalty(Player player) {
    if (_blockIfYellowCarded(player)) return;
    _recordAction(MatchActionType.penalty, {'playerId': player.id});
    setState(() => _homeScore += 3);
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${player.name} Penalty +3'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _recordDropGoal(Player player) {
    if (_blockIfYellowCarded(player)) return;
    _recordAction(MatchActionType.dropGoal, {'playerId': player.id});
    setState(() => _homeScore += 3);
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${player.name} Drop Goal +3'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _giveYellowCard(Player player) {
    _recordAction(MatchActionType.yellowCard, {'playerId': player.id});

    setState(() {
      _matchYellowCards[player.id] = (_matchYellowCards[player.id] ?? 0) + 1;
    });

    _startYellowCardTimer(player);

    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${player.name} 🟨 Yellow Card - 10 分鐘'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _startYellowCardTimer(Player player) {
    _yellowCardSecondsRemaining[player.id] = 600;

    _yellowCardTimers[player.id]?.cancel();
    _yellowCardTimers[player.id] = Timer.periodic(const Duration(seconds: 1), (
      timer,
    ) {
      setState(() {
        _yellowCardSecondsRemaining[player.id] =
            _yellowCardSecondsRemaining[player.id]! - 1;

        if (_yellowCardSecondsRemaining[player.id]! <= 0) {
          timer.cancel();
          _yellowCardTimers.remove(player.id);
          _yellowCardSecondsRemaining.remove(player.id);

          // Triple vibration burst to alert coach
          HapticFeedback.heavyImpact();
          Future.delayed(const Duration(milliseconds: 200), () {
            HapticFeedback.heavyImpact();
          });
          Future.delayed(const Duration(milliseconds: 400), () {
            HapticFeedback.heavyImpact();
          });
          // Play system alert sound
          SystemSound.play(SystemSoundType.alert);

          if (mounted) {
            showAdaptiveDialog(
              context: context,
              builder: (ctx) => AlertDialog.adaptive(
                title: const Text('🟨 Yellow Card Expired'),
                content: Text('${player.name} can return to play!'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
        }
      });
    });
  }

  void _giveRedCard(Player player) {
    int? playerPos;
    for (int i = 1; i <= 15; i++) {
      if (_onField[i]?.id == player.id) {
        playerPos = i;
        break;
      }
    }

    _recordAction(MatchActionType.redCard, {
      'playerId': player.id,
      'position': playerPos,
      'player': player,
    });

    setState(() {
      _matchRedCards[player.id] = (_matchRedCards[player.id] ?? 0) + 1;
    });

    if (playerPos != null) {
      setState(() {
        _onField[playerPos!] = null;
        _redCardLockedPositions[playerPos] = player;
      });
    }

    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${player.name} 🟥 Red Card - 離場（該位置不可換人）'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // === Match Events ===

  void _showMatchEvents() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161B22),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                children: [
                  const Text(
                    '比賽事件',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_actionHistory.length} 事件',
                    style: const TextStyle(color: Colors.white38),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _actionHistory.isEmpty
                    ? const Center(
                        child: Text(
                          '尚無事件',
                          style: TextStyle(color: Colors.white38),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _actionHistory.length,
                        itemBuilder: (context, index) {
                          final event = _actionHistory.reversed.toList()[index];
                          return _buildEventTile(event);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEventTile(MatchAction event) {
    String icon;
    String title;
    Color color;

    switch (event.type) {
      case MatchActionType.tryScore:
        icon = '🏉';
        title = 'Try +5';
        color = Colors.green;
        break;
      case MatchActionType.conversion:
        icon = '⚽';
        title = 'Conversion +2';
        color = Colors.blue;
        break;
      case MatchActionType.penalty:
        icon = '🎯';
        title = 'Penalty +3';
        color = Colors.orange;
        break;
      case MatchActionType.dropGoal:
        icon = '🦶';
        title = 'Drop Kick +3';
        color = Colors.purple;
        break;
      case MatchActionType.yellowCard:
        icon = '🟨';
        title = '黃牌';
        color = Colors.yellow.shade700;
        break;
      case MatchActionType.redCard:
        icon = '🟥';
        title = '紅牌';
        color = Colors.red;
        break;
      case MatchActionType.substitution:
        icon = '🔄';
        title = '換人';
        color = Colors.teal;
        break;
      case MatchActionType.fieldSwap:
        icon = '↔️';
        title = '位置交換';
        color = Colors.indigo;
        break;
      case MatchActionType.fieldMove:
        icon = '➡️';
        title = '球員移動';
        color = Colors.grey;
        break;
    }

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withAlpha(51),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(child: Text(icon, style: const TextStyle(fontSize: 20))),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      subtitle: Text(
        '${event.minute} 分鐘',
        style: const TextStyle(color: Colors.white38),
      ),
      trailing: Text(
        '${event.timestamp.hour}:${event.timestamp.minute.toString().padLeft(2, '0')}',
        style: const TextStyle(color: Colors.white30, fontSize: 12),
      ),
    );
  }

  // === Utility Methods ===

  String _getPositionName(int position) {
    const positionNames = {
      1: 'PR',
      2: 'HK',
      3: 'PR',
      4: 'LK',
      5: 'LK',
      6: 'FL',
      7: 'FL',
      8: 'N8',
      9: 'SH',
      10: 'FH',
      11: 'WG',
      12: 'CT',
      13: 'CT',
      14: 'WG',
      15: 'FB',
    };
    return positionNames[position] ?? 'P$position';
  }

  CardRarity _getPlayerRarity(Player player) {
    if (player.isCaptain) return CardRarity.special;
    if (player.isKicker) return CardRarity.totw;
    if ((_matchYellowCards[player.id] ?? 0) > 0) return CardRarity.silver;
    return CardRarity.gold;
  }

  String _formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// Display per-half time: each half shows 00:00 → 40:00
  String _displayTime() {
    switch (_phase) {
      case MatchPhase.firstHalf:
        return _formatTime(_elapsedSeconds.clamp(0, 2400));
      case MatchPhase.halfTime:
        return '40:00';
      case MatchPhase.secondHalf:
        return _formatTime((_elapsedSeconds - 2400).clamp(0, 2400));
      case MatchPhase.fullTime:
        return '40:00';
    }
  }

  void _toggleTimer() {
    if (_phase == MatchPhase.halfTime || _phase == MatchPhase.fullTime) {
      _showPhasePrompt();
      return;
    }
    setState(() => _isTimerRunning = !_isTimerRunning);

    if (_isTimerRunning) {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted || !_isTimerRunning) {
          timer.cancel();
          return;
        }
        setState(() {
          _elapsedSeconds++;
          // Auto half-time at 40 min, auto full-time at 80 min
          if (_phase == MatchPhase.firstHalf && _elapsedSeconds >= 2400) {
            _isTimerRunning = false;
            _phase = MatchPhase.halfTime;
            timer.cancel();
            HapticFeedback.heavyImpact();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('半場時間到！'),
                backgroundColor: Colors.orange,
              ),
            );
          } else if (_phase == MatchPhase.secondHalf &&
              _elapsedSeconds >= 4800) {
            _isTimerRunning = false;
            _phase = MatchPhase.fullTime;
            timer.cancel();
            HapticFeedback.heavyImpact();
            // Auto-show end match dialog
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _showEndMatchDialog();
            });
          }
        });
      });
    } else {
      _timer?.cancel();
    }
  }

  void _showPhaseControl() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161B22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '比賽階段控制',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              _phaseOption(
                ctx,
                '上半場',
                MatchPhase.firstHalf,
                Icons.play_arrow,
                const Color(0xFF2E7D32),
              ),
              _phaseOption(
                ctx,
                '中場休息',
                MatchPhase.halfTime,
                Icons.pause_circle,
                const Color(0xFFE65100),
              ),
              _phaseOption(
                ctx,
                '下半場',
                MatchPhase.secondHalf,
                Icons.play_arrow,
                const Color(0xFF1565C0),
              ),
              _phaseOption(
                ctx,
                '全場結束',
                MatchPhase.fullTime,
                Icons.stop_circle,
                const Color(0xFFC62828),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _phaseOption(
    BuildContext ctx,
    String label,
    MatchPhase phase,
    IconData icon,
    Color color,
  ) {
    final isCurrent = _phase == phase;
    return ListTile(
      leading: Icon(icon, color: isCurrent ? color : Colors.white30),
      title: Text(
        label,
        style: TextStyle(
          color: isCurrent ? color : Colors.white70,
          fontWeight: isCurrent ? FontWeight.w700 : FontWeight.normal,
        ),
      ),
      trailing: isCurrent
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withAlpha(40),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '目前',
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : null,
      onTap: () {
        Navigator.pop(ctx);
        if (phase == _phase) return;
        setState(() {
          _isTimerRunning = false;
          _timer?.cancel();
          _phase = phase;
          if (phase == MatchPhase.secondHalf && _elapsedSeconds < 2400) {
            _elapsedSeconds = 2400; // Jump to 40:00 for 2nd half
          }
        });
        HapticFeedback.mediumImpact();
        if (phase == MatchPhase.fullTime) {
          // Auto-show end match dialog when manually set to full time
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _showEndMatchDialog();
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('已切換至：$label'),
              duration: const Duration(seconds: 1),
            ),
          );
        }
      },
    );
  }

  void _showPhasePrompt() {
    if (_phase == MatchPhase.halfTime) {
      showAdaptiveDialog(
        context: context,
        builder: (ctx) => AlertDialog.adaptive(
          title: const Text('開始下半場'),
          content: const Text('準備好進入下半場了嗎？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('稍後'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  _phase = MatchPhase.secondHalf;
                });
                _toggleTimer();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.green),
              child: const Text('開始下半場'),
            ),
          ],
        ),
      );
    } else if (_phase == MatchPhase.fullTime) {
      _showEndMatchDialog();
    }
  }

  void _showScoreDialog(bool isHome) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161B22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isHome ? '主隊得分' : '客隊得分',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildScoreOption('Try +5', 5, Colors.green, isHome),
                _buildScoreOption('Conv +2', 2, Colors.blue, isHome),
                _buildScoreOption('Pen +3', 3, Colors.orange, isHome),
                _buildScoreOption('Drop +3', 3, Colors.purple, isHome),
                _buildScoreOption('-1', -1, Colors.grey, isHome),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreOption(String label, int points, Color color, bool isHome) {
    return ElevatedButton(
      onPressed: () {
        Navigator.pop(context);
        final oldHome = _homeScore;
        final oldAway = _awayScore;
        setState(() {
          if (isHome) {
            _homeScore = (_homeScore + points).clamp(0, 999);
          } else {
            _awayScore = (_awayScore + points).clamp(0, 999);
          }
        });
        // Record manual score adjustment for undo
        _actionHistory.add(
          MatchAction(
            type: MatchActionType.tryScore,
            timestamp: DateTime.now(),
            minute: _elapsedSeconds ~/ 60,
            data: {
              'manual': true,
              'isHome': isHome,
              'points': points,
              'oldHome': oldHome,
              'oldAway': oldAway,
            },
          ),
        );
        HapticFeedback.mediumImpact();

        // If away team scored a Try, prompt for conversion
        if (!isHome && points == 5) {
          _showAwayConversionDialog();
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
      child: Text(label),
    );
  }

  void _showAwayConversionDialog() {
    showAdaptiveDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog.adaptive(
        title: const Text('對方 Conversion'),
        content: const Text('對方 Conversion 成功了嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('未進'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              final oldHome = _homeScore;
              final oldAway = _awayScore;
              setState(() {
                _awayScore = (_awayScore + 2).clamp(0, 999);
              });
              _actionHistory.add(
                MatchAction(
                  type: MatchActionType.tryScore,
                  timestamp: DateTime.now(),
                  minute: _elapsedSeconds ~/ 60,
                  data: {
                    'manual': true,
                    'isHome': false,
                    'points': 2,
                    'oldHome': oldHome,
                    'oldAway': oldAway,
                  },
                ),
              );
              HapticFeedback.mediumImpact();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.green),
            child: const Text('進了 +2'),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'autofill':
        _autoFillLineup();
        break;
      case 'check_lineout':
        _checkLineout();
        break;
      case 'share_lineout':
        _shareLineout();
        break;
      case 'clear':
        setState(() {
          for (final p in _onField.values.whereType<Player>()) {
            _bench.add(p);
          }
          _onField.clear();
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('陣容已清除')));
        break;
      case 'load':
        _loadSavedLineup();
        break;
      case 'save':
        _saveCurrentLineup();
        break;
      case 'convert':
        _showConvertDialog();
        break;
      case 'end':
        _showEndMatchDialog();
        break;
    }
  }

  static const String _lineupSaveKey = 'saved_lineups';

  Future<void> _saveCurrentLineup() async {
    final onFieldIds = <String, String>{};
    _onField.forEach((pos, player) {
      if (player != null) onFieldIds[pos.toString()] = player.id;
    });
    if (onFieldIds.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('陣容為空，無法儲存')));
      return;
    }

    final ctrl = TextEditingController(
      text: '陣容 ${DateTime.now().month}/${DateTime.now().day}',
    );
    final name = await showAdaptiveDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog.adaptive(
        title: const Text('儲存陣容'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: '陣容名稱',
            hintText: '例如：主力陣容',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('儲存'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_lineupSaveKey);
    final List<dynamic> lineups = existing != null ? jsonDecode(existing) : [];
    lineups.insert(0, {
      'name': name,
      'lineup': onFieldIds,
      'savedAt': DateTime.now().toIso8601String(),
    });
    // Keep max 10 saved lineups
    if (lineups.length > 10) lineups.removeLast();
    await prefs.setString(_lineupSaveKey, jsonEncode(lineups));

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('陣容「$name」已儲存')));
    }
  }

  Future<void> _loadSavedLineup() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_lineupSaveKey);
    if (existing == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('沒有已儲存的陣容')));
      }
      return;
    }
    final List<dynamic> lineups = jsonDecode(existing);
    if (lineups.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('沒有已儲存的陣容')));
      }
      return;
    }

    if (!mounted) return;
    final pp = context.read<PlayerProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161B22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '載入陣容',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              ...lineups.take(10).map((item) {
                final m = item as Map<String, dynamic>;
                final savedAt = DateTime.tryParse(m['savedAt'] ?? '');
                final dateStr = savedAt != null
                    ? '${savedAt.month}/${savedAt.day} ${savedAt.hour}:${savedAt.minute.toString().padLeft(2, '0')}'
                    : '';
                final lineupMap = m['lineup'] as Map<String, dynamic>;
                return ListTile(
                  leading: const Icon(Icons.list_alt, color: Colors.white54),
                  title: Text(
                    m['name'] ?? '未命名',
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    '$dateStr · ${lineupMap.length} 位球員',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                      size: 20,
                    ),
                    onPressed: () async {
                      lineups.remove(item);
                      await prefs.setString(
                        _lineupSaveKey,
                        jsonEncode(lineups),
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(const SnackBar(content: Text('已刪除')));
                      }
                    },
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _applyLineup(lineupMap, pp);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _applyLineup(Map<String, dynamic> lineupMap, PlayerProvider pp) {
    // Move all on-field players back to bench/available
    for (final p in _onField.values.whereType<Player>()) {
      _bench.add(p);
    }
    _onField.clear();

    // Apply saved lineup
    lineupMap.forEach((posStr, playerId) {
      final pos = int.tryParse(posStr);
      if (pos == null) return;
      final player = pp.getPlayerById(playerId as String);
      if (player != null) {
        _onField[pos] = player;
        _bench.remove(player);
        _available.remove(player);
      }
    });

    setState(() {});
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('陣容已載入')));
  }

  void _autoFillLineup() {
    final allAvailable = [..._bench, ..._available];
    final service = AutoFillService(
      availablePlayers: allAvailable,
      currentLineup: _onField,
    );

    final newLineup = service.autoFill();

    setState(() {
      _onField.clear();
      _onField.addAll(newLineup);

      // Update bench/available lists based on new lineup
      final assignedIds = newLineup.values
          .where((p) => p != null)
          .map((p) => p!.id)
          .toSet();
      _bench.removeWhere((p) => assignedIds.contains(p.id));
      _available.removeWhere((p) => assignedIds.contains(p.id));

      // Re-populate bench with remaining best players if needed
      while (_bench.length < 8 && _available.isNotEmpty) {
        _bench.add(_available.removeAt(0));
      }
    });

    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已智能填充最佳陣容')));
  }

  void _checkLineout() {
    final checker = LineoutChecker(
      lineup: _onField,
      allPlayers: context.read<PlayerProvider>().players,
    );
    final warnings = checker.checkLineout();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161B22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Lineout 檢查',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            LineoutWarningsWidget(warnings: warnings),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _shareLineout() {
    final teamName = context.read<TeamProvider>().currentTeam?.name ?? '我們';
    ShareService.shareLineup(
      context: context,
      teamName: teamName,
      opponent: widget.opponent ?? '對手',
      matchDate: DateTime.now(),
      lineup: _onField,
      bench: _bench,
    );
  }

  void _showConvertDialog() {
    showAdaptiveDialog(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: const Text('轉為正式比賽'),
        content: const Text('將此預覽轉為正式比賽？\n比分和陣容將被保留並開始記錄統計。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => MatchEngineScreen(
                    isPreviewMode: false,
                    opponent: widget.opponent,
                    initialLineup: Map.from(_onField),
                  ),
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.green),
            child: const Text('確認轉換'),
          ),
        ],
      ),
    );
  }

  void _showEndMatchDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161B22),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$_homeScore - $_awayScore',
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '比賽時間: ${_formatTime(_elapsedSeconds)} | ${_actionHistory.length} 事件',
              style: const TextStyle(fontSize: 14, color: Colors.white38),
            ),
            const SizedBox(height: 16),
            // Share
            ListTile(
              leading: Icon(Icons.adaptive.share, color: Colors.blue),
              title: const Text('分享比賽結果'),
              onTap: () {
                final teamName =
                    context.read<TeamProvider>().currentTeam?.name ?? '我們';
                ShareService.shareMatchResult(
                  context: context,
                  teamName: teamName,
                  opponent: widget.opponent ?? '對手',
                  homeScore: _homeScore,
                  awayScore: _awayScore,
                  matchDate: DateTime.now(),
                );
              },
            ),

            const Divider(),

            // Submit Official
            ListTile(
              leading: const Icon(Icons.check_circle, color: Colors.green),
              title: const Text('提交正式比賽'),
              subtitle: const Text('記錄為正式比賽，更新所有球員統計'),
              onTap: () {
                Navigator.pop(context);
                _submitOfficialMatch();
              },
            ),

            // Save as Preview
            ListTile(
              leading: const Icon(Icons.save_alt, color: Colors.orange),
              title: const Text('儲存為練習賽'),
              subtitle: const Text('保存為練習賽，不更新統計'),
              onTap: () {
                Navigator.pop(context);
                _saveAsPreview();
              },
            ),

            // Discard
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('放棄不保存'),
              subtitle: const Text('放棄所有比賽數據'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
            ),

            const Divider(),

            // Continue
            ListTile(
              leading: const Icon(Icons.play_arrow, color: Colors.blue),
              title: const Text('繼續比賽'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitOfficialMatch() async {
    final tp = context.read<TeamProvider>();
    final pp = context.read<PlayerProvider>();
    final matchService = MatchService();
    final seasonService = SeasonService();

    // --- 1. Collect per-player stats from action history ---
    final playerTries = <String, int>{};
    final playerConversions = <String, int>{};
    final playerPenalties = <String, int>{};
    final playerDropGoals = <String, int>{};

    for (final action in _actionHistory) {
      if (action.data['manual'] == true) continue;
      final pid = action.data['playerId'] as String?;
      if (pid == null) continue;
      switch (action.type) {
        case MatchActionType.tryScore:
          playerTries[pid] = (playerTries[pid] ?? 0) + 1;
          break;
        case MatchActionType.conversion:
          playerConversions[pid] = (playerConversions[pid] ?? 0) + 1;
          break;
        case MatchActionType.penalty:
          playerPenalties[pid] = (playerPenalties[pid] ?? 0) + 1;
          break;
        case MatchActionType.dropGoal:
          playerDropGoals[pid] = (playerDropGoals[pid] ?? 0) + 1;
          break;
        default:
          break;
      }
    }

    // --- 2. Update player stats ---
    final playerUpdateFutures = <Future>[];
    for (final player in pp.players) {
      final tries = playerTries[player.id] ?? 0;
      final convs = playerConversions[player.id] ?? 0;
      final pens = playerPenalties[player.id] ?? 0;
      final drops = playerDropGoals[player.id] ?? 0;
      final yellows = _matchYellowCards[player.id] ?? 0;
      final reds = _matchRedCards[player.id] ?? 0;

      if (tries > 0 ||
          convs > 0 ||
          pens > 0 ||
          drops > 0 ||
          yellows > 0 ||
          reds > 0) {
        final data = <String, dynamic>{};
        if (tries > 0) data['tries'] = player.tries + tries;
        if (convs > 0) data['conversions'] = player.conversions + convs;
        if (pens > 0) data['penalties'] = player.penalties + pens;
        if (drops > 0) data['dropGoals'] = player.dropGoals + drops;
        if (yellows > 0) data['yellowCards'] = player.yellowCards + yellows;
        if (reds > 0) data['redCards'] = player.redCards + reds;
        playerUpdateFutures.add(pp.updatePlayer(player.id, data));
      }
    }
    await Future.wait(playerUpdateFutures);

    // --- 3. Save match to Firestore ---
    final teamId = tp.currentTeam?.id ?? '';
    final seasonId = tp.currentSeason?.id;

    final positionSlots = <int, String?>{};
    _onField.forEach((pos, player) {
      positionSlots[pos] = player?.id;
    });

    final matchState = MatchState(
      id: '',
      eventId: widget.eventId ?? '',
      teamId: teamId,
      seasonId: seasonId,
      mode: MatchMode.official,
      status: MatchStatus.completed,
      positionSlots: positionSlots,
      ourScore: _homeScore,
      opponentScore: _awayScore,
      isCompleted: true,
      createdAt: DateTime.now(),
    );

    try {
      await matchService.createMatch(matchState);
    } catch (e) {
      debugPrint('Failed to save match: $e');
    }

    // --- 4. Update team stats ---
    if (teamId.isNotEmpty) {
      final isWin = _homeScore > _awayScore;
      final isLoss = _homeScore < _awayScore;
      final isDraw = _homeScore == _awayScore;

      final teamUpdates = <String, dynamic>{};
      teamUpdates['totalScored'] =
          (tp.currentTeam?.totalScored ?? 0) + _homeScore;
      teamUpdates['totalConceded'] =
          (tp.currentTeam?.totalConceded ?? 0) + _awayScore;
      if (isWin) {
        teamUpdates['matchesWon'] = (tp.currentTeam?.matchesWon ?? 0) + 1;
      }
      if (isLoss) {
        teamUpdates['matchesLost'] = (tp.currentTeam?.matchesLost ?? 0) + 1;
      }
      if (isDraw) {
        teamUpdates['matchesDrawn'] = (tp.currentTeam?.matchesDrawn ?? 0) + 1;
      }

      try {
        await tp.updateTeam(teamUpdates);
      } catch (e) {
        debugPrint('Failed to update team stats: $e');
      }

      // --- 5. Update season stats ---
      if (seasonId != null) {
        try {
          await seasonService.updateSeasonStats(
            seasonId,
            scored: _homeScore,
            conceded: _awayScore,
            won: isWin,
            lost: isLoss,
            drawn: isDraw,
          );
        } catch (e) {
          debugPrint('Failed to update season stats: $e');
        }
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('正式比賽已提交 ($_homeScore - $_awayScore)，球員及球隊統計已更新'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.pop(context);
  }

  Future<void> _saveAsPreview() async {
    final tp = context.read<TeamProvider>();
    final matchService = MatchService();

    final teamId = tp.currentTeam?.id ?? '';
    final seasonId = tp.currentSeason?.id;

    final positionSlots = <int, String?>{};
    _onField.forEach((pos, player) {
      positionSlots[pos] = player?.id;
    });

    final matchState = MatchState(
      id: '',
      eventId: widget.eventId ?? '',
      teamId: teamId,
      seasonId: seasonId,
      mode: MatchMode.preview,
      status: MatchStatus.completed,
      positionSlots: positionSlots,
      ourScore: _homeScore,
      opponentScore: _awayScore,
      isCompleted: true,
      createdAt: DateTime.now(),
    );

    try {
      await matchService.createMatch(matchState);
    } catch (e) {
      debugPrint('Failed to save preview match: $e');
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('練習賽已保存 ($_homeScore - $_awayScore)'),
        backgroundColor: Colors.orange,
      ),
    );
    Navigator.pop(context);
  }
}
