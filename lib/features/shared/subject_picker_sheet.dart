import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../models/study_subject.dart';

Future<void> showSubjectPickerSheet({
  required BuildContext context,
  required List<StudySubject> subjects,
  required String selectedSubjectId,
  required ValueChanged<String> onSelected,
}) async {
  await showCupertinoModalPopup<void>(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      return Material(
        color: Colors.transparent,
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.72,
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
                  const SizedBox(height: 14),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Container(
                        decoration: _surfaceDecoration(theme),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final (index, subject)
                                in subjects.indexed) ...[
                              _SubjectPickerRow(
                                subject: subject,
                                selected: subject.id == selectedSubjectId,
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  onSelected(subject.id);
                                },
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
    },
  );
}

class _SubjectPickerRow extends StatelessWidget {
  const _SubjectPickerRow({
    required this.subject,
    required this.selected,
    required this.onPressed,
  });

  final StudySubject subject;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            _SubjectDot(colorHex: subject.colorHex),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                subject.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge,
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              selected
                  ? CupertinoIcons.check_mark_circled_solid
                  : CupertinoIcons.circle,
              size: 20,
              color: selected
                  ? AppTheme.accentBlue
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _SubjectDot extends StatelessWidget {
  const _SubjectDot({required this.colorHex});

  final String colorHex;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: Color(int.parse('FF$colorHex', radix: 16)),
        shape: BoxShape.circle,
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

BoxDecoration _surfaceDecoration(ThemeData theme) {
  return BoxDecoration(
    color: theme.colorScheme.surface,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: theme.dividerColor),
  );
}
