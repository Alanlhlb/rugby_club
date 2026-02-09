import 'package:flutter/material.dart';
import '../models/player.dart';

/// Service for exporting lineup as PDF or image
class PdfExportService {
  /// Generate lineup sheet data for export
  static LineupExportData generateLineupData({
    required String teamName,
    required String opponent,
    required DateTime matchDate,
    required Map<int, Player?> lineup,
    required List<Player> bench,
  }) {
    return LineupExportData(
      teamName: teamName,
      opponent: opponent,
      matchDate: matchDate,
      lineup: lineup,
      bench: bench,
    );
  }

  /// Format lineup as text for sharing
  static String formatLineupAsText(LineupExportData data) {
    final buffer = StringBuffer();

    buffer.writeln('═══════════════════════════════');
    buffer.writeln('       ${data.teamName}');
    buffer.writeln('    vs ${data.opponent}');
    buffer.writeln('   ${_formatDate(data.matchDate)}');
    buffer.writeln('═══════════════════════════════');
    buffer.writeln();

    // Starting XV
    buffer.writeln('【正選陣容】');
    buffer.writeln('───────────────────────────────');

    // Forwards
    buffer.writeln('前鋒:');
    for (int i = 1; i <= 8; i++) {
      final player = data.lineup[i];
      buffer.writeln(
        '  ${i.toString().padLeft(2)}. ${player?.name ?? "空缺"} ${player != null ? "#${player.jerseyNumber}" : ""}',
      );
    }

    buffer.writeln();

    // Backs
    buffer.writeln('後衛:');
    for (int i = 9; i <= 15; i++) {
      final player = data.lineup[i];
      buffer.writeln(
        '  ${i.toString().padLeft(2)}. ${player?.name ?? "空缺"} ${player != null ? "#${player.jerseyNumber}" : ""}',
      );
    }

    buffer.writeln();

    // Bench
    if (data.bench.isNotEmpty) {
      buffer.writeln('【替補席】');
      buffer.writeln('───────────────────────────────');
      for (int i = 0; i < data.bench.length; i++) {
        final player = data.bench[i];
        buffer.writeln(
          '  ${(16 + i).toString().padLeft(2)}. ${player.name} #${player.jerseyNumber}',
        );
      }
    }

    buffer.writeln();
    buffer.writeln('═══════════════════════════════');

    return buffer.toString();
  }

  /// Get position name for display
  static String getPositionName(int position) {
    const names = {
      1: 'Loosehead Prop',
      2: 'Hooker',
      3: 'Tighthead Prop',
      4: 'Lock',
      5: 'Lock',
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
    return names[position] ?? 'Position $position';
  }

  /// Get Chinese position name
  static String getPositionNameCN(int position) {
    const names = {
      1: '鬆頭支柱',
      2: '鈎球員',
      3: '緊頭支柱',
      4: '鎖',
      5: '鎖',
      6: '盲邊側翼',
      7: '開邊側翼',
      8: '八號',
      9: '傳鋒',
      10: '接鋒',
      11: '左翼',
      12: '內中鋒',
      13: '外中鋒',
      14: '右翼',
      15: '殿衛',
    };
    return names[position] ?? '位置 $position';
  }

  static String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }
}

class LineupExportData {
  final String teamName;
  final String opponent;
  final DateTime matchDate;
  final Map<int, Player?> lineup;
  final List<Player> bench;

  LineupExportData({
    required this.teamName,
    required this.opponent,
    required this.matchDate,
    required this.lineup,
    required this.bench,
  });

  int get filledPositions => lineup.values.where((p) => p != null).length;
  int get totalPositions => 15;
}

/// Widget for lineup export preview
class LineupExportPreview extends StatelessWidget {
  final LineupExportData data;
  final VoidCallback? onShare;
  final VoidCallback? onCopy;

  const LineupExportPreview({
    super.key,
    required this.data,
    this.onShare,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade700,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Column(
              children: [
                Text(
                  data.teamName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'vs ${data.opponent}',
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  PdfExportService._formatDate(data.matchDate),
                  style: const TextStyle(color: Colors.white60, fontSize: 14),
                ),
              ],
            ),
          ),

          // Lineup grid
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '正選陣容',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Divider(),

                // Forwards
                _buildPositionGroup('前鋒', 1, 8),
                const SizedBox(height: 8),

                // Backs
                _buildPositionGroup('後衛', 9, 15),

                if (data.bench.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    '替補席',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Divider(),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: data.bench.asMap().entries.map((e) {
                      return _buildPlayerChip(16 + e.key, e.value);
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),

          // Action buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onCopy,
                    icon: const Icon(Icons.copy),
                    label: const Text('複製文字'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onShare,
                    icon: Icon(Icons.adaptive.share),
                    label: const Text('分享'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPositionGroup(String title, int start, int end) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(end - start + 1, (i) {
            final pos = start + i;
            final player = data.lineup[pos];
            return _buildPlayerChip(pos, player);
          }),
        ),
      ],
    );
  }

  Widget _buildPlayerChip(int position, Player? player) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: player != null ? Colors.green.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: player != null ? Colors.green.shade200 : Colors.grey.shade300,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$position.',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: player != null ? Colors.green : Colors.grey,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            player?.name ?? '空缺',
            style: TextStyle(
              color: player != null ? Colors.black87 : Colors.grey,
            ),
          ),
          if (player != null) ...[
            const SizedBox(width: 4),
            Text(
              '#${player.jerseyNumber}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ],
      ),
    );
  }
}
