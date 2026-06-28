import 'package:flutter/material.dart';

enum VibrationPattern { none, short, doublePulse, slow }

extension ThemeModeLabel on ThemeMode {
  String get label {
    return switch (this) {
      ThemeMode.system => 'システム',
      ThemeMode.light => 'ライト',
      ThemeMode.dark => 'ダーク',
    };
  }
}

extension VibrationPatternLabel on VibrationPattern {
  String get label {
    return switch (this) {
      VibrationPattern.none => 'なし',
      VibrationPattern.short => '短く',
      VibrationPattern.doublePulse => '二度',
      VibrationPattern.slow => 'ゆっくり',
    };
  }
}

@immutable
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.libraryModeEnabled = false,
    this.vibrationPattern = VibrationPattern.short,
    this.keepScreenAwake = false,
  });

  final ThemeMode themeMode;
  final bool libraryModeEnabled;
  final VibrationPattern vibrationPattern;
  final bool keepScreenAwake;

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? libraryModeEnabled,
    VibrationPattern? vibrationPattern,
    bool? keepScreenAwake,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      libraryModeEnabled: libraryModeEnabled ?? this.libraryModeEnabled,
      vibrationPattern: vibrationPattern ?? this.vibrationPattern,
      keepScreenAwake: keepScreenAwake ?? this.keepScreenAwake,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'themeMode': themeMode.name,
      'libraryModeEnabled': libraryModeEnabled,
      'vibrationPattern': vibrationPattern.name,
      'keepScreenAwake': keepScreenAwake,
    };
  }

  factory AppSettings.fromJson(Map<String, Object?> json) {
    return AppSettings(
      themeMode: _themeModeFromName(json['themeMode'] as String?),
      libraryModeEnabled: json['libraryModeEnabled'] as bool? ?? false,
      vibrationPattern: _vibrationPatternFromName(
        json['vibrationPattern'] as String?,
      ),
      keepScreenAwake: json['keepScreenAwake'] as bool? ?? false,
    );
  }
}

ThemeMode _themeModeFromName(String? name) {
  for (final mode in ThemeMode.values) {
    if (mode.name == name) {
      return mode;
    }
  }
  return ThemeMode.system;
}

VibrationPattern _vibrationPatternFromName(String? name) {
  for (final pattern in VibrationPattern.values) {
    if (pattern.name == name) {
      return pattern;
    }
  }
  return VibrationPattern.short;
}
