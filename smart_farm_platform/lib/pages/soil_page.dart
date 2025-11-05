// 'dart:convert' removed: raw-rows debug helper removed from final UI
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
// no_data_placeholder removed; per-page small placeholders are used instead
import '../widgets/paginated_history.dart';
import '../theme/app_theme.dart';
import '../utils/ui_helpers.dart';

class SoilPage extends StatefulWidget {
  const SoilPage({super.key});

  @override
  State<SoilPage> createState() => _SoilPageState();
}

class _TimePoint {
  final DateTime timestamp;
  final double value;
  const _TimePoint(this.timestamp, this.value);
}

class _SoilPageState extends State<SoilPage>
    with AutomaticKeepAliveClientMixin {
  late final ApiService api = ApiService();
  // synthetic dev toggle removed per user request
  // no per-group expansion state required for final UI

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
              final heading = Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  Text(
                    'Soil Analysis',
                    style: TextStyle(
                      color: AppTheme.foreground,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  _buildStatusChip(api.getSource('soil')),
                  if (isNarrow)
                    ElevatedButton.icon(
                      onPressed: () async {
                        await _forceRefreshAllSoilSources();
                      },
                      icon: const Icon(Icons.sync, size: 18),
                      label: Text(
                        'Refresh Server',
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                ],
              );

              if (isNarrow) {
                return heading;
              }

              return Row(
                children: [
                  Expanded(child: heading),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await _forceRefreshAllSoilSources();
                    },
                    icon: const Icon(Icons.sync, size: 18),
                    label: Text(
                      'Refresh Server',
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          SizedBox(height: 8),
          Text(
            'Monitor moisture, nutrients and soil health',
            style: TextStyle(color: AppTheme.mutedForeground),
          ),
          SizedBox(height: 8),
          // synthetic toggle removed — bridge and APEX provide real data
          SizedBox(height: 16),

          // Render one pager per group so each group has its own Prev/Next
          Column(
            children: ['7', '8', '10'].map((gid) {
              return PaginatedHistory(
                group: 'soil',
                source: gid,
                // Page size: show 5 rows per page and let the fetcher request
                // a slightly larger window when necessary. This restores the
                // expected Prev/Next paging behavior (5 rows at a time).
                limit: 5,
                fetcher: (offset, limit) =>
                    _fetchSoilGroupRows(gid, offset: offset, limit: limit),
                builder: (context, rows, page, changePage) {
                  if (rows.isEmpty) {
                    // Show a small placeholder for empty groups so the UI makes
                    // it clear that the group exists but has no recent rows.
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isNarrow = constraints.maxWidth < 480;
                            final chips = Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              children: [
                                Chip(
                                  label: Text(
                                    '0 rows',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                  backgroundColor: Colors.blueGrey,
                                ),
                              ],
                            );

                            if (isNarrow) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    UiHelpers.groupLabel('Soil', gid),
                                    style: TextStyle(
                                      color: AppTheme.foreground,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  chips,
                                ],
                              );
                            }

                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    UiHelpers.groupLabel('Soil', gid),
                                    style: TextStyle(
                                      color: AppTheme.foreground,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                chips,
                              ],
                            );
                          },
                        ),
                        SizedBox(height: 8),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: SizedBox(
                              height: 96,
                              child: Center(
                                child: Text(
                                  'No data for ${UiHelpers.groupLabel('Soil', gid)}',
                                  style: TextStyle(
                                    color: AppTheme.mutedForeground,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 24),
                      ],
                    );
                  }

                  // Use the same rendering as before but operating on the provided
                  // per-group rows list (which is newest-first already).
                  final list = List<Map<String, dynamic>>.from(rows);

                  // Sort newest-first (defensive)
                  list.sort((a, b) {
                    final ta = UiHelpers.parseTimestamp(
                      a['CREATED_AT'] ??
                          a['created_at'] ??
                          a['timestamp'] ??
                          a['Timestamp'] ??
                          a['T'],
                    );
                    final tb = UiHelpers.parseTimestamp(
                      b['CREATED_AT'] ??
                          b['created_at'] ??
                          b['timestamp'] ??
                          b['Timestamp'] ??
                          b['T'],
                    );
                    if (ta == null && tb == null) return 0;
                    if (ta == null) return 1;
                    if (tb == null) return -1;
                    return tb.compareTo(ta);
                  });

                  final recentForCharts = list.length > 5
                      ? list.sublist(0, 5)
                      : list;
                  final chartSample = recentForCharts.reversed.toList();

                  double? valOf(
                    Map<String, dynamic> r,
                    List<String> candidates,
                  ) {
                    for (final k in candidates) {
                      if (!r.containsKey(k)) continue;
                      final s = r[k]?.toString();
                      if (s == null) continue;
                      final d = double.tryParse(s);
                      if (d != null) return d;
                    }
                    return null;
                  }

                  List<_TimePoint> seriesFor(List<String> cand) {
                    final points = <_TimePoint>[];
                    DateTime? lastTimestamp;
                    int fallbackMinutes = 0;
                    for (var i = 0; i < chartSample.length; i++) {
                      final r = chartSample[i];
                      final v = valOf(r, cand);
                      if (v == null) continue;
                      final rawTs = r['CREATED_AT'] ??
                          r['created_at'] ??
                          r['Timestamp'] ??
                          r['timestamp'] ??
                          r['T'];
                      final dt = UiHelpers.parseTimestamp(rawTs);
                      DateTime ts;
                      if (dt != null) {
                        ts = dt.toUtc();
                        lastTimestamp = ts;
                        fallbackMinutes = 0;
                      } else if (lastTimestamp != null) {
                        fallbackMinutes += 5;
                        ts = lastTimestamp.add(Duration(minutes: fallbackMinutes));
                      } else {
                        // no timestamps anywhere yet: fabricate sequential points near now
                        fallbackMinutes += 5;
                        ts = DateTime.now().toUtc().subtract(
                              Duration(minutes: (chartSample.length - i) * 5 - fallbackMinutes),
                            );
                      }
                      points.add(_TimePoint(ts, v));
                    }
                    points.sort((a, b) => a.timestamp.compareTo(b.timestamp));
                    return points;
                  }

                  final moistureSeries = seriesFor([
                    'MOISTURE',
                    'moisture',
                    'moisture_pct',
                    'MOISTURE_PCT',
                  ]);
                  final tempSeries = seriesFor([
                    'TEMPERATURE',
                    'temperature',
                    'temp',
                    'Temp',
                  ]);
                  final ecSeries = seriesFor([
                    'EC',
                    'ec',
                    'electrical_conductivity',
                  ]);
                  final phSeries = seriesFor(['PH', 'ph']);
                  final nSeries = seriesFor([
                    'N',
                    'nitrogen',
                    'nitrogen_ppm',
                    'nitrogen_mg_l',
                  ]);
                  final pSeries = seriesFor([
                    'P',
                    'phosphorus',
                    'phosphorus_ppm',
                    'phosphorus_mg_l',
                  ]);
                  final kSeries = seriesFor([
                    'K',
                    'potassium',
                    'potassium_ppm',
                    'potassium_mg_l',
                  ]);

                  LineChartData buildChartData(
                    List<_TimePoint> series,
                    Color color,
                  ) {
                    if (series.isEmpty) return LineChartData();

                    final sorted = [...series]
                      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
                    final base = sorted.first.timestamp;
                    final spots = sorted
                        .map(
                          (p) => FlSpot(
                            p.timestamp.difference(base).inSeconds.toDouble(),
                            p.value,
                          ),
                        )
                        .toList();

                    double minY = spots
                        .map((s) => s.y)
                        .reduce((a, b) => a < b ? a : b);
                    double maxY = spots
                        .map((s) => s.y)
                        .reduce((a, b) => a > b ? a : b);
                    if (minY == maxY) {
                      minY = minY - 1.0;
                      maxY = maxY + 1.0;
                    }
                    final padding = (maxY - minY) * 0.12;
                    minY = minY - padding;
                    maxY = maxY + padding;
                    final intervalY = ((maxY - minY) / 4).abs();

                    double minX = 0;
                    double maxX = spots.last.x;
                    if (maxX == minX) {
                      maxX = minX + 60; // pad single point charts with 1 minute
                    }
                    final intervalX = (maxX - minX) / 3;
                    final formatter = DateFormat('HH:mm');

                    String formatTick(double value) {
                      final dt = base.add(Duration(seconds: value.round()));
                      return formatter.format(dt.toLocal());
                    }

                    return LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (v) =>
                            FlLine(color: Colors.white12, strokeWidth: 1),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                              interval: intervalY == 0 ? 1 : intervalY,
                            reservedSize: 36,
                            getTitlesWidget: (value, meta) => Text(
                              value.toStringAsFixed(1),
                              style: TextStyle(
                                color: AppTheme.mutedForeground,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 32,
                                interval: intervalX == 0 ? 60 : intervalX,
                            getTitlesWidget: (value, meta) => Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                formatTick(value),
                                style: TextStyle(
                                  color: AppTheme.mutedForeground,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
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
                                  final ts = base.add(
                                    Duration(seconds: it.x.round()),
                                  );
                                  final tsLabel = DateFormat('MMM d HH:mm')
                                      .format(ts.toLocal());
                                  return LineTooltipItem(
                                    '${it.y.toStringAsFixed(2)}\n$tsLabel',
                                    TextStyle(color: Colors.white),
                                  );
                                },
                              )
                              .toList(),
                        ),
                      ),
                    );
                  }

                  Widget smallChartWithValue(
                    String title,
                    List<_TimePoint> series,
                    Color color,
                    String latestLabel,
                  ) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                color: AppTheme.mutedForeground,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (latestLabel.isNotEmpty)
                              Text(
                                latestLabel,
                                style: TextStyle(
                                  color: AppTheme.foreground,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                        SizedBox(
                          height: 110,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(6.0),
                              child: series.isEmpty
                                  ? Center(
                                      child: Text(
                                        'n/a',
                                        style: TextStyle(
                                          color: AppTheme.mutedForeground,
                                        ),
                                      ),
                                    )
                                  : LineChart(buildChartData(series, color)),
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  String latestLabelFor(List<String> cand, String suffix) {
                    if (list.isEmpty) return '';
                    final latest = list.first;
                    final v = valOf(latest, cand);
                    if (v == null) return '';
                    return '${v.toString()}$suffix';
                  }

                  // Show all available rows in the table (newest-first). Charts
                  // below still sample a small number for visual clarity.
                  final nowUtc = DateTime.now().toUtc();
                  final ascRows = list.reversed
                      .map<Map<String, dynamic>>((row) => Map<String, dynamic>.from(row))
                      .toList();
                  final normalizedAsc = <Map<String, dynamic>>[];
                  DateTime? lastTs;
                  int fallbackMinutes = 0;

                  for (var i = 0; i < ascRows.length; i++) {
                    final row = ascRows[i];
                    final rawTs = row['timestamp_reading'] ??
                        row['TIMESTAMP_READING'] ??
                        row['CREATED_AT'] ??
                        row['created_at'] ??
                        row['Timestamp'] ??
                        row['timestamp'] ??
                        row['T'];
                    final parsed = UiHelpers.parseTimestamp(rawTs);
                    DateTime ts;
                    if (parsed != null) {
                      ts = parsed.toUtc();
                      lastTs = ts;
                      fallbackMinutes = 0;
                    } else if (lastTs != null) {
                      fallbackMinutes += 5;
                      ts = lastTs.add(Duration(minutes: fallbackMinutes));
                      lastTs = ts;
                    } else {
                      fallbackMinutes += 5;
                      ts = nowUtc.subtract(
                        Duration(minutes: (ascRows.length - i) * 5 - fallbackMinutes),
                      );
                      lastTs = ts;
                    }

                    final iso = ts.toUtc().toIso8601String();
                    row['timestamp_reading'] = iso;
                    row['TIMESTAMP_READING'] = iso;
                    row['_timestamp_label'] = UiHelpers.formatTimestamp(iso);
                    normalizedAsc.add(row);
                  }

                  final tableRows = normalizedAsc.reversed.toList();
                  final tableColumns = [
                    'Timestamp',
                    'Moisture',
                    'Temperature',
                    'Ec',
                    'pH',
                    'Nitrogen',
                    'Phosphorus',
                    'Potassium',
                  ];

                  final chartCards = [
                    smallChartWithValue(
                      'Moisture',
                      moistureSeries,
                      Colors.blue,
                      latestLabelFor([
                        'MOISTURE',
                        'moisture',
                        'moisture_pct',
                      ], '%'),
                    ),
                    smallChartWithValue(
                      'Temp',
                      tempSeries,
                      Colors.redAccent,
                      latestLabelFor([
                        'TEMPERATURE',
                        'temperature',
                        'temp',
                      ], ''),
                    ),
                    smallChartWithValue(
                      'EC',
                      ecSeries,
                      Colors.green,
                      latestLabelFor(['EC', 'ec'], ''),
                    ),
                    smallChartWithValue(
                      'pH',
                      phSeries,
                      Colors.purple,
                      latestLabelFor(['PH', 'ph'], ''),
                    ),
                    smallChartWithValue(
                      'N',
                      nSeries,
                      Colors.brown,
                      latestLabelFor(['N', 'nitrogen'], ''),
                    ),
                    smallChartWithValue(
                      'P',
                      pSeries,
                      Colors.orange,
                      latestLabelFor(['P', 'phosphorus'], ''),
                    ),
                    smallChartWithValue(
                      'K',
                      kSeries,
                      Colors.teal,
                      latestLabelFor(['K', 'potassium'], ''),
                    ),
                  ];

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isNarrow = constraints.maxWidth < 520;
                          final title = Text(
                            UiHelpers.groupLabel('Soil', gid),
                            style: TextStyle(
                              color: AppTheme.foreground,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          );
                          final chipRow = Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Chip(
                                label: Text(
                                  '${list.length} rows',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                  ),
                                ),
                                backgroundColor: Colors.blueGrey,
                              ),
                            ],
                          );

                          if (isNarrow) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                title,
                                const SizedBox(height: 8),
                                chipRow,
                              ],
                            );
                          }

                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: title),
                              chipRow,
                            ],
                          );
                        },
                      ),
                      SizedBox(height: 8),

                      LayoutBuilder(
                        builder: (context, constraints) {
                          final maxWidth = constraints.maxWidth;
                          const spacing = 8.0;
                          int columns;
                          if (maxWidth >= 1100) {
                            columns = 4;
                          } else if (maxWidth >= 820) {
                            columns = 3;
                          } else if (maxWidth >= 540) {
                            columns = 2;
                          } else {
                            columns = 1;
                          }
                          final effectiveColumns = chartCards.isEmpty
                              ? 1
                              : columns.clamp(1, chartCards.length).toInt();
                          final tileWidth = effectiveColumns > 1
                              ? (maxWidth - spacing * (effectiveColumns - 1)) /
                                    effectiveColumns
                              : maxWidth;

                          return Wrap(
                            spacing: spacing,
                            runSpacing: spacing,
                            children: chartCards
                                .map(
                                  (card) =>
                                      SizedBox(width: tileWidth, child: card),
                                )
                                .toList(),
                          );
                        },
                      ),

                      SizedBox(height: 12),
                      Text(
                        'History (newest first) — ${list.length} rows',
                        style: TextStyle(color: AppTheme.mutedForeground),
                      ),
                      SizedBox(height: 8),

                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Soil data — ${UiHelpers.groupLabel('Soil', gid)}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              SizedBox(height: 12),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columns: tableColumns
                                      .map(
                                        (title) => DataColumn(
                                          label: Text(
                                            title,
                                            style: TextStyle(
                                              color: AppTheme.foreground,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  rows: tableRows.map((r) {
                                    String cell(dynamic v, List<String> cand) {
                                      final val = valOf(r, cand);
                                      return val == null ? '' : val.toString();
                                    }
                                    final tsLabel = (r['_timestamp_label'] ?? '')
                                        .toString()
                                        .trim();
                                    return DataRow(
                                      cells: [
                                        DataCell(Text(tsLabel.isEmpty ? '—' : tsLabel)),
                                        DataCell(
                                          Text(
                                            cell(r, [
                                              'MOISTURE',
                                              'moisture',
                                              'moisture_pct',
                                            ]),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            cell(r, [
                                              'TEMPERATURE',
                                              'temperature',
                                              'temp',
                                            ]),
                                          ),
                                        ),
                                        DataCell(Text(cell(r, ['EC', 'ec']))),
                                        DataCell(Text(cell(r, ['PH', 'ph']))),
                                        DataCell(
                                          Text(cell(r, ['N', 'nitrogen'])),
                                        ),
                                        DataCell(
                                          Text(cell(r, ['P', 'phosphorus'])),
                                        ),
                                        DataCell(
                                          Text(cell(r, ['K', 'potassium'])),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 24),
                    ],
                  );
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// Try the consolidated endpoint first; if it doesn't provide rows for all
  /// target groups (7,8,10) then fall back to enumerating sources and
  /// aggregating per-source history. Returns a flattened list of rows
  /// suitable for the page builder.
  Future<List<Map<String, dynamic>>?> _fetchSoilRows({
    int offset = 0,
    int limit = 10,
  }) async {
    try {
      // Ask the consolidated endpoint for a slightly larger window so that
      // client-side slicing can emulate offset when backend doesn't support it.
      final fetchLimit = offset > 0 ? (offset + limit) : limit;
      final consolidated = await api.fetchSoilGroupHistory(
        limit: fetchLimit,
        offset: 0,
        synthetic: false,
      );
      if (consolidated != null && consolidated.isNotEmpty) {
        // If consolidated results include at least one row for each target
        // group, return the client-sliced window.
        final present = <String>{};
        for (final r in consolidated) {
          final gid =
              (r['GROUP_ID'] ??
                      r['group_id'] ??
                      r['Group'] ??
                      r['group'] ??
                      r['GROUP'] ??
                      r['GroupId'])
                  ?.toString();
          if (gid != null) present.add(gid);
        }
        if (['7', '8', '10'].every((g) => present.contains(g))) {
          // return slice emulating offset
          if (offset > 0) {
            if (consolidated.length <= offset) return <Map<String, dynamic>>[];
            final end = (offset + limit) < consolidated.length
                ? (offset + limit)
                : consolidated.length;
            return consolidated.sublist(offset, end);
          }
          return consolidated;
        }
        // else continue to fallback to per-source aggregation below
      }
    } catch (_) {}

    // Fallback: enumerate available sources and fetch per-source history
    try {
      final all = await api.fetchAllGroupRaw('soil');
      if (all == null || all.isEmpty) return <Map<String, dynamic>>[];

      final collected = <Map<String, dynamic>>[];
      final seen = <String>{};
      for (final src in all.keys) {
        try {
          var hist = await api.fetchGroupHistory(
            'soil',
            src.toString(),
            limit: 50,
          );
          if (hist == null || hist.isEmpty) continue;
          for (final r in hist) {
            final gidRaw =
                r['GROUP_ID'] ??
                r['group_id'] ??
                r['Group'] ??
                r['group'] ??
                r['GROUP'] ??
                r['GroupId'];
            final gid = gidRaw?.toString();
            if (gid == null) continue;
            if (gid == '7' || gid == '8' || gid == '10') collected.add(r);
          }
        } catch (_) {}
      }

      // Deduplicate by canonical (group + parsed timestamp + optional source)
      final deduped = <Map<String, dynamic>>[];
      for (final r in collected) {
        final dt = UiHelpers.parseTimestamp(
          r['CREATED_AT'] ??
              r['created_at'] ??
              r['corrected_created_at'] ??
              r['CORRECTED_CREATED_AT'] ??
              r['correctedCreatedAt'] ??
              r['Timestamp'] ??
              r['timestamp'] ??
              r['T'],
        );
        final createdKey = dt != null
            ? dt.toUtc().toIso8601String()
            : (r['CREATED_AT'] ??
                          r['created_at'] ??
                          r['corrected_created_at'] ??
                          r['Timestamp'] ??
                          r['timestamp'] ??
                          r['T'])
                      ?.toString() ??
                  '';
        final gid =
            (r['GROUP_ID'] ??
                    r['group_id'] ??
                    r['Group'] ??
                    r['group'] ??
                    r['GROUP'] ??
                    r['GroupId'])
                ?.toString() ??
            '';
        final srcKey =
            (r['SOURCE'] ?? r['source'] ?? r['src'] ?? '')?.toString() ?? '';
        final key = '$gid|$createdKey|$srcKey';
        if (seen.contains(key)) continue;
        seen.add(key);
        try {
          if (dt != null) {
            r['CREATED_AT'] = dt.toUtc().toIso8601String();
          } else if (r['corrected_created_at'] != null) {
            r['CREATED_AT'] = r['corrected_created_at'].toString();
          }
        } catch (_) {}
        deduped.add(r);
      }

      // sort newest-first
      deduped.sort((a, b) {
        final ta = UiHelpers.parseTimestamp(
          a['CREATED_AT'] ??
              a['created_at'] ??
              a['timestamp'] ??
              a['Timestamp'] ??
              a['T'],
        );
        final tb = UiHelpers.parseTimestamp(
          b['CREATED_AT'] ??
              b['created_at'] ??
              b['timestamp'] ??
              b['Timestamp'] ??
              b['T'],
        );
        if (ta == null && tb == null) return 0;
        if (ta == null) return 1;
        if (tb == null) return -1;
        return tb.compareTo(ta);
      });

      // emulate offset slicing
      if (offset > 0) {
        if (deduped.length <= offset) return <Map<String, dynamic>>[];
        final end = (offset + limit) < deduped.length
            ? (offset + limit)
            : deduped.length;
        return deduped.sublist(offset, end);
      }

      return deduped;
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  /// Fetch rows for a single soil group (gid like '7','8','10') and return
  /// a list sliced by offset/limit. This prefers the consolidated endpoint
  /// but will fall back to the aggregated per-source collection helper.
  Future<List<Map<String, dynamic>>?> _fetchSoilGroupRows(
    String gid, {
    int offset = 0,
    int limit = 10,
  }) async {
    try {
      // Ask consolidated endpoint for a larger window to allow client-side
      // filtering and slicing for a single group.
      final fetchLimit = ((offset + limit) * 6) > 200
          ? 200
          : ((offset + limit) * 6);
      var consolidated = await api.fetchSoilGroupHistory(
        limit: fetchLimit,
        offset: 0,
        synthetic: false,
      );
      List<Map<String, dynamic>> rows = [];
      if (consolidated != null && consolidated.isNotEmpty) {
        rows = consolidated;
        // If the consolidated endpoint did not include rows for the requested
        // gid, prefer the more expensive per-source aggregator fallback so
        // groups that are missing from the consolidated response still show.
        try {
          final presentGroups = <String>{};
          for (final r in rows) {
            final gidRaw =
                r['GROUP_ID'] ??
                r['group_id'] ??
                r['Group'] ??
                r['group'] ??
                r['GROUP'] ??
                r['GroupId'];
            if (gidRaw != null) presentGroups.add(gidRaw.toString());
          }
          if (!presentGroups.contains(gid)) {
            // consolidated response lacks this gid — fallback to aggregate
            final fallback = await _fetchSoilRows(offset: 0, limit: 200);
            if (fallback != null && fallback.isNotEmpty) rows = fallback;
          }
        } catch (_) {}
        if (kDebugMode) {
          try {
            final presentGroups = <String>{};
            for (final r in rows) {
              final gidRaw =
                  r['GROUP_ID'] ??
                  r['group_id'] ??
                  r['Group'] ??
                  r['group'] ??
                  r['GROUP'] ??
                  r['GroupId'];
              if (gidRaw != null) presentGroups.add(gidRaw.toString());
            }
            print(
              '[debug] fetchSoilGroupRows consolidated returned ${rows.length} rows, groups: ${presentGroups.join(',')} for requested gid=$gid',
            );
          } catch (_) {}
        }
      } else {
        // Fallback to the more expensive aggregator which deduplicates and
        // returns a merged list across sources.
        final fallback = await _fetchSoilRows(offset: 0, limit: 200);
        if (fallback != null) rows = fallback;
      }

      // Filter for the requested group id
      final filtered = rows.where((r) {
        final gidRaw =
            r['GROUP_ID'] ??
            r['group_id'] ??
            r['Group'] ??
            r['group'] ??
            r['GROUP'] ??
            r['GroupId'];
        final g = gidRaw?.toString() ?? '';
        return g == gid;
      }).toList();
      if (kDebugMode)
        print(
          '[debug] fetchSoilGroupRows filtered for gid=$gid -> ${filtered.length} rows (from ${rows.length} total)',
        );

      // Normalize & sort newest-first
      filtered.sort((a, b) {
        final ta = UiHelpers.parseTimestamp(
          a['CREATED_AT'] ??
              a['created_at'] ??
              a['timestamp'] ??
              a['Timestamp'] ??
              a['T'],
        );
        final tb = UiHelpers.parseTimestamp(
          b['CREATED_AT'] ??
              b['created_at'] ??
              b['timestamp'] ??
              b['Timestamp'] ??
              b['T'],
        );
        if (ta == null && tb == null) return 0;
        if (ta == null) return 1;
        if (tb == null) return -1;
        return tb.compareTo(ta);
      });

      // Emulate offset/limit for this group's rows
      if (offset > 0) {
        if (filtered.length <= offset) return <Map<String, dynamic>>[];
        final end = (offset + limit) < filtered.length
            ? (offset + limit)
            : filtered.length;
        return filtered.sublist(offset, end);
      }

      return filtered;
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Widget _buildStatusChip(String? source) {
    if (source == null) return SizedBox.shrink();
    if (source == 'live') {
      return Chip(
        label: Text(
          'LIVE',
          style: TextStyle(fontSize: 12, color: Colors.white),
        ),
        backgroundColor: Colors.green,
      );
    }
    if (source == 'offline' || source == 'cache' || source == 'stale_cache') {
      return Chip(
        label: Text(
          'OFFLINE — showing cached results',
          style: TextStyle(fontSize: 12),
        ),
        backgroundColor: Colors.orange.shade200,
      );
    }

    return Chip(
      label: Text(source, style: TextStyle(fontSize: 12)),
      backgroundColor: Colors.black12,
    );
  }

  /// Trigger server-side refresh for the known soil sources and reload UI.
  Future<void> _forceRefreshAllSoilSources() async {
    final sc = ScaffoldMessenger.of(context);
    sc.showSnackBar(
      SnackBar(content: Text('Requesting server refresh for soil sources...')),
    );
    final sources = ['soil_g7', 'soil_g8', 'soil_g10'];
    var anyOk = false;
    for (final s in sources) {
      try {
        final ok = await api.forceRefreshGroupSource('soil', s);
        if (ok) anyOk = true;
        // small delay to avoid overwhelming the bridge
        await Future.delayed(Duration(milliseconds: 300));
      } catch (e) {
        if (kDebugMode) print('force refresh $s error: $e');
      }
    }
    sc.hideCurrentSnackBar();
    if (anyOk) {
      sc.showSnackBar(
        SnackBar(content: Text('Server refresh requested — reloading data...')),
      );
      // allow server a short time to cache results then refresh UI
      await Future.delayed(Duration(seconds: 1));
      setState(() {});
    } else {
      sc.showSnackBar(
        SnackBar(
          content: Text(
            'Server refresh failed for all soil sources (check bridge logs)',
          ),
        ),
      );
    }
  }

  // _loadSoilRows removed: paging is handled by PaginatedHistory with a
  // consolidated backend endpoint (fetchSoilGroupHistory) and ApiService
  // client-side slicing fallback when needed.

  @override
  bool get wantKeepAlive => true;
}

// _SoilDataSource removed — per-group DataTable widgets are used directly in the
// final UI (each table is small — up to 7 rows) so a DataTableSource is not
// necessary here.
