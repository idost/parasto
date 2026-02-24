import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:myna/models/analytics_models.dart';
import 'package:myna/services/admin_unicef_report_service.dart';
import 'package:myna/utils/app_logger.dart';

/// Utility class for exporting analytics data to CSV format
class CsvExport {
  /// Export generic data to CSV and share
  static Future<bool> exportAndShare({
    required List<String> headers,
    required List<List<dynamic>> rows,
    required String filename,
  }) async {
    try {
      // Build CSV content
      final buffer = StringBuffer();

      // BOM for Excel UTF-8 support (ensures Persian text displays correctly)
      buffer.write('\uFEFF');

      // Headers
      buffer.writeln(headers.map(_escapeCell).join(','));

      // Rows
      for (final row in rows) {
        buffer.writeln(row.map(_escapeCell).join(','));
      }

      // Write to temp file
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsString(buffer.toString(), encoding: utf8);

      // Share
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: filename,
      );

      return true;
    } catch (e) {
      AppLogger.e('Error exporting CSV', error: e);
      return false;
    }
  }

  /// Escape a cell value for CSV format
  static String _escapeCell(dynamic cell) {
    final str = cell?.toString() ?? '';
    // Escape quotes and wrap in quotes if contains comma, quote, or newline
    if (str.contains(',') || str.contains('"') || str.contains('\n') || str.contains('\r')) {
      return '"${str.replaceAll('"', '""')}"';
    }
    return str;
  }

  /// Export top content rankings to CSV
  static Future<bool> exportTopContent(List<ContentRanking> items) async {
    return exportAndShare(
      headers: ['رتبه', 'عنوان', 'نوع', 'ساعت شنیدن', 'شنوندگان', 'امتیاز', 'تعداد فروش', 'درآمد'],
      rows: items.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        return [
          index + 1,
          item.title,
          item.typeLabel,
          item.totalHours.toStringAsFixed(1),
          item.uniqueListeners,
          item.avgRating.toStringAsFixed(1),
          item.purchaseCount,
          '\$${item.revenue.toStringAsFixed(2)}',
        ];
      }).toList(),
      filename: 'parasto_top_content_${_dateString()}.csv',
    );
  }

  /// Export top creators rankings to CSV
  static Future<bool> exportTopCreators(List<CreatorRanking> items) async {
    return exportAndShare(
      headers: ['رتبه', 'نام', 'نقش', 'تعداد محتوا', 'ساعت شنیدن', 'درآمد'],
      rows: items.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        return [
          index + 1,
          item.name,
          item.typeLabel,
          item.contentCount,
          item.totalHours.toStringAsFixed(1),
          '\$${item.totalRevenue.toStringAsFixed(2)}',
        ];
      }).toList(),
      filename: 'parasto_top_creators_${_dateString()}.csv',
    );
  }

  /// Export daily listening data to CSV
  static Future<bool> exportDailyListening(List<DailyListening> items) async {
    return exportAndShare(
      headers: ['تاریخ', 'ساعت شنیدن'],
      rows: items.map((item) => [
        item.fullDate,
        item.hours.toStringAsFixed(2),
      ]).toList(),
      filename: 'parasto_daily_listening_${_dateString()}.csv',
    );
  }

  /// Export user stats to CSV
  static Future<bool> exportUserStats(UserStats stats) async {
    final rows = <List<dynamic>>[
      ['کاربران فعال روزانه (DAU)', stats.dau],
      ['کاربران فعال هفتگی (WAU)', stats.wau],
      ['کاربران فعال ماهانه (MAU)', stats.mau],
      ['ثبت‌نام جدید', stats.newSignups],
      ['کل کاربران', stats.totalUsers],
      ['', ''],
      ['تفکیک نقش', ''],
      ['شنوندگان', stats.listenerCount],
      ['گویندگان', stats.narratorCount],
      ['مدیران', stats.adminCount],
    ];

    return exportAndShare(
      headers: ['شاخص', 'مقدار'],
      rows: rows,
      filename: 'parasto_user_stats_${_dateString()}.csv',
    );
  }

  /// Export sales stats to CSV
  static Future<bool> exportSalesStats(SalesStats stats) async {
    final rows = <List<dynamic>>[
      ['کل خرید', stats.totalPurchases],
      ['کل درآمد', stats.formattedRevenue],
      ['خریداران یکتا', stats.uniqueBuyers],
    ];

    return exportAndShare(
      headers: ['شاخص', 'مقدار'],
      rows: rows,
      filename: 'parasto_sales_stats_${_dateString()}.csv',
    );
  }

  /// Export a Unicef analytics snapshot to CSV and share it.
  /// Returns true if the file was shared successfully.
  static Future<bool> exportUnicefSnapshot(UnicefSnapshotData snapshot) async {
    final rows = <List<dynamic>>[
      ['بازه گزارش', '${snapshot.reportStart.toLocal()} — ${snapshot.reportEnd.toLocal()}'],
      ['کل زمان شنیدن (ساعت)', snapshot.totalHours.toStringAsFixed(1)],
      ['شنوندگان یکتا', snapshot.uniqueListeners],
      ['محتوای یکتا پخش شده', snapshot.uniqueContent],
      ['کاربران فعال روزانه (DAU)', snapshot.dau],
      ['کاربران فعال هفتگی (WAU)', snapshot.wau],
      ['کاربران فعال ماهانه (MAU)', snapshot.mau],
      ['کل کاربران', snapshot.totalUsers],
      ['ثبت‌نام جدید', snapshot.newSignups],
      ['کل گویندگان', snapshot.totalNarrators],
      ['کل کتاب‌های صوتی', snapshot.totalAudiobooks],
      ['کل موسیقی', snapshot.totalMusic],
      ['کل پادکست', snapshot.totalPodcasts],
      ['کل کتاب الکترونیکی', snapshot.totalEbooks],
    ];
    return exportAndShare(
      headers: ['شاخص', 'مقدار'],
      rows: rows,
      filename: 'parasto_unicef_${_dateString()}.csv',
    );
  }

  /// Get current date string for filenames
  static String _dateString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
