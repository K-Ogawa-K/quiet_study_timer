import 'package:flutter/services.dart'
    show MissingPluginException, PlatformException;
import 'package:wakelock_plus/wakelock_plus.dart';

abstract class WakeLockService {
  Future<void> enable();

  Future<void> disable();
}

class SystemWakeLockService implements WakeLockService {
  const SystemWakeLockService();

  @override
  Future<void> enable() async {
    await _setEnabled(true);
  }

  @override
  Future<void> disable() async {
    await _setEnabled(false);
  }

  Future<void> _setEnabled(bool enabled) async {
    try {
      await WakelockPlus.toggle(enable: enabled);
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    } on Error catch (error) {
      if (!_isUninitializedPluginError(error)) {
        rethrow;
      }
    }
  }
}

bool _isUninitializedPluginError(Error error) {
  return error.toString().startsWith('LateInitializationError');
}
