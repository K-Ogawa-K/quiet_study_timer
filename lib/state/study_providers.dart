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
import '../services/haptic_service.dart';
import '../services/notification_service.dart';
import '../services/wake_lock_service.dart';

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

final hapticServiceProvider = Provider<HapticService>((ref) {
  return const SystemHapticService();
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return LocalNotificationService();
});

final wakeLockServiceProvider = Provider<WakeLockService>((ref) {
  return const SystemWakeLockService();
});

final notificationPermissionControllerProvider =
    NotifierProvider<
      NotificationPermissionController,
      NotificationPermissionState
    >(NotificationPermissionController.new);

class NotificationPermissionController
    extends Notifier<NotificationPermissionState> {
  @override
  NotificationPermissionState build() {
    unawaited(refresh());
    return NotificationPermissionState.unknown;
  }

  Future<void> refresh() async {
    final notificationService = ref.read(notificationServiceProvider);
    final permissionState = await notificationService.permissionState();
    if (!ref.mounted) {
      return;
    }
    state = permissionState;
  }

  Future<void> requestPermission() async {
    final notificationService = ref.read(notificationServiceProvider);
    final permissionState = await notificationService.requestPermission();
    if (!ref.mounted) {
      return;
    }
    state = permissionState;
  }
}

final subjectsProvider =
    NotifierProvider<SubjectsController, List<StudySubject>>(
      SubjectsController.new,
    );

final activeSubjectsProvider = Provider<List<StudySubject>>((ref) {
  return ref
      .watch(subjectsProvider)
      .where((subject) => !subject.isArchived)
      .toList();
});

class SubjectsController extends Notifier<List<StudySubject>> {
  @override
  List<StudySubject> build() {
    unawaited(_load());
    return _sortedSubjects(defaultStudySubjects);
  }

  Future<void> _load() async {
    final subjects = await ref.read(studyDataRepositoryProvider).loadSubjects();
    if (subjects == null || subjects.isEmpty) {
      return;
    }

    state = _normalizeSubjects(subjects);
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

    state = _sortedSubjects([
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

    state = _normalizeSubjects(subjects);
    unawaited(_save());
  }

  void setSubjectColor(String subjectId, String colorHex) {
    if (!_subjectColorPalette.contains(colorHex)) {
      return;
    }

    state = _sortedSubjects([
      for (final subject in state)
        if (subject.id == subjectId)
          subject.copyWith(colorHex: colorHex)
        else
          subject,
    ]);
    unawaited(_save());
  }

  void setSubjectArchived(String subjectId, bool archived) {
    StudySubject? subject;
    for (final existingSubject in state) {
      if (existingSubject.id == subjectId) {
        subject = existingSubject;
        break;
      }
    }
    if (subject == null || subject.isArchived == archived) {
      return;
    }

    final activeCount = state.where((subject) => !subject.isArchived).length;
    if (archived && !subject.isArchived && activeCount <= 1) {
      return;
    }

    state = _normalizeSubjects([
      for (final subject in state)
        if (subject.id == subjectId)
          subject.copyWith(isArchived: archived)
        else
          subject,
    ]);
    unawaited(_save());
  }

  void moveSubject(String subjectId, int direction) {
    if (direction == 0 || state.length < 2) {
      return;
    }

    final subjects = _sortedSubjects(state);
    final currentIndex = subjects.indexWhere(
      (subject) => subject.id == subjectId,
    );
    if (currentIndex == -1) {
      return;
    }

    final nextIndex = currentIndex + direction.sign;
    if (nextIndex < 0 || nextIndex >= subjects.length) {
      return;
    }

    final current = subjects[currentIndex];
    final next = subjects[nextIndex];
    state = _sortedSubjects([
      for (final subject in subjects)
        if (subject.id == current.id)
          subject.copyWith(sortOrder: next.sortOrder)
        else if (subject.id == next.id)
          subject.copyWith(sortOrder: current.sortOrder)
        else
          subject,
    ]);
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

  void setKeepScreenAwake(bool enabled) {
    state = state.copyWith(keepScreenAwake: enabled);
    unawaited(_save());
  }
}

final recordsControllerProvider =
    NotifierProvider<RecordsController, List<StudyRecord>>(
      RecordsController.new,
    );

class RecordsController extends Notifier<List<StudyRecord>> {
  Future<void>? _loadFuture;

  @override
  List<StudyRecord> build() {
    _loadFuture = _load();
    unawaited(_loadFuture);
    return const [];
  }

  Future<void> _load() async {
    final records = await ref.read(studyDataRepositoryProvider).loadRecords();
    if (!ref.mounted) {
      return;
    }
    state = _sortedUniqueRecords([...records, ...state]);
  }

  Future<void> ensureLoaded() async {
    await _loadFuture;
  }

  Future<void> _save() async {
    await ref.read(studyDataRepositoryProvider).saveRecords(state);
  }

  void addRecord(StudyRecord record) {
    if (state.any((existingRecord) => existingRecord.id == record.id)) {
      return;
    }

    state = _sortedUniqueRecords([...state, record]);
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
    required this.selectedBreakSeconds,
    required this.now,
    this.activeSession,
    this.lastCompletedRecord,
    this.lastCompletedBreakSeconds,
  });

  final String selectedSubjectId;
  final int selectedPresetSeconds;
  final int selectedBreakSeconds;
  final DateTime now;
  final ActiveSession? activeSession;
  final StudyRecord? lastCompletedRecord;
  final int? lastCompletedBreakSeconds;

  FocusState copyWith({
    String? selectedSubjectId,
    int? selectedPresetSeconds,
    int? selectedBreakSeconds,
    DateTime? now,
    ActiveSession? activeSession,
    bool clearActiveSession = false,
    StudyRecord? lastCompletedRecord,
    bool clearCompletedRecord = false,
    int? lastCompletedBreakSeconds,
    bool clearCompletedBreak = false,
  }) {
    return FocusState(
      selectedSubjectId: selectedSubjectId ?? this.selectedSubjectId,
      selectedPresetSeconds:
          selectedPresetSeconds ?? this.selectedPresetSeconds,
      selectedBreakSeconds: selectedBreakSeconds ?? this.selectedBreakSeconds,
      now: now ?? this.now,
      activeSession: clearActiveSession
          ? null
          : activeSession ?? this.activeSession,
      lastCompletedRecord: clearCompletedRecord
          ? null
          : lastCompletedRecord ?? this.lastCompletedRecord,
      lastCompletedBreakSeconds: clearCompletedBreak
          ? null
          : lastCompletedBreakSeconds ?? this.lastCompletedBreakSeconds,
    );
  }
}

class FocusController extends Notifier<FocusState> {
  Timer? _ticker;
  Future<void> _sessionPersistenceQueue = Future<void>.value();

  @override
  FocusState build() {
    final wakeLockService = ref.read(wakeLockServiceProvider);
    ref.onDispose(() {
      _ticker?.cancel();
      unawaited(wakeLockService.disable());
    });
    ref.listen(settingsControllerProvider, (_, _) {
      unawaited(_syncWakeLockForState());
    });
    unawaited(_restoreActiveSession());
    final firstSubject = ref.read(activeSubjectsProvider).first;
    return FocusState(
      selectedSubjectId: firstSubject.id,
      selectedPresetSeconds: 25 * 60,
      selectedBreakSeconds: 5 * 60,
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
      clearCompletedBreak: true,
    );
  }

  void selectPreset(int seconds) {
    if (state.activeSession != null) {
      return;
    }
    state = state.copyWith(
      selectedPresetSeconds: seconds,
      clearCompletedRecord: true,
      clearCompletedBreak: true,
    );
  }

  void selectBreakPreset(int seconds) {
    if (state.activeSession != null) {
      return;
    }
    state = state.copyWith(selectedBreakSeconds: seconds);
  }

  void start() {
    final now = DateTime.now();
    final targetSeconds = state.selectedPresetSeconds;
    final subjectId = _activeSubjectIdOrFirst(state.selectedSubjectId);
    final session = ActiveSession(
      id: _uuid.v4(),
      subjectId: subjectId,
      kind: StudySessionKind.focus,
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
      selectedSubjectId: subjectId,
      activeSession: session,
      clearCompletedRecord: true,
      clearCompletedBreak: true,
    );
    _persistActiveSession(session);
    _startTicker();
    unawaited(_scheduleSessionNotification(session));
    unawaited(_syncWakeLockForState());
  }

  void startBreak() {
    final now = DateTime.now();
    final targetSeconds = state.selectedBreakSeconds;
    final subjectId = _activeSubjectIdOrFirst(state.selectedSubjectId);
    final session = ActiveSession(
      id: _uuid.v4(),
      subjectId: subjectId,
      kind: StudySessionKind.rest,
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
      selectedSubjectId: subjectId,
      activeSession: session,
      clearCompletedRecord: true,
      clearCompletedBreak: true,
    );
    _persistActiveSession(session);
    _startTicker();
    unawaited(_scheduleSessionNotification(session));
    unawaited(_syncWakeLockForState());
  }

  void pause() {
    final session = state.activeSession;
    if (session == null || session.status != StudySessionStatus.running) {
      return;
    }

    final now = DateTime.now();
    if (session.shouldComplete(now)) {
      _completeSession(
        now,
        endedAt: session.expectedEndAt,
        playCompletionHaptic: true,
      );
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
    _persistActiveSession(state.activeSession);
    unawaited(_cancelSessionNotification());
    unawaited(_syncWakeLockForState());
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
    _persistActiveSession(state.activeSession);
    _startTicker();
    unawaited(_scheduleCurrentSessionNotification());
    unawaited(_syncWakeLockForState());
  }

  void finish() {
    final session = state.activeSession;
    if (session == null) {
      return;
    }

    final now = DateTime.now();
    unawaited(_cancelSessionNotification());
    _completeSession(now);
  }

  void dismissCompletion() {
    state = state.copyWith(
      clearCompletedRecord: true,
      clearCompletedBreak: true,
    );
  }

  void startAgain() {
    state = state.copyWith(
      clearCompletedRecord: true,
      clearCompletedBreak: true,
    );
    start();
  }

  void startDebugFocus() {
    if (state.activeSession != null) {
      return;
    }
    state = state.copyWith(selectedPresetSeconds: 10);
    start();
  }

  void startDebugBreak() {
    if (state.activeSession != null) {
      return;
    }
    state = state.copyWith(selectedBreakSeconds: 10);
    startBreak();
  }

  void releaseScreenAwake() {
    unawaited(ref.read(wakeLockServiceProvider).disable());
  }

  String _activeSubjectIdOrFirst(String subjectId) {
    final activeSubjects = ref.read(activeSubjectsProvider);
    if (activeSubjects.any((subject) => subject.id == subjectId)) {
      return subjectId;
    }
    return activeSubjects.first.id;
  }

  void reconcileWithClock() {
    final session = state.activeSession;
    final now = DateTime.now();
    if (session == null) {
      state = state.copyWith(now: now);
      unawaited(_cancelSessionNotification());
      unawaited(_syncWakeLockForState());
      return;
    }

    if (session.shouldComplete(now)) {
      _completeSession(
        now,
        endedAt: session.expectedEndAt,
        playCompletionHaptic: true,
      );
      return;
    }

    state = state.copyWith(now: now);
    if (session.status == StudySessionStatus.running) {
      unawaited(
        _scheduleSessionNotification(session, requestPermission: false),
      );
    } else {
      unawaited(_cancelSessionNotification());
    }
    unawaited(_syncWakeLockForState());
  }

  Future<void> _restoreActiveSession() async {
    final repository = ref.read(studyDataRepositoryProvider);
    final session = await repository.loadActiveSession();
    if (!ref.mounted) {
      return;
    }

    if (state.activeSession != null) {
      return;
    }

    if (session == null) {
      unawaited(_cancelSessionNotification());
      unawaited(_syncWakeLockForState());
      return;
    }

    if (session.status == StudySessionStatus.completed) {
      _persistActiveSession(null);
      unawaited(_cancelSessionNotification());
      unawaited(_syncWakeLockForState());
      return;
    }

    await ref.read(recordsControllerProvider.notifier).ensureLoaded();
    if (!ref.mounted) {
      return;
    }

    final now = DateTime.now();
    state = state.copyWith(
      now: now,
      selectedSubjectId: session.subjectId,
      selectedPresetSeconds: session.kind == StudySessionKind.focus
          ? session.targetSeconds
          : state.selectedPresetSeconds,
      selectedBreakSeconds: session.kind == StudySessionKind.rest
          ? session.targetSeconds
          : state.selectedBreakSeconds,
      activeSession: session,
      clearCompletedRecord: true,
      clearCompletedBreak: true,
    );

    if (session.shouldComplete(now)) {
      _completeSession(
        now,
        endedAt: session.expectedEndAt,
        playCompletionHaptic: false,
      );
      return;
    }

    if (session.status == StudySessionStatus.running) {
      _startTicker();
      unawaited(
        _scheduleSessionNotification(session, requestPermission: false),
      );
    } else {
      _ticker?.cancel();
      unawaited(_cancelSessionNotification());
    }
    unawaited(_syncWakeLockForState());
  }

  void _persistActiveSession(ActiveSession? session) {
    final repository = ref.read(studyDataRepositoryProvider);
    _sessionPersistenceQueue = _sessionPersistenceQueue
        .catchError((Object _) {})
        .then((_) async {
          if (session == null) {
            await repository.clearActiveSession();
          } else {
            await repository.saveActiveSession(session);
          }
        });
  }

  Future<void> _syncWakeLockForState() async {
    final settings = ref.read(settingsControllerProvider);
    final session = state.activeSession;
    final shouldEnable =
        settings.keepScreenAwake &&
        session != null &&
        session.status == StudySessionStatus.running;
    final wakeLockService = ref.read(wakeLockServiceProvider);
    if (shouldEnable) {
      await wakeLockService.enable();
    } else {
      await wakeLockService.disable();
    }
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
      _completeSession(
        now,
        endedAt: session.expectedEndAt,
        playCompletionHaptic: true,
      );
      return;
    }

    state = state.copyWith(now: now);
  }

  void _completeSession(
    DateTime observedAt, {
    DateTime? endedAt,
    bool playCompletionHaptic = false,
  }) {
    final session = state.activeSession;
    if (session == null) {
      return;
    }

    final completedAt = endedAt ?? observedAt;
    final durationSeconds = max(
      1,
      session.completedDurationSeconds(completedAt),
    );
    if (session.kind == StudySessionKind.rest) {
      _completeBreakSession(
        session: session,
        observedAt: observedAt,
        completedAt: completedAt,
        durationSeconds: durationSeconds,
        playCompletionHaptic: playCompletionHaptic,
      );
      return;
    }

    final existingRecord = _recordForSession(session.id);
    final record =
        existingRecord ??
        StudyRecord(
          id: session.id,
          subjectId: session.subjectId,
          startedAt: session.startedAt,
          endedAt: completedAt,
          durationSeconds: durationSeconds,
          source: StudyRecordSource.timer,
        );
    if (existingRecord == null) {
      ref.read(recordsControllerProvider.notifier).addRecord(record);
    }
    _ticker?.cancel();
    _persistActiveSession(null);
    unawaited(_cancelSessionNotification());
    state = state.copyWith(
      now: observedAt,
      activeSession: session.copyWith(
        status: StudySessionStatus.completed,
        completedAt: completedAt,
      ),
      clearActiveSession: true,
      lastCompletedRecord: record,
      clearCompletedBreak: true,
    );
    unawaited(_syncWakeLockForState());

    if (playCompletionHaptic) {
      _playCompletionHaptic();
    }
  }

  StudyRecord? _recordForSession(String sessionId) {
    for (final record in ref.read(recordsControllerProvider)) {
      if (record.id == sessionId) {
        return record;
      }
    }
    return null;
  }

  void _completeBreakSession({
    required ActiveSession session,
    required DateTime observedAt,
    required DateTime completedAt,
    required int durationSeconds,
    required bool playCompletionHaptic,
  }) {
    _ticker?.cancel();
    _persistActiveSession(null);
    unawaited(_cancelSessionNotification());
    state = state.copyWith(
      now: observedAt,
      activeSession: session.copyWith(
        status: StudySessionStatus.completed,
        completedAt: completedAt,
      ),
      clearActiveSession: true,
      clearCompletedRecord: true,
      lastCompletedBreakSeconds: durationSeconds,
    );
    unawaited(_syncWakeLockForState());

    if (playCompletionHaptic) {
      _playCompletionHaptic();
    }
  }

  void _playCompletionHaptic() {
    final settings = ref.read(settingsControllerProvider);
    unawaited(
      ref
          .read(hapticServiceProvider)
          .playTimerCompletion(settings.vibrationPattern),
    );
  }

  Future<void> _scheduleCurrentSessionNotification() async {
    final session = state.activeSession;
    if (session == null || session.status != StudySessionStatus.running) {
      return;
    }
    await _scheduleSessionNotification(session);
  }

  Future<void> _scheduleSessionNotification(
    ActiveSession session, {
    bool requestPermission = true,
  }) async {
    final notificationService = ref.read(notificationServiceProvider);
    await notificationService.scheduleSessionEnd(
      session,
      requestPermission: requestPermission,
    );
    if (!ref.mounted) {
      return;
    }
    await ref.read(notificationPermissionControllerProvider.notifier).refresh();
  }

  Future<void> _cancelSessionNotification() async {
    await ref.read(notificationServiceProvider).cancelAllSessionEnds();
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

List<StudyRecord> _sortedUniqueRecords(List<StudyRecord> records) {
  final recordsById = <String, StudyRecord>{};
  for (final record in records) {
    recordsById[record.id] = record;
  }
  return recordsById.values.toList()
    ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
}

List<StudySubject> _normalizeSubjects(List<StudySubject> subjects) {
  final sortedSubjects = _sortedSubjects(subjects);
  if (sortedSubjects.any((subject) => !subject.isArchived)) {
    return sortedSubjects;
  }

  return [
    for (final (index, subject) in sortedSubjects.indexed)
      if (index == 0) subject.copyWith(isArchived: false) else subject,
  ];
}

List<StudySubject> _sortedSubjects(List<StudySubject> subjects) {
  return [...subjects]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
}
