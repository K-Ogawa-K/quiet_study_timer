import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quiet_study_timer/app/quiet_study_app.dart';
import 'package:quiet_study_timer/models/active_session.dart';
import 'package:quiet_study_timer/models/app_settings.dart';
import 'package:quiet_study_timer/models/study_record.dart';
import 'package:quiet_study_timer/repositories/study_data_repository.dart';
import 'package:quiet_study_timer/services/notification_service.dart';
import 'package:quiet_study_timer/services/wake_lock_service.dart';
import 'package:quiet_study_timer/state/study_providers.dart';
import 'package:quiet_study_timer/utils/time_format.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows the quiet study timer shell', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: QuietStudyApp()));
    await tester.pumpAndSettle();

    expect(find.text('集中'), findsWidgets);
    expect(find.text('記録'), findsWidgets);
    expect(find.text('分析'), findsWidgets);
    expect(find.text('設定'), findsWidgets);
    expect(find.text('25:00'), findsOneWidget);
    expect(find.text('開始'), findsOneWidget);
  });

  testWidgets('starts and pauses the timer', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: QuietStudyApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('開始'));
    await tester.pump();

    expect(find.text('一時停止'), findsWidgets);

    await tester.tap(find.text('一時停止').last);
    await tester.pump();

    expect(find.text('再開'), findsOneWidget);
  });

  testWidgets('finishes a timer record and reflects it across tabs', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: QuietStudyApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('開始'));
    await tester.pump();
    await tester.tap(find.text('終了'));
    await tester.pumpAndSettle();

    expect(find.text('記録'), findsWidgets);

    await tester.tap(find.text('記録').last);
    await tester.pumpAndSettle();

    expect(find.text('今日'), findsWidgets);
    expect(find.text('英語'), findsWidgets);
    expect(find.text('1分未満'), findsWidgets);

    await tester.tap(find.text('分析').last);
    await tester.pumpAndSettle();

    expect(find.text('7日間'), findsOneWidget);
    expect(find.text('日別'), findsOneWidget);
    expect(find.text('科目別'), findsOneWidget);
    expect(find.text('1分未満'), findsWidgets);
  });

  testWidgets('starts and finishes a break without adding a study record', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const QuietStudyApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('開始'));
    await tester.pump();
    await tester.tap(find.text('終了'));
    await tester.pumpAndSettle();

    expect(container.read(recordsControllerProvider), hasLength(1));
    expect(find.text('休憩する'), findsOneWidget);
    expect(find.text('もう一度'), findsOneWidget);

    await tester.tap(find.text('1分'));
    await tester.pump();
    await tester.tap(find.text('休憩する'));
    await tester.pumpAndSettle();

    expect(find.text('休憩中'), findsOneWidget);
    expect(find.text('01:00'), findsOneWidget);

    await tester.tap(find.text('終了'));
    await tester.pumpAndSettle();

    expect(find.text('休憩完了'), findsOneWidget);
    expect(find.text('閉じる'), findsOneWidget);
    expect(find.text('もう一度'), findsOneWidget);
    expect(container.read(recordsControllerProvider), hasLength(1));
  });

  test('break sessions are not saved as study records', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(focusControllerProvider.notifier);
    controller.selectBreakPreset(60);
    controller.startBreak();
    controller.finish();

    expect(container.read(recordsControllerProvider), isEmpty);
    expect(
      container.read(focusControllerProvider).lastCompletedBreakSeconds,
      greaterThan(0),
    );
  });

  testWidgets('adds a manual record from the records tab', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: QuietStudyApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('記録').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(CupertinoIcons.add));
    await tester.pumpAndSettle();

    expect(find.text('記録を追加'), findsOneWidget);

    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('今日'), findsWidgets);
    expect(find.text('25分'), findsWidgets);
    expect(find.text('英語'), findsWidgets);

    await tester.tap(find.text('分析').last);
    await tester.pumpAndSettle();

    expect(find.text('7日間'), findsOneWidget);
    expect(find.text('日別'), findsOneWidget);
    expect(find.text('科目別'), findsOneWidget);
    expect(find.text('25分'), findsWidgets);
  });

  testWidgets('opens theme and subject management from settings', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: QuietStudyApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('設定').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('テーマ'));
    await tester.pumpAndSettle();

    expect(find.text('システム'), findsWidgets);
    expect(find.text('ライト'), findsOneWidget);
    expect(find.text('ダーク'), findsOneWidget);

    await tester.tap(find.text('キャンセル').last);
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(find.text('科目の追加・編集'));
    await tester.pumpAndSettle();

    expect(find.text('科目名'), findsOneWidget);
    expect(find.text('英語'), findsWidgets);
    expect(find.text('数学'), findsWidgets);

    await tester.tap(find.text('英語').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(CupertinoTextField).last, '英語A');
    await tester.tap(find.text('保存').first, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('英語A'), findsWidgets);
  });

  testWidgets('shows the no vibration pattern option in settings', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: QuietStudyApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('設定').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('振動パターン'));
    await tester.pumpAndSettle();

    expect(find.text('なし'), findsOneWidget);
    expect(find.text('短く'), findsWidgets);
    expect(find.text('二度'), findsOneWidget);
    expect(find.text('ゆっくり'), findsOneWidget);
  });

  testWidgets(
    'shows the quiet notification setting without prompting on boot',
    (tester) async {
      await tester.pumpWidget(const ProviderScope(child: QuietStudyApp()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('設定').last);
      await tester.pumpAndSettle();

      expect(find.text('タイマー通知'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text && (widget.data == '未確認' || widget.data == '未対応'),
        ),
        findsWidgets,
      );
    },
  );

  test('subjects and records persist through the repository', () async {
    final startedAt = DateTime.now().subtract(const Duration(minutes: 25));
    final endedAt = DateTime.now();

    final firstContainer = ProviderContainer();

    firstContainer.read(subjectsProvider.notifier).addSubject('化学');
    firstContainer
        .read(recordsControllerProvider.notifier)
        .addManualRecord(
          subjectId: 'english',
          startedAt: startedAt,
          endedAt: endedAt,
        );

    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    firstContainer.dispose();

    final secondContainer = ProviderContainer();
    addTearDown(secondContainer.dispose);

    secondContainer.read(subjectsProvider);
    secondContainer.read(recordsControllerProvider);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(
      secondContainer.read(subjectsProvider).map((subject) => subject.name),
      contains('化学'),
    );
    expect(secondContainer.read(recordsControllerProvider), hasLength(1));
    expect(
      secondContainer.read(sevenDayAnalyticsProvider).totalSeconds,
      greaterThan(0),
    );
  });

  test('vibration pattern setting persists', () async {
    final firstContainer = ProviderContainer();

    firstContainer
        .read(settingsControllerProvider.notifier)
        .setVibrationPattern(VibrationPattern.none);

    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    firstContainer.dispose();

    final secondContainer = ProviderContainer();
    addTearDown(secondContainer.dispose);

    secondContainer.read(settingsControllerProvider);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(
      secondContainer.read(settingsControllerProvider).vibrationPattern,
      VibrationPattern.none,
    );
  });

  test('repository ignores invalid persisted json safely', () async {
    SharedPreferences.setMockInitialValues({
      'study_subjects_v1': '{broken',
      'study_records_v1': jsonEncode([
        {'id': 'missing-fields'},
        {
          'id': 'invalid-range',
          'subjectId': 'english',
          'startedAt': DateTime(2026, 1, 1, 10).toIso8601String(),
          'endedAt': DateTime(2026, 1, 1, 9).toIso8601String(),
          'durationSeconds': -60,
          'source': 'manual',
        },
      ]),
      'app_settings_v1': jsonEncode({'themeMode': 1}),
      'active_session_v1': jsonEncode({'id': 'missing-fields'}),
    });

    final repository = SharedPreferencesStudyDataRepository();

    expect(await repository.loadSubjects(), isNull);
    expect(await repository.loadRecords(), isEmpty);
    expect(await repository.loadSettings(), isNull);
    expect(await repository.loadActiveSession(), isNull);
  });

  test('active focus session restores after app restart', () async {
    final firstContainer = ProviderContainer();
    firstContainer.read(focusControllerProvider.notifier).start();

    final firstSession = firstContainer
        .read(focusControllerProvider)
        .activeSession;
    var savedSession = await firstContainer
        .read(studyDataRepositoryProvider)
        .loadActiveSession();
    for (var index = 0; index < 5 && savedSession == null; index += 1) {
      await Future<void>.delayed(Duration.zero);
      savedSession = await firstContainer
          .read(studyDataRepositoryProvider)
          .loadActiveSession();
    }
    expect(savedSession?.id, firstSession?.id);
    firstContainer.dispose();

    final secondContainer = ProviderContainer();
    addTearDown(secondContainer.dispose);
    secondContainer.read(focusControllerProvider);

    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final restoredSession = secondContainer
        .read(focusControllerProvider)
        .activeSession;
    expect(restoredSession?.id, firstSession?.id);
    expect(restoredSession?.status, StudySessionStatus.running);
  });

  test(
    'timer notifications are rescheduled through pause resume and finish',
    () async {
      final notifications = _FakeNotificationService();
      final container = ProviderContainer(
        overrides: [
          notificationServiceProvider.overrideWithValue(notifications),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(focusControllerProvider.notifier);

      controller.start();
      await _flushAsync();
      expect(notifications.scheduledKinds, [StudySessionKind.focus]);

      controller.pause();
      await _flushAsync();
      expect(notifications.cancelAllCount, 1);

      controller.resume();
      await _flushAsync();
      expect(notifications.scheduledKinds, [
        StudySessionKind.focus,
        StudySessionKind.focus,
      ]);

      controller.finish();
      await _flushAsync();
      expect(notifications.cancelAllCount, 2);
      expect(container.read(recordsControllerProvider), hasLength(1));

      controller.reconcileWithClock();
      expect(container.read(recordsControllerProvider), hasLength(1));
    },
  );

  test('expired persisted focus session saves a record only once', () async {
    final now = DateTime.now();
    final startedAt = now.subtract(const Duration(minutes: 30));
    final endedAt = now.subtract(const Duration(minutes: 5));
    final session = ActiveSession(
      id: 'persisted-focus-session',
      subjectId: 'english',
      kind: StudySessionKind.focus,
      mode: StudySessionMode.timer,
      status: StudySessionStatus.running,
      targetSeconds: 25 * 60,
      startedAt: startedAt,
      runStartedAt: startedAt,
      elapsedBeforeCurrentRunSeconds: 0,
      expectedEndAt: endedAt,
    );
    SharedPreferences.setMockInitialValues({
      'active_session_v1': jsonEncode(session.toJson()),
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(recordsControllerProvider);
    container.read(focusControllerProvider);

    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(focusControllerProvider).activeSession, isNull);
    expect(container.read(recordsControllerProvider), hasLength(1));

    container.read(focusControllerProvider.notifier).reconcileWithClock();
    expect(container.read(recordsControllerProvider), hasLength(1));
  });

  test(
    'expired persisted focus session with an existing record is not duplicated',
    () async {
      final now = DateTime.now();
      final startedAt = now.subtract(const Duration(minutes: 30));
      final endedAt = now.subtract(const Duration(minutes: 5));
      final session = ActiveSession(
        id: 'already-recorded-session',
        subjectId: 'english',
        kind: StudySessionKind.focus,
        mode: StudySessionMode.timer,
        status: StudySessionStatus.running,
        targetSeconds: 25 * 60,
        startedAt: startedAt,
        runStartedAt: startedAt,
        elapsedBeforeCurrentRunSeconds: 0,
        expectedEndAt: endedAt,
      );
      final record = StudyRecord(
        id: session.id,
        subjectId: session.subjectId,
        startedAt: startedAt,
        endedAt: endedAt,
        durationSeconds: 25 * 60,
        source: StudyRecordSource.timer,
      );
      SharedPreferences.setMockInitialValues({
        'active_session_v1': jsonEncode(session.toJson()),
        'study_records_v1': jsonEncode([record.toJson()]),
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(recordsControllerProvider);
      container.read(focusControllerProvider);

      await _flushAsync();

      expect(container.read(recordsControllerProvider), hasLength(1));
      expect(
        container.read(focusControllerProvider).lastCompletedRecord?.id,
        session.id,
      );

      container.read(focusControllerProvider.notifier).reconcileWithClock();
      expect(container.read(recordsControllerProvider), hasLength(1));
    },
  );

  test(
    'expired persisted break session does not save a study record',
    () async {
      final now = DateTime.now();
      final startedAt = now.subtract(const Duration(minutes: 2));
      final endedAt = now.subtract(const Duration(minutes: 1));
      final session = ActiveSession(
        id: 'persisted-break-session',
        subjectId: 'english',
        kind: StudySessionKind.rest,
        mode: StudySessionMode.timer,
        status: StudySessionStatus.running,
        targetSeconds: 60,
        startedAt: startedAt,
        runStartedAt: startedAt,
        elapsedBeforeCurrentRunSeconds: 0,
        expectedEndAt: endedAt,
      );
      SharedPreferences.setMockInitialValues({
        'active_session_v1': jsonEncode(session.toJson()),
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(recordsControllerProvider);
      container.read(focusControllerProvider);

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(recordsControllerProvider), isEmpty);
      expect(
        container.read(focusControllerProvider).lastCompletedBreakSeconds,
        greaterThan(0),
      );
    },
  );

  test('cross-midnight records are counted on their start day', () async {
    final now = DateTime.now();
    final yesterday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 1));
    final startedAt = DateTime(
      yesterday.year,
      yesterday.month,
      yesterday.day,
      23,
      50,
    );

    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(recordsControllerProvider.notifier)
        .addManualRecord(
          subjectId: 'english',
          startedAt: startedAt,
          endedAt: startedAt.add(const Duration(minutes: 30)),
        );

    expect(container.read(todayTotalSecondsProvider), 0);
    expect(container.read(sevenDayAnalyticsProvider).totalSeconds, 30 * 60);
  });

  test('seven day analytics includes the start boundary only', () {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final includedDay = today.subtract(const Duration(days: 6));
    final excludedDay = today.subtract(const Duration(days: 7));
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final recordsController = container.read(
      recordsControllerProvider.notifier,
    );
    recordsController.addManualRecord(
      subjectId: 'english',
      startedAt: includedDay.add(const Duration(hours: 9)),
      endedAt: includedDay.add(const Duration(hours: 9, minutes: 20)),
    );
    recordsController.addManualRecord(
      subjectId: 'english',
      startedAt: excludedDay.add(const Duration(hours: 9)),
      endedAt: excludedDay.add(const Duration(hours: 9, minutes: 20)),
    );

    final analytics = container.read(sevenDayAnalyticsProvider);
    expect(analytics.totalSeconds, 20 * 60);
    expect(analytics.days.first.date, includedDay);
  });

  test('record section titles stay stable around today and yesterday', () {
    final now = DateTime(2026, 6, 29, 12);

    expect(formatRecordSectionTitle(DateTime(2026, 6, 29), now), '今日');
    expect(formatRecordSectionTitle(DateTime(2026, 6, 28), now), '昨日');
    expect(formatRecordSectionTitle(DateTime(2026, 6, 20), now), '6月20日');
  });

  test('manual records with invalid time ranges are ignored', () {
    final now = DateTime.now();
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(recordsControllerProvider.notifier);
    controller.addManualRecord(
      subjectId: 'english',
      startedAt: now,
      endedAt: now,
    );
    controller.addManualRecord(
      subjectId: 'english',
      startedAt: now,
      endedAt: now.subtract(const Duration(minutes: 1)),
    );
    expect(container.read(recordsControllerProvider), isEmpty);

    controller.addManualRecord(
      subjectId: 'english',
      startedAt: now,
      endedAt: now.add(const Duration(minutes: 25)),
    );
    final record = container.read(recordsControllerProvider).single;
    controller.updateRecord(
      record.copyWith(endedAt: record.startedAt, durationSeconds: 0),
    );

    expect(
      container.read(recordsControllerProvider).single.endedAt,
      record.endedAt,
    );
  });

  test('keep screen awake only follows running sessions', () async {
    final wakeLock = _FakeWakeLockService();
    final container = ProviderContainer(
      overrides: [wakeLockServiceProvider.overrideWithValue(wakeLock)],
    );
    addTearDown(container.dispose);

    container
        .read(settingsControllerProvider.notifier)
        .setKeepScreenAwake(true);
    await Future<void>.delayed(Duration.zero);

    final controller = container.read(focusControllerProvider.notifier);
    controller.start();
    await Future<void>.delayed(Duration.zero);
    expect(wakeLock.enabled, isTrue);

    controller.pause();
    await Future<void>.delayed(Duration.zero);
    expect(wakeLock.enabled, isFalse);

    controller.resume();
    await Future<void>.delayed(Duration.zero);
    expect(wakeLock.enabled, isTrue);

    controller.finish();
    await Future<void>.delayed(Duration.zero);
    expect(wakeLock.enabled, isFalse);
  });

  test('subjects can be recolored reordered and archived safely', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(subjectsProvider.notifier);
    final firstSubject = container.read(subjectsProvider).first;
    final secondSubject = container.read(subjectsProvider)[1];

    controller.setSubjectColor(firstSubject.id, 'D79A2B');
    controller.moveSubject(secondSubject.id, -1);
    controller.setSubjectArchived(firstSubject.id, true);

    final subjects = container.read(subjectsProvider);
    expect(subjects.first.id, secondSubject.id);
    expect(
      subjects.firstWhere((subject) => subject.id == firstSubject.id).colorHex,
      'D79A2B',
    );
    expect(
      subjects
          .firstWhere((subject) => subject.id == firstSubject.id)
          .isArchived,
      isTrue,
    );
    expect(
      container.read(activeSubjectsProvider).map((subject) => subject.id),
      isNot(contains(firstSubject.id)),
    );
  });

  test(
    'archived subjects still appear in records and analytics data',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final subject = container.read(subjectsProvider).first;
      container
          .read(subjectsProvider.notifier)
          .renameSubject(subject.id, '英語A');
      container
          .read(subjectsProvider.notifier)
          .setSubjectColor(subject.id, 'D79A2B');
      container
          .read(recordsControllerProvider.notifier)
          .addManualRecord(
            subjectId: subject.id,
            startedAt: DateTime.now().subtract(const Duration(minutes: 25)),
            endedAt: DateTime.now(),
          );
      container
          .read(subjectsProvider.notifier)
          .setSubjectArchived(subject.id, true);

      final archivedSubject = container
          .read(subjectsProvider)
          .firstWhere((item) => item.id == subject.id);

      expect(archivedSubject.name, '英語A');
      expect(archivedSubject.colorHex, 'D79A2B');
      expect(archivedSubject.isArchived, isTrue);
      expect(
        container.read(sevenDayAnalyticsProvider).subjectTotals[subject.id],
        greaterThan(0),
      );
    },
  );

  testWidgets('archived subjects stay out of new focus selection', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final archivedSubject = container.read(subjectsProvider).first;
    container
        .read(recordsControllerProvider.notifier)
        .addManualRecord(
          subjectId: archivedSubject.id,
          startedAt: DateTime.now().subtract(const Duration(minutes: 25)),
          endedAt: DateTime.now(),
        );
    container
        .read(subjectsProvider.notifier)
        .setSubjectArchived(archivedSubject.id, true);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const QuietStudyApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('記録').last);
    await tester.pumpAndSettle();
    expect(find.text(archivedSubject.name), findsWidgets);

    await tester.tap(find.text('集中').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('数学').first);
    await tester.pumpAndSettle();

    expect(find.text(archivedSubject.name), findsNothing);
    expect(find.text('数学'), findsWidgets);
  });

  testWidgets('record sheets remain usable on a small dark screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 1136);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(settingsControllerProvider.notifier)
        .setThemeMode(ThemeMode.dark);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const QuietStudyApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('記録').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(CupertinoIcons.add));
    await tester.pumpAndSettle();

    expect(find.text('記録を追加'), findsOneWidget);

    await tester.tap(find.text('科目').last);
    await tester.pumpAndSettle();

    expect(find.text('英語'), findsWidgets);
  });

  test('the last active subject cannot be archived', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(subjectsProvider.notifier);
    final subjects = container.read(subjectsProvider);
    for (final subject in subjects.take(subjects.length - 1)) {
      controller.setSubjectArchived(subject.id, true);
    }

    final lastSubject = container.read(activeSubjectsProvider).single;
    controller.setSubjectArchived(lastSubject.id, true);

    expect(container.read(activeSubjectsProvider), hasLength(1));
    expect(
      container
          .read(subjectsProvider)
          .firstWhere((subject) => subject.id == lastSubject.id)
          .isArchived,
      isFalse,
    );
  });
}

class _FakeWakeLockService implements WakeLockService {
  var enabled = false;

  @override
  Future<void> enable() async {
    enabled = true;
  }

  @override
  Future<void> disable() async {
    enabled = false;
  }
}

class _FakeNotificationService implements NotificationService {
  final scheduledKinds = <StudySessionKind>[];
  final requestPermissionFlags = <bool>[];
  var cancelAllCount = 0;

  @override
  Future<void> initialize() async {}

  @override
  Future<NotificationPermissionState> permissionState() async {
    return NotificationPermissionState.granted;
  }

  @override
  Future<NotificationPermissionState> requestPermission() async {
    return NotificationPermissionState.granted;
  }

  @override
  Future<void> scheduleSessionEnd(
    ActiveSession session, {
    bool requestPermission = true,
  }) async {
    scheduledKinds.add(session.kind);
    requestPermissionFlags.add(requestPermission);
  }

  @override
  Future<void> cancelSessionEnd({StudySessionKind? kind}) async {
    cancelAllCount += 1;
  }

  @override
  Future<void> cancelAllSessionEnds() async {
    cancelAllCount += 1;
  }
}

Future<void> _flushAsync() async {
  for (var index = 0; index < 4; index += 1) {
    await Future<void>.delayed(Duration.zero);
  }
}
