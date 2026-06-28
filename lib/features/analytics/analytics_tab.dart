import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_theme.dart';
import '../../models/study_analytics.dart';
import '../../models/study_subject.dart';
import '../../state/study_providers.dart';
import '../../utils/time_format.dart';

class AnalyticsTab extends ConsumerWidget {
  const AnalyticsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analytics = ref.watch(sevenDayAnalyticsProvider);
    final subjects = ref.watch(subjectsProvider);

    return CupertinoPageScaffold(
      navigationBar: _navigationBar(context, '分析'),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          children: [
            _SummaryCard(totalSeconds: analytics.totalSeconds),
            const SizedBox(height: 18),
            if (analytics.hasRecords) ...[
              _SevenDayBars(days: analytics.days),
              const SizedBox(height: 18),
              _SubjectBreakdown(
                totalSeconds: analytics.totalSeconds,
                subjectTotals: analytics.subjectTotals,
                subjects: subjects,
              ),
            ] else
              const _EmptyAnalyticsCard(),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.totalSeconds});

  final int totalSeconds;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _surfaceDecoration(theme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '7日間',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            formatDurationCompact(totalSeconds),
            style: theme.textTheme.titleLarge,
          ),
        ],
      ),
    );
  }
}

class _SevenDayBars extends StatelessWidget {
  const _SevenDayBars({required this.days});

  final List<DailyStudyTotal> days;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxSeconds = days.fold<int>(
      0,
      (maxSeconds, day) => max(maxSeconds, day.totalSeconds),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: _surfaceDecoration(theme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('日別', style: theme.textTheme.titleMedium),
          const SizedBox(height: 16),
          SizedBox(
            height: 118,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final day in days) ...[
                  Expanded(
                    child: _DayBar(
                      day: day,
                      maxSeconds: maxSeconds,
                      isToday: _isSameLocalDay(day.date, DateTime.now()),
                    ),
                  ),
                  if (day != days.last) const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DayBar extends StatelessWidget {
  const _DayBar({
    required this.day,
    required this.maxSeconds,
    required this.isToday,
  });

  final DailyStudyTotal day;
  final int maxSeconds;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fraction = maxSeconds == 0 ? 0.0 : day.totalSeconds / maxSeconds;
    final barHeight = day.totalSeconds == 0 ? 2.0 : max(12.0, 82.0 * fraction);
    final barColor = isToday
        ? AppTheme.accentBlue
        : AppTheme.accentBlue.withValues(alpha: 0.42);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SizedBox(
          height: 86,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: 8,
              height: barHeight,
              decoration: BoxDecoration(
                color: day.totalSeconds == 0 ? theme.dividerColor : barColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _weekdayLabel(day.date),
          style: theme.textTheme.labelMedium?.copyWith(
            color: isToday
                ? AppTheme.accentBlue
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: isToday ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _SubjectBreakdown extends StatelessWidget {
  const _SubjectBreakdown({
    required this.totalSeconds,
    required this.subjectTotals,
    required this.subjects,
  });

  final int totalSeconds;
  final Map<String, int> subjectTotals;
  final List<StudySubject> subjects;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = subjectTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      decoration: _surfaceDecoration(theme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('科目別', style: theme.textTheme.titleMedium),
          ),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Text(
                '内訳はまだありません',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            for (final entry in rows)
              _BreakdownRow(
                subject: _subjectById(subjects, entry.key),
                seconds: entry.value,
                fraction: totalSeconds == 0 ? 0 : entry.value / totalSeconds,
              ),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.subject,
    required this.seconds,
    required this.fraction,
  });

  final StudySubject subject;
  final int seconds;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subjectColor = Color(int.parse('FF${subject.colorHex}', radix: 16));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: subjectColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  subject.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              Text(
                formatDurationCompact(seconds),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Container(
              height: 6,
              color: theme.dividerColor,
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: fraction.clamp(0, 1),
                child: Container(color: subjectColor),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyAnalyticsCard extends StatelessWidget {
  const _EmptyAnalyticsCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 30),
      decoration: _surfaceDecoration(theme),
      child: Column(
        children: [
          Text('記録はまだありません', style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            '集中すると7日間が見えます',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

CupertinoNavigationBar _navigationBar(BuildContext context, String title) {
  final theme = Theme.of(context);
  return CupertinoNavigationBar(
    middle: Text(title),
    border: Border(bottom: BorderSide(color: theme.dividerColor)),
    backgroundColor: theme.scaffoldBackgroundColor.withValues(alpha: 0.92),
  );
}

BoxDecoration _surfaceDecoration(ThemeData theme) {
  return BoxDecoration(
    color: theme.colorScheme.surface,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: theme.dividerColor),
  );
}

StudySubject _subjectById(List<StudySubject> subjects, String subjectId) {
  return subjects.firstWhere(
    (subject) => subject.id == subjectId,
    orElse: () => StudySubject(
      id: subjectId,
      name: '未設定',
      colorHex: '8E8E93',
      sortOrder: 999,
    ),
  );
}

String _weekdayLabel(DateTime date) {
  return switch (date.weekday) {
    DateTime.monday => '月',
    DateTime.tuesday => '火',
    DateTime.wednesday => '水',
    DateTime.thursday => '木',
    DateTime.friday => '金',
    DateTime.saturday => '土',
    _ => '日',
  };
}

bool _isSameLocalDay(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}
