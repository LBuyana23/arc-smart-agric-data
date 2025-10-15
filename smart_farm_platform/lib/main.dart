import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'providers/app_state.dart';
import 'widgets/main_sidebar.dart';
import 'pages/overview_page.dart';
import 'pages/irrigation_page.dart';
import 'pages/placeholder_page.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
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
    final currentPage = context.watch<AppState>().currentPage;

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      body: Row(
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
    );
  }

  Widget _buildPage(String page) {
    switch (page) {
      case 'Overview':
        return OverviewPage(key: ValueKey('overview'));
      case 'Irrigation':
        return IrrigationPage(key: ValueKey('irrigation'));
      case 'Soil':
        return PlaceholderPage(
          key: ValueKey('soil'),
          title: 'Soil Analysis',
          description: 'Monitor soil composition, nutrients, and health metrics',
          icon: Icons.terrain,
        );
      case 'Crop Vision':
        return PlaceholderPage(
          key: ValueKey('crop'),
          title: 'Crop Vision',
          description: 'AI-powered crop health monitoring and analysis',
          icon: Icons.grass,
        );
      case 'Climate':
        return PlaceholderPage(
          key: ValueKey('climate'),
          title: 'Climate Data',
          description: 'Comprehensive weather and climate monitoring',
          icon: Icons.wb_sunny,
        );
      case 'Data Catalog':
        return PlaceholderPage(
          key: ValueKey('catalog'),
          title: 'Data Catalog',
          description: 'Browse and manage your farm data sources',
          icon: Icons.storage,
        );
      case 'API & Integrations':
        return PlaceholderPage(
          key: ValueKey('api'),
          title: 'API & Integrations',
          description: 'Connect external tools and manage API access',
          icon: Icons.api,
        );
      default:
        return OverviewPage(key: ValueKey('overview'));
    }
  }
}
