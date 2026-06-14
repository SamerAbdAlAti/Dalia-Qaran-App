import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

// ─── States ───

class FontScaleState {
  final double scale;
  const FontScaleState(this.scale);
}

// ─── Cubit ───

class FontScaleCubit extends Cubit<FontScaleState> {
  static const double min = 0.8;
  static const double max = 1.6;

  final SharedPreferences _prefs;

  FontScaleCubit(this._prefs)
      : super(
          FontScaleState(
            _prefs.getDouble(AppConstants.keyFontScale) ?? 1.0,
          ),
        );

  void setScale(double scale) {
    final clamped = scale.clamp(min, max);
    _prefs.setDouble(AppConstants.keyFontScale, clamped);
    emit(FontScaleState(clamped));
  }

  void increase() => setScale(state.scale + 0.1);
  void decrease() => setScale(state.scale - 0.1);
}
