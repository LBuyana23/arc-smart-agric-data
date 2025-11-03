import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final ApiService _api = ApiService();
  bool _autoRefresh = true;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Settings', style: TextStyle(color: AppTheme.foreground, fontSize: 32, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text('Platform and runtime options', style: TextStyle(color: AppTheme.mutedForeground)),
          SizedBox(height: 20),

          // A simplified, user-focused settings UI. Technical debug links removed.
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Data & Cache', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  SizedBox(height: 8),
                  Text('Manage local stored data and cached snapshots.', style: TextStyle(color: AppTheme.mutedForeground)),
                  SizedBox(height: 12),
                  Wrap(spacing: 8, children: [
                    ElevatedButton.icon(
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          // Clear common Hive boxes used for cached data
                          try {
                            await Hive.box('greenhouse_data').clear();
                          } catch (_) {}
                          try {
                            await Hive.box('irrigation_data').clear();
                          } catch (_) {}
                          try {
                            await Hive.box('soil_data').clear();
                          } catch (_) {}
                          try {
                            await Hive.box('crop_vision_data').clear();
                          } catch (_) {}
                          try {
                            await Hive.box('historical_data').clear();
                          } catch (_) {}
                          messenger.showSnackBar(SnackBar(content: Text('Local cache cleared'), backgroundColor: AppTheme.primaryGreen));
                        } catch (e) {
                          messenger.showSnackBar(SnackBar(content: Text('Failed to clear cache: $e')));
                        }
                      },
                      icon: Icon(Icons.delete_outline),
                      label: Text('Clear local cache'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
                    ),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          await _api.refreshCropVision();
                          await _api.refreshGreenhouse();
                          await _api.refreshIrrigation();
                          await _api.refreshSoil();
                          messenger.showSnackBar(SnackBar(content: Text('Refresh requested'), backgroundColor: AppTheme.primaryGreen));
                        } catch (e) {
                          messenger.showSnackBar(SnackBar(content: Text('Refresh failed: $e')));
                        }
                      },
                      icon: Icon(Icons.refresh),
                      label: Text('Refresh now'),
                    ),
                  ])
                ],
              ),
            ),
          ),

          SizedBox(height: 16),

          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Preferences', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Expanded(child: Text('Auto refresh (UI hint)')),
                    Switch(value: _autoRefresh, onChanged: (v) => setState(() => _autoRefresh = v)),
                  ]),
                  SizedBox(height: 8),
                  Text('Auto refresh controls whether the UI will automatically request fresh data in the background. Network and polling behavior is governed by the app and backend settings.', style: TextStyle(color: AppTheme.mutedForeground)),
                ],
              ),
            ),
          ),

          SizedBox(height: 16),

          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('About', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  SizedBox(height: 8),
                  Text('Smart Farm Data Platform'),
                  SizedBox(height: 6),
                  Text('This app shows recent sensor telemetry and insights. For support or deployment instructions see project documentation.', style: TextStyle(color: AppTheme.mutedForeground)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
