import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/analytics/analytics_tab.dart';
import '../../features/focus/focus_tab.dart';
import '../../features/records/records_tab.dart';
import '../../features/settings/settings_tab.dart';
import '../../state/study_providers.dart';
import '../theme/app_theme.dart';

class RootTabShell extends ConsumerStatefulWidget {
  const RootTabShell({super.key});

  @override
  ConsumerState<RootTabShell> createState() => _RootTabShellState();
}

class _RootTabShellState extends ConsumerState<RootTabShell>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(focusControllerProvider.notifier).reconcileWithClock();
      return;
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      ref.read(focusControllerProvider.notifier).releaseScreenAwake();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CupertinoTheme(
      data: AppTheme.cupertinoThemeFor(theme),
      child: CupertinoTabScaffold(
        tabBar: CupertinoTabBar(
          activeColor: AppTheme.accentBlue,
          inactiveColor: theme.colorScheme.onSurfaceVariant,
          backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.92),
          border: Border(top: BorderSide(color: theme.dividerColor)),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.timer),
              label: '集中',
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.list_bullet),
              label: '記録',
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.chart_bar),
              label: '分析',
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.gear_alt),
              label: '設定',
            ),
          ],
        ),
        tabBuilder: (context, index) {
          return switch (index) {
            0 => const FocusTab(),
            1 => const RecordsTab(),
            2 => const AnalyticsTab(),
            _ => const SettingsTab(),
          };
        },
      ),
    );
  }
}
