import 'package:intl/intl.dart';

String formatTimerSeconds(int seconds) {
  final safeSeconds = seconds < 0 ? 0 : seconds;
  final hours = safeSeconds ~/ 3600;
  final minutes = (safeSeconds % 3600) ~/ 60;
  final remainingSeconds = safeSeconds % 60;

  if (hours > 0) {
    return '$hours:${_twoDigits(minutes)}:${_twoDigits(remainingSeconds)}';
  }

  return '${_twoDigits(minutes)}:${_twoDigits(remainingSeconds)}';
}

String formatDurationCompact(int seconds) {
  if (seconds <= 0) {
    return '0分';
  }

  if (seconds < 60) {
    return '1分未満';
  }

  final minutes = seconds ~/ 60;
  final hours = minutes ~/ 60;
  final remainingMinutes = minutes % 60;

  if (hours == 0) {
    return '$minutes分';
  }

  if (remainingMinutes == 0) {
    return '$hours時間';
  }

  return '$hours時間$remainingMinutes分';
}

String formatClockRange(DateTime startedAt, DateTime endedAt) {
  final formatter = DateFormat('H:mm');
  return '${formatter.format(startedAt)}-${formatter.format(endedAt)}';
}

String formatRecordSectionTitle(DateTime date, DateTime now) {
  final localDate = DateTime(date.year, date.month, date.day);
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));

  if (localDate == today) {
    return '今日';
  }
  if (localDate == yesterday) {
    return '昨日';
  }

  return DateFormat('M月d日').format(localDate);
}

String formatFormDate(DateTime date) {
  return DateFormat('yyyy/M/d').format(date);
}

String formatClock(DateTime dateTime) {
  return DateFormat('H:mm').format(dateTime);
}

String _twoDigits(int value) {
  return value.toString().padLeft(2, '0');
}
