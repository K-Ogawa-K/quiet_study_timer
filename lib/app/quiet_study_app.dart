import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/study_providers.dart';
import 'navigation/root_tab_shell.dart';
import 'theme/app_theme.dart';

class QuietStudyApp extends ConsumerWidget {
  const QuietStudyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);

    return MaterialApp(
      title: 'Quiet Study Timer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: settings.themeMode,
      home: const RootTabShell(),
    );
  }
}
