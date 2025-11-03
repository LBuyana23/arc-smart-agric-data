import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import '../widgets/no_data_placeholder.dart';
import '../widgets/paginated_history.dart';
import '../theme/app_theme.dart';
import '../utils/ui_helpers.dart';

class CropVisionPage extends StatefulWidget {
  const CropVisionPage({super.key});

  @override
  State<CropVisionPage> createState() => _CropVisionPageState();
}

class _CropVisionPageState extends State<CropVisionPage> with AutomaticKeepAliveClientMixin {
  final ApiService api = ApiService();
  // reserved for future UI state (expanded tables) — currently unused
  Map<String, dynamic>? _upstreamsConfig;

  @override
  void initState() {
    super.initState();
    // fetch upstream config lazily in background so image resolution can work
    _ensureUpstreamsConfig();
  }

  Future<void> _ensureUpstreamsConfig() async {
    if (_upstreamsConfig != null) return;
    try {
      final resp = await http.get(Uri.parse('${api.baseUrl}/config/upstreams')).timeout(Duration(seconds: 8));
      if (resp.statusCode == 200) {
        _upstreamsConfig = jsonDecode(resp.body) as Map<String, dynamic>;
        if (mounted) setState(() {});
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      'Crop Vision',
                      style: TextStyle(color: AppTheme.foreground, fontSize: 32, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: 8),
                  _buildStatusChip(api.getSource('crop_vision'))
                ],
              ),
            ),
          ]),
          SizedBox(height: 8),
          Text('AI-powered crop health monitoring', style: TextStyle(color: AppTheme.mutedForeground)),
          SizedBox(height: 16),

          FutureBuilder<Map<String, dynamic>?>(
            future: api.fetchAllGroupRaw('crop_vision'),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) return SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
              if (!snap.hasData || snap.data == null) return NoDataPlaceholder(onRetry: () async { try { await api.refreshCropVision(); } catch (_) {} });
              final map = snap.data!;
              if (map.isEmpty) return NoDataPlaceholder(onRetry: () async { try { await api.refreshCropVision(); } catch (_) {} });

              return Column(
                children: map.keys.map((src) => _buildGroupSection(src)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGroupSection(String src) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(UiHelpers.groupLabel('Crop Vision', src), style: TextStyle(color: AppTheme.foreground, fontSize: 18, fontWeight: FontWeight.w700)),
          SizedBox(height: 8),
          PaginatedHistory(
            group: 'crop_vision',
            source: src,
            limit: 10,
            builder: (context, rows, page, changePage) {
              if (rows.isEmpty) return Text('No history available');

              // sort ascending and take last page-size items
              rows.sort((a, b) {
                final ta = UiHelpers.parseTimestamp(a['CREATED_AT'] ?? a['Timestamp'] ?? a['timestamp'] ?? a['T']);
                final tb = UiHelpers.parseTimestamp(b['CREATED_AT'] ?? b['Timestamp'] ?? b['timestamp'] ?? b['T']);
                if (ta == null && tb == null) return 0;
                if (ta == null) return 1;
                if (tb == null) return -1;
                return ta.compareTo(tb);
              });

              final recent = rows.length > 10 ? rows.sublist(rows.length - 10) : rows;

              // detect keys
              final rawCols = rows.first.keys.toList();
              String? labelKey;
              for (final candidate in ['label', 'class', 'prediction', 'predicted_label']) {
                if (rawCols.contains(candidate)) {
                  labelKey = candidate;
                }
              }
              String? confKey;
              for (final candidate in ['confidence', 'score', 'probability']) {
                if (rawCols.contains(candidate)) {
                  confKey = candidate;
                }
              }
              String? recKey;
              for (final candidate in ['recommendation', 'recommendations', 'recommend', 'action', 'advice']) {
                if (rawCols.contains(candidate)) {
                  recKey = candidate;
                }
              }

              // Build BarChart for the 10 most recent readings (each bar = one reading).
              // The Y axis is confidence in range 0..100. X axis has no visible labels.
              Widget confChart() {
                if (confKey == null || labelKey == null) return SizedBox.shrink();

                final items = <Map<String, dynamic>>[];
                for (final r in recent) {
                  final lab = (r[labelKey] ?? '').toString();
                  double? v = double.tryParse((r[confKey] ?? '').toString());
                  if (v == null) continue;
                  // Normalize 0..1 -> 0..100
                  if (v <= 1.0) v = (v * 100.0);
                  // clamp
                  v = v.clamp(0.0, 100.0);
                  items.add({'label': lab, 'conf': v});
                }

                if (items.isEmpty) return SizedBox.shrink();

                final groups = <BarChartGroupData>[];
                for (int i = 0; i < items.length; i++) {
                  final val = (items[i]['conf'] as double?) ?? 0.0;
                  groups.add(BarChartGroupData(
                    x: i,
                    barRods: [BarChartRodData(toY: val, color: AppTheme.primaryGreen, width: 18)],
                    showingTooltipIndicators: [0],
                  ));
                }

                return SizedBox(
                  width: double.infinity,
                  height: 280,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(padding: EdgeInsets.symmetric(horizontal: 6.0, vertical: 4), child: Text('Confidence (latest ${items.length})', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                          SizedBox(height: 8),
                          // Constrain chart to avoid overflow; Expanded inside a fixed-height SizedBox
                          Expanded(
                            child: LayoutBuilder(builder: (ctx, constraints) {
                                          // Compute bar width and spacing to avoid overlaps.
                                          final available = constraints.maxWidth;
                                          final count = math.max(1, items.length);
                                          // ideal bar width is a fraction of the per-item slot
                                          double barWidth = (available / count) * 0.6;
                                          barWidth = barWidth.clamp(8.0, 48.0);
                                          // compute groupsSpace so bars + gaps fit within available width
                                          double groupsSpace = 4.0;
                                          if (count > 1) {
                                            final remaining = (available - (barWidth * count)).clamp(0.0, available);
                                            groupsSpace = math.max(4.0, remaining / (count - 1));
                                          }

                                          final adjustedGroups = groupsSpace;

                                          // Rebuild bar groups with computed barWidth and without always-visible tooltips
                                          final adjustedGroupsList = <BarChartGroupData>[];
                                          for (int i = 0; i < items.length; i++) {
                                            final val = (items[i]['conf'] as double?) ?? 0.0;
                                            adjustedGroupsList.add(BarChartGroupData(
                                              x: i,
                                              barRods: [BarChartRodData(toY: val, color: AppTheme.primaryGreen, width: barWidth)],
                                              // Do not show tooltips by default; allow touch to reveal them
                                              showingTooltipIndicators: const [],
                                            ));
                                          }

                                          return BarChart(
                                            BarChartData(
                                              minY: 0,
                                              maxY: 100,
                                              gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 25),
                                              titlesData: FlTitlesData(
                                                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 48, interval: 25, getTitlesWidget: (v, meta) => Padding(padding: EdgeInsets.only(right: 6), child: Text(v.toInt().toString(), style: TextStyle(color: AppTheme.mutedForeground, fontSize: 11))))),
                                                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                              ),
                                              barGroups: adjustedGroupsList,
                                              barTouchData: BarTouchData(
                                                enabled: true,
                                                touchTooltipData: BarTouchTooltipData(
                                                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                                    final idx = group.x.toInt();
                                                    if (idx < 0 || idx >= items.length) return null;
                                                    final label = (items[idx]['label'] as String?) ?? '';
                                                    final value = (rod.toY).toDouble();
                                                    var displayLabel = label;
                                                    if (displayLabel.length > 28) {
                                                      displayLabel = '${displayLabel.substring(0, 25)}...';
                                                    }
                                                    return BarTooltipItem('$displayLabel\n${value.toStringAsFixed(2)}', TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600));
                                                  },
                                                ),
                                              ),
                                              alignment: BarChartAlignment.start,
                                              groupsSpace: adjustedGroups,
                                            ),
                                          );
                                        }),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(padding: EdgeInsets.only(bottom: 8), child: Text('History (latest ${rows.length}) - shows recent detections and metadata', style: TextStyle(color: AppTheme.mutedForeground))),
                  confChart(),
                  // vertical cards
                  Column(
                    children: recent.reversed.map((r) {
                      final img = r['imageUrl'] ?? r['IMAGE_URL'] ?? r['image_url'] ?? r['image'];
                      final label = labelKey != null ? (r[labelKey]?.toString() ?? '') : '';
                      final rec = recKey != null ? (r[recKey]?.toString() ?? '') : '';
                      final confVal = confKey != null ? (r[confKey]?.toString() ?? '') : '';
                      final tsRaw = r['CREATED_AT'] ?? r['Timestamp'] ?? r['timestamp'] ?? r['T'];
                      final tsLabel = tsRaw == null ? '' : UiHelpers.formatCell(tsRaw, 'created_at');
                      // Resolve non-http image paths by attempting to prefix with
                      // the configured upstream URL for this source. We fetch
                      // /api/config/upstreams lazily and cache it in-state.
                      String? resolvedImg;
                      try {
                        final imgS = img?.toString();
                        if (imgS != null && imgS.isNotEmpty) {
                          if (imgS.toLowerCase().startsWith('http')) {
                            resolvedImg = imgS;
                          } else {
                            final cfg = _upstreamsConfig;
                            String? pref;
                            try {
                              pref = cfg?['crop_vision']?[src]?['url'] as String?;
                            } catch (_) {
                              pref = null;
                            }
                            if (pref == null) {
                              try {
                                pref = cfg?['crop_vision']?[src.toUpperCase()]?['url'] as String?;
                              } catch (_) {
                                pref = null;
                              }
                            }
                            if (pref != null && pref.isNotEmpty) {
                              if (pref.endsWith('/') && !imgS.startsWith('/')) {
                                resolvedImg = '$pref$imgS';
                              } else {
                                resolvedImg = '${pref.replaceAll(RegExp(r'/$'), '')}/${imgS.replaceAll(RegExp(r'^/'), '')}';
                              }
                            } else {
                              // fallback: prefix with bridge base host (strip /api)
                              final base = api.baseUrl.replaceAll(RegExp(r'/api\/\?$'), '');
                              resolvedImg = '$base/${imgS.replaceAll(RegExp(r'^/'), '')}';
                            }
                          }
                        }
                      } catch (_) {
                        resolvedImg = img?.toString();
                      }

                      final resolvedImgStr = resolvedImg?.toString() ?? '';
                      // If this is crop_vision G4, prefer routing the image through
                      // the bridge proxy to avoid CORS/redirect/auth issues.
                      // Prefer using direct HTTP(S) image URLs when present.
                      // Only route through the bridge proxy when the resolved URL
                      // is not an absolute HTTP(S) URL (e.g. a relative path) and
                      // the proxy is available to handle CORS/auth issues.
                      String displayImgUrl = resolvedImgStr;
                      try {
                        final lower = resolvedImgStr.toLowerCase();
                        final isAbsolute = lower.startsWith('http');
                        final isHttpOnly = lower.startsWith('http://');
                        // Force-proxy heuristic for known problematic sources (e.g. G4)
                        final srcLower = src.toString().toLowerCase();
                        final forceProxyForG4 = srcLower.contains('g4') || srcLower.endsWith('_g4') || srcLower.endsWith('g4');

                        final base = api.baseUrl.replaceAll(RegExp(r'/api\/?$'), '');
                        if ((!isAbsolute && resolvedImgStr.isNotEmpty) || isHttpOnly || forceProxyForG4) {
                          // Non-absolute, or http (not https), or explicit G4 sources: proxy via bridge
                          displayImgUrl = '$base/api/proxy/image?url=${Uri.encodeComponent(resolvedImgStr)}';
                        } else {
                          // Absolute https urls: use directly for performance
                          displayImgUrl = resolvedImgStr;
                        }
                      } catch (_) {
                        displayImgUrl = resolvedImgStr;
                      }

                      return Card(
                        margin: EdgeInsets.symmetric(vertical: 6),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (resolvedImgStr.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(right: 12.0),
                                  child: SizedBox(
                                    width: 88,
                                    height: 88,
                                    child: Image.network(
                                      displayImgUrl,
                                      width: 88,
                                      height: 88,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Center(child: Icon(Icons.broken_image)),
                                      loadingBuilder: (ctx, child, progress) {
                                        if (progress == null) return child;
                                        return Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)));
                                      },
                                    ),
                                  ),
                                ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (label.isNotEmpty) Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                    if (rec.isNotEmpty) ...[SizedBox(height: 6), Text(rec, style: TextStyle(color: AppTheme.mutedForeground), softWrap: true)],
                                    SizedBox(height: 8),
                                    Row(children: [if (confKey != null) Text('Confidence: $confVal', style: TextStyle(fontWeight: FontWeight.w600)), Spacer(), if (tsLabel.isNotEmpty) Text(tsLabel, style: TextStyle(color: AppTheme.mutedForeground, fontSize: 12))]),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
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

  @override
  bool get wantKeepAlive => true;

  // helper dialogs removed — currently unused. Re-add if detailed inspection UI is needed.
}

