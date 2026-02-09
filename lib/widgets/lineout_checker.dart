import 'package:flutter/material.dart';
import '../models/player.dart';

/// Lineout roster validation and warnings
class LineoutChecker {
  final Map<int, Player?> lineup;
  final List<Player> allPlayers;

  LineoutChecker({required this.lineup, required this.allPlayers});

  /// Check all lineout requirements and return warnings
  List<LineoutWarning> checkLineout() {
    final warnings = <LineoutWarning>[];

    // Check for lineout thrower (position 2 - Hooker)
    final hooker = lineup[2];
    if (hooker != null && !hooker.isLineoutThrower) {
      warnings.add(
        LineoutWarning(
          type: WarningType.noThrower,
          message: '第 2 號位 (${hooker.name}) 未標記為 Lineout Thrower',
          severity: WarningSeverity.warning,
          suggestion: '建議選擇有 Lineout Thrower 經驗的球員',
        ),
      );
    }

    // Check for jumpers (typically positions 4, 5, 6, 7, 8)
    final jumpPositions = [4, 5, 6, 7, 8];
    final jumpersInLineup = jumpPositions
        .map((pos) => lineup[pos])
        .where((p) => p != null && p.isLineoutJumper)
        .length;

    if (jumpersInLineup < 2) {
      warnings.add(
        LineoutWarning(
          type: WarningType.insufficientJumpers,
          message: '只有 $jumpersInLineup 名 Lineout Jumper 在前鋒位置',
          severity: WarningSeverity.warning,
          suggestion: '建議至少有 2 名 Jumper 在 4-8 號位',
        ),
      );
    }

    // Check for lifters (typically positions 4, 5, 6, 7)
    final liftPositions = [4, 5, 6, 7];
    final liftersInLineup = liftPositions
        .map((pos) => lineup[pos])
        .where((p) => p != null && p.isLineoutLifter)
        .length;

    if (liftersInLineup < 2) {
      warnings.add(
        LineoutWarning(
          type: WarningType.insufficientLifters,
          message: '只有 $liftersInLineup 名 Lineout Lifter 在鎖定位',
          severity: WarningSeverity.info,
          suggestion: '建議至少有 2 名 Lifter 來支援 Jumper',
        ),
      );
    }

    // Check for injured players
    final injuredOnField = lineup.values
        .where((p) => p != null && p.isInjured)
        .toList();

    if (injuredOnField.isNotEmpty) {
      warnings.add(
        LineoutWarning(
          type: WarningType.injuredPlayer,
          message:
              '${injuredOnField.length} 名傷病球員在場上: ${injuredOnField.map((p) => p!.name).join(", ")}',
          severity: WarningSeverity.error,
          suggestion: '建議替換傷病球員',
        ),
      );
    }

    // Check for red-carded players
    final redCardedOnField = lineup.values
        .where((p) => p != null && p.redCards > 0)
        .toList();

    if (redCardedOnField.isNotEmpty) {
      warnings.add(
        LineoutWarning(
          type: WarningType.redCardPlayer,
          message: '${redCardedOnField.length} 名紅牌球員在場上',
          severity: WarningSeverity.error,
          suggestion: '紅牌球員無法上場比賽',
        ),
      );
    }

    // Check for captain on field
    final captainOnField = lineup.values.any((p) => p != null && p.isCaptain);
    if (!captainOnField) {
      // Check if any captain exists in the squad
      final hasCaptain = allPlayers.any((p) => p.isCaptain);
      if (hasCaptain) {
        warnings.add(
          LineoutWarning(
            type: WarningType.noCaptain,
            message: '隊長未在場上',
            severity: WarningSeverity.info,
            suggestion: '考慮將隊長安排到陣容中',
          ),
        );
      }
    }

    return warnings;
  }

  /// Get a quick summary status
  LineoutStatus getStatus() {
    final warnings = checkLineout();

    if (warnings.any((w) => w.severity == WarningSeverity.error)) {
      return LineoutStatus.error;
    }
    if (warnings.any((w) => w.severity == WarningSeverity.warning)) {
      return LineoutStatus.warning;
    }
    if (warnings.isNotEmpty) {
      return LineoutStatus.info;
    }
    return LineoutStatus.ok;
  }
}

enum WarningType {
  noThrower,
  insufficientJumpers,
  insufficientLifters,
  injuredPlayer,
  redCardPlayer,
  noCaptain,
}

enum WarningSeverity { info, warning, error }

enum LineoutStatus { ok, info, warning, error }

class LineoutWarning {
  final WarningType type;
  final String message;
  final WarningSeverity severity;
  final String suggestion;

  LineoutWarning({
    required this.type,
    required this.message,
    required this.severity,
    required this.suggestion,
  });

  IconData get icon {
    switch (severity) {
      case WarningSeverity.error:
        return Icons.error;
      case WarningSeverity.warning:
        return Icons.warning;
      case WarningSeverity.info:
        return Icons.info;
    }
  }

  Color get color {
    switch (severity) {
      case WarningSeverity.error:
        return Colors.red;
      case WarningSeverity.warning:
        return Colors.orange;
      case WarningSeverity.info:
        return Colors.blue;
    }
  }
}

/// Widget to display lineout warnings
class LineoutWarningsWidget extends StatelessWidget {
  final List<LineoutWarning> warnings;
  final VoidCallback? onDismiss;

  const LineoutWarningsWidget({
    super.key,
    required this.warnings,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    if (warnings.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('陣容檢查通過 ✓', style: TextStyle(color: Colors.green)),
          ],
        ),
      );
    }

    return Column(
      children: warnings.map((warning) => _buildWarningTile(warning)).toList(),
    );
  }

  Widget _buildWarningTile(LineoutWarning warning) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: warning.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: warning.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(warning.icon, color: warning.color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  warning.message,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: warning.color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  warning.suggestion,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Status indicator badge for lineout
class LineoutStatusBadge extends StatelessWidget {
  final LineoutStatus status;

  const LineoutStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getColor().withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _getColor().withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getIcon(), size: 14, color: _getColor()),
          const SizedBox(width: 4),
          Text(
            _getText(),
            style: TextStyle(
              fontSize: 12,
              color: _getColor(),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Color _getColor() {
    switch (status) {
      case LineoutStatus.ok:
        return Colors.green;
      case LineoutStatus.info:
        return Colors.blue;
      case LineoutStatus.warning:
        return Colors.orange;
      case LineoutStatus.error:
        return Colors.red;
    }
  }

  IconData _getIcon() {
    switch (status) {
      case LineoutStatus.ok:
        return Icons.check_circle;
      case LineoutStatus.info:
        return Icons.info;
      case LineoutStatus.warning:
        return Icons.warning;
      case LineoutStatus.error:
        return Icons.error;
    }
  }

  String _getText() {
    switch (status) {
      case LineoutStatus.ok:
        return '就緒';
      case LineoutStatus.info:
        return '提示';
      case LineoutStatus.warning:
        return '警告';
      case LineoutStatus.error:
        return '錯誤';
    }
  }
}
