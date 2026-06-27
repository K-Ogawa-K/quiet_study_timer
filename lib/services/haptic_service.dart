import 'dart:async';

import 'package:flutter/services.dart';

import '../models/app_settings.dart';

abstract class HapticService {
  Future<void> playTimerCompletion(VibrationPattern pattern);
}

class SystemHapticService implements HapticService {
  const SystemHapticService();

  @override
  Future<void> playTimerCompletion(VibrationPattern pattern) async {
    switch (pattern) {
      case VibrationPattern.none:
        return;
      case VibrationPattern.short:
        await HapticFeedback.selectionClick();
        return;
      case VibrationPattern.doublePulse:
        await HapticFeedback.selectionClick();
        await Future<void>.delayed(const Duration(milliseconds: 140));
        await HapticFeedback.selectionClick();
        return;
      case VibrationPattern.slow:
        await HapticFeedback.lightImpact();
        await Future<void>.delayed(const Duration(milliseconds: 260));
        await HapticFeedback.selectionClick();
        return;
    }
  }
}
