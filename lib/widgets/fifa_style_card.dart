import 'package:flutter/material.dart';
import '../models/player.dart';

enum CardRarity { bronze, silver, gold, rareGold, totw, special }

class FifaStyleCard extends StatelessWidget {
  final Player player;
  final bool isSelected;
  final bool isDragging;
  final bool showPosition;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final double size;
  final CardRarity rarity;
  final int matchYellowCards;
  final int matchRedCards;

  const FifaStyleCard({
    super.key,
    required this.player,
    this.isSelected = false,
    this.isDragging = false,
    this.showPosition = true,
    this.onTap,
    this.onDoubleTap,
    this.size = 70,
    this.rarity = CardRarity.gold,
    this.matchYellowCards = 0,
    this.matchRedCards = 0,
  });

  @override
  Widget build(BuildContext context) {
    final hasRedCard = player.redCards > 0 || matchRedCards > 0;
    final hasYellowCard =
        !hasRedCard && (player.yellowCards > 0 || matchYellowCards > 0);
    final c = _colors();

    return GestureDetector(
      onTap: hasRedCard ? null : onTap,
      onDoubleTap: hasRedCard ? null : onDoubleTap,
      child: Opacity(
        opacity: isDragging ? 0.3 : (hasRedCard ? 0.45 : 1.0),
        child: SizedBox(
          width: size,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ─── Card ───
              Container(
                width: size,
                height: size * 1.18,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [c.top, Color.lerp(c.top, c.bot, 0.5)!, c.bot],
                    stops: const [0.0, 0.4, 1.0],
                  ),
                  border: Border.all(
                    color: isSelected ? Colors.white : c.border.withAlpha(180),
                    width: isSelected ? 2 : 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: c.border.withAlpha(isSelected ? 80 : 40),
                      blurRadius: isSelected ? 12 : 6,
                      offset: const Offset(0, 3),
                    ),
                    BoxShadow(
                      color: Colors.black.withAlpha(isSelected ? 140 : 100),
                      blurRadius: isSelected ? 8 : 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // ── gloss highlight (top-left)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: size * 0.45,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(5),
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withAlpha(18),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    // ── jersey number (top-left, large)
                    Positioned(
                      top: 2,
                      left: 4,
                      child: Text(
                        '${player.jerseyNumber}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: size * 0.28,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                          shadows: [
                            Shadow(
                              color: Colors.black.withAlpha(80),
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // ── position abbr + attribute tags (below number)
                    Positioned(
                      top: size * 0.28,
                      left: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _posAbbr(),
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: size * 0.10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                          if (_hasTags())
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: _buildTagsInline(),
                            ),
                        ],
                      ),
                    ),
                    // ── avatar silhouette (centre-right)
                    Positioned(
                      top: size * 0.04,
                      left: size * 0.36,
                      right: 3,
                      bottom: size * 0.24,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Colors.white.withAlpha(30),
                              Colors.white.withAlpha(8),
                            ],
                          ),
                          border: Border.all(
                            color: Colors.white.withAlpha(15),
                            width: 0.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            player.name.isNotEmpty
                                ? player.name[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: Colors.white.withAlpha(220),
                              fontSize: size * 0.22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // ── name bar (bottom)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 2,
                          horizontal: 3,
                        ),
                        decoration: BoxDecoration(
                          color: c.bot.withAlpha(210),
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(5),
                          ),
                        ),
                        child: Text(
                          _shortName(),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: size * 0.12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                    // ── yellow card indicator
                    if (hasYellowCard)
                      Positioned(
                        top: 2,
                        right: 2,
                        child: Container(
                          width: size * 0.10,
                          height: size * 0.14,
                          decoration: BoxDecoration(
                            color: Colors.yellow.shade700,
                            borderRadius: BorderRadius.circular(1),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.yellow.shade700.withAlpha(80),
                                blurRadius: 3,
                              ),
                            ],
                          ),
                        ),
                      ),
                    // ── red card indicator
                    if (hasRedCard)
                      Positioned(
                        top: 2,
                        right: 2,
                        child: Container(
                          width: size * 0.10,
                          height: size * 0.14,
                          decoration: BoxDecoration(
                            color: Colors.red.shade700,
                            borderRadius: BorderRadius.circular(1),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.shade700.withAlpha(80),
                                blurRadius: 3,
                              ),
                            ],
                          ),
                        ),
                      ),
                    // ── captain badge
                    if (player.isCaptain)
                      Positioned(
                        top: size * 0.42,
                        left: 3,
                        child: Container(
                          width: size * 0.14,
                          height: size * 0.14,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD700),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFFD700).withAlpha(60),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              'C',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: size * 0.09,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                    // ── injury icon
                    if (player.isInjured)
                      Positioned(
                        bottom: size * 0.20,
                        right: 2,
                        child: Icon(
                          Icons.local_hospital,
                          color: Colors.redAccent,
                          size: size * 0.13,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── helpers ───
  String _shortName() {
    final name = player.name;
    // Chinese names: no space, show full (usually 2-3 chars)
    if (!name.contains(' ')) {
      return name.length > 5 ? '${name.substring(0, 4)}.' : name;
    }
    // Western names: show surname
    final p = name.split(' ');
    if (p.length >= 2) return p.last;
    return name.length > 8 ? '${name.substring(0, 7)}.' : name;
  }

  String _posAbbr() {
    if (player.positions.isEmpty) return '??';
    final pos = player.positions.first.toUpperCase();
    const m = {
      'PROP': 'PR',
      'LOOSEHEAD PROP': 'LH',
      'TIGHTHEAD PROP': 'TH',
      'HOOKER': 'HK',
      'LOCK': 'LK',
      'FLANKER': 'FL',
      'BLINDSIDE FLANKER': 'FL',
      'OPENSIDE FLANKER': 'FL',
      'NUMBER EIGHT': 'N8',
      'NUMBER 8': 'N8',
      'SCRUM-HALF': 'SH',
      'FLY-HALF': 'FH',
      'CENTRE': 'CT',
      'INSIDE CENTRE': 'CT',
      'OUTSIDE CENTRE': 'CT',
      'WING': 'WG',
      'LEFT WING': 'WG',
      'RIGHT WING': 'WG',
      'FULL-BACK': 'FB',
      'FULLBACK': 'FB',
    };
    return m[pos] ?? pos.substring(0, pos.length.clamp(0, 2));
  }

  bool _hasTags() {
    return player.isKicker ||
        player.isLineoutThrower ||
        player.isLineoutJumper ||
        player.isLineoutLifter;
  }

  List<Widget> _buildTagsInline() {
    final tags = <Widget>[];
    final s = size * 0.11;
    if (player.isKicker) {
      tags.add(
        Text(
          'K',
          style: TextStyle(
            color: const Color(0xFFFF6F00),
            fontSize: s,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
    }
    if (player.isLineoutThrower) {
      tags.add(
        Text(
          'T',
          style: TextStyle(
            color: const Color(0xFF00BCD4),
            fontSize: s,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
    }
    if (player.isLineoutJumper) {
      tags.add(
        Text(
          'J',
          style: TextStyle(
            color: const Color(0xFF4CAF50),
            fontSize: s,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
    }
    if (player.isLineoutLifter) {
      tags.add(
        Text(
          'L',
          style: TextStyle(
            color: const Color(0xFFA855F7),
            fontSize: s,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
    }
    return tags;
  }

  _C _colors() {
    if (player.redCards > 0 || matchRedCards > 0) {
      return _C(
        Colors.grey.shade700,
        Colors.grey.shade900,
        Colors.grey.shade600,
      );
    }
    switch (rarity) {
      case CardRarity.bronze:
        return const _C(
          Color(0xFF8D6E3F),
          Color(0xFF5A4424),
          Color(0xFFCD7F32),
        );
      case CardRarity.silver:
        return const _C(
          Color(0xFF8A9A9B),
          Color(0xFF505E5F),
          Color(0xFFB0BEC5),
        );
      case CardRarity.gold:
        return const _C(
          Color(0xFFD4A422),
          Color(0xFF926B15),
          Color(0xFFE8C84A),
        );
      case CardRarity.rareGold:
        return const _C(
          Color(0xFFE8B923),
          Color(0xFFA67C00),
          Color(0xFFFFD740),
        );
      case CardRarity.totw:
        return const _C(
          Color(0xFF1C2541),
          Color(0xFF0B0E1A),
          Color(0xFF5C6BC0),
        );
      case CardRarity.special:
        return const _C(
          Color(0xFF311B47),
          Color(0xFF1A0E2E),
          Color(0xFFAB47BC),
        );
    }
  }
}

class _C {
  final Color top;
  final Color bot;
  final Color border;
  const _C(this.top, this.bot, this.border);
}

// ═══════════════════════════════════════════════════
//  Empty Slot  (FUTBIN style)
// ═══════════════════════════════════════════════════
class FifaEmptySlot extends StatelessWidget {
  final int positionNumber;
  final String positionName;
  final bool isHighlighted;
  final VoidCallback? onTap;
  final double size;

  const FifaEmptySlot({
    super.key,
    required this.positionNumber,
    required this.positionName,
    this.isHighlighted = false,
    this.onTap,
    this.size = 70,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isHighlighted
        ? const Color(0xFF4CAF50)
        : const Color(0xFF3E6B48);
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: size,
              height: size * 1.18,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: const Color(0xFF152115).withAlpha(220),
                border: Border.all(color: accent, width: isHighlighted ? 2 : 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(80),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  Icons.add_rounded,
                  color: accent,
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
                positionName,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: size * 0.12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
//  Draggable wrapper
// ═══════════════════════════════════════════════════
class FifaStyleCardDraggable extends StatelessWidget {
  final Player player;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final double size;
  final CardRarity rarity;

  const FifaStyleCardDraggable({
    super.key,
    required this.player,
    this.isSelected = false,
    this.onTap,
    this.onDoubleTap,
    this.size = 70,
    this.rarity = CardRarity.gold,
  });

  @override
  Widget build(BuildContext context) {
    return Draggable<Player>(
      data: player,
      feedback: Material(
        color: Colors.transparent,
        child: FifaStyleCard(
          player: player,
          size: size * 1.1,
          isSelected: true,
          showPosition: false,
          rarity: rarity,
        ),
      ),
      childWhenDragging: FifaStyleCard(
        player: player,
        size: size,
        isDragging: true,
        rarity: rarity,
      ),
      child: FifaStyleCard(
        player: player,
        size: size,
        isSelected: isSelected,
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        rarity: rarity,
      ),
    );
  }
}
