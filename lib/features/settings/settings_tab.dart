import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_theme.dart';
import '../../models/app_settings.dart';
import '../../models/study_subject.dart';
import '../../state/study_providers.dart';

class SettingsTab extends ConsumerWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final subjects = ref.watch(subjectsProvider);
    final controller = ref.read(settingsControllerProvider.notifier);

    return CupertinoPageScaffold(
      navigationBar: _navigationBar(context, '設定'),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            _SettingsSection(
              title: '静音',
              children: [
                _SettingsToggleRow(
                  title: '図書館モード',
                  value: settings.libraryModeEnabled,
                  onChanged: controller.setLibraryMode,
                ),
                _SettingsPickerRow(
                  title: '振動パターン',
                  value: settings.vibrationPattern.label,
                  onPressed: () => _showVibrationPicker(context, controller),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _SettingsSection(
              title: '表示',
              children: [
                _SettingsPickerRow(
                  title: 'テーマ',
                  value: settings.themeMode.label,
                  onPressed: () => _showThemePicker(context, controller),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _SettingsSection(
              title: '科目',
              children: [
                _SettingsPickerRow(
                  title: '科目の追加・編集',
                  value: '${subjects.length}件',
                  onPressed: () => _showSubjectManagementSheet(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(
            title,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Container(
          decoration: _surfaceDecoration(theme),
          child: Column(
            children: [
              for (final (index, child) in children.indexed) ...[
                child,
                if (index != children.length - 1)
                  Divider(
                    height: 1,
                    thickness: 1,
                    indent: 16,
                    color: theme.dividerColor,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsToggleRow extends StatelessWidget {
  const _SettingsToggleRow({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(child: Text(title, style: theme.textTheme.bodyLarge)),
          CupertinoSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _SettingsPickerRow extends StatelessWidget {
  const _SettingsPickerRow({
    required this.title,
    required this.value,
    required this.onPressed,
  });

  final String title;
  final String value;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            Expanded(child: Text(title, style: theme.textTheme.bodyLarge)),
            Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              CupertinoIcons.chevron_forward,
              size: 17,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _SubjectManagementSheet extends ConsumerStatefulWidget {
  const _SubjectManagementSheet();

  @override
  ConsumerState<_SubjectManagementSheet> createState() =>
      _SubjectManagementSheetState();
}

class _SubjectManagementSheetState
    extends ConsumerState<_SubjectManagementSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subjects = ref.watch(subjectsProvider);

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SheetHandle(color: theme.dividerColor),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Spacer(),
                  Text('科目', style: theme.textTheme.titleMedium),
                  const Spacer(),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('完了'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                decoration: _surfaceDecoration(theme),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: CupertinoTextField(
                              controller: _controller,
                              placeholder: '科目名',
                              textInputAction: TextInputAction.done,
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(20),
                              ],
                              decoration: BoxDecoration(
                                color: theme.scaffoldBackgroundColor,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: theme.dividerColor),
                              ),
                              onSubmitted: (_) => _addSubject(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 9,
                            ),
                            color: AppTheme.accentBlue,
                            borderRadius: BorderRadius.circular(8),
                            onPressed: _addSubject,
                            child: const Text(
                              '追加',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(
                      height: 1,
                      thickness: 1,
                      indent: 16,
                      color: theme.dividerColor,
                    ),
                    for (final (index, subject) in subjects.indexed) ...[
                      _SubjectRow(subject: subject),
                      if (index != subjects.length - 1)
                        Divider(
                          height: 1,
                          thickness: 1,
                          indent: 42,
                          color: theme.dividerColor,
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addSubject() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      return;
    }

    ref.read(subjectsProvider.notifier).addSubject(name);
    _controller.clear();
  }
}

class _SubjectRow extends StatelessWidget {
  const _SubjectRow({required this.subject});

  final StudySubject subject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: Color(int.parse('FF${subject.colorHex}', radix: 16)),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(subject.name, style: theme.textTheme.bodyLarge)),
        ],
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 5,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

Future<void> _showVibrationPicker(
  BuildContext context,
  SettingsController controller,
) async {
  await showCupertinoModalPopup<void>(
    context: context,
    builder: (context) {
      return CupertinoActionSheet(
        title: const Text('振動パターン'),
        actions: [
          for (final pattern in VibrationPattern.values)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(context).pop();
                controller.setVibrationPattern(pattern);
              },
              child: Text(pattern.label),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
      );
    },
  );
}

Future<void> _showThemePicker(
  BuildContext context,
  SettingsController controller,
) async {
  await showCupertinoModalPopup<void>(
    context: context,
    builder: (context) {
      return CupertinoActionSheet(
        title: const Text('テーマ'),
        actions: [
          for (final mode in ThemeMode.values)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(context).pop();
                controller.setThemeMode(mode);
              },
              child: Text(mode.label),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
      );
    },
  );
}

Future<void> _showSubjectManagementSheet(BuildContext context) async {
  await showCupertinoModalPopup<void>(
    context: context,
    builder: (context) => const _SubjectManagementSheet(),
  );
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
