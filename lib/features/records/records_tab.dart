import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/study_record.dart';
import '../../models/study_subject.dart';
import '../../state/study_providers.dart';
import '../../utils/time_format.dart';

class RecordsTab extends ConsumerWidget {
  const RecordsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(todayRecordsProvider);
    final subjects = ref.watch(subjectsProvider);
    final totalSeconds = ref.watch(todayTotalSecondsProvider);

    return CupertinoPageScaffold(
      navigationBar: _navigationBar(context, '記録'),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            _DayHeader(totalSeconds: totalSeconds),
            const SizedBox(height: 14),
            if (records.isEmpty)
              const _EmptyRecords()
            else
              _RecordList(records: records, subjects: subjects),
          ],
        ),
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.totalSeconds});

  final int totalSeconds;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Text('今日', style: theme.textTheme.titleLarge),
          const Spacer(),
          Text(
            formatDurationCompact(totalSeconds),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordList extends StatelessWidget {
  const _RecordList({required this.records, required this.subjects});

  final List<StudyRecord> records;
  final List<StudySubject> subjects;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: _surfaceDecoration(theme),
      child: Column(
        children: [
          for (final (index, record) in records.indexed) ...[
            _StudyRecordRow(
              record: record,
              subject: _subjectById(subjects, record.subjectId),
            ),
            if (index != records.length - 1)
              Divider(
                height: 1,
                thickness: 1,
                indent: 52,
                color: theme.dividerColor,
              ),
          ],
        ],
      ),
    );
  }
}

class _StudyRecordRow extends StatelessWidget {
  const _StudyRecordRow({required this.record, required this.subject});

  final StudyRecord record;
  final StudySubject subject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          _SubjectDot(subject: subject),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(subject.name, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  formatClockRange(record.startedAt, record.endedAt),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            formatDurationCompact(record.durationSeconds),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyRecords extends StatelessWidget {
  const _EmptyRecords();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
      decoration: _surfaceDecoration(theme),
      child: Text(
        '今日はまだ記録がありません',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
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

class _SubjectDot extends StatelessWidget {
  const _SubjectDot({required this.subject});

  final StudySubject subject;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: Color(int.parse('FF${subject.colorHex}', radix: 16)),
        shape: BoxShape.circle,
      ),
    );
  }
}
