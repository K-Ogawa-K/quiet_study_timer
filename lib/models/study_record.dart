import 'package:flutter/foundation.dart';

enum StudyRecordSource { timer, stopwatch, manual }

@immutable
class StudyRecord {
  const StudyRecord({
    required this.id,
    required this.subjectId,
    required this.startedAt,
    required this.endedAt,
    required this.durationSeconds,
    required this.source,
  });

  final String id;
  final String subjectId;
  final DateTime startedAt;
  final DateTime endedAt;
  final int durationSeconds;
  final StudyRecordSource source;

  StudyRecord copyWith({
    String? id,
    String? subjectId,
    DateTime? startedAt,
    DateTime? endedAt,
    int? durationSeconds,
    StudyRecordSource? source,
  }) {
    return StudyRecord(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      source: source ?? this.source,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'subjectId': subjectId,
      'startedAt': startedAt.toIso8601String(),
      'endedAt': endedAt.toIso8601String(),
      'durationSeconds': durationSeconds,
      'source': source.name,
    };
  }

  factory StudyRecord.fromJson(Map<String, Object?> json) {
    return StudyRecord(
      id: json['id'] as String,
      subjectId: json['subjectId'] as String,
      startedAt: DateTime.parse(json['startedAt'] as String),
      endedAt: DateTime.parse(json['endedAt'] as String),
      durationSeconds: json['durationSeconds'] as int,
      source: _recordSourceFromName(json['source'] as String?),
    );
  }
}

StudyRecordSource _recordSourceFromName(String? name) {
  for (final source in StudyRecordSource.values) {
    if (source.name == name) {
      return source;
    }
  }
  return StudyRecordSource.timer;
}
