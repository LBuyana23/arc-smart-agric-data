import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ApiIntegrationsPage extends StatefulWidget {
  const ApiIntegrationsPage({super.key});

  @override
  State<ApiIntegrationsPage> createState() => _ApiIntegrationsPageState();
}

class _ApiIntegrationsPageState extends State<ApiIntegrationsPage> {
  // Integration status not implemented; implement a /status endpoint on the bridge

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('API & Integrations', style: TextStyle(color: AppTheme.foreground, fontSize: 32, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text('External connections and integration health', style: TextStyle(color: AppTheme.mutedForeground)),
          SizedBox(height: 24),

          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('MQTT Broker', style: TextStyle(color: AppTheme.foreground, fontSize: 18, fontWeight: FontWeight.w600)),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.info, color: AppTheme.mutedForeground),
                      SizedBox(width: 12),
                      Expanded(child: Text('Integration status not available. Implement a /status endpoint on the bridge to show real connection health.', style: TextStyle(color: AppTheme.mutedForeground))),
                    ],
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(onPressed: null, style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen), child: Text('Reconnect')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
