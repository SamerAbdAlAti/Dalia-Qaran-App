import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../state/data_changed_notifier.dart';
import '../state/font_scale_cubit.dart';
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
import '../../features/quran/presentation/cubit/surah_reader_cubit.dart';
import '../../features/quran/presentation/cubit/mushaf_cubit.dart';
import '../../features/qibla/data/datasources/qibla_local_datasource.dart';
import '../../features/qibla/data/repositories/qibla_repository_impl.dart';
import '../../features/qibla/domain/repositories/qibla_repository.dart';
import '../../features/qibla/domain/usecases/qibla_usecases.dart';
import '../../features/qibla/presentation/cubit/qibla_cubit.dart';

final sl = GetIt.instance;

Future<void> initDependencies() async {
  final prefs = await SharedPreferences.getInstance();

  // ─── Core ───
  sl.registerLazySingleton<SharedPreferences>(() => prefs);
  sl.registerLazySingleton<DataChangedNotifier>(() => DataChangedNotifier());

  // ─── Global Cubits ───
  sl.registerLazySingleton<ThemeCubit>(() => ThemeCubit(sl()));
  sl.registerLazySingleton<FontScaleCubit>(() => FontScaleCubit(sl()));

  // ─── Features ───
  _initHome();
  _initQuran();
  _initQibla();
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
  sl.registerFactory<SurahReaderCubit>(
      () => SurahReaderCubit(sl(), sl(), sl()));

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
