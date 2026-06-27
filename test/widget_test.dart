import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quiet_study_timer/app/quiet_study_app.dart';
import 'package:quiet_study_timer/models/app_settings.dart';
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
}
