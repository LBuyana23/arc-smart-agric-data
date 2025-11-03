import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'providers/app_state.dart';
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
  // Historical payloads (full /api/all snapshots)
  await Hive.openBox('historical_data');

  // Disable the built-in simulation timers when running against the live
  // backend so the UI does not rebuild every second and cause excessive
  // network requests. Pass startSimulations=false to keep the app responsive
  // and rely on the real ApiService polling/cache behavior.
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(startSimulations: false),
      child: const SmartFarmApp(),
    ),
  );
}

class SmartFarmApp extends StatelessWidget {
  const SmartFarmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Farm Data Platform',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: const MainLayout(),
    );
  }
}

class MainLayout extends StatelessWidget {
  const MainLayout({super.key});

  @override
  Widget build(BuildContext context) {
  final appState = context.watch<AppState>();
  final currentPage = appState.currentPage;

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      body: Stack(
        children: [
          Row(
            children: [
              MainSidebar(),
              Expanded(
                child: AnimatedSwitcher(
                  duration: Duration(milliseconds: 300),
                  switchInCurve: Curves.easeInOut,
                  switchOutCurve: Curves.easeInOut,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: child,
                    );
                  },
                  child: _buildPage(currentPage),
                ),
              ),
            ],
          ),
          // When the sidebar is collapsed the footer chevron may be off-screen
          // on small devices or clipped by layout; show a small persistent
          // toggle handle on the left edge so the user can always reopen it.
          Builder(builder: (ctx) {
            final collapsed = context.watch<AppState>().isSidebarCollapsed;
            if (!collapsed) return SizedBox.shrink();
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
                    child: Icon(Icons.chevron_right, color: AppTheme.foreground),
                  ),
                ),
              ),
            );
          }),
          // The footer chevron in the sidebar is the single control for
          // opening and closing the sidebar. The previous overlay menu
          // handle was removed to avoid duplicate toggles and stray UI.
        ],
      ),
    );
  }

  Widget _buildPage(String page) {
    switch (page) {
      case 'Overview':
        return OverviewPage(key: ValueKey('overview'));
      case 'Irrigation':
        return IrrigationPage(key: ValueKey('irrigation'));
      case 'Soil':
        return SoilPage(key: ValueKey('soil'));
      case 'Crop Vision':
        return CropVisionPage(key: ValueKey('crop'));
      case 'Greenhouse':
        return GreenhousePage(key: ValueKey('greenhouse'));
      // Data Catalog and API & Integrations pages removed
      case 'Settings':
        return SettingsPage(key: ValueKey('settings'));
      default:
        return OverviewPage(key: ValueKey('overview'));
    }
  }
}
