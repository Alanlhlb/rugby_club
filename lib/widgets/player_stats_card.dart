import 'package:flutter/material.dart';
import '../models/player.dart';
import '../core/constants/app_colors.dart';

/// Top Scorer leaderboard widget
class TopScorerCard extends StatelessWidget {
  final List<PlayerStats> topScorers;
  final String title;

  const TopScorerCard({
    super.key,
    required this.topScorers,
    this.title = '得分王',
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🏆', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const Divider(),
            if (topScorers.isEmpty)
              const Padding(padding: EdgeInsets.all(16), child: Text('尚無數據'))
            else
              ...topScorers.asMap().entries.map((entry) {
                final index = entry.key;
                final stats = entry.value;
                return _buildPlayerRow(index + 1, stats);
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerRow(int rank, PlayerStats stats) {
    final rankColors = [
      Colors.amber,
      Colors.grey.shade400,
      Colors.brown.shade300,
    ];
    final rankColor = rank <= 3 ? rankColors[rank - 1] : Colors.grey.shade200;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          // Rank
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(color: rankColor, shape: BoxShape.circle),
            child: Center(
              child: Text(
                rank.toString(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: rank <= 3 ? Colors.white : Colors.black54,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Player info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stats.playerName,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  '#${stats.jerseyNumber}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          // Points
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${stats.totalPoints} 分',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primaryGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Iron Man (most appearances) leaderboard widget
class IronManCard extends StatelessWidget {
  final List<PlayerStats> ironMen;
  final String title;

  const IronManCard({super.key, required this.ironMen, this.title = '鐵人榜'});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('💪', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const Divider(),
            if (ironMen.isEmpty)
              const Padding(padding: EdgeInsets.all(16), child: Text('尚無數據'))
            else
              ...ironMen.asMap().entries.map((entry) {
                final index = entry.key;
                final stats = entry.value;
                return _buildPlayerRow(index + 1, stats);
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerRow(int rank, PlayerStats stats) {
    final rankColors = [
      Colors.amber,
      Colors.grey.shade400,
      Colors.brown.shade300,
    ];
    final rankColor = rank <= 3 ? rankColors[rank - 1] : Colors.grey.shade200;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          // Rank
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(color: rankColor, shape: BoxShape.circle),
            child: Center(
              child: Text(
                rank.toString(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: rank <= 3 ? Colors.white : Colors.black54,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Player info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stats.playerName,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  '#${stats.jerseyNumber}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          // Appearances
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${stats.appearances} 場',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Player statistics model
class PlayerStats {
  final String playerId;
  final String playerName;
  final int jerseyNumber;
  final int totalPoints;
  final int tries;
  final int conversions;
  final int penalties;
  final int dropGoals;
  final int appearances;
  final int yellowCards;
  final int redCards;

  PlayerStats({
    required this.playerId,
    required this.playerName,
    required this.jerseyNumber,
    this.totalPoints = 0,
    this.tries = 0,
    this.conversions = 0,
    this.penalties = 0,
    this.dropGoals = 0,
    this.appearances = 0,
    this.yellowCards = 0,
    this.redCards = 0,
  });

  /// Create from Player model
  factory PlayerStats.fromPlayer(
    Player player, {
    int? totalPoints,
    int? appearances,
  }) {
    return PlayerStats(
      playerId: player.id,
      playerName: player.name,
      jerseyNumber: player.jerseyNumber,
      totalPoints: totalPoints ?? 0,
      appearances: appearances ?? 0,
    );
  }
}
