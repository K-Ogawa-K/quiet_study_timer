import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_theme.dart';
import '../../models/study_record.dart';
import '../../models/study_subject.dart';
import '../../state/study_providers.dart';
import '../../utils/time_format.dart';

class RecordsTab extends ConsumerWidget {
  const RecordsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(recordsControllerProvider);
    final subjects = ref.watch(subjectsProvider);
    final groups = _groupRecordsByDay(records);

    return CupertinoPageScaffold(
      navigationBar: _navigationBar(context),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            if (groups.isEmpty)
              const _EmptyRecords()
            else
              for (final group in groups) ...[
                _DailyRecordSection(group: group, subjects: subjects),
                const SizedBox(height: 18),
              ],
          ],
        ),
      ),
    );
  }
}

class _DailyRecordSection extends ConsumerWidget {
  const _DailyRecordSection({required this.group, required this.subjects});

  final _DailyRecordGroup group;
  final List<StudySubject> subjects;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final now = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Text(
                formatRecordSectionTitle(group.date, now),
                style: theme.textTheme.titleLarge,
              ),
              const Spacer(),
              Text(
                formatDurationCompact(group.totalSeconds),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: _surfaceDecoration(theme),
          child: Column(
            children: [
              for (final (index, record) in group.records.indexed) ...[
                _StudyRecordRow(
                  record: record,
                  subject: _subjectById(subjects, record.subjectId),
                  onPressed: () =>
                      _showRecordFormSheet(context, initialRecord: record),
                ),
                if (index != group.records.length - 1)
                  Divider(
                    height: 1,
                    thickness: 1,
                    indent: 52,
                    color: theme.dividerColor,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _StudyRecordRow extends StatelessWidget {
  const _StudyRecordRow({
    required this.record,
    required this.subject,
    required this.onPressed,
  });

  final StudyRecord record;
  final StudySubject subject;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onPressed,
      child: Padding(
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
        'まだ記録がありません',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _RecordFormSheet extends ConsumerStatefulWidget {
  const _RecordFormSheet({this.initialRecord});

  final StudyRecord? initialRecord;

  @override
  ConsumerState<_RecordFormSheet> createState() => _RecordFormSheetState();
}

class _RecordFormSheetState extends ConsumerState<_RecordFormSheet> {
  late String _subjectId;
  late DateTime _date;
  late DateTime _startedAt;
  late DateTime _endedAt;

  bool get _isEditing => widget.initialRecord != null;
  bool get _canSave => _endedAt.isAfter(_startedAt);

  @override
  void initState() {
    super.initState();
    final initialRecord = widget.initialRecord;
    if (initialRecord != null) {
      _subjectId = initialRecord.subjectId;
      _date = _localDay(initialRecord.startedAt);
      _startedAt = initialRecord.startedAt;
      _endedAt = initialRecord.endedAt;
      return;
    }

    final now = DateTime.now();
    final roundedNow = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
    );
    final start = roundedNow.subtract(const Duration(minutes: 25));
    _date = _localDay(roundedNow);
    _startedAt = start.day == roundedNow.day ? start : _date;
    _endedAt = roundedNow.isAfter(_startedAt)
        ? roundedNow
        : _startedAt.add(const Duration(minutes: 25));
    _subjectId = ref.read(subjectsProvider).first.id;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subjects = ref.watch(subjectsProvider);
    final subject = _subjectById(subjects, _subjectId);

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SheetHandle(color: theme.dividerColor),
              const SizedBox(height: 8),
              Row(
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'キャンセル',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _isEditing ? '記録を編集' : '記録を追加',
                    style: theme.textTheme.titleMedium,
                  ),
                  const Spacer(),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    onPressed: _canSave ? _save : null,
                    child: Text(
                      '保存',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: _canSave
                            ? AppTheme.accentBlue
                            : theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                decoration: _surfaceDecoration(theme),
                child: Column(
                  children: [
                    _FormValueRow(
                      title: '科目',
                      value: subject.name,
                      leading: _SubjectDot(subject: subject),
                      onPressed: () =>
                          _showSubjectPicker(context, subjects, _setSubject),
                    ),
                    _DividerInset(color: theme.dividerColor),
                    _FormValueRow(
                      title: '日付',
                      value: formatFormDate(_date),
                      onPressed: () => _showDatePickerSheet(
                        context: context,
                        initialDate: _date,
                        onSelected: _setDate,
                      ),
                    ),
                    _DividerInset(color: theme.dividerColor),
                    _FormValueRow(
                      title: '開始時刻',
                      value: formatClock(_startedAt),
                      onPressed: () => _showTimePickerSheet(
                        context: context,
                        initialTime: _startedAt,
                        onSelected: _setStartTime,
                      ),
                    ),
                    _DividerInset(color: theme.dividerColor),
                    _FormValueRow(
                      title: '終了時刻',
                      value: formatClock(_endedAt),
                      onPressed: () => _showTimePickerSheet(
                        context: context,
                        initialTime: _endedAt,
                        onSelected: _setEndTime,
                      ),
                    ),
                  ],
                ),
              ),
              if (!_canSave) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '終了時刻は開始時刻より後にしてください',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: CupertinoColors.systemRed.resolveFrom(context),
                    ),
                  ),
                ),
              ],
              if (_isEditing) ...[
                const SizedBox(height: 18),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _confirmDelete,
                  child: Text(
                    '削除',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: CupertinoColors.systemRed.resolveFrom(context),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _setSubject(String subjectId) {
    setState(() => _subjectId = subjectId);
  }

  void _setDate(DateTime date) {
    setState(() {
      _date = _localDay(date);
      _startedAt = _combineDateAndTime(_date, _startedAt);
      _endedAt = _combineDateAndTime(_date, _endedAt);
    });
  }

  void _setStartTime(DateTime time) {
    setState(() {
      _startedAt = _combineDateAndTime(_date, time);
    });
  }

  void _setEndTime(DateTime time) {
    setState(() {
      _endedAt = _combineDateAndTime(_date, time);
    });
  }

  void _save() {
    if (!_canSave) {
      return;
    }

    final controller = ref.read(recordsControllerProvider.notifier);
    final initialRecord = widget.initialRecord;
    if (initialRecord == null) {
      controller.addManualRecord(
        subjectId: _subjectId,
        startedAt: _startedAt,
        endedAt: _endedAt,
      );
    } else {
      controller.updateRecord(
        initialRecord.copyWith(
          subjectId: _subjectId,
          startedAt: _startedAt,
          endedAt: _endedAt,
          durationSeconds: _endedAt.difference(_startedAt).inSeconds,
        ),
      );
    }

    Navigator.of(context).pop();
  }

  void _confirmDelete() {
    final recordId = widget.initialRecord?.id;
    if (recordId == null) {
      return;
    }

    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) {
        return CupertinoAlertDialog(
          title: const Text('記録を削除'),
          content: const Text('この記録を削除しますか。'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('キャンセル'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () {
                ref
                    .read(recordsControllerProvider.notifier)
                    .deleteRecord(recordId);
                Navigator.of(dialogContext).pop();
                Navigator.of(context).pop();
              },
              child: const Text('削除'),
            ),
          ],
        );
      },
    );
  }
}

class _FormValueRow extends StatelessWidget {
  const _FormValueRow({
    required this.title,
    required this.value,
    required this.onPressed,
    this.leading,
  });

  final String title;
  final String value;
  final VoidCallback onPressed;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            Expanded(child: Text(title, style: theme.textTheme.bodyLarge)),
            Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              CupertinoIcons.chevron_forward,
              size: 17,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 5,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

class _DividerInset extends StatelessWidget {
  const _DividerInset({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, thickness: 1, indent: 16, color: color);
  }
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

Future<void> _showRecordFormSheet(
  BuildContext context, {
  StudyRecord? initialRecord,
}) async {
  await showCupertinoModalPopup<void>(
    context: context,
    builder: (context) => _RecordFormSheet(initialRecord: initialRecord),
  );
}

Future<void> _showSubjectPicker(
  BuildContext context,
  List<StudySubject> subjects,
  ValueChanged<String> onSelected,
) async {
  await showCupertinoModalPopup<void>(
    context: context,
    builder: (context) {
      return CupertinoActionSheet(
        title: const Text('科目'),
        actions: [
          for (final subject in subjects)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(context).pop();
                onSelected(subject.id);
              },
              child: Text(subject.name),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
      );
    },
  );
}

Future<void> _showDatePickerSheet({
  required BuildContext context,
  required DateTime initialDate,
  required ValueChanged<DateTime> onSelected,
}) async {
  var selectedDate = initialDate;
  await _showPickerSheet(
    context: context,
    child: CupertinoDatePicker(
      mode: CupertinoDatePickerMode.date,
      initialDateTime: initialDate,
      onDateTimeChanged: (value) => selectedDate = value,
    ),
    onDone: () => onSelected(selectedDate),
  );
}

Future<void> _showTimePickerSheet({
  required BuildContext context,
  required DateTime initialTime,
  required ValueChanged<DateTime> onSelected,
}) async {
  var selectedTime = initialTime;
  await _showPickerSheet(
    context: context,
    child: CupertinoDatePicker(
      mode: CupertinoDatePickerMode.time,
      initialDateTime: initialTime,
      use24hFormat: true,
      onDateTimeChanged: (value) => selectedTime = value,
    ),
    onDone: () => onSelected(selectedTime),
  );
}

Future<void> _showPickerSheet({
  required BuildContext context,
  required Widget child,
  required VoidCallback onDone,
}) async {
  final theme = Theme.of(context);
  await showCupertinoModalPopup<void>(
    context: context,
    builder: (context) {
      return Material(
        color: Colors.transparent,
        child: SafeArea(
          top: false,
          child: Container(
            height: 300,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            color: theme.scaffoldBackgroundColor,
            child: Column(
              children: [
                Row(
                  children: [
                    const Spacer(),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        onDone();
                        Navigator.of(context).pop();
                      },
                      child: const Text('完了'),
                    ),
                  ],
                ),
                Expanded(child: child),
              ],
            ),
          ),
        ),
      );
    },
  );
}

CupertinoNavigationBar _navigationBar(BuildContext context) {
  final theme = Theme.of(context);
  return CupertinoNavigationBar(
    middle: const Text('記録'),
    trailing: CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: () => _showRecordFormSheet(context),
      child: const Icon(CupertinoIcons.add),
    ),
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

DateTime _localDay(DateTime dateTime) {
  return DateTime(dateTime.year, dateTime.month, dateTime.day);
}

DateTime _combineDateAndTime(DateTime date, DateTime time) {
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

List<_DailyRecordGroup> _groupRecordsByDay(List<StudyRecord> records) {
  final grouped = <DateTime, List<StudyRecord>>{};
  for (final record in records) {
    grouped.putIfAbsent(_localDay(record.startedAt), () => []).add(record);
  }

  final groups = [
    for (final entry in grouped.entries)
      _DailyRecordGroup(
        date: entry.key,
        records: entry.value
          ..sort((a, b) => b.startedAt.compareTo(a.startedAt)),
      ),
  ]..sort((a, b) => b.date.compareTo(a.date));

  return groups;
}

class _DailyRecordGroup {
  const _DailyRecordGroup({required this.date, required this.records});

  final DateTime date;
  final List<StudyRecord> records;

  int get totalSeconds {
    return records.fold<int>(
      0,
      (total, record) => total + record.durationSeconds,
    );
  }
}
