import 'package:flutter/material.dart';
import '../models/season.dart';
import '../core/constants/app_colors.dart';

/// Season dropdown selector widget
class SeasonSelector extends StatelessWidget {
  final Season? currentSeason;
  final List<Season> seasons;
  final ValueChanged<Season> onSeasonChanged;
  final VoidCallback? onAddSeason;

  const SeasonSelector({
    super.key,
    required this.currentSeason,
    required this.seasons,
    required this.onSeasonChanged,
    this.onAddSeason,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<Season>(
      initialValue: currentSeason,
      onSelected: onSeasonChanged,
      itemBuilder: (context) => [
        ...seasons.map((season) => PopupMenuItem<Season>(
          value: season,
          child: Row(
            children: [
              Icon(
                season.id == currentSeason?.id 
                    ? Icons.check_circle 
                    : Icons.circle_outlined,
                size: 18,
                color: season.id == currentSeason?.id 
                    ? AppColors.primaryGreen 
                    : Colors.grey,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      season.name,
                      style: TextStyle(
                        fontWeight: season.id == currentSeason?.id 
                            ? FontWeight.bold 
                            : FontWeight.normal,
                      ),
                    ),
                    Text(
                      '${_formatDate(season.startDate)} - ${_formatDate(season.endDate)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (season.isActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '進行中',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        )),
        if (onAddSeason != null) ...[
          const PopupMenuDivider(),
          PopupMenuItem<Season>(
            value: null,
            onTap: onAddSeason,
            child: const Row(
              children: [
                Icon(Icons.add, size: 18, color: Colors.blue),
                SizedBox(width: 12),
                Text('新增賽季', style: TextStyle(color: Colors.blue)),
              ],
            ),
          ),
        ],
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primaryGreen.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today, size: 14, color: Colors.green),
            const SizedBox(width: 6),
            Text(
              currentSeason?.name ?? '選擇賽季',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 18, color: Colors.green),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month}';
  }
}

/// Season comparison widget
class SeasonComparisonCard extends StatelessWidget {
  final Season season1;
  final Season season2;
  final Map<String, dynamic> stats1;
  final Map<String, dynamic> stats2;

  const SeasonComparisonCard({
    super.key,
    required this.season1,
    required this.season2,
    required this.stats1,
    required this.stats2,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '賽季比較',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        season1.name,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      _buildStatItem('比賽', stats1['matches']?.toString() ?? '0'),
                      _buildStatItem('勝場', stats1['wins']?.toString() ?? '0'),
                      _buildStatItem('得分', stats1['points']?.toString() ?? '0'),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 80,
                  color: Colors.grey.shade300,
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        season2.name,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      _buildStatItem('比賽', stats2['matches']?.toString() ?? '0'),
                      _buildStatItem('勝場', stats2['wins']?.toString() ?? '0'),
                      _buildStatItem('得分', stats2['points']?.toString() ?? '0'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
