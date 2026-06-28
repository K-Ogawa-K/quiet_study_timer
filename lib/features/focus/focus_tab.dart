import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_theme.dart';
import '../../models/active_session.dart';
import '../../models/study_record.dart';
import '../../models/study_subject.dart';
import '../../state/study_providers.dart';
import '../../utils/time_format.dart';
import '../shared/subject_picker_sheet.dart';

const _presetSeconds = [5 * 60, 10 * 60, 25 * 60, 50 * 60];
const _breakPresetSeconds = [60, 5 * 60, 10 * 60];

class FocusTab extends ConsumerWidget {
  const FocusTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focus = ref.watch(focusControllerProvider);
    final settings = ref.watch(settingsControllerProvider);
    final subjects = ref.watch(subjectsProvider);
    final activeSubjects = ref.watch(activeSubjectsProvider);
    final todayTotalSeconds = ref.watch(todayTotalSecondsProvider);
    final selectedSubject = _subjectById(
      activeSubjects,
      focus.selectedSubjectId,
    );

    return CupertinoPageScaffold(
      navigationBar: _navigationBar(context, '集中'),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          children: [
            _TodaySummary(totalSeconds: todayTotalSeconds),
            const SizedBox(height: 28),
            if (focus.activeSession != null)
              _ActiveSessionView(
                session: focus.activeSession!,
                now: focus.now,
                subject: _subjectById(subjects, focus.activeSession!.subjectId),
              )
            else if (focus.lastCompletedBreakSeconds != null)
              _CompletedBreakView(
                seconds: focus.lastCompletedBreakSeconds!,
                quiet: settings.libraryModeEnabled,
              )
            else if (focus.lastCompletedRecord != null)
              _CompletedSessionView(
                record: focus.lastCompletedRecord!,
                quiet: settings.libraryModeEnabled,
                selectedBreakSeconds: focus.selectedBreakSeconds,
                subject: _subjectById(
                  subjects,
                  focus.lastCompletedRecord!.subjectId,
                ),
              )
            else
              _ReadySessionView(
                subject: selectedSubject,
                subjects: activeSubjects,
                selectedSubjectId: selectedSubject.id,
              ),
          ],
        ),
      ),
    );
  }
}

class _TodaySummary extends StatelessWidget {
  const _TodaySummary({required this.totalSeconds});

  final int totalSeconds;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: _surfaceDecoration(theme),
      child: Row(
        children: [
          Text(
            '今日',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Text(
            formatDurationCompact(totalSeconds),
            style: theme.textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

class _ReadySessionView extends ConsumerWidget {
  const _ReadySessionView({
    required this.subject,
    required this.subjects,
    required this.selectedSubjectId,
  });

  final StudySubject subject;
  final List<StudySubject> subjects;
  final String selectedSubjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focus = ref.watch(focusControllerProvider);
    final controller = ref.read(focusControllerProvider.notifier);

    return Column(
      children: [
        _SubjectButton(
          subject: subject,
          onPressed: () => showSubjectPickerSheet(
            context: context,
            subjects: subjects,
            selectedSubjectId: selectedSubjectId,
            onSelected: controller.selectSubject,
          ),
        ),
        const SizedBox(height: 48),
        _TimeDisplay(seconds: focus.selectedPresetSeconds),
        const SizedBox(height: 40),
        _PresetRow(
          selectedSeconds: focus.selectedPresetSeconds,
          values: _presetSeconds,
          onSelected: controller.selectPreset,
        ),
        const SizedBox(height: 28),
        _PrimaryButton(label: '開始', onPressed: controller.start),
      ],
    );
  }
}

class _ActiveSessionView extends ConsumerWidget {
  const _ActiveSessionView({
    required this.session,
    required this.now,
    required this.subject,
  });

  final ActiveSession session;
  final DateTime now;
  final StudySubject subject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(focusControllerProvider.notifier);
    final isPaused = session.status == StudySessionStatus.paused;
    final isRest = session.kind == StudySessionKind.rest;
    final title = isRest ? '休憩' : subject.name;
    final statusLabel = isPaused ? '一時停止' : (isRest ? '休憩中' : '集中');

    return Column(
      children: [
        _SessionLabel(title: title, label: statusLabel),
        const SizedBox(height: 52),
        _TimeDisplay(seconds: session.displaySeconds(now)),
        const SizedBox(height: 44),
        Row(
          children: [
            Expanded(
              child: _SecondaryButton(
                label: isPaused ? '再開' : '一時停止',
                onPressed: isPaused ? controller.resume : controller.pause,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuietDestructiveButton(
                label: '終了',
                onPressed: controller.finish,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CompletedSessionView extends ConsumerWidget {
  const _CompletedSessionView({
    required this.record,
    required this.subject,
    required this.quiet,
    required this.selectedBreakSeconds,
  });

  final StudyRecord record;
  final StudySubject subject;
  final bool quiet;
  final int selectedBreakSeconds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(focusControllerProvider.notifier);
    final theme = Theme.of(context);

    return Column(
      children: [
        _SessionLabel(title: subject.name, label: quiet ? '完了' : '記録しました'),
        SizedBox(height: quiet ? 30 : 42),
        Text(
          formatDurationCompact(record.durationSeconds),
          style: quiet
              ? theme.textTheme.titleLarge
              : theme.textTheme.headlineLarge,
        ),
        const SizedBox(height: 8),
        Text(
          formatClockRange(record.startedAt, record.endedAt),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 34),
        _PresetRow(
          selectedSeconds: selectedBreakSeconds,
          values: _breakPresetSeconds,
          onSelected: controller.selectBreakPreset,
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: _SecondaryButton(
                label: '休憩する',
                onPressed: controller.startBreak,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PrimaryButton(
                label: 'もう一度',
                onPressed: controller.startAgain,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CompletedBreakView extends ConsumerWidget {
  const _CompletedBreakView({required this.seconds, required this.quiet});

  final int seconds;
  final bool quiet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(focusControllerProvider.notifier);
    final theme = Theme.of(context);

    return Column(
      children: [
        _SessionLabel(title: '休憩', label: quiet ? '完了' : '休憩完了'),
        SizedBox(height: quiet ? 30 : 42),
        Text(
          formatDurationCompact(seconds),
          style: quiet
              ? theme.textTheme.titleLarge
              : theme.textTheme.headlineLarge,
        ),
        const SizedBox(height: 42),
        Row(
          children: [
            Expanded(
              child: _SecondaryButton(
                label: '閉じる',
                onPressed: controller.dismissCompletion,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PrimaryButton(
                label: 'もう一度',
                onPressed: controller.startAgain,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SessionLabel extends StatelessWidget {
  const _SessionLabel({required this.title, required this.label});

  final String title;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(title, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _SubjectButton extends StatelessWidget {
  const _SubjectButton({required this.subject, required this.onPressed});

  final StudySubject subject;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: _surfaceDecoration(theme),
        child: Row(
          children: [
            _SubjectDot(subject: subject),
            const SizedBox(width: 10),
            Expanded(
              child: Text(subject.name, style: theme.textTheme.titleMedium),
            ),
            Icon(
              CupertinoIcons.chevron_down,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeDisplay extends StatelessWidget {
  const _TimeDisplay({required this.seconds});

  final int seconds;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        formatTimerSeconds(seconds),
        style: theme.textTheme.headlineLarge?.copyWith(
          fontSize: 76,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PresetRow extends StatelessWidget {
  const _PresetRow({
    required this.selectedSeconds,
    required this.values,
    required this.onSelected,
  });

  final int selectedSeconds;
  final List<int> values;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final seconds in values) ...[
          Expanded(
            child: _PresetButton(
              seconds: seconds,
              selected: seconds == selectedSeconds,
              onPressed: () => onSelected(seconds),
            ),
          ),
          if (seconds != values.last) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _PresetButton extends StatelessWidget {
  const _PresetButton({
    required this.seconds,
    required this.selected,
    required this.onPressed,
  });

  final int seconds;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = '${seconds ~/ 60}分';

    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onPressed,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.accentBlue.withValues(alpha: 0.12)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppTheme.accentBlue : theme.dividerColor,
          ),
        ),
        child: Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: selected
                ? AppTheme.accentBlue
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      color: AppTheme.accentBlue,
      borderRadius: BorderRadius.circular(8),
      minimumSize: const Size(0, 54),
      onPressed: onPressed,
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(0, 54),
      onPressed: onPressed,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: _surfaceDecoration(theme),
        child: Text(
          label,
          style: theme.textTheme.titleMedium?.copyWith(
            color: AppTheme.accentBlue,
          ),
        ),
      ),
    );
  }
}

class _QuietDestructiveButton extends StatelessWidget {
  const _QuietDestructiveButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(0, 54),
      onPressed: onPressed,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: _surfaceDecoration(theme),
        child: Text(
          label,
          style: theme.textTheme.titleMedium?.copyWith(
            color: CupertinoColors.systemRed.resolveFrom(context),
          ),
        ),
      ),
    );
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
        color: _subjectColor(subject),
        shape: BoxShape.circle,
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

Color _subjectColor(StudySubject subject) {
  return Color(int.parse('FF${subject.colorHex}', radix: 16));
}
