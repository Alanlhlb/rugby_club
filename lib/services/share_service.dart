import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/player.dart';
import '../models/event.dart';
import 'pdf_export_service.dart';

/// Service for sharing content
class ShareService {
  /// Share match result
  static Future<void> shareMatchResult({
    required BuildContext context,
    required String teamName,
    required String opponent,
    required int homeScore,
    required int awayScore,
    required DateTime matchDate,
  }) async {
    final isWin = homeScore > awayScore;
    final isDraw = homeScore == awayScore;
    final result = isWin
        ? '🎉 勝利!'
        : isDraw
        ? '🤝 平局'
        : '😔 惜敗';

    final text =
        '''
$result

$teamName $homeScore - $awayScore $opponent

📅 ${_formatDate(matchDate)}

#RugbyClub #Rugby
''';

    await _showShareSheet(context, text);
  }

  /// Share lineup
  static Future<void> shareLineup({
    required BuildContext context,
    required String teamName,
    required String opponent,
    required DateTime matchDate,
    required Map<int, Player?> lineup,
    required List<Player> bench,
  }) async {
    final data = PdfExportService.generateLineupData(
      teamName: teamName,
      opponent: opponent,
      matchDate: matchDate,
      lineup: lineup,
      bench: bench,
    );

    final text = PdfExportService.formatLineupAsText(data);
    await _showShareSheet(context, text);
  }

  /// Share event details
  static Future<void> shareEvent({
    required BuildContext context,
    required Event event,
  }) async {
    final text =
        '''
📅 ${event.displayTitle}

🗓️ ${_formatDate(event.date)} ${_formatTime(event.date)}
${event.location != null ? '📍 ${event.location}' : ''}
${event.notes != null ? '\n📝 ${event.notes}' : ''}

#RugbyClub
''';

    await _showShareSheet(context, text);
  }

  /// Share player stats
  static Future<void> sharePlayerStats({
    required BuildContext context,
    required Player player,
  }) async {
    final text =
        '''
🏉 ${player.name} #${player.jerseyNumber}

📊 本季數據:
• 達陣: ${player.tries}
• 轉換: ${player.conversions}
• 罰球: ${player.penalties}
• 總得分: ${player.totalPoints}

#RugbyClub #Rugby
''';

    await _showShareSheet(context, text);
  }

  /// Copy text to clipboard
  static Future<void> copyToClipboard(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已複製到剪貼簿'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// Show share bottom sheet with options
  static Future<void> _showShareSheet(BuildContext context, String text) async {
    await showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '分享',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),

            // Preview
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                text.length > 200 ? '${text.substring(0, 200)}...' : text,
                style: const TextStyle(fontSize: 12),
              ),
            ),

            const SizedBox(height: 16),

            // Share options
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildShareOption(
                  context,
                  icon: Icons.copy,
                  label: '複製',
                  color: Colors.blue,
                  onTap: () {
                    Navigator.pop(context);
                    copyToClipboard(context, text);
                  },
                ),
                _buildShareOption(
                  context,
                  icon: Icons.message,
                  label: 'WhatsApp',
                  color: Colors.green,
                  onTap: () {
                    Navigator.pop(context);
                    _shareToWhatsApp(context, text);
                  },
                ),
                _buildShareOption(
                  context,
                  icon: Icons.telegram,
                  label: 'Telegram',
                  color: Colors.blue.shade400,
                  onTap: () {
                    Navigator.pop(context);
                    _shareToTelegram(context, text);
                  },
                ),
                _buildShareOption(
                  context,
                  icon: Icons.adaptive.more,
                  label: '更多',
                  color: Colors.grey,
                  onTap: () {
                    Navigator.pop(context);
                    _shareNative(context, text);
                  },
                ),
              ],
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  static Widget _buildShareOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  static Future<void> _shareToWhatsApp(
    BuildContext context,
    String text,
  ) async {
    final scaffold = ScaffoldMessenger.of(context);
    final url = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        await copyToClipboard(context, text);
        scaffold.showSnackBar(
          const SnackBar(content: Text('未安裝 WhatsApp，內容已複製到剪貼簿')),
        );
      }
    }
  }

  static Future<void> _shareToTelegram(
    BuildContext context,
    String text,
  ) async {
    final scaffold = ScaffoldMessenger.of(context);
    final url = Uri.parse(
      'https://t.me/share/url?text=${Uri.encodeComponent(text)}',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        await copyToClipboard(context, text);
        scaffold.showSnackBar(
          const SnackBar(content: Text('未安裝 Telegram，內容已複製到剪貼簿')),
        );
      }
    }
  }

  static Future<void> _shareNative(BuildContext context, String text) async {
    await copyToClipboard(context, text);
  }

  static String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  static String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
