import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kalla_lai/core/storage/kv_store.dart';

class AppSettingsState {
  const AppSettingsState({
    required this.themeMode,
    required this.languageCode,
    required this.notificationsEnabled,
    required this.apiUrlOverride,
  });

  final ThemeMode themeMode;
  final String languageCode;
  final bool notificationsEnabled;

  /// Empty means "use the build/runtime default".
  final String apiUrlOverride;

  AppSettingsState copyWith({
    ThemeMode? themeMode,
    String? languageCode,
    bool? notificationsEnabled,
    String? apiUrlOverride,
  }) => AppSettingsState(
    themeMode: themeMode ?? this.themeMode,
    languageCode: languageCode ?? this.languageCode,
    notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    apiUrlOverride: apiUrlOverride ?? this.apiUrlOverride,
  );
}

/// User-configurable options, persisted locally on this device.
class AppSettingsCubit extends Cubit<AppSettingsState> {
  AppSettingsCubit() : super(_read());

  static const _themeKey = 'kalla_lai.theme_mode.v1';
  static const _languageKey = 'kalla_lai.language.v1';
  static const _notificationsKey = 'kalla_lai.notifications.v1';
  static const _apiUrlKey = 'kalla_lai.api_url.v1';

  static AppSettingsState _read() => AppSettingsState(
    themeMode: switch (kvStore.read(_themeKey)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      // The product ships with a plain white canvas by default; visitors can
      // still opt into dark mode from settings.
      _ => ThemeMode.light,
    },
    languageCode: kvStore.read(_languageKey) == 'ne' ? 'ne' : 'en',
    notificationsEnabled: kvStore.read(_notificationsKey) != 'false',
    apiUrlOverride: kvStore.read(_apiUrlKey) ?? '',
  );

  void setThemeMode(ThemeMode mode) {
    kvStore.write(
      _themeKey,
      switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      },
    );
    emit(state.copyWith(themeMode: mode));
  }

  void setLanguage(String code) {
    final language = code == 'ne' ? 'ne' : 'en';
    kvStore.write(_languageKey, language);
    emit(state.copyWith(languageCode: language));
  }

  void setNotifications(bool enabled) {
    kvStore.write(_notificationsKey, enabled.toString());
    emit(state.copyWith(notificationsEnabled: enabled));
  }

  void setApiUrlOverride(String value) {
    kvStore.write(_apiUrlKey, value.trim());
    emit(state.copyWith(apiUrlOverride: value.trim()));
  }

  static String? get savedApiUrlOverride {
    final value = kvStore.read(_apiUrlKey);
    return (value == null || value.isEmpty) ? null : value;
  }
}
