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

String _twoDigits(int value) {
  return value.toString().padLeft(2, '0');
}
