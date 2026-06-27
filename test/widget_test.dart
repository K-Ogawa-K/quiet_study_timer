import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quiet_study_timer/app/quiet_study_app.dart';

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
}
