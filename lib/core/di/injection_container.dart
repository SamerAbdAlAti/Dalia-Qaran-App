import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../state/data_changed_notifier.dart';
import '../state/font_scale_cubit.dart';
import '../state/quran_appearance_cubit.dart';
import '../theme/theme_cubit.dart';
import '../../features/home/data/datasources/home_local_datasource.dart';
import '../../features/home/data/repositories/home_repository_impl.dart';
import '../../features/home/domain/repositories/home_repository.dart';
import '../../features/home/domain/usecases/home_usecases.dart';
import '../../features/home/presentation/cubit/home_cubit.dart';
import '../../features/quran/data/datasources/quran_local_datasource.dart';
import '../../features/quran/data/datasources/mushaf_local_datasource.dart';
import '../../features/quran/data/repositories/quran_repository_impl.dart';
import '../../features/quran/data/repositories/mushaf_repository_impl.dart';
import '../../features/quran/domain/repositories/quran_repository.dart';
import '../../features/quran/domain/repositories/mushaf_repository.dart';
import '../../features/quran/domain/usecases/quran_usecases.dart';
import '../../features/quran/domain/usecases/mushaf_usecases.dart';
import '../../features/quran/presentation/cubit/surah_list_cubit.dart';
import '../../features/quran/presentation/cubit/mushaf_cubit.dart';
import '../../features/adhkar/data/datasources/adhkar_datasource.dart';
import '../../features/adhkar/data/repositories/adhkar_repository_impl.dart';
import '../../features/adhkar/domain/repositories/adhkar_repository.dart';
import '../../features/adhkar/domain/usecases/adhkar_usecases.dart';
import '../../features/adhkar/presentation/cubit/adhkar_reader_cubit.dart';
import '../../features/qibla/data/datasources/qibla_local_datasource.dart';
import '../../features/qibla/data/repositories/qibla_repository_impl.dart';
import '../../features/qibla/domain/repositories/qibla_repository.dart';
import '../../features/qibla/domain/usecases/qibla_usecases.dart';
import '../../features/qibla/presentation/cubit/qibla_cubit.dart';
import '../../features/quran_audio/data/datasources/quran_audio_local_datasource.dart';
import '../../features/quran_audio/data/datasources/quran_audio_remote_datasource.dart';
import '../../features/quran_audio/data/repositories/quran_audio_repository_impl.dart';
import '../../features/quran_audio/domain/repositories/quran_audio_repository.dart';
import '../../features/quran_audio/domain/usecases/quran_audio_usecases.dart';
import '../../features/quran_audio/presentation/cubit/quran_audio_cubit.dart';
import '../../features/tafsir/data/datasources/tafsir_remote_datasource.dart';
import '../../features/tafsir/data/repositories/tafsir_repository_impl.dart';
import '../../features/tafsir/domain/repositories/tafsir_repository.dart';
import '../../features/tafsir/domain/usecases/tafsir_usecases.dart';
import '../../features/tafsir/presentation/cubit/tafsir_cubit.dart';

final sl = GetIt.instance;

Future<void> initDependencies() async {
  final prefs = await SharedPreferences.getInstance();

  // ─── Core ───
  sl.registerLazySingleton<SharedPreferences>(() => prefs);
  sl.registerLazySingleton<DataChangedNotifier>(() => DataChangedNotifier());

  // ─── Global Cubits ───
  sl.registerLazySingleton<ThemeCubit>(() => ThemeCubit(sl()));
  sl.registerLazySingleton<FontScaleCubit>(() => FontScaleCubit(sl()));
  sl.registerLazySingleton<QuranAppearanceCubit>(() => QuranAppearanceCubit(sl()));

  // ─── Features ───
  _initHome();
  _initQuran();
  _initQibla();
  _initAdhkar();
  _initQuranAudio();
  _initTafsir();
}

void _initTafsir() {
  sl.registerLazySingleton<TafsirRemoteDatasource>(() => TafsirRemoteDatasource());
  sl.registerLazySingleton<TafsirRepository>(
      () => TafsirRepositoryImpl(sl(), sl()));
  sl.registerLazySingleton<GetTafsir>(() => GetTafsir(sl()));
  sl.registerFactory<TafsirCubit>(() => TafsirCubit(sl()));
}

void _initHome() {
  sl.registerLazySingleton<HomeLocalDatasource>(() => HomeLocalDatasource(sl()));
  sl.registerLazySingleton<HomeRepository>(() => HomeRepositoryImpl(sl()));
  sl.registerLazySingleton<GetPrayerTimes>(() => GetPrayerTimes(sl()));
  sl.registerLazySingleton<RefreshLocation>(() => RefreshLocation(sl()));
  sl.registerLazySingleton<SetManualLocation>(() => SetManualLocation(sl()));
  sl.registerLazySingleton<SetCalculationMethod>(
      () => SetCalculationMethod(sl()));
  sl.registerFactory<HomeCubit>(() => HomeCubit(sl(), sl(), sl(), sl()));
}

void _initQuran() {
  sl.registerLazySingleton<QuranLocalDatasource>(
      () => QuranLocalDatasource(sl()));
  sl.registerLazySingleton<QuranRepository>(
      () => QuranRepositoryImpl(sl()));
  sl.registerLazySingleton<GetSurahs>(() => GetSurahs(sl()));
  sl.registerLazySingleton<GetAyahs>(() => GetAyahs(sl()));
  sl.registerLazySingleton<SaveLastRead>(() => SaveLastRead(sl()));
  sl.registerLazySingleton<GetLastRead>(() => GetLastRead(sl()));
  sl.registerFactory<SurahListCubit>(() => SurahListCubit(sl(), sl()));

  // Mushaf (page-based reader)
  sl.registerLazySingleton<MushafLocalDatasource>(
      () => MushafLocalDatasource(sl()));
  sl.registerLazySingleton<MushafRepository>(
      () => MushafRepositoryImpl(sl()));
  sl.registerLazySingleton<InitMushaf>(() => InitMushaf(sl()));
  sl.registerLazySingleton<GetMushafPage>(() => GetMushafPage(sl()));
  sl.registerLazySingleton<SaveMushafLastRead>(
      () => SaveMushafLastRead(sl()));
  sl.registerLazySingleton<SaveMushafBookmarks>(
      () => SaveMushafBookmarks(sl()));
  sl.registerLazySingleton<SaveMushafReadPages>(
      () => SaveMushafReadPages(sl()));
  sl.registerFactory<MushafCubit>(
      () => MushafCubit(sl(), sl(), sl(), sl(), sl(), sl()));
}

void _initQibla() {
  sl.registerLazySingleton<QiblaLocalDatasource>(
      () => QiblaLocalDatasource(sl()));
  sl.registerLazySingleton<QiblaRepository>(
      () => QiblaRepositoryImpl(sl()));
  sl.registerLazySingleton<GetQiblaData>(() => GetQiblaData(sl()));
  sl.registerFactory<QiblaCubit>(() => QiblaCubit(sl()));
}

void _initAdhkar() {
  sl.registerLazySingleton<AdhkarDatasource>(() => AdhkarDatasource());
  sl.registerLazySingleton<AdhkarRepository>(
      () => AdhkarRepositoryImpl(sl()));
  sl.registerLazySingleton<GetAdhkar>(() => GetAdhkar(sl()));
  sl.registerFactory<AdhkarReaderCubit>(() => AdhkarReaderCubit(sl()));
}

void _initQuranAudio() {
  sl.registerLazySingleton<QuranAudioRemoteDatasource>(
      () => QuranAudioRemoteDatasource());
  sl.registerLazySingleton<QuranAudioLocalDatasource>(
      () => QuranAudioLocalDatasource());
  sl.registerLazySingleton<QuranAudioRepository>(
      () => QuranAudioRepositoryImpl(sl(), sl(), sl()));
  sl.registerLazySingleton<GetReciters>(() => GetReciters(sl()));
  sl.registerLazySingleton<DownloadSurah>(() => DownloadSurah(sl()));
  // Singleton: must survive page navigation so background audio playback
  // and the media notification keep working when the user leaves the
  // Quran reading page (a factory cubit gets close()'d -> player disposed
  // -> audio stops the moment its BlocProvider is popped).
  sl.registerLazySingleton<QuranAudioCubit>(
      () => QuranAudioCubit(sl(), sl(), sl(), sl()));
}
