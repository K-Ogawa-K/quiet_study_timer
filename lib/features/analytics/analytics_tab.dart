import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/study_subject.dart';
import '../../state/study_providers.dart';
import '../../utils/time_format.dart';

class AnalyticsTab extends ConsumerWidget {
  const AnalyticsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalSeconds = ref.watch(todayTotalSecondsProvider);
    final subjectTotals = ref.watch(todaySubjectTotalsProvider);
    final subjects = ref.watch(subjectsProvider);

    return CupertinoPageScaffold(
      navigationBar: _navigationBar(context, '分析'),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            _SummaryCard(totalSeconds: totalSeconds),
            const SizedBox(height: 18),
            _SubjectBreakdown(
              totalSeconds: totalSeconds,
              subjectTotals: subjectTotals,
              subjects: subjects,
            ),
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
      padding: const EdgeInsets.all(18),
      decoration: _surfaceDecoration(theme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '今日',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            formatDurationCompact(totalSeconds),
            style: theme.textTheme.titleLarge,
          ),
        ],
      ),
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
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
              child: Text(
                '今日はまだ記録がありません',
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(subject.name, style: theme.textTheme.bodyMedium),
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
            child: LinearProgressIndicator(
              value: fraction.clamp(0, 1),
              minHeight: 6,
              color: Color(int.parse('FF${subject.colorHex}', radix: 16)),
              backgroundColor: theme.dividerColor,
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
    orElse: () => subjects.first,
  );
}
