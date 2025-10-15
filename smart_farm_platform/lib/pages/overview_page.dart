import 'package:flutter/material.dart';
import 'dart:math';
import '../models/sensor_data.dart';
import '../theme/app_theme.dart';
import '../widgets/live_data_timeline.dart';
import '../widgets/sensor_card.dart';
import '../widgets/ai_insight_card.dart';
import '../widgets/weather_overview.dart';

class OverviewPage extends StatelessWidget {
  const OverviewPage({super.key});

  List<SensorData> get _sensors => [
        SensorData(
          name: 'Air Temperature',
          value: 24.5,
          unit: '°C',
          threshold: 30.0,
          icon: Icons.thermostat,
        ),
        SensorData(
          name: 'Soil Moisture',
          value: 68.2,
          unit: '%',
          threshold: 70.0,
          icon: Icons.water_drop,
        ),
        SensorData(
          name: 'pH Level',
          value: 6.8,
          unit: 'pH',
          threshold: 7.5,
          icon: Icons.science,
        ),
        SensorData(
          name: 'Water Flow',
          value: 45.3,
          unit: 'L/min',
          threshold: 50.0,
          icon: Icons.waves,
        ),
      ];

  @override
  Widget build(BuildContext context) {
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
          LayoutBuilder(
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
                children: _sensors.map((sensor) => SensorCard(sensor: sensor)).toList(),
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
