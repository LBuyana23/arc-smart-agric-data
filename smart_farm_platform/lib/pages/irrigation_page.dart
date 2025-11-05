import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
// Charting removed for irrigation page — charts are not needed; keep table-only UI
import '../theme/app_theme.dart';
// sensor_data model import unused by current UI
// irrigation_data model import removed (we read raw subgroup payloads directly)
import '../services/api_service.dart';
import '../widgets/no_data_placeholder.dart';
import '../utils/ui_helpers.dart';
import '../widgets/paginated_history.dart';

class IrrigationPage extends StatefulWidget {
  const IrrigationPage({super.key});

  @override
  State<IrrigationPage> createState() => _IrrigationPageState();
}

class _IrrigationPageState extends State<IrrigationPage>
    with AutomaticKeepAliveClientMixin {
  // _selectedTimeRange removed - time-series UI is not used currently
  // Representative-row helper removed; irrigation page now renders raw subgroup history directly.
  late final ApiService _api;
  late Future<Map<String, dynamic>?> _allSourcesFuture;
  String? _irrigationSourceLabel;

  @override
  void initState() {
    super.initState();
    _api = ApiService();
    _allSourcesFuture = _api.fetchAllGroupRaw('irrigation');
    _irrigationSourceLabel = _api.getSource('irrigation');
  }

  void _reloadSources({bool invalidateCache = false}) {
    if (!mounted) return;
    if (invalidateCache) {
      _api.invalidateGroupCache('irrigation');
    }
    setState(() {
      _allSourcesFuture = _api.fetchAllGroupRaw('irrigation');
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final source = _irrigationSourceLabel;
    final size = MediaQuery.of(context).size;
    final horizontalPadding = size.width < 640 ? 16.0 : 24.0;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 680;
              final heading = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Irrigation',
                          style: TextStyle(
                            color: AppTheme.foreground,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (source != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Chip(
                            label: Text(source, style: TextStyle(fontSize: 12)),
                            backgroundColor: Colors.black12,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Water flow monitoring and analysis',
                    style: TextStyle(
                      color: AppTheme.mutedForeground,
                      fontSize: 16,
                    ),
                  ),
                ],
              );

              final actions = Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  ElevatedButton.icon(
                    onPressed: () async {
                      await _forceRefreshAllIrrigationSources();
                    },
                    icon: const Icon(Icons.sync),
                    label: const Text('Refresh Server'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text(
                            'CSV export feature - Coming soon',
                          ),
                          backgroundColor: AppTheme.primaryGreen,
                        ),
                      );
                    },
                    icon: const Icon(Icons.download),
                    label: const Text('Export CSV'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      foregroundColor: AppTheme.darkBackground,
                    ),
                  ),
                ],
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [heading, const SizedBox(height: 12), actions],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: heading),
                  const SizedBox(width: 16),
                  actions,
                ],
              );
            },
          ),
          SizedBox(height: 24),
          // Render a section per irrigation subgroup (charts + last 10 rows table)
          FutureBuilder<Map<String, dynamic>?>(
            future: _allSourcesFuture,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 80,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (!snap.hasData ||
                  snap.data == null ||
                  (snap.data as Map).isEmpty) {
                return const NoDataPlaceholder(
                  message: 'No irrigation sources found',
                );
              }
              final map = Map<String, dynamic>.from(snap.data as Map);

              return Column(
                children: map.entries.map((entry) {
                  final src = entry.key;
                  Map<String, dynamic>? payloadMap;
                  try {
                    if (entry.value is Map<String, dynamic>) {
                      payloadMap = Map<String, dynamic>.from(
                        entry.value as Map,
                      );
                    }
                  } catch (_) {}

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            UiHelpers.groupLabel('Irrigation', src),
                            style: TextStyle(
                              color: AppTheme.foreground,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          PaginatedHistory(
                            group: 'irrigation',
                            source: src,
                            limit: 10,
                            fetcher: (offset, limit) =>
                                _fetchGroupHistoryWithFallback(
                                  'irrigation',
                                  src.toString(),
                                  payloadMap,
                                  offset,
                                  limit,
                                  null,
                                ),
                            builder: (context, rows, page, changePage) {
                              if (rows.isEmpty) {
                                if (payloadMap != null &&
                                    payloadMap.isNotEmpty) {
                                  if (payloadMap.length == 1 &&
                                      payloadMap.containsKey('error')) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'No history available yet for this source',
                                          style: TextStyle(
                                            color: AppTheme.mutedForeground,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 6,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
                                            ElevatedButton.icon(
                                              onPressed: () async {
                                                final sc = ScaffoldMessenger.of(
                                                  context,
                                                );
                                                sc.showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Requesting server refresh for $src...',
                                                    ),
                                                  ),
                                                );
                                                var ok = await _api
                                                    .forceRefreshGroupSource(
                                                      'irrigation',
                                                      src.toString(),
                                                    );
                                                if (!ok) {
                                                  ok = await _api
                                                      .forceRefreshGroupSource(
                                                        'irrigation',
                                                        'irrigation_telemetry',
                                                      );
                                                }
                                                sc.hideCurrentSnackBar();
                                                if (ok) {
                                                  sc.showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        'Refresh requested; data should appear shortly',
                                                      ),
                                                    ),
                                                  );
                                                  await Future.delayed(
                                                    const Duration(seconds: 2),
                                                  );
                                                  _reloadSources(
                                                    invalidateCache: true,
                                                  );
                                                } else {
                                                  sc.showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        'Server refresh failed (check bridge logs)',
                                                      ),
                                                    ),
                                                  );
                                                }
                                              },
                                              icon: const Icon(Icons.sync),
                                              label: const Text(
                                                'Force-refresh this source',
                                              ),
                                            ),
                                            Text(
                                              'Bridge reports: ${payloadMap['error']}',
                                              style: TextStyle(
                                                color: AppTheme.mutedForeground,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    );
                                  }

                                  final cols = payloadMap.keys.toList();
                                  final displayCols = UiHelpers.pickDefaultCols(
                                    cols,
                                    'irrigation',
                                    hasImage: false,
                                    expanded: false,
                                  );
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        child: Text(
                                          'Latest snapshot (no history yet)',
                                          style: TextStyle(
                                            color: AppTheme.mutedForeground,
                                          ),
                                        ),
                                      ),
                                      SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: DataTable(
                                          columnSpacing: 16,
                                          columns: displayCols
                                              .map(
                                                (c) => DataColumn(
                                                  label: Text(
                                                    UiHelpers.friendlyName(c),
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                          rows: [
                                            DataRow(
                                              cells: displayCols
                                                  .map(
                                                    (c) => DataCell(
                                                      SizedBox(
                                                        width: 140,
                                                        child: Text(
                                                          UiHelpers.formatCell(
                                                            (payloadMap ??
                                                                    {})[c] ??
                                                                '',
                                                            c,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  )
                                                  .toList(),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                }

                                return Text(
                                  'No history available',
                                  style: TextStyle(
                                    color: AppTheme.mutedForeground,
                                  ),
                                );
                              }

                              final sortedRows =
                                  List<Map<String, dynamic>>.from(rows);
                              sortedRows.sort((a, b) {
                                final ta = UiHelpers.parseTimestamp(
                                  a['CREATED_AT'] ??
                                      a['Timestamp'] ??
                                      a['timestamp'] ??
                                      a['T'],
                                );
                                final tb = UiHelpers.parseTimestamp(
                                  b['CREATED_AT'] ??
                                      b['Timestamp'] ??
                                      b['timestamp'] ??
                                      b['T'],
                                );
                                if (ta == null && tb == null) return 0;
                                if (ta == null) return 1;
                                if (tb == null) return -1;
                                return tb.compareTo(ta);
                              });

                              final recent = sortedRows;
                              final cols = rows.first.keys.toList();
                              final displayCols = UiHelpers.pickDefaultCols(
                                cols,
                                'irrigation',
                                hasImage: false,
                                expanded: false,
                              );
                              final totalCandidates = [
                                'TOTAL_VOLUME',
                                'total_volume',
                                'totalVolume',
                                'total_flow',
                                'totalFlow',
                              ];
                              String? totalKey;
                              for (final k in totalCandidates) {
                                if (cols.contains(k)) {
                                  totalKey = k;
                                  break;
                                }
                              }
                              if (totalKey != null &&
                                  !displayCols.contains(totalKey)) {
                                final flowCandidates = [
                                  'FLOW_RATE_LMIN',
                                  'flow_rate_Lmin',
                                  'flow_rate_lmin',
                                  'flowRateLmin',
                                  'flow_rate',
                                  'flowRate',
                                ];
                                int insertAt = displayCols.length;
                                for (final f in flowCandidates) {
                                  final idx = displayCols.indexOf(f);
                                  if (idx >= 0) {
                                    insertAt = idx + 1;
                                    break;
                                  }
                                }
                                if (insertAt > displayCols.length) {
                                  insertAt = displayCols.length;
                                }
                                try {
                                  displayCols.insert(insertAt, totalKey);
                                } catch (_) {
                                  displayCols.add(totalKey);
                                }
                              }

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Text(
                                      'Recent raw rows (last ${recent.length} rows — tap to open full payload)',
                                      style: TextStyle(
                                        color: AppTheme.mutedForeground,
                                      ),
                                    ),
                                  ),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: DataTable(
                                      columnSpacing: 16,
                                      columns: displayCols
                                          .map(
                                            (c) => DataColumn(
                                              label: Text(
                                                UiHelpers.friendlyName(c),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                      rows: recent
                                          .map(
                                            (r) => DataRow(
                                              cells: displayCols
                                                  .map(
                                                    (c) => DataCell(
                                                      SizedBox(
                                                        width: 140,
                                                        child: Text(
                                                          UiHelpers.formatCell(
                                                            r[c],
                                                            c,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  )
                                                  .toList(),
                                              onSelectChanged: (_) =>
                                                  _showSourceDetail(
                                                    context,
                                                    src,
                                                    r,
                                                  ),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          SizedBox(height: 24),
          // Raw data table is rendered inside the FutureBuilder above so it can include latest data
        ],
      ),
    );
  }

  // Charting helpers removed — irrigation page no longer contains charts.

  void _showSourceDetail(
    BuildContext context,
    String src,
    Map<String, dynamic> payload,
  ) {
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
                    children: [
                      Text(
                        e.key,
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      SizedBox(width: 8),
                      Expanded(child: Text(e.value?.toString() ?? '')),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  // Legacy snapshot card and helpers removed — irrigation page now renders per-subgroup only

  @override
  bool get wantKeepAlive => true;

  Future<void> _forceRefreshAllIrrigationSources() async {
    final sc = ScaffoldMessenger.of(context);
    sc.showSnackBar(
      SnackBar(
        content: Text('Requesting server refresh for irrigation sources...'),
      ),
    );
    final keysMap = await _api.fetchAllGroupRaw('irrigation');
    final sources = <String>{};
    if (keysMap != null && keysMap.isNotEmpty) {
      keysMap.forEach((rawKey, rawValue) {
        Map<String, dynamic>? payload;
        if (rawValue is Map) {
          try {
            payload = Map<String, dynamic>.from(rawValue);
          } catch (_) {}
        }
        sources.addAll(_refreshCandidatesFor(rawKey.toString(), payload));
      });
    }
    if (sources.isEmpty) {
      sources.addAll({'irrigation_telemetry', 'DEFAULT', 'default', 'telemetry', '1', '2'});
    } else {
      sources.addAll({'irrigation_telemetry', 'DEFAULT', 'default', 'telemetry'});
    }

    var anyOk = false;
    for (final s in sources) {
      try {
        final ok = await _api.forceRefreshGroupSource('irrigation', s);
        if (ok) anyOk = true;
        await Future.delayed(Duration(milliseconds: 300));
      } catch (e) {
        if (kDebugMode) print('force refresh irrigation $s error: $e');
      }
    }

    sc.hideCurrentSnackBar();
    if (anyOk) {
      sc.showSnackBar(
        SnackBar(content: Text('Server refresh requested — reloading data...')),
      );
      await Future.delayed(Duration(seconds: 1));
      _reloadSources(invalidateCache: true);
    } else {
      sc.showSnackBar(
        SnackBar(
          content: Text(
            'Server refresh failed for all irrigation sources (check bridge logs)',
          ),
        ),
      );
    }
  }
}

// Add fallback helper to try several candidate source names when consolidated endpoint isn't ready
extension _IrrigationFetchFallback on _IrrigationPageState {
  List<String> _refreshCandidatesFor(String src, Map<String, dynamic>? payload) {
    final seen = <String>{};
    void add(String? value) {
      if (value == null) return;
      final trimmed = value.trim();
      if (trimmed.isEmpty) return;
      seen.add(trimmed);
      seen.add(trimmed.toLowerCase());
    }

    add(src);
    add(src.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_'));

    if (payload != null) {
      for (final key in ['SOURCE', 'source', 'source_name', 'name', 'group_id', 'group']) {
        try {
          add(payload[key]?.toString());
        } catch (_) {}
      }
    }

    final match = RegExp(r"\d+").firstMatch(src);
    if (match != null) {
      final digits = match.group(0)!;
      add('irrigation_$digits');
      add('irrigation_g$digits');
      add('g$digits');
      add('G$digits');
      add(digits);
    }

    // Remove empties and return unique list preserving insertion order roughly.
    final ordered = <String>[];
    for (final candidate in seen) {
      if (candidate.trim().isEmpty) continue;
      if (!ordered.contains(candidate)) ordered.add(candidate);
    }
    return ordered;
  }

  Future<List<Map<String, dynamic>>> _fetchGroupHistoryWithFallback(
    String group,
    String src,
    Map<String, dynamic>? payloadMap,
    int offset,
    int limit,
    String? duration,
  ) async {
    final candidates = <String>[];
    candidates.add(src);
    if (payloadMap != null) {
      for (final k in [
        'SOURCE',
        'source',
        'source_name',
        'name',
        'group_id',
        'group',
      ]) {
        try {
          final v = payloadMap[k];
          if (v != null) candidates.add(v.toString());
        } catch (_) {}
      }
    }
    final m = RegExp(r"\d+").firstMatch(src);
    if (m != null) {
      final d = m.group(0)!;
      candidates.add('${group}_g$d');
      candidates.add('${group}_$d');
      candidates.add('g$d');
      candidates.add('G$d');
      candidates.add(d);
    }
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
        final r = await _api.fetchGroupHistory(
          group,
          cand,
          limit: limit,
          offset: offset,
          duration: duration,
        );
        if (r != null && r.isNotEmpty) return r;
      } catch (_) {}
    }
    try {
      final r = await _api.fetchGroupHistory(
        group,
        src.toString(),
        limit: limit,
        offset: offset,
        duration: duration,
      );
      if (r != null && r.isNotEmpty) return r;
    } catch (_) {}
    return <Map<String, dynamic>>[];
  }
}
