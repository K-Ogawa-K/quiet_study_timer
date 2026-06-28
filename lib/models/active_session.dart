import 'dart:math';

import 'package:flutter/foundation.dart';

enum StudySessionMode { timer, stopwatch }

enum StudySessionKind { focus, rest }

enum StudySessionStatus { running, paused, completed }

const Object _unset = Object();

@immutable
class ActiveSession {
  const ActiveSession({
    required this.id,
    required this.subjectId,
    required this.kind,
    required this.mode,
    required this.status,
    required this.targetSeconds,
    required this.startedAt,
    required this.elapsedBeforeCurrentRunSeconds,
    this.runStartedAt,
    this.expectedEndAt,
    this.pausedAt,
    this.completedAt,
  });

  final String id;
  final String subjectId;
  final StudySessionKind kind;
  final StudySessionMode mode;
  final StudySessionStatus status;
  final int targetSeconds;
  final DateTime startedAt;
  final DateTime? runStartedAt;
  final int elapsedBeforeCurrentRunSeconds;
  final DateTime? expectedEndAt;
  final DateTime? pausedAt;
  final DateTime? completedAt;

  int elapsedSeconds(DateTime now) {
    if (status != StudySessionStatus.running || runStartedAt == null) {
      return max(0, elapsedBeforeCurrentRunSeconds);
    }

    final runElapsed = now.difference(runStartedAt!).inSeconds;
    return max(0, elapsedBeforeCurrentRunSeconds + runElapsed);
  }

  int completedDurationSeconds(DateTime now) {
    final elapsed = elapsedSeconds(now);
    if (mode == StudySessionMode.timer) {
      return max(0, min(targetSeconds, elapsed));
    }
    return max(0, elapsed);
  }

  int displaySeconds(DateTime now) {
    if (mode == StudySessionMode.stopwatch) {
      return elapsedSeconds(now);
    }
    return remainingSeconds(now);
  }

  int remainingSeconds(DateTime now) {
    if (mode == StudySessionMode.stopwatch) {
      return 0;
    }

    if (status == StudySessionStatus.running && expectedEndAt != null) {
      final remainingMilliseconds = expectedEndAt!
          .difference(now)
          .inMilliseconds;
      return max(0, (remainingMilliseconds / 1000).ceil());
    }

    return max(0, targetSeconds - elapsedSeconds(now));
  }

  bool shouldComplete(DateTime now) {
    if (mode != StudySessionMode.timer ||
        status != StudySessionStatus.running ||
        expectedEndAt == null) {
      return false;
    }
    return !now.isBefore(expectedEndAt!);
  }

  ActiveSession copyWith({
    String? id,
    String? subjectId,
    StudySessionKind? kind,
    StudySessionMode? mode,
    StudySessionStatus? status,
    int? targetSeconds,
    DateTime? startedAt,
    Object? runStartedAt = _unset,
    int? elapsedBeforeCurrentRunSeconds,
    Object? expectedEndAt = _unset,
    Object? pausedAt = _unset,
    Object? completedAt = _unset,
  }) {
    return ActiveSession(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      kind: kind ?? this.kind,
      mode: mode ?? this.mode,
      status: status ?? this.status,
      targetSeconds: targetSeconds ?? this.targetSeconds,
      startedAt: startedAt ?? this.startedAt,
      runStartedAt: identical(runStartedAt, _unset)
          ? this.runStartedAt
          : runStartedAt as DateTime?,
      elapsedBeforeCurrentRunSeconds:
          elapsedBeforeCurrentRunSeconds ?? this.elapsedBeforeCurrentRunSeconds,
      expectedEndAt: identical(expectedEndAt, _unset)
          ? this.expectedEndAt
          : expectedEndAt as DateTime?,
      pausedAt: identical(pausedAt, _unset)
          ? this.pausedAt
          : pausedAt as DateTime?,
      completedAt: identical(completedAt, _unset)
          ? this.completedAt
          : completedAt as DateTime?,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'subjectId': subjectId,
      'kind': kind.name,
      'mode': mode.name,
      'status': status.name,
      'targetSeconds': targetSeconds,
      'startedAt': startedAt.toIso8601String(),
      'runStartedAt': runStartedAt?.toIso8601String(),
      'elapsedBeforeCurrentRunSeconds': elapsedBeforeCurrentRunSeconds,
      'expectedEndAt': expectedEndAt?.toIso8601String(),
      'pausedAt': pausedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  factory ActiveSession.fromJson(Map<String, Object?> json) {
    return ActiveSession(
      id: json['id'] as String,
      subjectId: json['subjectId'] as String,
      kind: _sessionKindFromName(json['kind'] as String?),
      mode: _sessionModeFromName(json['mode'] as String?),
      status: _sessionStatusFromName(json['status'] as String?),
      targetSeconds: json['targetSeconds'] as int,
      startedAt: DateTime.parse(json['startedAt'] as String),
      runStartedAt: _dateTimeFromJson(json['runStartedAt']),
      elapsedBeforeCurrentRunSeconds:
          json['elapsedBeforeCurrentRunSeconds'] as int,
      expectedEndAt: _dateTimeFromJson(json['expectedEndAt']),
      pausedAt: _dateTimeFromJson(json['pausedAt']),
      completedAt: _dateTimeFromJson(json['completedAt']),
    );
  }
}

DateTime? _dateTimeFromJson(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.parse(value);
}

StudySessionKind _sessionKindFromName(String? name) {
  for (final kind in StudySessionKind.values) {
    if (kind.name == name) {
      return kind;
    }
  }
  return StudySessionKind.focus;
}

StudySessionMode _sessionModeFromName(String? name) {
  for (final mode in StudySessionMode.values) {
    if (mode.name == name) {
      return mode;
    }
  }
  return StudySessionMode.timer;
}

StudySessionStatus _sessionStatusFromName(String? name) {
  for (final status in StudySessionStatus.values) {
    if (status.name == name) {
      return status;
    }
  }
  return StudySessionStatus.running;
}
