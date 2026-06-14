import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

// ─── States ───

class ThemeState {
  final ThemeMode mode;
  const ThemeState(this.mode);
}

// ─── Cubit ───

class ThemeCubit extends Cubit<ThemeState> {
  final SharedPreferences _prefs;

  ThemeCubit(this._prefs) : super(ThemeState(_load(_prefs)));

  static ThemeMode _load(SharedPreferences prefs) =>
      switch (prefs.getString(AppConstants.keyTheme)) {
        'dark' => ThemeMode.dark,
        'light' => ThemeMode.light,
        _ => ThemeMode.system,
      };

  void toggle() {
    final next =
        state.mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    _save(next);
    emit(ThemeState(next));
  }

  void setMode(ThemeMode mode) {
    _save(mode);
    emit(ThemeState(mode));
  }

  void _save(ThemeMode mode) =>
      _prefs.setString(AppConstants.keyTheme, mode.name);
}
