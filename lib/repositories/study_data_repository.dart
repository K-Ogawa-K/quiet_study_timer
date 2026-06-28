import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/active_session.dart';
import '../models/app_settings.dart';
import '../models/study_record.dart';
import '../models/study_subject.dart';

abstract class StudyDataRepository {
  Future<List<StudySubject>?> loadSubjects();

  Future<void> saveSubjects(List<StudySubject> subjects);

  Future<List<StudyRecord>> loadRecords();

  Future<void> saveRecords(List<StudyRecord> records);

  Future<AppSettings?> loadSettings();

  Future<void> saveSettings(AppSettings settings);

  Future<ActiveSession?> loadActiveSession();

  Future<void> saveActiveSession(ActiveSession session);

  Future<void> clearActiveSession();
}

class SharedPreferencesStudyDataRepository implements StudyDataRepository {
  static const _activeSessionStorageKey = 'active_session_v1';
  static const _recordsStorageKey = 'study_records_v1';
  static const _settingsStorageKey = 'app_settings_v1';
  static const _subjectsStorageKey = 'study_subjects_v1';

  @override
  Future<List<StudySubject>?> loadSubjects() async {
    final rawJson = await _readString(_subjectsStorageKey);
    if (rawJson == null) {
      return null;
    }

    final decoded = _decodeJson(rawJson);
    if (decoded is! List) {
      return null;
    }

    return [for (final item in decoded) ?_studySubjectFromJson(item)];
  }

  @override
  Future<void> saveSubjects(List<StudySubject> subjects) async {
    await _writeJson(
      _subjectsStorageKey,
      subjects.map((subject) => subject.toJson()).toList(),
    );
  }

  @override
  Future<List<StudyRecord>> loadRecords() async {
    final rawJson = await _readString(_recordsStorageKey);
    if (rawJson == null) {
      return const [];
    }

    final decoded = _decodeJson(rawJson);
    if (decoded is! List) {
      return const [];
    }

    return [for (final item in decoded) ?_studyRecordFromJson(item)];
  }

  @override
  Future<void> saveRecords(List<StudyRecord> records) async {
    await _writeJson(
      _recordsStorageKey,
      records.map((record) => record.toJson()).toList(),
    );
  }

  @override
  Future<AppSettings?> loadSettings() async {
    final rawJson = await _readString(_settingsStorageKey);
    if (rawJson == null) {
      return null;
    }

    final decoded = _decodeJson(rawJson);
    if (decoded is! Map) {
      return null;
    }

    return _appSettingsFromJson(decoded);
  }

  @override
  Future<void> saveSettings(AppSettings settings) async {
    await _writeJson(_settingsStorageKey, settings.toJson());
  }

  @override
  Future<ActiveSession?> loadActiveSession() async {
    final rawJson = await _readString(_activeSessionStorageKey);
    if (rawJson == null) {
      return null;
    }

    final decoded = _decodeJson(rawJson);
    if (decoded is! Map) {
      return null;
    }

    return _activeSessionFromJson(decoded);
  }

  @override
  Future<void> saveActiveSession(ActiveSession session) async {
    await _writeJson(_activeSessionStorageKey, session.toJson());
  }

  @override
  Future<void> clearActiveSession() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_activeSessionStorageKey);
  }

  Future<String?> _readString(String key) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(key);
  }

  Future<void> _writeJson(String key, Object? value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(key, jsonEncode(value));
  }
}

Object? _decodeJson(String rawJson) {
  try {
    return jsonDecode(rawJson);
  } on Object {
    return null;
  }
}

StudySubject? _studySubjectFromJson(Object? value) {
  if (value is! Map) {
    return null;
  }

  try {
    final subject = StudySubject.fromJson(Map<String, Object?>.from(value));
    if (subject.id.isEmpty ||
        subject.name.trim().isEmpty ||
        subject.colorHex.isEmpty) {
      return null;
    }
    return subject;
  } on Object {
    return null;
  }
}

StudyRecord? _studyRecordFromJson(Object? value) {
  if (value is! Map) {
    return null;
  }

  try {
    final record = StudyRecord.fromJson(Map<String, Object?>.from(value));
    if (!record.endedAt.isAfter(record.startedAt) ||
        record.durationSeconds <= 0) {
      return null;
    }
    return record;
  } on Object {
    return null;
  }
}

AppSettings? _appSettingsFromJson(Map<dynamic, dynamic> value) {
  try {
    return AppSettings.fromJson(Map<String, Object?>.from(value));
  } on Object {
    return null;
  }
}

ActiveSession? _activeSessionFromJson(Map<dynamic, dynamic> value) {
  try {
    final session = ActiveSession.fromJson(Map<String, Object?>.from(value));
    if (session.id.isEmpty ||
        session.subjectId.isEmpty ||
        session.targetSeconds <= 0 ||
        session.elapsedBeforeCurrentRunSeconds < 0) {
      return null;
    }
    if (session.mode == StudySessionMode.timer &&
        session.status == StudySessionStatus.running &&
        session.expectedEndAt == null) {
      return null;
    }
    return session;
  } on Object {
    return null;
  }
}
