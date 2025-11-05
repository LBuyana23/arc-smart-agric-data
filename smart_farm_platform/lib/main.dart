import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'providers/app_state.dart';
import 'services/api_service.dart';
import 'services/insights_service.dart';
import 'services/weather_service.dart';
import 'widgets/main_sidebar.dart';
import 'pages/overview_page.dart';
import 'pages/irrigation_page.dart';
// import 'pages/placeholder_page.dart';
import 'pages/soil_page.dart';
import 'pages/crop_vision_page.dart';
import 'pages/greenhouse_page.dart';
// Data Catalog and API Integrations pages removed per user request
import 'pages/settings_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Hive and open boxes for each endpoint before the app starts
  await Hive.initFlutter();
  await Hive.openBox('greenhouse_data');
  await Hive.openBox('soil_data');
  await Hive.openBox('crop_vision_data');
  await Hive.openBox('irrigation_data');
  // Persisted history lists used by ApiService
  await Hive.openBox('history_cache');
  // Historical payloads (full /api/all snapshots)
  await Hive.openBox('historical_data');

  // Disable the built-in simulation timers when running against the live
  // backend so the UI does not rebuild every second and cause excessive
  // network requests. Pass startSimulations=false to keep the app responsive
  // and rely on the real ApiService polling/cache behavior.
  // Enable ApiService background polling for normal app runs. Tests will
  // not call enablePolling and therefore won't start ApiService timers.
  ApiService().enablePolling();
  unawaited(ApiService().warmupBackend());
  runApp(
    ChangeNotifierProvider(
      create: (_) {
        final appState = AppState(startSimulations: false);
        scheduleMicrotask(() {
          appState.startDataSyncWithServices(
            ApiService(),
            InsightsService(),
            WeatherService(),
          );
        });
        return appState;
      },
      child: const SmartFarmApp(),
    ),
  );
}

class SmartFarmApp extends StatelessWidget {
  const SmartFarmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Soil Sync',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: const MainLayout(),
    );
  }
}

class _NavDestination {
  final String page;
  final IconData icon;

  const _NavDestination(this.page, this.icon);
}

class MainLayout extends StatelessWidget {
  const MainLayout({super.key});

  static const List<_NavDestination> _primaryDestinations = [
    _NavDestination('Overview', Icons.dashboard),
    _NavDestination('Irrigation', Icons.water_drop),
    _NavDestination('Soil', Icons.terrain),
    _NavDestination('Crop Vision', Icons.grass),
    _NavDestination('Greenhouse', Icons.park),
  ];

  static const List<_NavDestination> _drawerOnlyDestinations = [
    _NavDestination('Settings', Icons.settings),
  ];

  bool _useMobileLayout(double width) => width < 900;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final currentPage = appState.currentPage;
    final width = MediaQuery.of(context).size.width;

    if (_useMobileLayout(width)) {
      return _buildMobileLayout(context, appState, currentPage);
    }

    return _buildDesktopLayout(context, appState, currentPage);
  }

  Widget _buildDesktopLayout(
    BuildContext context,
    AppState appState,
    String currentPage,
  ) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      body: Stack(
        children: [
          Row(
            children: [
              const MainSidebar(),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  switchInCurve: Curves.easeInOut,
                  switchOutCurve: Curves.easeInOut,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                  child: _buildPage(currentPage),
                ),
              ),
            ],
          ),
          Builder(
            builder: (ctx) {
              final collapsed = ctx.watch<AppState>().isSidebarCollapsed;
              if (!collapsed) return const SizedBox.shrink();
              final height = MediaQuery.of(ctx).size.height;
              return Positioned(
                left: 4,
                top: (height / 2) - 28,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => ctx.read<AppState>().toggleSidebar(),
                    child: Container(
                      width: 44,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppTheme.cardBackground.withAlpha(230),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Icon(
                        Icons.chevron_right,
                        color: AppTheme.foreground,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    AppState appState,
    String currentPage,
  ) {
    final navIndex = _primaryDestinations.indexWhere(
      (dest) => dest.page == currentPage,
    );
    final safeIndex = navIndex >= 0 ? navIndex : 0;

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: Text(currentPage),
        backgroundColor: AppTheme.cardBackground,
        foregroundColor: AppTheme.foreground,
        iconTheme: const IconThemeData(color: AppTheme.foreground),
        actions: [
          IconButton(
            icon: Icon(
              Icons.settings,
              color: currentPage == 'Settings'
                  ? AppTheme.primaryGreen
                  : AppTheme.mutedForeground,
            ),
            onPressed: () => appState.setCurrentPage('Settings'),
            tooltip: 'Settings',
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: AppTheme.cardBackground,
        child: SafeArea(
          child: _buildDrawerContent(context, appState, currentPage),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        switchInCurve: Curves.easeInOut,
        switchOutCurve: Curves.easeInOut,
        child: _buildPage(currentPage),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: safeIndex,
        onTap: (index) =>
            appState.setCurrentPage(_primaryDestinations[index].page),
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppTheme.cardBackground,
        selectedItemColor: AppTheme.primaryGreen,
        unselectedItemColor: AppTheme.mutedForeground,
        items: _primaryDestinations
            .map(
              (dest) => BottomNavigationBarItem(
                icon: Icon(dest.icon),
                label: dest.page,
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildDrawerContent(
    BuildContext context,
    AppState appState,
    String currentPage,
  ) {
    final destinations = <_NavDestination>[
      ..._primaryDestinations,
      ..._drawerOnlyDestinations,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.eco, color: AppTheme.primaryGreen, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      'Soil Sync',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.foreground,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Smart Farm Inc.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: destinations.length,
            itemBuilder: (ctx, index) {
              final dest = destinations[index];
              final isSelected = dest.page == currentPage;
              return ListTile(
                leading: Icon(
                  dest.icon,
                  color: isSelected
                      ? AppTheme.primaryGreen
                      : AppTheme.mutedForeground,
                ),
                title: Text(
                  dest.page,
                  style: TextStyle(
                    color: isSelected
                        ? AppTheme.primaryGreen
                        : AppTheme.foreground,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  appState.setCurrentPage(dest.page);
                },
              );
            },
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildPage(String page) {
    switch (page) {
      case 'Overview':
        return OverviewPage(key: const ValueKey('overview'));
      case 'Irrigation':
        return IrrigationPage(key: const ValueKey('irrigation'));
      case 'Soil':
        return SoilPage(key: const ValueKey('soil'));
      case 'Crop Vision':
        return CropVisionPage(key: const ValueKey('crop'));
      case 'Greenhouse':
        return GreenhousePage(key: const ValueKey('greenhouse'));
      // Data Catalog and API & Integrations pages removed
      case 'Settings':
        return SettingsPage(key: const ValueKey('settings'));
      default:
        return OverviewPage(key: const ValueKey('overview'));
    }
  }
}
