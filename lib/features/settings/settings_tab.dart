import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_theme.dart';
import '../../models/app_settings.dart';
import '../../models/study_subject.dart';
import '../../services/notification_service.dart';
import '../../state/study_providers.dart';

class SettingsTab extends ConsumerWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final notificationPermission = ref.watch(
      notificationPermissionControllerProvider,
    );
    final activeSubjects = ref.watch(activeSubjectsProvider);
    final controller = ref.read(settingsControllerProvider.notifier);
    final focusController = ref.read(focusControllerProvider.notifier);
    final notificationController = ref.read(
      notificationPermissionControllerProvider.notifier,
    );

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
                _SettingsPickerRow(
                  title: 'タイマー通知',
                  value: notificationPermission.label,
                  subtitle: _notificationSubtitle(notificationPermission),
                  onPressed: notificationController.requestPermission,
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
                _SettingsToggleRow(
                  title: '画面を暗くしない',
                  value: settings.keepScreenAwake,
                  onChanged: controller.setKeepScreenAwake,
                ),
              ],
            ),
            const SizedBox(height: 24),
            _SettingsSection(
              title: '科目',
              children: [
                _SettingsPickerRow(
                  title: '科目の追加・編集',
                  value: '${activeSubjects.length}件',
                  onPressed: () => _showSubjectManagementSheet(context),
                ),
              ],
            ),
            if (kDebugMode) ...[
              const SizedBox(height: 24),
              _SettingsSection(
                title: '開発',
                children: [
                  _SettingsPickerRow(
                    title: '10秒集中',
                    value: '開始',
                    onPressed: focusController.startDebugFocus,
                  ),
                  _SettingsPickerRow(
                    title: '10秒休憩',
                    value: '開始',
                    onPressed: focusController.startDebugBreak,
                  ),
                ],
              ),
            ],
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
    this.subtitle,
  });

  final String title;
  final String value;
  final VoidCallback onPressed;
  final String? subtitle;

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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.bodyLarge),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
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
    final activeCount = ref.watch(activeSubjectsProvider).length;

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.82,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
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
                  child: Padding(
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
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: Container(
                      decoration: _surfaceDecoration(theme),
                      child: Column(
                        children: [
                          for (final (index, subject) in subjects.indexed) ...[
                            _SubjectRow(
                              subject: subject,
                              isFirst: index == 0,
                              isLast: index == subjects.length - 1,
                              onPressed: () => _showSubjectEditorSheet(
                                context,
                                subject: subject,
                                activeCount: activeCount,
                              ),
                              onMoveUp: () => ref
                                  .read(subjectsProvider.notifier)
                                  .moveSubject(subject.id, -1),
                              onMoveDown: () => ref
                                  .read(subjectsProvider.notifier)
                                  .moveSubject(subject.id, 1),
                            ),
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
                  ),
                ),
              ],
            ),
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
  const _SubjectRow({
    required this.subject,
    required this.isFirst,
    required this.isLast,
    required this.onPressed,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final StudySubject subject;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onPressed;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rowColor = subject.isArchived
        ? theme.colorScheme.onSurface.withValues(alpha: 0.46)
        : theme.colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
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
          Expanded(
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 44),
              alignment: Alignment.centerLeft,
              onPressed: onPressed,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      subject.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: rowColor,
                      ),
                    ),
                  ),
                  if (subject.isArchived) ...[
                    const SizedBox(width: 8),
                    Text(
                      '非表示',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          _SubjectMoveButton(
            icon: CupertinoIcons.chevron_up,
            enabled: !isFirst,
            onPressed: onMoveUp,
          ),
          _SubjectMoveButton(
            icon: CupertinoIcons.chevron_down,
            enabled: !isLast,
            onPressed: onMoveDown,
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(32, 32),
            onPressed: onPressed,
            child: Icon(
              CupertinoIcons.chevron_forward,
              size: 17,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SubjectMoveButton extends StatelessWidget {
  const _SubjectMoveButton({
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(30, 32),
      onPressed: enabled ? onPressed : null,
      child: Icon(
        icon,
        size: 17,
        color: enabled
            ? theme.colorScheme.onSurfaceVariant
            : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.28),
      ),
    );
  }
}

class _SubjectEditorSheet extends ConsumerStatefulWidget {
  const _SubjectEditorSheet({required this.subject, required this.activeCount});

  final StudySubject subject;
  final int activeCount;

  @override
  ConsumerState<_SubjectEditorSheet> createState() =>
      _SubjectEditorSheetState();
}

class _SubjectEditorSheetState extends ConsumerState<_SubjectEditorSheet> {
  late final TextEditingController _nameController;
  late String _colorHex;
  late bool _isArchived;

  static const _colorOptions = [
    '2F80ED',
    '35A67B',
    '7B61D1',
    'D79A2B',
    '8E8E93',
    'D96A6A',
  ];

  bool get _hasChanges {
    return _nameController.text.trim() != widget.subject.name ||
        _colorHex != widget.subject.colorHex ||
        _isArchived != widget.subject.isArchived;
  }

  bool get _hasDuplicateName {
    final name = _nameController.text.trim();
    return ref
        .read(subjectsProvider)
        .any(
          (subject) => subject.id != widget.subject.id && subject.name == name,
        );
  }

  bool get _canToggleArchive {
    return widget.subject.isArchived || widget.activeCount > 1;
  }

  bool get _wouldArchiveLastActive {
    return _isArchived && !widget.subject.isArchived && widget.activeCount <= 1;
  }

  bool get _canSave {
    return _nameController.text.trim().isNotEmpty &&
        !_hasDuplicateName &&
        !_wouldArchiveLastActive &&
        _hasChanges;
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.subject.name)
      ..addListener(() => setState(() {}));
    _colorHex = widget.subject.colorHex;
    _isArchived = widget.subject.isArchived;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'キャンセル',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text('科目', style: theme.textTheme.titleMedium),
                  const Spacer(),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    onPressed: _canSave ? _save : null,
                    child: Text(
                      '保存',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: _canSave
                            ? AppTheme.accentBlue
                            : theme.colorScheme.onSurfaceVariant,
                        fontWeight: _canSave
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                decoration: _surfaceDecoration(theme),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      child: CupertinoTextField(
                        controller: _nameController,
                        placeholder: '科目名',
                        autofocus: true,
                        textInputAction: TextInputAction.done,
                        inputFormatters: [LengthLimitingTextInputFormatter(20)],
                        decoration: BoxDecoration(
                          color: theme.scaffoldBackgroundColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: theme.dividerColor),
                        ),
                      ),
                    ),
                    Divider(
                      height: 1,
                      thickness: 1,
                      indent: 16,
                      color: theme.dividerColor,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text('色', style: theme.textTheme.bodyLarge),
                          ),
                          for (final colorHex in _colorOptions) ...[
                            _ColorOptionButton(
                              colorHex: colorHex,
                              selected: colorHex == _colorHex,
                              onPressed: () =>
                                  setState(() => _colorHex = colorHex),
                            ),
                            if (colorHex != _colorOptions.last)
                              const SizedBox(width: 8),
                          ],
                        ],
                      ),
                    ),
                    Divider(
                      height: 1,
                      thickness: 1,
                      indent: 16,
                      color: theme.dividerColor,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('非表示', style: theme.textTheme.bodyLarge),
                                if (!_canToggleArchive)
                                  Text(
                                    '最低1つは残します',
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                          color: theme
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                              ],
                            ),
                          ),
                          CupertinoSwitch(
                            value: _isArchived,
                            onChanged: _canToggleArchive
                                ? (value) => setState(() => _isArchived = value)
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (_hasDuplicateName) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '同じ科目名があります',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: CupertinoColors.systemRed.resolveFrom(context),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _save() {
    if (!_canSave) {
      return;
    }

    final controller = ref.read(subjectsProvider.notifier);
    controller.renameSubject(widget.subject.id, _nameController.text);
    controller.setSubjectColor(widget.subject.id, _colorHex);
    controller.setSubjectArchived(widget.subject.id, _isArchived);
    Navigator.of(context).pop();
  }
}

class _ColorOptionButton extends StatelessWidget {
  const _ColorOptionButton({
    required this.colorHex,
    required this.selected,
    required this.onPressed,
  });

  final String colorHex;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = Color(int.parse('FF$colorHex', radix: 16));
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(28, 28),
      onPressed: onPressed,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            width: selected ? 3 : 1,
            color: selected
                ? AppTheme.accentBlue
                : Theme.of(context).dividerColor,
          ),
        ),
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

String? _notificationSubtitle(NotificationPermissionState state) {
  return switch (state) {
    NotificationPermissionState.denied => 'アプリ内の表示と振動は使えます',
    NotificationPermissionState.unsupported => 'この端末では使えません',
    _ => null,
  };
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

Future<void> _showSubjectEditorSheet(
  BuildContext context, {
  required StudySubject subject,
  required int activeCount,
}) async {
  await showCupertinoModalPopup<void>(
    context: context,
    builder: (context) =>
        _SubjectEditorSheet(subject: subject, activeCount: activeCount),
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
