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

    final decoded = jsonDecode(rawJson);
    if (decoded is! List) {
      return null;
    }

    return decoded
        .whereType<Map>()
        .map((item) => StudySubject.fromJson(Map<String, Object?>.from(item)))
        .toList();
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

    final decoded = jsonDecode(rawJson);
    if (decoded is! List) {
      return const [];
    }

    return decoded
        .whereType<Map>()
        .map((item) => StudyRecord.fromJson(Map<String, Object?>.from(item)))
        .toList();
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

    final decoded = jsonDecode(rawJson);
    if (decoded is! Map) {
      return null;
    }

    return AppSettings.fromJson(Map<String, Object?>.from(decoded));
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

    final decoded = jsonDecode(rawJson);
    if (decoded is! Map) {
      return null;
    }

    return ActiveSession.fromJson(Map<String, Object?>.from(decoded));
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
