import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../core/di/injection_container.dart';
import '../core/services/media_notification_service.dart';
import '../core/theme/app_colors.dart';
import '../features/home/presentation/cubit/home_cubit.dart';
import '../features/home/presentation/pages/home_page.dart';
import '../features/home/presentation/pages/prayer_page.dart';
import '../features/quran/presentation/pages/surah_list_page.dart';
import '../features/quran/presentation/pages/mushaf_viewer_page.dart';
import '../features/qibla/presentation/pages/qibla_page.dart';
import '../features/settings/presentation/pages/settings_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;
  late final List<Widget> _pages;
  StreamSubscription<int>? _mediaOpenSub;

  @override
  void initState() {
    super.initState();
    _pages = [
      HomePage(onNavigateTo: _navigateTo),
      const QuranPage(),
      const PrayerPage(),
      const QiblaPage(),
      const SettingsPage(),
    ];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Handle cold-start: notification tapped before AppShell was mounted
      final pending = MediaNotificationService.pendingOpenSurahNum;
      if (pending != null && pending > 0 && mounted) {
        MediaNotificationService.pendingOpenSurahNum = null;
        _openQuranAtSurah(pending);
      }
      // Handle warm-start: notification tapped while app was in background
      _mediaOpenSub = MediaNotificationService.onOpen.listen((surahNum) {
        if (mounted) _openQuranAtSurah(surahNum);
      });
    });
  }

  void _openQuranAtSurah(int surahNum) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MushafViewerPage(surahId: surahNum)),
    );
  }

  @override
  void dispose() {
    _mediaOpenSub?.cancel();
    super.dispose();
  }

  void _navigateTo(int index) {
    if (index == 1) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const MushafViewerPage()),
      );
    } else {
      setState(() => _currentIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<HomeCubit>()..load(),
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: _pages,
        ),
        bottomNavigationBar: _BottomNav(
          currentIndex: _currentIndex,
          onTap: _navigateTo,
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onTap,
      backgroundColor: colors.card,
      height: 68.h.clamp(56.0, 80.0),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'الرئيسية',
        ),
        NavigationDestination(
          icon: Icon(Icons.menu_book_outlined),
          selectedIcon: Icon(Icons.menu_book),
          label: 'القرآن',
        ),
        NavigationDestination(
          icon: Icon(Icons.access_time_outlined),
          selectedIcon: Icon(Icons.access_time_filled),
          label: 'الصلاة',
        ),
        NavigationDestination(
          icon: Icon(Icons.explore_outlined),
          selectedIcon: Icon(Icons.explore),
          label: 'القبلة',
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: 'الإعدادات',
        ),
      ],
    );
  }
}
