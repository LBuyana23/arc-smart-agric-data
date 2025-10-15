import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import '../theme/app_theme.dart';
import '../models/sensor_data.dart';

class IrrigationPage extends StatefulWidget {
  const IrrigationPage({super.key});

  @override
  State<IrrigationPage> createState() => _IrrigationPageState();
}

class _IrrigationPageState extends State<IrrigationPage> {
  String _selectedTimeRange = '24h';

  List<TimeSeriesData> _generateTimeSeriesData(String range) {
    final now = DateTime.now();
    int points;
    Duration interval;

    switch (range) {
      case '1h':
        points = 60;
        interval = Duration(minutes: 1);
        break;
      case '7d':
        points = 168;
        interval = Duration(hours: 1);
        break;
      case '30d':
        points = 30;
        interval = Duration(days: 1);
        break;
      default:
        points = 24;
        interval = Duration(hours: 1);
    }

    return List.generate(points, (i) {
      final time = now.subtract(interval * (points - i));
      final value = 40 + Random().nextDouble() * 20 + sin(i / 5) * 5;
      return TimeSeriesData(timestamp: time, value: value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = IrrigationSnapshot(
      waterFlow: 45.3,
      delta: 2.1,
      timestamp: DateTime.now(),
    );

    final timeSeriesData = _generateTimeSeriesData(_selectedTimeRange);

    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Irrigation',
                    style: TextStyle(
                      color: AppTheme.foreground,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Water flow monitoring and analysis',
                    style: TextStyle(
                      color: AppTheme.mutedForeground,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('CSV export feature - Coming soon'),
                      backgroundColor: AppTheme.primaryGreen,
                    ),
                  );
                },
                icon: Icon(Icons.download),
                label: Text('Export CSV'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: AppTheme.darkBackground,
                ),
              ),
            ],
          ),
          SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 1000) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 1, child: _buildLatestSnapshot(snapshot)),
                    SizedBox(width: 16),
                    Expanded(flex: 2, child: _buildTimeSeriesChart(timeSeriesData)),
                  ],
                );
              } else {
                return Column(
                  children: [
                    _buildLatestSnapshot(snapshot),
                    SizedBox(height: 16),
                    _buildTimeSeriesChart(timeSeriesData),
                  ],
                );
              }
            },
          ),
          SizedBox(height: 24),
          _buildRawDataTable(),
        ],
      ),
    );
  }

  Widget _buildLatestSnapshot(IrrigationSnapshot snapshot) {
    final isDeltaPositive = snapshot.delta > 0;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Latest Snapshot',
              style: TextStyle(
                color: AppTheme.foreground,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  snapshot.waterFlow.toStringAsFixed(1),
                  style: TextStyle(
                    color: AppTheme.foreground,
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(width: 8),
                Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'L/min',
                    style: TextStyle(
                      color: AppTheme.mutedForeground,
                      fontSize: 20,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDeltaPositive
                    ? AppTheme.primaryGreen.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isDeltaPositive
                      ? AppTheme.primaryGreen.withOpacity(0.3)
                      : Colors.red.withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isDeltaPositive ? Icons.arrow_upward : Icons.arrow_downward,
                    color: isDeltaPositive ? AppTheme.primaryGreen : Colors.red,
                    size: 16,
                  ),
                  SizedBox(width: 4),
                  Text(
                    '${snapshot.delta.abs().toStringAsFixed(1)} L/min',
                    style: TextStyle(
                      color: isDeltaPositive ? AppTheme.primaryGreen : Colors.red,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Last updated: ${DateFormat('HH:mm:ss').format(snapshot.timestamp)}',
              style: TextStyle(
                color: AppTheme.mutedForeground,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSeriesChart(List<TimeSeriesData> data) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Time-Series Analysis',
                  style: TextStyle(
                    color: AppTheme.foreground,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Row(
                  children: ['1h', '24h', '7d', '30d'].map((range) {
                    final isSelected = _selectedTimeRange == range;
                    return Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _selectedTimeRange = range;
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          backgroundColor: isSelected
                              ? AppTheme.primaryGreen.withOpacity(0.1)
                              : Colors.transparent,
                          foregroundColor:
                              isSelected ? AppTheme.primaryGreen : AppTheme.mutedForeground,
                          side: BorderSide(
                            color: isSelected ? AppTheme.primaryGreen : AppTheme.border,
                          ),
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        child: Text(range),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            SizedBox(height: 24),
            Container(
              height: 300,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 10,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: AppTheme.border,
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: TextStyle(
                              color: AppTheme.mutedForeground,
                              fontSize: 12,
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: AppTheme.border),
                  ),
                  minX: 0,
                  maxX: (data.length - 1).toDouble(),
                  minY: 30,
                  maxY: 70,
                  lineBarsData: [
                    LineChartBarData(
                      spots: data
                          .asMap()
                          .entries
                          .map((e) => FlSpot(e.key.toDouble(), e.value.value))
                          .toList(),
                      isCurved: true,
                      color: AppTheme.primaryGreen,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryGreen.withOpacity(0.2),
                            AppTheme.primaryGreen.withOpacity(0.0),
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

  Widget _buildRawDataTable() {
    final mockData = List.generate(5, (i) {
      return {
        'timestamp': DateFormat('yyyy-MM-dd HH:mm:ss')
            .format(DateTime.now().subtract(Duration(minutes: i * 15))),
        'water_flow': (45 + Random().nextDouble() * 10).toStringAsFixed(2),
        'pressure': (3.2 + Random().nextDouble() * 0.5).toStringAsFixed(2),
        'valve_status': i % 2 == 0 ? 'OPEN' : 'CLOSED',
      };
    });

    return Card(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Raw Data Table',
              style: TextStyle(
                color: AppTheme.foreground,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: MaterialStateProperty.all(
                  AppTheme.darkBackground,
                ),
                columns: [
                  DataColumn(
                    label: Text(
                      'Timestamp',
                      style: TextStyle(
                        color: AppTheme.foreground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Water Flow (L/min)',
                      style: TextStyle(
                        color: AppTheme.foreground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Pressure (bar)',
                      style: TextStyle(
                        color: AppTheme.foreground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Valve Status',
                      style: TextStyle(
                        color: AppTheme.foreground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                rows: mockData.map((row) {
                  return DataRow(
                    cells: [
                      DataCell(Text(
                        row['timestamp']!,
                        style: TextStyle(color: AppTheme.mutedForeground, fontSize: 12),
                      )),
                      DataCell(Text(
                        row['water_flow']!,
                        style: TextStyle(color: AppTheme.foreground),
                      )),
                      DataCell(Text(
                        row['pressure']!,
                        style: TextStyle(color: AppTheme.foreground),
                      )),
                      DataCell(
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: row['valve_status'] == 'OPEN'
                                ? AppTheme.primaryGreen.withOpacity(0.1)
                                : Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            row['valve_status']!,
                            style: TextStyle(
                              color: row['valve_status'] == 'OPEN'
                                  ? AppTheme.primaryGreen
                                  : Colors.orange,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
