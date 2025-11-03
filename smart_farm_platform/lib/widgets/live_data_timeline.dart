import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';

class LiveDataTimeline extends StatelessWidget {
  const LiveDataTimeline({super.key});

  @override
  Widget build(BuildContext context) {
    final liveData = context.watch<AppState>().liveData;

    return Card(
      child: Container(
        height: 120,
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.primaryGreen,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryGreen.withAlpha((0.5 * 255).round()),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'LIVE DATA FEED',
                  style: TextStyle(
                    color: AppTheme.primaryGreen,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  '(Last 60s)',
                  style: TextStyle(
                    color: AppTheme.mutedForeground,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Expanded(
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: false),
                  titlesData: FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: (liveData.length - 1).toDouble(),
                  minY: 15,
                  maxY: 35,
                  lineBarsData: [
                    LineChartBarData(
                      spots: liveData
                          .asMap()
                          .entries
                          .map((e) => FlSpot(e.key.toDouble(), e.value))
                          .toList(),
                      isCurved: true,
                      color: AppTheme.primaryGreen,
                      barWidth: 2,
                      isStrokeCapRound: true,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryGreen.withAlpha((0.3 * 255).round()),
                            AppTheme.primaryGreen.withAlpha((0.0 * 255).round()),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
