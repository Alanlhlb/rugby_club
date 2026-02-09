import '../models/player.dart';

/// Auto Fill service for intelligent lineup suggestions
class AutoFillService {
  final List<Player> availablePlayers;
  final Map<int, Player?> currentLineup;

  AutoFillService({
    required this.availablePlayers,
    required this.currentLineup,
  });

  /// Auto-fill empty positions based on player preferences and roles
  Map<int, Player?> autoFill() {
    final result = Map<int, Player?>.from(currentLineup);
    final assigned = result.values
        .where((p) => p != null)
        .map((p) => p!.id)
        .toSet();

    // Get unassigned available players (excluding injured and red-carded)
    final unassigned = availablePlayers
        .where((p) => !assigned.contains(p.id))
        .where((p) => !p.isInjured)
        .where((p) => p.redCards == 0)
        .toList();

    // Fill positions 1-15 if empty
    for (int pos = 1; pos <= 15; pos++) {
      if (result[pos] == null && unassigned.isNotEmpty) {
        final bestPlayer = _findBestPlayerForPosition(pos, unassigned);
        if (bestPlayer != null) {
          result[pos] = bestPlayer;
          unassigned.remove(bestPlayer);
        }
      }
    }

    return result;
  }

  /// Find the best player for a specific position
  Player? _findBestPlayerForPosition(int position, List<Player> candidates) {
    if (candidates.isEmpty) return null;

    final positionFullNames = _getPositionFullNames(position);

    // Priority 1: Player with matching position preference
    final positionMatches = candidates
        .where(
          (p) => p.positions.any(
            (pPos) => positionFullNames.any(
              (fn) => fn.toUpperCase() == pPos.toUpperCase(),
            ),
          ),
        )
        .toList();

    if (positionMatches.isNotEmpty) {
      // Within position matches, prioritize special roles
      return _prioritizeByRole(position, positionMatches);
    }

    // Priority 2: Player from same position group (forwards vs backs)
    final isForwardPosition = position <= 8;
    const forwardKeywords = [
      'prop',
      'hooker',
      'lock',
      'flanker',
      'eight',
      'back row',
    ];
    const backKeywords = ['half', 'centre', 'wing', 'full-back', 'fullback'];
    final groupMatches = candidates.where((p) {
      final hasForwardPos = p.positions.any((pos) {
        final lp = pos.toLowerCase();
        return forwardKeywords.any((kw) => lp.contains(kw));
      });
      final hasBackPos = p.positions.any((pos) {
        final lp = pos.toLowerCase();
        return backKeywords.any((kw) => lp.contains(kw));
      });
      return isForwardPosition ? hasForwardPos : hasBackPos;
    }).toList();

    if (groupMatches.isNotEmpty) {
      return _prioritizeByRole(position, groupMatches);
    }

    // Priority 3: Any available player
    return candidates.first;
  }

  /// Prioritize players by special roles for specific positions
  Player _prioritizeByRole(int position, List<Player> candidates) {
    // Position 2 (Hooker): Prefer lineout thrower
    if (position == 2) {
      final thrower = candidates.firstWhere(
        (p) => p.isLineoutThrower,
        orElse: () => candidates.first,
      );
      return thrower;
    }

    // Positions 4, 5 (Locks): Prefer lineout jumpers
    if (position == 4 || position == 5) {
      final jumper = candidates.firstWhere(
        (p) => p.isLineoutJumper,
        orElse: () => candidates.first,
      );
      return jumper;
    }

    // Position 9 (Scrum-half) or 10 (Fly-half): Prefer captain
    if (position == 9 || position == 10) {
      final captain = candidates.firstWhere(
        (p) => p.isCaptain,
        orElse: () => candidates.first,
      );
      return captain;
    }

    // Position 10 or 15: Prefer kicker
    if (position == 10 || position == 15) {
      final kicker = candidates.firstWhere(
        (p) => p.isKicker,
        orElse: () => candidates.first,
      );
      return kicker;
    }

    return candidates.first;
  }

  /// Get full position names for a position number
  List<String> _getPositionFullNames(int position) {
    const positionFullNames = {
      1: ['Loosehead Prop'],
      2: ['Hooker'],
      3: ['Tighthead Prop'],
      4: ['Lock'],
      5: ['Lock'],
      6: ['Blindside Flanker'],
      7: ['Openside Flanker'],
      8: ['Number 8'],
      9: ['Scrum-half'],
      10: ['Fly-half'],
      11: ['Left Wing'],
      12: ['Inside Centre'],
      13: ['Outside Centre'],
      14: ['Right Wing'],
      15: ['Fullback'],
    };
    return positionFullNames[position] ?? [];
  }

  /// Get suggested lineup with explanations
  List<AutoFillSuggestion> getSuggestions() {
    final suggestions = <AutoFillSuggestion>[];
    final assigned = currentLineup.values
        .where((p) => p != null)
        .map((p) => p!.id)
        .toSet();

    final unassigned = availablePlayers
        .where((p) => !assigned.contains(p.id))
        .where((p) => !p.isInjured)
        .where((p) => p.redCards == 0)
        .toList();

    for (int pos = 1; pos <= 15; pos++) {
      if (currentLineup[pos] == null && unassigned.isNotEmpty) {
        final bestPlayer = _findBestPlayerForPosition(
          pos,
          List.from(unassigned),
        );
        if (bestPlayer != null) {
          suggestions.add(
            AutoFillSuggestion(
              position: pos,
              player: bestPlayer,
              reason: _getReasonForSuggestion(pos, bestPlayer),
            ),
          );
          unassigned.remove(bestPlayer);
        }
      }
    }

    return suggestions;
  }

  String _getReasonForSuggestion(int position, Player player) {
    final posFullNames = _getPositionFullNames(position);

    // Check if position matches
    if (player.positions.any(
      (p) => posFullNames.any((fn) => fn.toUpperCase() == p.toUpperCase()),
    )) {
      return '${player.name} 是 ${posFullNames.first} 位置球員';
    }

    // Check special roles
    if (position == 2 && player.isLineoutThrower) {
      return '${player.name} 是 Lineout Thrower';
    }
    if ((position == 4 || position == 5) && player.isLineoutJumper) {
      return '${player.name} 是 Lineout Jumper';
    }
    if ((position == 9 || position == 10) && player.isCaptain) {
      return '${player.name} 是隊長';
    }
    if ((position == 10 || position == 15) && player.isKicker) {
      return '${player.name} 是 Kicker';
    }

    return '${player.name} 可填補空缺';
  }
}

class AutoFillSuggestion {
  final int position;
  final Player player;
  final String reason;

  AutoFillSuggestion({
    required this.position,
    required this.player,
    required this.reason,
  });
}
