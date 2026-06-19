import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/di/injection_container.dart';
import 'core/services/background_service.dart';
import 'core/services/media_notification_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/reminders_service.dart';
import 'core/services/widget_service.dart';
import 'core/state/font_scale_cubit.dart';
import 'core/state/quran_appearance_cubit.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_cubit.dart';
import 'features/quran_audio/presentation/cubit/quran_audio_cubit.dart';
import 'features/splash/presentation/pages/splash_page.dart';
import 'objectbox/objectbox_store.dart';

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  FlutterNativeSplash.preserve(widgetsBinding: binding);
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  // SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
  //   statusBarColor: Colors.transparent,
  //   statusBarIconBrightness: Brightness.dark,
  //   systemNavigationBarColor: Colors.white,
  //   systemNavigationBarIconBrightness: Brightness.dark,
  // ));
  // Run independent init tasks in parallel to reduce cold-start time.
  // initDependencies() needs ObjectBox, so it runs after the parallel phase.
  MediaNotificationService.init(); // register channel handler synchronously before runApp
  await Future.wait([
    initObjectboxStore(),
    NotificationService.init(),
    BackgroundService.init().then((_) {
      BackgroundService.scheduleDailyReschedule();
      BackgroundService.scheduleWidgetRefresh();
    }),
    WidgetService.init(),
  ]);
  await initDependencies();
  unawaited(RemindersService.migrateToNativeDhikr());
  unawaited(WidgetService.updateTodayAyah());

  runApp(const QuranApp());
}

class QuranApp extends StatelessWidget {
  const QuranApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<ThemeCubit>()),
        BlocProvider(create: (_) => sl<FontScaleCubit>()),
        BlocProvider(create: (_) => sl<QuranAppearanceCubit>()),
        // App-wide singleton so background playback + the media notification
        // survive navigation (e.g. leaving the Quran page for another tab).
        BlocProvider(create: (_) => sl<QuranAudioCubit>()..loadReciters()),
      ],
      child: const _AppView(),
    );
  }
}

class _AppView extends StatelessWidget {
  const _AppView();

  @override
  Widget build(BuildContext context) {
    final themeMode = context.select<ThemeCubit, ThemeMode>(
      (c) => c.state.mode,
    );
    final fontScale = context.select<FontScaleCubit, double>(
      (c) => c.state.scale,
    );

    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            WidgetsBinding.instance.platformDispatcher.platformBrightness ==
                Brightness.dark);

    final overlayStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor:
          isDark ? const Color(0xFF0D1B0C) : const Color(0xFFF5F1E8),
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    );

    // AnnotatedRegion is more reliable than the imperative call on OEM devices
    // (MIUI, One UI, etc.) — it re-applies the style on every rebuild.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: ScreenUtilInit(
      // Design size مبنية على شاشة iPhone 14 (390×844)
      designSize: const Size(390, 844),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) => MaterialApp(
        title: 'داليا للقرآن الكريم و إتجاه القبلة و مواقيت الصلاة',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: themeMode,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl,
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(fontScale),
            ),
            child: child!,
          ),
        ),
        home: const SplashPage(),
      ),
    ),
    );
  }
}
