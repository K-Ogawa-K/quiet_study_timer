import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quiet_study_timer/app/quiet_study_app.dart';
import 'package:quiet_study_timer/models/active_session.dart';
import 'package:quiet_study_timer/models/app_settings.dart';
import 'package:quiet_study_timer/services/wake_lock_service.dart';
import 'package:quiet_study_timer/state/study_providers.dart';

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

    expect(find.text('記録しました'), findsOneWidget);

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

    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('科目の追加・編集'));
    await tester.pumpAndSettle();

    expect(find.text('科目名'), findsOneWidget);
    expect(find.text('英語'), findsWidgets);
    expect(find.text('数学'), findsWidgets);

    await tester.tap(find.text('英語').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(CupertinoTextField).last, '英語A');
    await tester.tap(find.text('保存'));
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
