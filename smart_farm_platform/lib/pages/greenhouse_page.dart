// 'dart:convert' removed: raw-rows debug helper removed from final UI
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
// import 'dart:math'; // removed unused import
import '../services/api_service.dart';
// greenhouse_data model import removed (not used by FutureBuilder UI)
import '../theme/app_theme.dart';
import '../widgets/paginated_history.dart';
import '../widgets/no_data_placeholder.dart';
import '../utils/ui_helpers.dart';
import '../utils/csv_export.dart';

class GreenhousePage extends StatefulWidget {
  const GreenhousePage({super.key});

  @override
  State<GreenhousePage> createState() => _GreenhousePageState();
}

class _GreenhousePageState extends State<GreenhousePage> with AutomaticKeepAliveClientMixin {
  late final ApiService api = ApiService();
  // removed unused _expandedTables field
  // Time window selection: '1h', '24h', '7d'
  String _selectedWindow = '1h';

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('Greenhouse', style: TextStyle(color: AppTheme.foreground, fontSize: 32, fontWeight: FontWeight.bold)),
            SizedBox(width: 8),
            _buildStatusChip(api.getSource('greenhouse'))
          ]),
          SizedBox(height: 8),
          Text('Environmental sensors and gas monitoring', style: TextStyle(color: AppTheme.mutedForeground)),
          SizedBox(height: 16),
          
          // Render a section per greenhouse subgroup returned by the bridge.
          FutureBuilder<Map<String, dynamic>?>(
            future: api.fetchAllGroupRaw('greenhouse'),
            builder: (context, snap) {
              if (!snap.hasData) return NoDataPlaceholder(onRetry: () async { try { await api.refreshGreenhouse(); } catch (_) {} });
              final map = snap.data!;
              if (map.isEmpty) return NoDataPlaceholder(onRetry: () async { try { await api.refreshGreenhouse(); } catch (_) {} });
              return Column(
                children: map.entries.map((entry) {
                  final src = entry.key;

                  return Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                                // Top row: heading and time-window selector + export
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(child: Builder(builder: (context) {
                                      // Determine a friendly group id for the heading; keep a raw displayId for dialogs.
                                      String displayId = src.toString();
                                      Map<String, dynamic>? payloadMap;
                                      try {
                                        if (entry.value is Map<String, dynamic>) {
                                          payloadMap = Map<String, dynamic>.from(entry.value as Map);
                                          final gidRaw = payloadMap['GROUP_ID'] ?? payloadMap['group_id'] ?? payloadMap['GROUP'] ?? payloadMap['group'] ?? payloadMap['Group'] ?? payloadMap['GroupId'];
                                          displayId = gidRaw?.toString() ?? displayId;
                                        }
                                      } catch (_) {}
                                      // fallback: try to extract digits from the source key
                                      if (displayId.isEmpty) {
                                        final m = RegExp(r"\d+").firstMatch(src.toString());
                                        if (m != null) { displayId = m.group(0)!; }
                                      }
                                      // user-specific mapping: map known iot-style name to group 9
                                      final sl = displayId.toLowerCase();
                                      if (sl.contains('iot') || sl.contains('greenhouse_iot') || sl.contains('greenhouseiot')) { displayId = '9'; }

                                      return Row(
                                        mainAxisAlignment: MainAxisAlignment.start,
                                        children: [
                                          Text(UiHelpers.groupLabel('Greenhouse', src, payloadMap), style: TextStyle(color: AppTheme.foreground, fontSize: 18, fontWeight: FontWeight.w700)),
                                          SizedBox(width: 12),
                                          Chip(label: Text('Group ' + displayId, style: TextStyle(fontSize: 12)), backgroundColor: Colors.black12),
                                        ],
                                      );
                                    })),
                                    // Time window selector + export button
                                    Row(children: [
                                      DropdownButton<String>(
                                        value: _selectedWindow,
                                        items: const [
                                          DropdownMenuItem(value: '1h', child: Text('Last Hour')),
                                          DropdownMenuItem(value: '24h', child: Text('Last 24 Hours')),
                                          DropdownMenuItem(value: '7d', child: Text('Last 7 Days')),
                                        ],
                                        onChanged: (v) {
                                          if (v == null) { return; }
                                          setState(() { _selectedWindow = v; });
                                        },
                                      ),
                                      SizedBox(width: 8),
                                      ElevatedButton.icon(
                                        onPressed: () async {
                                          await exportGroupToCsv(context, 'greenhouse', api);
                                        },
                                        icon: Icon(Icons.download),
                                        label: Text('Export CSV'),
                                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen, foregroundColor: AppTheme.darkBackground),
                                      ),
                                    ])
                                  ],
                                ),
                                SizedBox(height: 8),
                        SizedBox(height: 8),
                        // Restore: Table for greenhouse group
                        PaginatedHistory(
                          group: 'greenhouse',
                          source: src,
                          limit: 10,
                          fetcher: (offset, limit) => api.fetchGroupHistory('greenhouse', src.toString(), limit: limit, offset: offset, duration: _selectedWindow),
                          builder: (context, rows, page, changePage) {
                            if (rows.isEmpty) return Text('No history available');
                            final columns = rows.isNotEmpty ? rows.first.keys.toList() : <dynamic>[];
                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                columns: columns.map((c) => DataColumn(label: Text(c.toString(), style: TextStyle(fontWeight: FontWeight.bold)))).toList(),
                                rows: rows.map((row) => DataRow(
                                  cells: columns.map((c) => DataCell(Text(row[c]?.toString() ?? ''))).toList(),
                                )).toList(),
                              ),
                            );
                          },
                        ),
                        SizedBox(height: 8),
                        // Restore: Compact chart for greenhouse group
                        PaginatedHistory(
                          group: 'greenhouse',
                          source: src,
                          limit: 200,
                          fetcher: (offset, limit) => api.fetchGroupHistory('greenhouse', src.toString(), limit: limit, offset: offset, duration: _selectedWindow),
                          builder: (context, rows, page, changePage) {
                            if (rows.isEmpty) return Text('No history available');

                            // Work on a copy and sort ascending by timestamp for charts
                            final list = List<Map<String, dynamic>>.from(rows);
                            list.sort((a, b) {
                              final ta = UiHelpers.parseTimestamp(a['TIMESTAMP_READING'] ?? a['timestamp_reading'] ?? a['Timestamp'] ?? a['timestamp'] ?? a['CREATED_AT'] ?? a['created_at'] ?? a['T']);
                              final tb = UiHelpers.parseTimestamp(b['TIMESTAMP_READING'] ?? b['timestamp_reading'] ?? b['Timestamp'] ?? b['timestamp'] ?? b['CREATED_AT'] ?? b['created_at'] ?? b['T']);
                              if (ta == null && tb == null) return 0;
                              if (ta == null) return 1;
                              if (tb == null) return -1;
                              return ta.compareTo(tb);
                            });

                            // Helper to resolve actual key present in rows for a list of candidates
                            String? resolveKey(List<String> candidates) {
                              if (list.isEmpty) return null;
                              final present = <String>{};
                              for (final r in list) for (final k in r.keys) present.add(k.toString());
                              for (final c in candidates) {
                                for (final k in present) if (k.toLowerCase() == c.toLowerCase()) return k;
                              }
                              for (final c in candidates) {
                                for (final k in present) if (k.toLowerCase().contains(c.toLowerCase())) return k;
                              }
                              return null;
                            }

                            // Build a series for given candidate keys. Returns spots and base millis.
                            Map<String, dynamic> buildSeries(List<String> candidates) {
                              final actual = resolveKey(candidates);
                              if (actual == null) return {'spots': <FlSpot>[], 'base': 0};
                              final times = <int>[];
                              final values = <double>[];
                              for (final r in list) {
                                final vRaw = r[actual];
                                if (vRaw == null) continue;
                                final v = vRaw is num ? vRaw.toDouble() : double.tryParse(vRaw.toString().replaceAll(RegExp(r"[^0-9.\-]"), ''));
                                if (v == null) continue;
                                final dt = UiHelpers.parseTimestamp(r['TIMESTAMP_READING'] ?? r['timestamp_reading'] ?? r['Timestamp'] ?? r['timestamp'] ?? r['CREATED_AT'] ?? r['created_at'] ?? r['T']);
                                if (dt != null) times.add(dt.toUtc().millisecondsSinceEpoch);
                                else times.add(-1);
                                values.add(v);
                              }
                              if (values.isEmpty) return {'spots': <FlSpot>[], 'base': 0};

                              final hasTs = times.any((t) => t > 0);
                              final spots = <FlSpot>[];
                              if (hasTs) {
                                final valid = times.where((t) => t > 0).toList()..sort();
                                final base = valid.first;
                                int nextIndex = 0;
                                for (var i = 0; i < times.length; i++) {
                                  final t = times[i];
                                  final v = values[i];
                                  if (t > 0) {
                                    spots.add(FlSpot((t - base) / 1000.0, v));
                                  } else {
                                    spots.add(FlSpot((valid.last - base) / 1000.0 + (++nextIndex).toDouble(), v));
                                  }
                                }
                                spots.sort((a, b) => a.x.compareTo(b.x));
                                return {'spots': spots, 'base': valid.first};
                              }

                              // no timestamps, use indices
                              for (var i = 0; i < values.length; i++) spots.add(FlSpot(i.toDouble(), values[i]));
                              return {'spots': spots, 'base': 0};
                            }

                            final tempSeries = buildSeries(['TEMPERATURE', 'temperature', 'temp', 'temperature_c']);
                            final co2Series = buildSeries(['CO2', 'co2', 'co_2', 'co2_ppm', 'co₂']);

                            Widget buildLineCard(String title, List<FlSpot> spots, Color color, int baseMillis) {
                              if (spots.isEmpty) return SizedBox(height: 140, child: Card(child: Center(child: Text('n/a', style: TextStyle(color: AppTheme.mutedForeground)))));
                              double minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
                              double maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
                              if (minY == maxY) {
                                minY = minY - 1.0;
                                maxY = maxY + 1.0;
                              }
                              final padding = (maxY - minY) * 0.12;
                              minY = minY - padding;
                              maxY = maxY + padding;

                              double interval = ((maxY - minY) / 4).abs();

                              return SizedBox(
                                height: 160,
                                child: Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: LineChart(
                                      LineChartData(
                                        gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: Colors.white12, strokeWidth: 1)),
                                        titlesData: FlTitlesData(
                                          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: interval, reservedSize: 40, getTitlesWidget: (value, meta) => Text(value.toStringAsFixed(1), style: TextStyle(color: AppTheme.mutedForeground, fontSize: 10)))),
                                          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36, getTitlesWidget: (value, meta) {
                                            if (baseMillis == 0) return Text(value.toStringAsFixed(0), style: TextStyle(color: AppTheme.mutedForeground, fontSize: 10));
                                            final ms = baseMillis + (value * 1000).toInt();
                                            final dt = DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
                                            return Text('${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}', style: TextStyle(color: AppTheme.mutedForeground, fontSize: 10));
                                          })),
                                          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                        ),
                                        minY: minY,
                                        maxY: maxY,
                                        minX: spots.first.x,
                                        maxX: spots.last.x,
                                        lineBarsData: [LineChartBarData(spots: spots, isCurved: true, color: color, dotData: FlDotData(show: false), barWidth: 2)],
                                        lineTouchData: LineTouchData(enabled: true, touchTooltipData: LineTouchTooltipData(getTooltipItems: (items) => items.map((it) => LineTooltipItem(it.y.toStringAsFixed(2), TextStyle(color: Colors.white))).toList())),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Charts', style: TextStyle(color: AppTheme.foreground, fontWeight: FontWeight.bold)),
                                SizedBox(height: 8),
                                buildLineCard('Temperature', List<FlSpot>.from(tempSeries['spots'] as List<FlSpot>), AppTheme.primaryGreen, tempSeries['base'] as int),
                                SizedBox(height: 8),
                                buildLineCard('CO₂', List<FlSpot>.from(co2Series['spots'] as List<FlSpot>), Colors.tealAccent, co2Series['base'] as int),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // Ensure _buildStatusChip is defined in _GreenhousePageState
  Widget _buildStatusChip(String? source) {
    if (source == null) return SizedBox.shrink();
    if (source == 'live') {
      return Chip(label: Text('LIVE', style: TextStyle(fontSize: 12, color: Colors.white)), backgroundColor: Colors.green);
    }
    if (source == 'offline' || source == 'cache' || source == 'stale_cache') {
      return Chip(label: Text('OFFLINE — showing cached results', style: TextStyle(fontSize: 12)), backgroundColor: Colors.orange.shade200);
    }
    return Chip(label: Text(source, style: TextStyle(fontSize: 12)), backgroundColor: Colors.black12);
  }

  // chart title helpers removed (not used)

  @override
  bool get wantKeepAlive => true;
}
