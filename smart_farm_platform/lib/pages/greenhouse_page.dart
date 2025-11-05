// 'dart:convert' removed: raw-rows debug helper removed from final UI
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
// greenhouse_data model import removed (not used by FutureBuilder UI)
import '../theme/app_theme.dart';
import '../widgets/paginated_history.dart';
import '../widgets/no_data_placeholder.dart';
import '../utils/ui_helpers.dart';
import '../utils/csv_export.dart';

class _ChartDefinition {
  const _ChartDefinition({
    required this.title,
    required this.keys,
    required this.color,
    this.unit,
  });

  final String title;
  final List<String> keys;
  final Color color;
  final String? unit;
}

class _TimePoint {
  const _TimePoint(this.timestamp, this.value);

  final DateTime timestamp;
  final double value;
}

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
  final Map<String, TextEditingController> _searchControllers = {};

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 600;
              final actionButton = ElevatedButton.icon(
                onPressed: () async { await _forceRefreshAllGreenhouseSources(); },
                icon: Icon(Icons.sync, size: 18),
                label: Text('Refresh Server', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
              );

              final headingRow = Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  Text('Greenhouse', style: TextStyle(color: AppTheme.foreground, fontSize: 32, fontWeight: FontWeight.bold)),
                  _buildStatusChip(api.getSource('greenhouse')),
                  if (isNarrow) actionButton,
                ],
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    headingRow,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: headingRow),
                  actionButton,
                ],
              );
            },
          ),
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
              final sections = <Widget>[];
              final seenGroupIds = <String>{};
              map.forEach((rawKey, rawValue) {
                final src = rawKey.toString();
                Map<String, dynamic>? payloadMap;
                try {
                  if (rawValue is Map<String, dynamic>) {
                    payloadMap = Map<String, dynamic>.from(rawValue as Map);
                  }
                } catch (_) {}

                final groupId = _resolveGroupId(src, payloadMap);
                if (!seenGroupIds.add(groupId)) {
                  return;
                }

                final controller = _searchControllerFor(groupId);
                final rawQuery = controller.text.trim();
                final normalizedQuery = rawQuery.toLowerCase();

                sections.add(
                  _buildGroupSectionWidget(
                    rawSource: src,
                    payloadMap: payloadMap,
                    groupId: groupId,
                    controller: controller,
                    rawQuery: rawQuery,
                    normalizedQuery: normalizedQuery,
                  ),
                );
              });

              if (sections.isEmpty) {
                return NoDataPlaceholder(onRetry: () async {
                  try {
                    await api.refreshGreenhouse();
                  } catch (_) {}
                });
              }

              return Column(children: sections);
            },
          ),
        ],
      ),
    );
  }

  TextEditingController _searchControllerFor(String source) {
    return _searchControllers.putIfAbsent(source, () => TextEditingController());
  }

  List<Map<String, dynamic>> _normalizeTimelineRows(
    List<Map<String, dynamic>> rows, {
    String? expectedGroupId,
  }) {
    if (rows.isEmpty) return rows;
    return rows.map((row) {
      final copy = Map<String, dynamic>.from(row);
      final tsCandidate = row['timestamp_reading'] ??
          row['TIMESTAMP_READING'] ??
          row['Timestamp'] ??
          row['timestamp'] ??
          row['CREATED_AT'] ??
          row['created_at'] ??
          row['T'];
      final parsed = UiHelpers.parseTimestamp(tsCandidate);
      if (parsed != null) {
        final iso = parsed.toUtc().toIso8601String();
        copy['timestamp_reading'] = iso;
        copy['TIMESTAMP_READING'] = iso;
      }
      if (expectedGroupId != null && expectedGroupId.isNotEmpty) {
        final gid = copy['GROUP_ID'] ??
            copy['group_id'] ??
            copy['Group'] ??
            copy['group'] ??
            copy['GroupId'];
        if (gid == null || gid.toString().trim().isEmpty) {
          copy['GROUP_ID'] = expectedGroupId;
        }
      }
      return copy;
    }).toList();
  }

  Widget _buildSearchField(TextEditingController controller) {
    return TextField(
      controller: controller,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: 'Filter rows',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  controller.clear();
                  setState(() {});
                },
              ),
      ),
    );
  }

  String _windowLabel(String? window) {
    switch (window) {
      case '1h':
        return 'Last Hour';
      case '7d':
        return 'Last 7 Days';
      case '24h':
      default:
        return 'Last 24 Hours';
    }
  }

  String _resolveGroupId(String source, Map<String, dynamic>? payload) {
    try {
      final gidRaw = payload?['GROUP_ID'] ?? payload?['group_id'] ?? payload?['group'] ?? payload?['Group'];
      if (gidRaw != null) {
        final gidStr = gidRaw.toString();
        final digits = RegExp(r"(\d+)").firstMatch(gidStr)?.group(0);
        if (digits != null && digits.isNotEmpty) {
          return digits;
        }
        if (gidStr.toLowerCase().contains('iot')) {
          return '9';
        }
      }
    } catch (_) {}

    final lower = source.toLowerCase();
    if (lower.contains('iot')) return '9';
    final match = RegExp(r"(\d+)").firstMatch(source);
    if (match != null) return match.group(0)!;
    return source;
  }

  bool _isIotSource(String source, Map<String, dynamic>? payload) {
    final lower = source.toLowerCase();
    if (lower.contains('iot')) return true;
    try {
      final gidRaw = payload?['GROUP_ID'] ?? payload?['group_id'] ?? payload?['group'] ?? payload?['Group'];
      if (gidRaw != null) {
        final gidStr = gidRaw.toString().toLowerCase();
        if (gidStr.contains('iot')) return true;
      }
    } catch (_) {}
    return false;
  }

  Future<List<Map<String, dynamic>>> _fetchFilteredGroupHistory({
    required String group,
    required String source,
    required Map<String, dynamic>? payload,
    required int offset,
    required int limit,
    required String? duration,
    String? query,
    String? expectedGroupId,
  }) async {
    final normalizedQuery = query?.trim().toLowerCase();
    final hasQuery = normalizedQuery != null && normalizedQuery.isNotEmpty;
    final fetchOffset = hasQuery ? 0 : offset;
    final fetchLimit = hasQuery ? (offset + limit * 3 + 20) : limit;
    var rows = await _fetchGroupHistoryWithFallback(
      group,
      source,
      payload,
      fetchOffset,
      fetchLimit,
      duration,
      expectedGroupId: expectedGroupId,
    );
    rows = _normalizeTimelineRows(rows, expectedGroupId: expectedGroupId);

    void sortNewestFirst(List<Map<String, dynamic>> list) {
      list.sort((a, b) {
        final ta = UiHelpers.parseTimestamp(a['TIMESTAMP_READING'] ?? a['timestamp_reading'] ?? a['Timestamp'] ?? a['timestamp'] ?? a['CREATED_AT'] ?? a['created_at'] ?? a['T']);
        final tb = UiHelpers.parseTimestamp(b['TIMESTAMP_READING'] ?? b['timestamp_reading'] ?? b['Timestamp'] ?? b['timestamp'] ?? b['CREATED_AT'] ?? b['created_at'] ?? b['T']);
        if (ta == null && tb == null) return 0;
        if (ta == null) return 1;
        if (tb == null) return -1;
        return tb.compareTo(ta);
      });
    }

    List<Map<String, dynamic>> slice(List<Map<String, dynamic>> list) {
      if (list.isEmpty) return <Map<String, dynamic>>[];
      if (offset >= list.length) return <Map<String, dynamic>>[];
      final end = (offset + limit) > list.length ? list.length : offset + limit;
      return list.sublist(offset, end);
    }

    if (!hasQuery) {
      final sorted = List<Map<String, dynamic>>.from(rows);
      sortNewestFirst(sorted);
      if (offset > 0 && rows.length <= limit) {
        return sorted;
      }
      return slice(sorted);
    }

    final filtered = rows
        .where((row) => row.entries.any((entry) => entry.value != null && entry.value.toString().toLowerCase().contains(normalizedQuery)))
        .toList();

    sortNewestFirst(filtered);

    return slice(filtered);
  }

  Widget _buildGroupSectionWidget({
    required String rawSource,
    required Map<String, dynamic>? payloadMap,
    required String groupId,
    required TextEditingController controller,
    required String rawQuery,
    required String normalizedQuery,
  }) {
    final isIotGroup = _isIotSource(rawSource, payloadMap);
    if (isIotGroup && payloadMap != null) {
      payloadMap['GROUP_ID'] = '9';
      payloadMap['group_id'] = '9';
    }

    final queryActive = normalizedQuery.isNotEmpty;
    final windowLabel = _windowLabel(_selectedWindow);
  final tableReloadToken = 'table-$groupId-$_selectedWindow-$normalizedQuery';
  final chartReloadToken = 'chart-$groupId-$_selectedWindow';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 720;

              Widget buildTitle() {
                final heading = UiHelpers.groupLabel('Greenhouse', rawSource, payloadMap);
                final chipLabel = isIotGroup ? 'Group 9 — IoT sensors' : 'Group $groupId';
                return Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    Text(
                      heading,
                      style: TextStyle(color: AppTheme.foreground, fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    Chip(label: Text(chipLabel, style: const TextStyle(fontSize: 12)), backgroundColor: Colors.black12),
                  ],
                );
              }

              final dropdown = DropdownButton<String>(
                value: _selectedWindow,
                items: const [
                  DropdownMenuItem(value: '1h', child: Text('Last Hour')),
                  DropdownMenuItem(value: '24h', child: Text('Last 24 Hours')),
                  DropdownMenuItem(value: '7d', child: Text('Last 7 Days')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _selectedWindow = v;
                  });
                },
              );

              final exportButton = ElevatedButton.icon(
                onPressed: () async {
                  await exportGroupToCsv(context, 'greenhouse', api);
                },
                icon: const Icon(Icons.download),
                label: const Text('Export CSV'),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen, foregroundColor: AppTheme.darkBackground),
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildTitle(),
                    const SizedBox(height: 12),
                    dropdown,
                    const SizedBox(height: 8),
                    SizedBox(width: double.infinity, child: _buildSearchField(controller)),
                    const SizedBox(height: 8),
                    SizedBox(width: double.infinity, child: exportButton),
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: buildTitle()),
                  const SizedBox(width: 16),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      dropdown,
                      SizedBox(width: 240, child: _buildSearchField(controller)),
                      exportButton,
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          PaginatedHistory(
            group: 'greenhouse',
            source: rawSource,
            limit: 10,
            reloadToken: tableReloadToken,
            fetcher: (offset, limit) => _fetchFilteredGroupHistory(
              group: 'greenhouse',
              source: rawSource,
              payload: payloadMap,
              offset: offset,
              limit: limit,
              duration: _selectedWindow,
              query: queryActive ? normalizedQuery : null,
              expectedGroupId: groupId,
            ),
            builder: (context, rows, page, changePage) {
              if (rows.isEmpty) {
                if (queryActive) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('No rows match "$rawQuery"', style: TextStyle(color: AppTheme.mutedForeground)),
                      TextButton(
                        onPressed: () {
                          controller.clear();
                          setState(() {});
                        },
                        child: const Text('Clear filter'),
                      ),
                    ],
                  );
                }
                return const Text('No history available');
              }

              final sortedRows = List<Map<String, dynamic>>.from(rows);
              sortedRows.sort((a, b) {
                final ta = UiHelpers.parseTimestamp(a['TIMESTAMP_READING'] ?? a['timestamp_reading'] ?? a['Timestamp'] ?? a['timestamp'] ?? a['CREATED_AT'] ?? a['created_at'] ?? a['T']);
                final tb = UiHelpers.parseTimestamp(b['TIMESTAMP_READING'] ?? b['timestamp_reading'] ?? b['Timestamp'] ?? b['timestamp'] ?? b['CREATED_AT'] ?? b['created_at'] ?? b['T']);
                if (ta == null && tb == null) return 0;
                if (ta == null) return 1;
                if (tb == null) return -1;
                return tb.compareTo(ta);
              });

              final rawCols = sortedRows.first.keys.map((c) => c.toString()).toList();
              final displayCols = UiHelpers.pickDefaultCols(rawCols, 'greenhouse', hasImage: false, expanded: false);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Showing ${sortedRows.length} rows — $windowLabel', style: TextStyle(color: AppTheme.mutedForeground)),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: displayCols.map((c) => DataColumn(label: Text(UiHelpers.friendlyName(c)))).toList(),
                      rows: sortedRows
                          .map(
                            (row) => DataRow(
                              cells: displayCols
                                  .map((col) => DataCell(SizedBox(width: 140, child: Text(UiHelpers.formatCell(row[col], col)))))
                                  .toList(),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          PaginatedHistory(
            group: 'greenhouse',
            source: rawSource,
            limit: 200,
            reloadToken: chartReloadToken,
            fetcher: (offset, limit) => _fetchGroupHistoryWithFallback(
              'greenhouse',
              rawSource,
              payloadMap,
              offset,
              limit,
              _selectedWindow,
              expectedGroupId: groupId,
            ),
            builder: (context, rows, page, changePage) {
              if (rows.isEmpty) return const Text('No history available');

              final list = List<Map<String, dynamic>>.from(rows);
              list.sort((a, b) {
                final ta = UiHelpers.parseTimestamp(a['TIMESTAMP_READING'] ?? a['timestamp_reading'] ?? a['Timestamp'] ?? a['timestamp'] ?? a['CREATED_AT'] ?? a['created_at'] ?? a['T']);
                final tb = UiHelpers.parseTimestamp(b['TIMESTAMP_READING'] ?? b['timestamp_reading'] ?? b['Timestamp'] ?? b['timestamp'] ?? b['CREATED_AT'] ?? b['created_at'] ?? b['T']);
                if (ta == null && tb == null) return 0;
                if (ta == null) return 1;
                if (tb == null) return -1;
                return ta.compareTo(tb);
              });

              double? numericValue(Map<String, dynamic> row, List<String> candidates) {
                for (final key in candidates) {
                  if (!row.containsKey(key)) continue;
                  final raw = row[key];
                  if (raw == null) continue;
                  if (raw is num) return raw.toDouble();
                  final parsed = double.tryParse(raw.toString().replaceAll(RegExp(r"[^0-9.\-]"), ''));
                  if (parsed != null) return parsed;
                }
                return null;
              }

              List<_TimePoint> seriesFor(List<String> candidates) {
                final points = <_TimePoint>[];
                DateTime? lastTimestamp;
                int fallbackMinutes = 0;
                final nowUtc = DateTime.now().toUtc();

                for (var i = 0; i < list.length; i++) {
                  final row = list[i];
                  final value = numericValue(row, candidates);
                  if (value == null) continue;

                  final rawTs = row['TIMESTAMP_READING'] ??
                      row['timestamp_reading'] ??
                      row['CREATED_AT'] ??
                      row['created_at'] ??
                      row['Timestamp'] ??
                      row['timestamp'] ??
                      row['T'];

                  final parsedTs = UiHelpers.parseTimestamp(rawTs);
                  DateTime pointTs;
                  if (parsedTs != null) {
                    pointTs = parsedTs.toUtc();
                    lastTimestamp = pointTs;
                    fallbackMinutes = 0;
                  } else if (lastTimestamp != null) {
                    fallbackMinutes += 5;
                    pointTs = lastTimestamp.add(Duration(minutes: fallbackMinutes));
                  } else {
                    fallbackMinutes += 5;
                    pointTs = nowUtc.subtract(
                      Duration(minutes: (list.length - i) * 5 - fallbackMinutes),
                    );
                  }

                  points.add(_TimePoint(pointTs, value));
                }

                points.sort((a, b) => a.timestamp.compareTo(b.timestamp));
                return points;
              }

              LineChartData chartDataFor(List<_TimePoint> series, Color color, String? unit) {
                final sorted = [...series]..sort((a, b) => a.timestamp.compareTo(b.timestamp));
                final base = sorted.first.timestamp;
                final spots = sorted
                    .map(
                      (p) => FlSpot(
                        p.timestamp.difference(base).inSeconds.toDouble(),
                        p.value,
                      ),
                    )
                    .toList();

                double minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
                double maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
                if (minY == maxY) {
                  minY = minY - 1.0;
                  maxY = maxY + 1.0;
                }
                final padding = (maxY - minY) * 0.12;
                minY = minY - padding;
                maxY = maxY + padding;
                final intervalY = ((maxY - minY) / 4).abs();
                final effectiveIntervalY = intervalY <= 0 ? (maxY == 0 ? 1.0 : maxY.abs()) : intervalY;

                double minX = 0;
                double maxX = spots.last.x;
                if (maxX == minX) {
                  maxX = minX + 60;
                }
                final formatter = DateFormat('HH:mm');

                return LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (v) => const FlLine(color: Colors.white12, strokeWidth: 1),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: effectiveIntervalY,
                        reservedSize: 48,
                        getTitlesWidget: (value, meta) => Text(
                          value.toStringAsFixed(1),
                          style: TextStyle(color: AppTheme.mutedForeground, fontSize: 10),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        getTitlesWidget: (value, meta) {
                          final dt = base.add(Duration(seconds: value.round()));
                          return Text(
                            formatter.format(dt.toLocal()),
                            style: TextStyle(color: AppTheme.mutedForeground, fontSize: 10),
                          );
                        },
                      ),
                    ),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  minY: minY,
                  maxY: maxY,
                  minX: minX,
                  maxX: maxX,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: color,
                      dotData: FlDotData(show: false),
                      barWidth: 2,
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (items) => items
                          .map(
                            (it) {
                              final timestamp = base.add(Duration(seconds: it.x.round()));
                              final timeLabel = DateFormat('MMM d HH:mm').format(timestamp.toLocal());
                              final numeric = it.y.toStringAsFixed(2);
                              final displayValue = unit != null && unit.isNotEmpty ? '$numeric $unit' : numeric;
                              return LineTooltipItem(
                                '$displayValue\n$timeLabel',
                                const TextStyle(color: Colors.white),
                              );
                            },
                          )
                          .toList(),
                    ),
                  ),
                );
              }

              Widget buildLineCard(_ChartDefinition def, List<_TimePoint> series) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          def.title,
                          style: TextStyle(color: AppTheme.foreground, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 180,
                          child: series.isEmpty
                              ? Center(
                                  child: Text('n/a', style: TextStyle(color: AppTheme.mutedForeground)),
                                )
                              : LineChart(chartDataFor(series, def.color, def.unit)),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final chartDefinitions = <_ChartDefinition>[
                const _ChartDefinition(
                  title: 'Air Temperature (°C)',
                  keys: ['TEMPERATURE', 'temperature', 'temp', 'temperature_c'],
                  color: AppTheme.primaryGreen,
                  unit: '°C',
                ),
                const _ChartDefinition(
                  title: 'Relative Humidity (%)',
                  keys: ['HUMIDITY', 'humidity', 'humidity_pct', 'RH', 'rh'],
                  color: Colors.lightBlueAccent,
                  unit: '%',
                ),
                const _ChartDefinition(
                  title: 'CO₂ (ppm)',
                  keys: ['CO2', 'co2', 'co_2', 'co2_ppm', 'co₂'],
                  color: Colors.tealAccent,
                  unit: 'ppm',
                ),
                const _ChartDefinition(
                  title: 'Barometric Pressure (kPa)',
                  keys: ['PRESSURE', 'pressure', 'pressure_kpa', 'pressure_hpa'],
                  color: Colors.deepPurpleAccent,
                  unit: 'kPa',
                ),
                const _ChartDefinition(
                  title: 'Light Intensity (lux)',
                  keys: ['LIGHT_INTENSITY', 'light_intensity', 'Light_Intensity', 'light', 'lux'],
                  color: Colors.amberAccent,
                  unit: 'lux',
                ),
                const _ChartDefinition(
                  title: 'Smoke Level',
                  keys: ['SMOKE', 'smoke'],
                  color: Colors.orangeAccent,
                ),
                const _ChartDefinition(
                  title: 'Carbon Monoxide (ppm)',
                  keys: ['CO', 'co', 'co_ppm'],
                  color: Colors.redAccent,
                  unit: 'ppm',
                ),
                const _ChartDefinition(
                  title: 'Liquefied Petroleum Gas (ppm)',
                  keys: ['LPG', 'lpg'],
                  color: Colors.greenAccent,
                  unit: 'ppm',
                ),
                const _ChartDefinition(
                  title: 'Methane Level (ppm)',
                  keys: ['METHANE_LEVEL', 'methane_level', 'methane'],
                  color: Colors.lightGreen,
                  unit: 'ppm',
                ),
                const _ChartDefinition(
                  title: 'Propane Level (ppm)',
                  keys: ['PROPANE_LEVEL', 'propane_level', 'propane'],
                  color: Colors.pinkAccent,
                  unit: 'ppm',
                ),
                const _ChartDefinition(
                  title: 'Butane Level (ppm)',
                  keys: ['BUTANE_LEVEL', 'butane_level', 'butane'],
                  color: Colors.deepOrangeAccent,
                  unit: 'ppm',
                ),
                const _ChartDefinition(
                  title: 'Hydrogen Level (ppm)',
                  keys: ['HYDROGEN_LEVEL', 'hydrogen_level', 'hydrogen'],
                  color: Colors.yellowAccent,
                  unit: 'ppm',
                ),
                const _ChartDefinition(
                  title: 'Alcohol Level (ppm)',
                  keys: ['ALCOHOL_LEVEL', 'alcohol_level', 'alcohol'],
                  color: Colors.indigoAccent,
                  unit: 'ppm',
                ),
                const _ChartDefinition(
                  title: 'Ammonia Level (ppm)',
                  keys: ['AMMONIA_LEVEL', 'ammonia_level', 'ammonia'],
                  color: Colors.cyanAccent,
                  unit: 'ppm',
                ),
                const _ChartDefinition(
                  title: 'Benzene Level (ppm)',
                  keys: ['BENZENE_LEVEL', 'benzene_level', 'benzene'],
                  color: Colors.blueGrey,
                  unit: 'ppm',
                ),
                const _ChartDefinition(
                  title: 'Toluene Level (ppm)',
                  keys: ['TOLUENE_LEVEL', 'toluene_level', 'toluene'],
                  color: Colors.brown,
                  unit: 'ppm',
                ),
              ];

              final chartCards = <Widget>[];
              for (final def in chartDefinitions) {
                final series = seriesFor(def.keys);
                if (series.isEmpty) continue;
                chartCards.add(buildLineCard(def, series));
              }

              if (chartCards.isEmpty) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Charts', style: TextStyle(color: AppTheme.foreground, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'No chartable greenhouse metrics found for this source window.',
                          style: TextStyle(color: AppTheme.mutedForeground),
                        ),
                      ),
                    ),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Charts', style: TextStyle(color: AppTheme.foreground, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...List.generate(chartCards.length, (index) {
                    final card = chartCards[index];
                    if (index == chartCards.length - 1) return card;
                    return Column(
                      children: [
                        card,
                        const SizedBox(height: 12),
                      ],
                    );
                  }),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    for (final controller in _searchControllers.values) {
      controller.dispose();
    }
    _searchControllers.clear();
    super.dispose();
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

  /// Try several candidate source names to fetch per-source history when
  /// the consolidated endpoint returns a sentinel error object.
  Future<List<Map<String, dynamic>>> _fetchGroupHistoryWithFallback(
    String group,
    String src,
    Map<String, dynamic>? payloadMap,
    int offset,
    int limit,
    String? duration,
    {String? expectedGroupId}) async {
    final candidates = <String>[];
    candidates.add(src);

    if (payloadMap != null) {
      for (final k in ['SOURCE', 'source', 'source_name', 'name', 'group_id', 'group']) {
        try {
          final v = payloadMap[k];
          if (v != null) candidates.add(v.toString());
        } catch (_) {}
      }
    }

    // Try numeric variants extracted from the source key.
    final m = RegExp(r"\d+").firstMatch(src);
    if (m != null) {
      final d = m.group(0)!;
      candidates.add('${group}_g$d');
      candidates.add('${group}_$d');
      candidates.add('g$d');
      candidates.add('G$d');
      candidates.add(d);
    }

    final lowerSrc = src.toLowerCase();
    if (lowerSrc.contains('iot')) {
      candidates.add('greenhouse_g9');
      candidates.add('g9');
      candidates.add('9');
    }

    // Deduplicate while preserving order
    final seen = <String>{};
    final unique = <String>[];
    for (final c in candidates) {
      final s = c.toString();
      if (s.isEmpty) continue;
      if (!seen.contains(s)) {
        seen.add(s);
        unique.add(s);
      }
    }

    for (final cand in unique) {
      try {
        final r = await api.fetchGroupHistory(group, cand, limit: limit, offset: offset, duration: duration);
        if (r != null && r.isNotEmpty) {
          return _normalizeTimelineRows(r, expectedGroupId: expectedGroupId);
        }
      } catch (_) {}
    }

    // Last resort: try original src as-is
    try {
      final r = await api.fetchGroupHistory(group, src.toString(), limit: limit, offset: offset, duration: duration);
      if (r != null && r.isNotEmpty) {
        return _normalizeTimelineRows(r, expectedGroupId: expectedGroupId);
      }
    } catch (_) {}

    return <Map<String, dynamic>>[];
  }

  // chart title helpers removed (not used)

  @override
  bool get wantKeepAlive => true;

  /// Trigger server-side refresh for greenhouse sources and reload UI.
  Future<void> _forceRefreshAllGreenhouseSources() async {
    final sc = ScaffoldMessenger.of(context);
    sc.showSnackBar(SnackBar(content: Text('Requesting server refresh for greenhouse sources...')));
    final keysMap = await api.fetchAllGroupRaw('greenhouse');
    final sources = <String>[];
    if (keysMap != null && keysMap.isNotEmpty) {
      sources.addAll(keysMap.keys.map((k) => k.toString()));
    } else {
      // fallback candidate list
      sources.addAll(['greenhouse_g1', 'greenhouse_g9', 'greenhouse_iot', 'DEFAULT', 'default']);
    }

    var anyOk = false;
    for (final s in sources) {
      try {
        final ok = await api.forceRefreshGroupSource('greenhouse', s);
        if (ok) anyOk = true;
        await Future.delayed(Duration(milliseconds: 300));
      } catch (e) {
        if (kDebugMode) print('force refresh greenhouse $s error: $e');
      }
    }

    sc.hideCurrentSnackBar();
    if (anyOk) {
      sc.showSnackBar(SnackBar(content: Text('Server refresh requested — reloading data...')));
      await Future.delayed(Duration(seconds: 1));
      setState(() {});
    } else {
      sc.showSnackBar(SnackBar(content: Text('Server refresh failed for greenhouse sources (check bridge logs)')));
    }
  }
}
