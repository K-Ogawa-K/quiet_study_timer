import 'package:flutter/foundation.dart';

@immutable
class DailyStudyTotal {
  const DailyStudyTotal({required this.date, required this.totalSeconds});

  final DateTime date;
  final int totalSeconds;
}

@immutable
class SevenDayAnalytics {
  const SevenDayAnalytics({
    required this.days,
    required this.totalSeconds,
    required this.subjectTotals,
  });

  final List<DailyStudyTotal> days;
  final int totalSeconds;
  final Map<String, int> subjectTotals;

  bool get hasRecords => totalSeconds > 0;
}
