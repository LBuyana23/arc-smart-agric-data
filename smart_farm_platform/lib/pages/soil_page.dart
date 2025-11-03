// 'dart:convert' removed: raw-rows debug helper removed from final UI
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:fl_chart/fl_chart.dart';
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

class _SoilPageState extends State<SoilPage> with AutomaticKeepAliveClientMixin {
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
          Row(children: [
            Text('Soil Analysis', style: TextStyle(color: AppTheme.foreground, fontSize: 32, fontWeight: FontWeight.bold)),
            SizedBox(width: 8),
            _buildStatusChip(api.getSource('soil')),
            SizedBox(width: 12),
            if (kDebugMode)
              TextButton.icon(
                onPressed: () async {
                  // Force a synchronous refresh of the primary soil source (V1)
                  final sc = ScaffoldMessenger.of(context);
                  sc.showSnackBar(SnackBar(content: Text('Refreshing upstream...')));
                  final ok = await api.forceRefreshGroupSource('soil', 'V1');
                  sc.hideCurrentSnackBar();
                  if (ok) {
                    sc.showSnackBar(SnackBar(content: Text('Refresh succeeded — reloading')));
                    setState(() {});
                  } else {
                    sc.showSnackBar(SnackBar(content: Text('Refresh failed (see bridge logs)')));
                  }
                },
                icon: Icon(Icons.refresh, size: 18),
                label: Text('Refresh Live', style: TextStyle(fontSize: 12)),
              ),
          ]),
          SizedBox(height: 8),
          Text('Monitor moisture, nutrients and soil health', style: TextStyle(color: AppTheme.mutedForeground)),
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
                fetcher: (offset, limit) => _fetchSoilGroupRows(gid, offset: offset, limit: limit),
                builder: (context, rows, page, changePage) {
                  if (rows.isEmpty) {
                    // Show a small placeholder for empty groups so the UI makes
                    // it clear that the group exists but has no recent rows.
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(UiHelpers.groupLabel('Soil', gid), style: TextStyle(color: AppTheme.foreground, fontSize: 20, fontWeight: FontWeight.w700)),
                            Row(children: [
                              Chip(label: Text('0 rows', style: TextStyle(fontSize: 12, color: Colors.white)), backgroundColor: Colors.blueGrey),
                              SizedBox(width: 8),
                            ]),
                          ],
                        ),
                        SizedBox(height: 8),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: SizedBox(height: 96, child: Center(child: Text('No data for ${UiHelpers.groupLabel('Soil', gid)}', style: TextStyle(color: AppTheme.mutedForeground)))),
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
                    final ta = UiHelpers.parseTimestamp(a['CREATED_AT'] ?? a['created_at'] ?? a['timestamp'] ?? a['Timestamp'] ?? a['T']);
                    final tb = UiHelpers.parseTimestamp(b['CREATED_AT'] ?? b['created_at'] ?? b['timestamp'] ?? b['Timestamp'] ?? b['T']);
                    if (ta == null && tb == null) return 0;
                    if (ta == null) return 1;
                    if (tb == null) return -1;
                    return tb.compareTo(ta);
                  });

                  final recentForCharts = list.length > 5 ? list.sublist(0, 5) : list;
                  final chartSample = recentForCharts.reversed.toList();

                  double? valOf(Map<String, dynamic> r, List<String> candidates) {
                    for (final k in candidates) {
                      if (!r.containsKey(k)) continue;
                      final s = r[k]?.toString();
                      if (s == null) continue;
                      final d = double.tryParse(s);
                      if (d != null) return d;
                    }
                    return null;
                  }

                  List<FlSpot> spotsFor(List<String> cand) {
                    final spots = <FlSpot>[];
                    final times = <int>[];
                    final values = <double>[];

                    for (var i = 0; i < chartSample.length; i++) {
                      final r = chartSample[i];
                      final v = valOf(r, cand);
                      if (v == null) continue;
                      final dt = UiHelpers.parseTimestamp(r['CREATED_AT'] ?? r['created_at'] ?? r['Timestamp'] ?? r['timestamp'] ?? r['T']);
                      if (dt != null) {
                        times.add(dt.toUtc().millisecondsSinceEpoch);
                        values.add(v);
                      } else {
                        // mark as no-timestamp by using -1
                        times.add(-1);
                        values.add(v);
                      }
                    }

                    if (times.isEmpty) return <FlSpot>[];

                    // If we have at least one real timestamp, convert all timestamped
                    // points to seconds since the first timestamp. Points without
                    // timestamps will be placed at increasing integer positions after
                    // the timestamped range to avoid mixing huge epoch values.
                    final hasTimestamp = times.any((t) => t > 0);
                    if (hasTimestamp) {
                      final validTimes = times.where((t) => t > 0).toList();
                      validTimes.sort();
                      final base = validTimes.first;
                      int nextIndex = 0;
                      for (var i = 0; i < times.length; i++) {
                        final t = times[i];
                        final v = values[i];
                        if (t > 0) {
                          final x = (t - base) / 1000.0; // seconds from base
                          spots.add(FlSpot(x, v));
                        } else {
                          // place non-timestamped points after the last time as sequential
                          spots.add(FlSpot((validTimes.last - base) / 1000.0 + (++nextIndex).toDouble(), v));
                        }
                      }
                    } else {
                      // No timestamps at all: use sequential indices
                      for (var i = 0; i < values.length; i++) {
                        spots.add(FlSpot(i.toDouble(), values[i]));
                      }
                    }

                    spots.sort((a, b) => a.x.compareTo(b.x));
                    return spots;
                  }

                  final moistureSpots = spotsFor(['MOISTURE', 'moisture', 'moisture_pct', 'MOISTURE_PCT']);
                  final tempSpots = spotsFor(['TEMPERATURE', 'temperature', 'temp', 'Temp']);
                  final ecSpots = spotsFor(['EC', 'ec', 'electrical_conductivity']);
                  final phSpots = spotsFor(['PH', 'ph']);
                  final nSpots = spotsFor(['N', 'nitrogen', 'nitrogen_ppm', 'nitrogen_mg_l']);
                  final pSpots = spotsFor(['P', 'phosphorus', 'phosphorus_ppm', 'phosphorus_mg_l']);
                  final kSpots = spotsFor(['K', 'potassium', 'potassium_ppm', 'potassium_mg_l']);

                  LineChartData buildChartData(List<FlSpot> spots, Color color) {
                    if (spots.isEmpty) return LineChartData();
                    double minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
                    double maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
                    if (minY == maxY) {
                      minY = minY - 1.0;
                      maxY = maxY + 1.0;
                    }
                    final padding = (maxY - minY) * 0.12;
                    minY = minY - padding;
                    maxY = maxY + padding;
                    final interval = ((maxY - minY) / 4).abs();

                    return LineChartData(
                      gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: Colors.white12, strokeWidth: 1)),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: interval, reservedSize: 36, getTitlesWidget: (value, meta) => Text(value.toStringAsFixed(1), style: TextStyle(color: AppTheme.mutedForeground, fontSize: 10)))),
                        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      minY: minY,
                      maxY: maxY,
                      lineBarsData: [LineChartBarData(spots: spots, isCurved: true, color: color, dotData: FlDotData(show: false), barWidth: 2)],
                      lineTouchData: LineTouchData(enabled: true, touchTooltipData: LineTouchTooltipData(getTooltipItems: (items) => items.map((it) => LineTooltipItem(it.y.toStringAsFixed(2), TextStyle(color: Colors.white))).toList())),
                    );
                  }

                  Widget smallChartWithValue(String title, List<FlSpot> spots, Color color, String latestLabel) {
                    return Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [Text(title, style: TextStyle(color: AppTheme.mutedForeground, fontSize: 12)), SizedBox(width: 8), if (latestLabel.isNotEmpty) Text(latestLabel, style: TextStyle(color: AppTheme.foreground, fontSize: 12, fontWeight: FontWeight.w600))]),
                          SizedBox(
                            height: 110,
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(6.0),
                                child: spots.isEmpty ? Center(child: Text('n/a', style: TextStyle(color: AppTheme.mutedForeground))) : LineChart(buildChartData(spots, color)),
                              ),
                            ),
                          ),
                        ],
                      ),
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
                  final tableRows = List<Map<String, dynamic>>.from(list);
                  final tableColumns = ['Created At', 'Moisture', 'Temperature', 'Ec', 'pH', 'Nitrogen', 'Phosphorus', 'Potassium'];

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(UiHelpers.groupLabel('Soil', gid), style: TextStyle(color: AppTheme.foreground, fontSize: 20, fontWeight: FontWeight.w700)),
                          Row(children: [
                            Chip(label: Text('${list.length} rows', style: TextStyle(fontSize: 12, color: Colors.white)), backgroundColor: Colors.blueGrey),
                            SizedBox(width: 8),
                          ]),
                        ],
                      ),
                      SizedBox(height: 8),

                      Row(children: [
                        smallChartWithValue('Moisture', moistureSpots, Colors.blue, latestLabelFor(['MOISTURE', 'moisture', 'moisture_pct'], '%')),
                        SizedBox(width: 8),
                        smallChartWithValue('Temp', tempSpots, Colors.redAccent, latestLabelFor(['TEMPERATURE', 'temperature', 'temp'], '')),
                        SizedBox(width: 8),
                        smallChartWithValue('EC', ecSpots, Colors.green, latestLabelFor(['EC', 'ec'], '')),
                      ]),
                      SizedBox(height: 8),
                      Row(children: [
                        smallChartWithValue('pH', phSpots, Colors.purple, latestLabelFor(['PH', 'ph'], '')),
                        SizedBox(width: 8),
                        smallChartWithValue('N', nSpots, Colors.brown, latestLabelFor(['N', 'nitrogen'], '')),
                        SizedBox(width: 8),
                        smallChartWithValue('P', pSpots, Colors.orange, latestLabelFor(['P', 'phosphorus'], '')),
                        SizedBox(width: 8),
                        smallChartWithValue('K', kSpots, Colors.teal, latestLabelFor(['K', 'potassium'], '')),
                      ]),

                      SizedBox(height: 12),
                      Text('History (newest first) — ${list.length} rows', style: TextStyle(color: AppTheme.mutedForeground)),
                      SizedBox(height: 8),

                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            children: [
                              Align(alignment: Alignment.centerLeft, child: Text('Soil data — ${UiHelpers.groupLabel('Soil', gid)}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)) ),
                              SizedBox(height: 12),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columns: List<DataColumn>.generate(tableColumns.length, (i) {
                                    final title = tableColumns[i];
                                    if (i == 0) return DataColumn(label: Text(title, style: TextStyle(color: AppTheme.foreground, fontWeight: FontWeight.w600)));
                                    return DataColumn(label: Text(title));
                                  }),
                                  rows: tableRows.map((r) {
                                    String fmtTs(dynamic v) {
                                      final out = UiHelpers.formatTimestamp(v);
                                      if (out.isNotEmpty) return out;
                                      if (v != null) return v.toString();
                                      return '';
                                    }
                                    String cell(dynamic v, List<String> cand) {
                                      final val = valOf(r, cand);
                                      return val == null ? '' : val.toString();
                                    }
                                    return DataRow(cells: [
                                      DataCell(Text(fmtTs(r['CREATED_AT'] ?? r['created_at'] ?? r['Timestamp'] ?? r['timestamp'] ?? r['T']), style: TextStyle(color: AppTheme.mutedForeground))),
                                      DataCell(Text(cell(r, ['MOISTURE', 'moisture', 'moisture_pct']))),
                                      DataCell(Text(cell(r, ['TEMPERATURE', 'temperature', 'temp']))),
                                      DataCell(Text(cell(r, ['EC', 'ec']))),
                                      DataCell(Text(cell(r, ['PH', 'ph']))),
                                      DataCell(Text(cell(r, ['N', 'nitrogen']))),
                                      DataCell(Text(cell(r, ['P', 'phosphorus']))),
                                      DataCell(Text(cell(r, ['K', 'potassium']))),
                                    ], onSelectChanged: (_) => _showSourceDetail(context, gid, r));
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
  Future<List<Map<String, dynamic>>?> _fetchSoilRows({int offset = 0, int limit = 10}) async {
    try {
      // Ask the consolidated endpoint for a slightly larger window so that
      // client-side slicing can emulate offset when backend doesn't support it.
      final fetchLimit = offset > 0 ? (offset + limit) : limit;
      final consolidated = await api.fetchSoilGroupHistory(limit: fetchLimit, offset: 0, synthetic: false);
      if (consolidated != null && consolidated.isNotEmpty) {
        // If consolidated results include at least one row for each target
        // group, return the client-sliced window.
        final present = <String>{};
        for (final r in consolidated) {
          final gid = (r['GROUP_ID'] ?? r['group_id'] ?? r['Group'] ?? r['group'] ?? r['GROUP'] ?? r['GroupId'])?.toString();
          if (gid != null) present.add(gid);
        }
        if (['7', '8', '10'].every((g) => present.contains(g))) {
          // return slice emulating offset
          if (offset > 0) {
            if (consolidated.length <= offset) return <Map<String, dynamic>>[];
            final end = (offset + limit) < consolidated.length ? (offset + limit) : consolidated.length;
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
          var hist = await api.fetchGroupHistory('soil', src.toString(), limit: 50);
          if (hist == null || hist.isEmpty) continue;
          for (final r in hist) {
            final gidRaw = r['GROUP_ID'] ?? r['group_id'] ?? r['Group'] ?? r['group'] ?? r['GROUP'] ?? r['GroupId'];
            final gid = gidRaw?.toString();
            if (gid == null) continue;
            if (gid == '7' || gid == '8' || gid == '10') collected.add(r);
          }
        } catch (_) {}
      }

      // Deduplicate by canonical (group + parsed timestamp + optional source)
      final deduped = <Map<String, dynamic>>[];
      for (final r in collected) {
        final dt = UiHelpers.parseTimestamp(r['CREATED_AT'] ?? r['created_at'] ?? r['corrected_created_at'] ?? r['CORRECTED_CREATED_AT'] ?? r['correctedCreatedAt'] ?? r['Timestamp'] ?? r['timestamp'] ?? r['T']);
        final createdKey = dt != null ? dt.toUtc().toIso8601String() : (r['CREATED_AT'] ?? r['created_at'] ?? r['corrected_created_at'] ?? r['Timestamp'] ?? r['timestamp'] ?? r['T'])?.toString() ?? '';
        final gid = (r['GROUP_ID'] ?? r['group_id'] ?? r['Group'] ?? r['group'] ?? r['GROUP'] ?? r['GroupId'])?.toString() ?? '';
        final srcKey = (r['SOURCE'] ?? r['source'] ?? r['src'] ?? '')?.toString() ?? '';
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
        final ta = UiHelpers.parseTimestamp(a['CREATED_AT'] ?? a['created_at'] ?? a['timestamp'] ?? a['Timestamp'] ?? a['T']);
        final tb = UiHelpers.parseTimestamp(b['CREATED_AT'] ?? b['created_at'] ?? b['timestamp'] ?? b['Timestamp'] ?? b['T']);
        if (ta == null && tb == null) return 0;
        if (ta == null) return 1;
        if (tb == null) return -1;
        return tb.compareTo(ta);
      });

      // emulate offset slicing
      if (offset > 0) {
        if (deduped.length <= offset) return <Map<String, dynamic>>[];
        final end = (offset + limit) < deduped.length ? (offset + limit) : deduped.length;
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
  Future<List<Map<String, dynamic>>?> _fetchSoilGroupRows(String gid, {int offset = 0, int limit = 10}) async {
    try {
      // Ask consolidated endpoint for a larger window to allow client-side
      // filtering and slicing for a single group.
      final fetchLimit = ((offset + limit) * 6) > 200 ? 200 : ((offset + limit) * 6);
      var consolidated = await api.fetchSoilGroupHistory(limit: fetchLimit, offset: 0, synthetic: false);
      List<Map<String, dynamic>> rows = [];
      if (consolidated != null && consolidated.isNotEmpty) {
        rows = consolidated;
        // If the consolidated endpoint did not include rows for the requested
        // gid, prefer the more expensive per-source aggregator fallback so
        // groups that are missing from the consolidated response still show.
        try {
          final presentGroups = <String>{};
          for (final r in rows) {
            final gidRaw = r['GROUP_ID'] ?? r['group_id'] ?? r['Group'] ?? r['group'] ?? r['GROUP'] ?? r['GroupId'];
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
              final gidRaw = r['GROUP_ID'] ?? r['group_id'] ?? r['Group'] ?? r['group'] ?? r['GROUP'] ?? r['GroupId'];
              if (gidRaw != null) presentGroups.add(gidRaw.toString());
            }
            print('[debug] fetchSoilGroupRows consolidated returned ${rows.length} rows, groups: ${presentGroups.join(',')} for requested gid=$gid');
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
        final gidRaw = r['GROUP_ID'] ?? r['group_id'] ?? r['Group'] ?? r['group'] ?? r['GROUP'] ?? r['GroupId'];
        final g = gidRaw?.toString() ?? '';
        return g == gid;
      }).toList();
      if (kDebugMode) print('[debug] fetchSoilGroupRows filtered for gid=$gid -> ${filtered.length} rows (from ${rows.length} total)');

      // Normalize & sort newest-first
      filtered.sort((a, b) {
        final ta = UiHelpers.parseTimestamp(a['CREATED_AT'] ?? a['created_at'] ?? a['timestamp'] ?? a['Timestamp'] ?? a['T']);
        final tb = UiHelpers.parseTimestamp(b['CREATED_AT'] ?? b['created_at'] ?? b['timestamp'] ?? b['Timestamp'] ?? b['T']);
        if (ta == null && tb == null) return 0;
        if (ta == null) return 1;
        if (tb == null) return -1;
        return tb.compareTo(ta);
      });

      // Emulate offset/limit for this group's rows
      if (offset > 0) {
        if (filtered.length <= offset) return <Map<String, dynamic>>[];
        final end = (offset + limit) < filtered.length ? (offset + limit) : filtered.length;
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
      return Chip(label: Text('LIVE', style: TextStyle(fontSize: 12, color: Colors.white)), backgroundColor: Colors.green);
    }
    if (source == 'offline' || source == 'cache' || source == 'stale_cache') {
      return Chip(label: Text('OFFLINE — showing cached results', style: TextStyle(fontSize: 12)), backgroundColor: Colors.orange.shade200);
    }

    return Chip(label: Text(source, style: TextStyle(fontSize: 12)), backgroundColor: Colors.black12);
  }

  void _showSourceDetail(BuildContext context, String src, Map<String, dynamic> payload) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Source: $src'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: payload.entries.map((e) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [Text(e.key, style: TextStyle(fontWeight: FontWeight.w600)), SizedBox(width: 8), Expanded(child: Text(e.value?.toString() ?? ''))],
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('Close'))],
        );
      },
    );
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

