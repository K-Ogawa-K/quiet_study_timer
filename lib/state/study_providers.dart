import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/active_session.dart';
import '../models/app_settings.dart';
import '../models/study_analytics.dart';
import '../models/study_record.dart';
import '../models/study_subject.dart';
import '../repositories/study_data_repository.dart';

const _uuid = Uuid();
const _subjectColorPalette = [
  '2F80ED',
  '35A67B',
  '7B61D1',
  '8E8E93',
  'D79A2B',
  'D96A6A',
  '4A90A4',
  '9B7A5C',
];

const defaultStudySubjects = <StudySubject>[
  StudySubject(id: 'english', name: '英語', colorHex: '2F80ED', sortOrder: 0),
  StudySubject(id: 'math', name: '数学', colorHex: '35A67B', sortOrder: 1),
  StudySubject(id: 'reading', name: '読書', colorHex: '7B61D1', sortOrder: 2),
  StudySubject(id: 'other', name: 'その他', colorHex: '8E8E93', sortOrder: 3),
];

final studyDataRepositoryProvider = Provider<StudyDataRepository>((ref) {
  return SharedPreferencesStudyDataRepository();
});

final subjectsProvider =
    NotifierProvider<SubjectsController, List<StudySubject>>(
      SubjectsController.new,
    );

class SubjectsController extends Notifier<List<StudySubject>> {
  @override
  List<StudySubject> build() {
    unawaited(_load());
    return _sortedActiveSubjects(defaultStudySubjects);
  }

  Future<void> _load() async {
    final subjects = await ref.read(studyDataRepositoryProvider).loadSubjects();
    if (subjects == null || subjects.isEmpty) {
      return;
    }

    state = _sortedActiveSubjects(subjects);
  }

  Future<void> _save() async {
    await ref.read(studyDataRepositoryProvider).saveSubjects(state);
  }

  void addSubject(String name) {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      return;
    }

    final existingNames = state.map((subject) => subject.name).toSet();
    if (existingNames.contains(trimmedName)) {
      return;
    }

    final nextSortOrder = state.isEmpty
        ? 0
        : state.map((subject) => subject.sortOrder).reduce(max) + 1;
    final colorHex =
        _subjectColorPalette[nextSortOrder % _subjectColorPalette.length];

    state = _sortedActiveSubjects([
      ...state,
      StudySubject(
        id: _uuid.v4(),
        name: trimmedName,
        colorHex: colorHex,
        sortOrder: nextSortOrder,
      ),
    ]);
    unawaited(_save());
  }

  void renameSubject(String subjectId, String name) {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      return;
    }

    final hasDuplicate = state.any(
      (subject) => subject.id != subjectId && subject.name == trimmedName,
    );
    if (hasDuplicate) {
      return;
    }

    var updated = false;
    final subjects = [
      for (final subject in state)
        if (subject.id == subjectId)
          subject.copyWith(name: trimmedName)
        else
          subject,
    ];

    updated = subjects.any(
      (subject) => subject.id == subjectId && subject.name == trimmedName,
    );
    if (!updated) {
      return;
    }

    state = _sortedActiveSubjects(subjects);
    unawaited(_save());
  }
}

final settingsControllerProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);

class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    unawaited(_load());
    return const AppSettings();
  }

  Future<void> _load() async {
    final settings = await ref.read(studyDataRepositoryProvider).loadSettings();
    if (settings != null) {
      state = settings;
    }
  }

  Future<void> _save() async {
    await ref.read(studyDataRepositoryProvider).saveSettings(state);
  }

  void setLibraryMode(bool enabled) {
    state = state.copyWith(libraryModeEnabled: enabled);
    unawaited(_save());
  }

  void setVibrationPattern(VibrationPattern pattern) {
    state = state.copyWith(vibrationPattern: pattern);
    unawaited(_save());
  }

  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
    unawaited(_save());
  }
}

final recordsControllerProvider =
    NotifierProvider<RecordsController, List<StudyRecord>>(
      RecordsController.new,
    );

class RecordsController extends Notifier<List<StudyRecord>> {
  @override
  List<StudyRecord> build() {
    unawaited(_load());
    return const [];
  }

  Future<void> _load() async {
    final records = [
      ...await ref.read(studyDataRepositoryProvider).loadRecords(),
    ]..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    state = records;
  }

  Future<void> _save() async {
    await ref.read(studyDataRepositoryProvider).saveRecords(state);
  }

  void addRecord(StudyRecord record) {
    final records = [...state, record]
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    state = records;
    unawaited(_save());
  }

  void addManualRecord({
    required String subjectId,
    required DateTime startedAt,
    required DateTime endedAt,
  }) {
    addRecord(
      StudyRecord(
        id: _uuid.v4(),
        subjectId: subjectId,
        startedAt: startedAt,
        endedAt: endedAt,
        durationSeconds: endedAt.difference(startedAt).inSeconds,
        source: StudyRecordSource.manual,
      ),
    );
  }

  void updateRecord(StudyRecord record) {
    final records = [
      for (final existingRecord in state)
        if (existingRecord.id == record.id) record else existingRecord,
    ]..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    state = records;
    unawaited(_save());
  }

  void deleteRecord(String recordId) {
    state = [
      for (final record in state)
        if (record.id != recordId) record,
    ];
    unawaited(_save());
  }
}

final todayRecordsProvider = Provider<List<StudyRecord>>((ref) {
  final records = ref.watch(recordsControllerProvider);
  final now = DateTime.now();
  return records
      .where((record) => _isSameLocalDay(record.startedAt, now))
      .toList()
    ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
});

final todayTotalSecondsProvider = Provider<int>((ref) {
  return ref
      .watch(todayRecordsProvider)
      .fold<int>(0, (total, record) => total + record.durationSeconds);
});

final todaySubjectTotalsProvider = Provider<Map<String, int>>((ref) {
  final totals = <String, int>{};
  for (final record in ref.watch(todayRecordsProvider)) {
    totals.update(
      record.subjectId,
      (value) => value + record.durationSeconds,
      ifAbsent: () => record.durationSeconds,
    );
  }
  return totals;
});

final sevenDayAnalyticsProvider = Provider<SevenDayAnalytics>((ref) {
  final records = ref.watch(recordsControllerProvider);
  final today = _localDay(DateTime.now());
  final startDate = today.subtract(const Duration(days: 6));
  final dayTotals = <DateTime, int>{};
  final subjectTotals = <String, int>{};

  for (var index = 0; index < 7; index += 1) {
    dayTotals[startDate.add(Duration(days: index))] = 0;
  }

  for (final record in records) {
    final recordDay = _localDay(record.startedAt);
    if (recordDay.isBefore(startDate) || recordDay.isAfter(today)) {
      continue;
    }

    dayTotals.update(
      recordDay,
      (value) => value + record.durationSeconds,
      ifAbsent: () => record.durationSeconds,
    );
    subjectTotals.update(
      record.subjectId,
      (value) => value + record.durationSeconds,
      ifAbsent: () => record.durationSeconds,
    );
  }

  final days = [
    for (final entry in dayTotals.entries)
      DailyStudyTotal(date: entry.key, totalSeconds: entry.value),
  ];
  final totalSeconds = days.fold<int>(
    0,
    (total, day) => total + day.totalSeconds,
  );

  return SevenDayAnalytics(
    days: days,
    totalSeconds: totalSeconds,
    subjectTotals: subjectTotals,
  );
});

final focusControllerProvider = NotifierProvider<FocusController, FocusState>(
  FocusController.new,
);

class FocusState {
  const FocusState({
    required this.selectedSubjectId,
    required this.selectedPresetSeconds,
    required this.now,
    this.activeSession,
    this.lastCompletedRecord,
  });

  final String selectedSubjectId;
  final int selectedPresetSeconds;
  final DateTime now;
  final ActiveSession? activeSession;
  final StudyRecord? lastCompletedRecord;

  FocusState copyWith({
    String? selectedSubjectId,
    int? selectedPresetSeconds,
    DateTime? now,
    ActiveSession? activeSession,
    bool clearActiveSession = false,
    StudyRecord? lastCompletedRecord,
    bool clearCompletedRecord = false,
  }) {
    return FocusState(
      selectedSubjectId: selectedSubjectId ?? this.selectedSubjectId,
      selectedPresetSeconds:
          selectedPresetSeconds ?? this.selectedPresetSeconds,
      now: now ?? this.now,
      activeSession: clearActiveSession
          ? null
          : activeSession ?? this.activeSession,
      lastCompletedRecord: clearCompletedRecord
          ? null
          : lastCompletedRecord ?? this.lastCompletedRecord,
    );
  }
}

class FocusController extends Notifier<FocusState> {
  Timer? _ticker;

  @override
  FocusState build() {
    ref.onDispose(() => _ticker?.cancel());
    final firstSubject = ref.read(subjectsProvider).first;
    return FocusState(
      selectedSubjectId: firstSubject.id,
      selectedPresetSeconds: 25 * 60,
      now: DateTime.now(),
    );
  }

  void selectSubject(String subjectId) {
    if (state.activeSession != null) {
      return;
    }
    state = state.copyWith(
      selectedSubjectId: subjectId,
      clearCompletedRecord: true,
    );
  }

  void selectPreset(int seconds) {
    if (state.activeSession != null) {
      return;
    }
    state = state.copyWith(
      selectedPresetSeconds: seconds,
      clearCompletedRecord: true,
    );
  }

  void start() {
    final now = DateTime.now();
    final targetSeconds = state.selectedPresetSeconds;
    final session = ActiveSession(
      id: _uuid.v4(),
      subjectId: state.selectedSubjectId,
      mode: StudySessionMode.timer,
      status: StudySessionStatus.running,
      targetSeconds: targetSeconds,
      startedAt: now,
      runStartedAt: now,
      elapsedBeforeCurrentRunSeconds: 0,
      expectedEndAt: now.add(Duration(seconds: targetSeconds)),
    );

    state = state.copyWith(
      now: now,
      activeSession: session,
      clearCompletedRecord: true,
    );
    _startTicker();
  }

  void pause() {
    final session = state.activeSession;
    if (session == null || session.status != StudySessionStatus.running) {
      return;
    }

    final now = DateTime.now();
    if (session.shouldComplete(now)) {
      _completeSession(now, endedAt: session.expectedEndAt);
      return;
    }

    final elapsed = min(session.targetSeconds, session.elapsedSeconds(now));
    state = state.copyWith(
      now: now,
      activeSession: session.copyWith(
        status: StudySessionStatus.paused,
        runStartedAt: null,
        elapsedBeforeCurrentRunSeconds: elapsed,
        expectedEndAt: null,
        pausedAt: now,
      ),
    );
    _ticker?.cancel();
  }

  void resume() {
    final session = state.activeSession;
    if (session == null || session.status != StudySessionStatus.paused) {
      return;
    }

    final now = DateTime.now();
    final remainingSeconds =
        session.targetSeconds - session.elapsedBeforeCurrentRunSeconds;
    if (remainingSeconds <= 0) {
      _completeSession(now);
      return;
    }

    state = state.copyWith(
      now: now,
      activeSession: session.copyWith(
        status: StudySessionStatus.running,
        runStartedAt: now,
        expectedEndAt: now.add(Duration(seconds: remainingSeconds)),
        pausedAt: null,
      ),
    );
    _startTicker();
  }

  void finish() {
    final session = state.activeSession;
    if (session == null) {
      return;
    }

    final now = DateTime.now();
    _completeSession(now);
  }

  void dismissCompletion() {
    state = state.copyWith(clearCompletedRecord: true);
  }

  void startAgain() {
    state = state.copyWith(clearCompletedRecord: true);
    start();
  }

  void reconcileWithClock() {
    final session = state.activeSession;
    final now = DateTime.now();
    if (session == null) {
      state = state.copyWith(now: now);
      return;
    }

    if (session.shouldComplete(now)) {
      _completeSession(now, endedAt: session.expectedEndAt);
      return;
    }

    state = state.copyWith(now: now);
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final session = state.activeSession;
    if (session == null || session.status != StudySessionStatus.running) {
      return;
    }

    final now = DateTime.now();
    if (session.shouldComplete(now)) {
      _completeSession(now, endedAt: session.expectedEndAt);
      return;
    }

    state = state.copyWith(now: now);
  }

  void _completeSession(DateTime observedAt, {DateTime? endedAt}) {
    final session = state.activeSession;
    if (session == null) {
      return;
    }

    final completedAt = endedAt ?? observedAt;
    final durationSeconds = max(
      1,
      session.completedDurationSeconds(completedAt),
    );
    final record = StudyRecord(
      id: _uuid.v4(),
      subjectId: session.subjectId,
      startedAt: session.startedAt,
      endedAt: completedAt,
      durationSeconds: durationSeconds,
      source: StudyRecordSource.timer,
    );

    ref.read(recordsControllerProvider.notifier).addRecord(record);
    _ticker?.cancel();
    state = state.copyWith(
      now: observedAt,
      activeSession: session.copyWith(
        status: StudySessionStatus.completed,
        completedAt: completedAt,
      ),
      clearActiveSession: true,
      lastCompletedRecord: record,
    );
  }
}

bool _isSameLocalDay(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

DateTime _localDay(DateTime dateTime) {
  return DateTime(dateTime.year, dateTime.month, dateTime.day);
}

List<StudySubject> _sortedActiveSubjects(List<StudySubject> subjects) {
  return subjects.where((subject) => !subject.isArchived).toList()
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
}
