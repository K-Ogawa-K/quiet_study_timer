import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/active_session.dart';
import '../models/app_settings.dart';
import '../models/study_record.dart';
import '../models/study_subject.dart';

const _recordsStorageKey = 'study_records_v1';
const _settingsStorageKey = 'app_settings_v1';

const _uuid = Uuid();

const defaultStudySubjects = <StudySubject>[
  StudySubject(id: 'english', name: '英語', colorHex: '2F80ED', sortOrder: 0),
  StudySubject(id: 'math', name: '数学', colorHex: '35A67B', sortOrder: 1),
  StudySubject(id: 'reading', name: '読書', colorHex: '7B61D1', sortOrder: 2),
  StudySubject(id: 'other', name: 'その他', colorHex: '8E8E93', sortOrder: 3),
];

final subjectsProvider = Provider<List<StudySubject>>((ref) {
  return defaultStudySubjects.where((subject) => !subject.isArchived).toList()
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
});

final settingsControllerProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);

class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    unawaited(_load());
    return const AppSettings();
  }

  Future<void> _load() async {
    final preferences = await SharedPreferences.getInstance();
    final rawJson = preferences.getString(_settingsStorageKey);
    if (rawJson == null) {
      return;
    }

    final decoded = jsonDecode(rawJson);
    if (decoded is Map<String, Object?>) {
      state = AppSettings.fromJson(decoded);
    }
  }

  Future<void> _save() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _settingsStorageKey,
      jsonEncode(state.toJson()),
    );
  }

  void setLibraryMode(bool enabled) {
    state = state.copyWith(libraryModeEnabled: enabled);
    unawaited(_save());
  }

  void setVibrationPattern(VibrationPattern pattern) {
    state = state.copyWith(vibrationPattern: pattern);
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
    final preferences = await SharedPreferences.getInstance();
    final rawJson = preferences.getString(_recordsStorageKey);
    if (rawJson == null) {
      return;
    }

    final decoded = jsonDecode(rawJson);
    if (decoded is! List) {
      return;
    }

    final records =
        decoded
            .whereType<Map<String, Object?>>()
            .map(StudyRecord.fromJson)
            .toList()
          ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    state = records;
  }

  Future<void> _save() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = state.map((record) => record.toJson()).toList();
    await preferences.setString(_recordsStorageKey, jsonEncode(encoded));
  }

  void addRecord(StudyRecord record) {
    final records = [...state, record]
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    state = records;
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
