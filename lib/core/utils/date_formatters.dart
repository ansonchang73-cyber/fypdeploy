import 'package:intl/intl.dart';

class DateFormatters {
  /// Formats DateTime to "08:00 AM"
  static String formatToTime(DateTime date) {
    return DateFormat('hh:mm a').format(date);
  }

  /// Formats DateTime to "Oct 24"
  static String formatToMonthDay(DateTime date) {
    return DateFormat('MMM dd').format(date);
  }

  /// Formats DateTime to "Tomorrow 10:30 AM" or "Today 08:00 AM"
  static String formatRelativeTime(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final targetDate = DateTime(date.year, date.month, date.day);

    final timeString = formatToTime(date);

    if (targetDate == today) {
      return 'Today $timeString';
    } else if (targetDate == tomorrow) {
      return 'Tomorrow $timeString';
    } else {
      return '${formatToMonthDay(date)} $timeString';
    }
  }
}