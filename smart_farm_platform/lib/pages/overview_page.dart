import 'package:flutter/material.dart';
import '../models/sensor_data.dart';
import '../models/greenhouse_data.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/live_data_timeline.dart';
import '../widgets/sensor_card.dart';
import '../widgets/ai_insight_card.dart';
import '../widgets/weather_overview.dart';

class OverviewPage extends StatelessWidget {
  final ApiService? api;

  const OverviewPage({super.key, this.api});

  @override
  Widget build(BuildContext context) {
  final apiClient = api ?? ApiService();

    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dashboard Overview',
            style: TextStyle(
              color: AppTheme.foreground,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'Real-time monitoring and insights',
            style: TextStyle(
              color: AppTheme.mutedForeground,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 24),
          LiveDataTimeline(),
          SizedBox(height: 24),

          // Fetch greenhouse data and populate sensor cards
          FutureBuilder<GreenhouseData>(
            future: apiClient.fetchLatestGreenhouseData(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('Error loading greenhouse data: ${snapshot.error}'),
                );
              }

              final greenhouse = snapshot.data!;

              final sensors = [
                SensorData(
                  name: 'Air Temperature',
                  value: greenhouse.temperature,
                  unit: '°C',
                  threshold: 30.0,
                  icon: Icons.thermostat,
                ),
                SensorData(
                  name: 'Humidity',
                  value: greenhouse.humidity,
                  unit: '%',
                  threshold: 70.0,
                  icon: Icons.water_drop,
                ),
                SensorData(
                  name: 'Pressure',
                  value: greenhouse.pressure,
                  unit: 'hPa',
                  threshold: 110.0,
                  icon: Icons.speed,
                ),
                SensorData(
                  name: 'CO2',
                  value: greenhouse.co2 ?? 0,
                  unit: 'ppm',
                  threshold: 1000.0,
                  icon: Icons.cloud,
                ),
              ];

              return LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = constraints.maxWidth > 1200
                      ? 4
                      : constraints.maxWidth > 800
                          ? 2
                          : 1;
                  return GridView.count(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.2,
                    children: sensors.map((sensor) => SensorCard(sensor: sensor)).toList(),
                  );
                },
              );
            },
          ),

          SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 800) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: AIInsightCard()),
                    SizedBox(width: 16),
                    Expanded(child: WeatherOverview()),
                  ],
                );
              } else {
                return Column(
                  children: [
                    AIInsightCard(),
                    SizedBox(height: 16),
                    WeatherOverview(),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
