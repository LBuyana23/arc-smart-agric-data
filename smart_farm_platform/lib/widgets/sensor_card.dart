import 'package:flutter/material.dart';
import '../models/sensor_data.dart';
import '../theme/app_theme.dart';

class SensorCard extends StatelessWidget {
  final SensorData sensor;

  const SensorCard({super.key, required this.sensor});

  @override
  Widget build(BuildContext context) {
    final isOverThreshold = sensor.value > sensor.threshold;
    final progress = (sensor.value / sensor.threshold).clamp(0.0, 1.0);

    return Card(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(sensor.icon, color: AppTheme.primaryGreen, size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    sensor.name,
                    style: TextStyle(
                      color: AppTheme.mutedForeground,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  sensor.value.toStringAsFixed(1),
                  style: TextStyle(
                    color: isOverThreshold ? Colors.red : AppTheme.foreground,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(width: 8),
                Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    sensor.unit,
                    style: TextStyle(
                      color: AppTheme.mutedForeground,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppTheme.border,
                    valueColor: AlwaysStoppedAnimation(
                      isOverThreshold ? Colors.red : AppTheme.primaryGreen,
                    ),
                    minHeight: 8,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Threshold: ${sensor.threshold.toStringAsFixed(1)} ${sensor.unit}',
                  style: TextStyle(
                    color: AppTheme.mutedForeground,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
