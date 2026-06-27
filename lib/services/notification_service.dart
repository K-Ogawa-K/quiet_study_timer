import 'dart:async';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart'
    show MissingPluginException, PlatformException;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/active_session.dart';

enum NotificationPermissionState { unknown, granted, denied, unsupported }

extension NotificationPermissionStateLabel on NotificationPermissionState {
  String get label {
    return switch (this) {
      NotificationPermissionState.unknown => '未確認',
      NotificationPermissionState.granted => '許可済み',
      NotificationPermissionState.denied => '未許可',
      NotificationPermissionState.unsupported => '未対応',
    };
  }
}

abstract class NotificationService {
  Future<void> initialize();

  Future<NotificationPermissionState> permissionState();

  Future<NotificationPermissionState> requestPermission();

  Future<void> scheduleSessionEnd(ActiveSession session);

  Future<void> cancelSessionEnd();
}

class LocalNotificationService implements NotificationService {
  LocalNotificationService({FlutterLocalNotificationsPlugin? notifications})
    : _notifications = notifications ?? FlutterLocalNotificationsPlugin();

  static const _sessionNotificationId = 1001;
  static const _channelId = 'quiet_study_timer_session';
  static const _channelName = 'Timer';
  static const _channelDescription = 'Quiet timer completion notifications';

  final FlutterLocalNotificationsPlugin _notifications;
  var _initialized = false;

  @override
  Future<void> initialize() async {
    if (!_supportsLocalNotifications) {
      return;
    }

    if (_initialized) {
      return;
    }

    tz_data.initializeTimeZones();
    try {
      await _notifications.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
            defaultPresentSound: false,
          ),
          macOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
            defaultPresentSound: false,
          ),
        ),
      );
      _initialized = true;
    } on MissingPluginException {
      _initialized = false;
    } on PlatformException {
      _initialized = false;
    } on Error catch (error) {
      if (!_isUninitializedPluginError(error)) {
        rethrow;
      }
      _initialized = false;
    }
  }

  @override
  Future<NotificationPermissionState> permissionState() async {
    if (!_supportsLocalNotifications) {
      return NotificationPermissionState.unsupported;
    }

    await initialize();

    try {
      final android = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        final enabled = await android.areNotificationsEnabled();
        return enabled == true
            ? NotificationPermissionState.granted
            : NotificationPermissionState.denied;
      }

      return NotificationPermissionState.unknown;
    } on MissingPluginException {
      return NotificationPermissionState.unsupported;
    } on PlatformException {
      return NotificationPermissionState.unknown;
    } on Error catch (error) {
      if (!_isUninitializedPluginError(error)) {
        rethrow;
      }
      return NotificationPermissionState.unsupported;
    }
  }

  @override
  Future<NotificationPermissionState> requestPermission() async {
    if (!_supportsLocalNotifications) {
      return NotificationPermissionState.unsupported;
    }

    await initialize();

    try {
      final android = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        final granted = await android.requestNotificationsPermission();
        return granted == true
            ? NotificationPermissionState.granted
            : NotificationPermissionState.denied;
      }

      final ios = _notifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        final granted = await ios.requestPermissions(
          alert: true,
          badge: false,
          sound: false,
        );
        return granted == true
            ? NotificationPermissionState.granted
            : NotificationPermissionState.denied;
      }

      final macOS = _notifications
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >();
      if (macOS != null) {
        final granted = await macOS.requestPermissions(
          alert: true,
          badge: false,
          sound: false,
        );
        return granted == true
            ? NotificationPermissionState.granted
            : NotificationPermissionState.denied;
      }

      return NotificationPermissionState.unsupported;
    } on MissingPluginException {
      return NotificationPermissionState.unsupported;
    } on PlatformException {
      return NotificationPermissionState.denied;
    } on Error catch (error) {
      if (!_isUninitializedPluginError(error)) {
        rethrow;
      }
      return NotificationPermissionState.unsupported;
    }
  }

  @override
  Future<void> scheduleSessionEnd(ActiveSession session) async {
    if (!_supportsLocalNotifications) {
      return;
    }

    final expectedEndAt = session.expectedEndAt;
    if (expectedEndAt == null || !expectedEndAt.isAfter(DateTime.now())) {
      return;
    }

    await cancelSessionEnd();

    final permission = await requestPermission();
    if (permission != NotificationPermissionState.granted) {
      return;
    }

    final title = switch (session.kind) {
      StudySessionKind.focus => '集中が終わりました',
      StudySessionKind.rest => '休憩が終わりました',
    };

    try {
      await _notifications.zonedSchedule(
        id: _sessionNotificationId,
        title: title,
        body: '',
        scheduledDate: tz.TZDateTime.from(expectedEndAt, tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            playSound: false,
            enableVibration: false,
            silent: true,
          ),
          iOS: DarwinNotificationDetails(
            presentSound: false,
            presentBadge: false,
          ),
          macOS: DarwinNotificationDetails(
            presentSound: false,
            presentBadge: false,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: session.id,
      );
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    } on Error catch (error) {
      if (!_isUninitializedPluginError(error)) {
        rethrow;
      }
      return;
    }
  }

  @override
  Future<void> cancelSessionEnd() async {
    if (!_supportsLocalNotifications) {
      return;
    }

    await initialize();
    try {
      await _notifications.cancel(id: _sessionNotificationId);
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    } on Error catch (error) {
      if (!_isUninitializedPluginError(error)) {
        rethrow;
      }
      return;
    }
  }
}

bool get _supportsLocalNotifications {
  if (kIsWeb) {
    return false;
  }

  return switch (defaultTargetPlatform) {
    TargetPlatform.android ||
    TargetPlatform.iOS ||
    TargetPlatform.macOS => true,
    _ => false,
  };
}

bool _isUninitializedPluginError(Error error) {
  return error.toString().startsWith('LateInitializationError');
}
