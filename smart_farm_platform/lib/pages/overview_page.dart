// lib/pages/overview_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../services/geocoding_service.dart';
import '../services/ai_integration.dart';
import '../services/api_service.dart';
import '../utils/ui_helpers.dart';
import 'dart:async';

class OverviewPage extends StatefulWidget {
  const OverviewPage({super.key});

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  String _selectedWindow = '1h';
  Future<Map<String, dynamic>>? _metricsFuture;

  void _loadMetrics() {
    _metricsFuture = _gatherOverviewMetrics(_selectedWindow);
    // refresh UI when metrics complete
    _metricsFuture!.then((_) {
      if (mounted) setState(() {});
    });
  }

  void _onWindowChanged(String? v) {
    if (v == null) return;
    setState(() {
      _selectedWindow = v;
      _loadMetrics();
    });
  }

  @override
  void initState() {
    super.initState();
    _loadMetrics();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Dashboard Overview', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              Row(children: [
                const Text('Window: '),
                DropdownButton<String>(value: _selectedWindow, items: const [
                  DropdownMenuItem(value: '1h', child: Text('Past 1 Hour')),
                  DropdownMenuItem(value: '24h', child: Text('Past 24 Hours')),
                  DropdownMenuItem(value: '7d', child: Text('Past 7 Days')),
                ], onChanged: _onWindowChanged),
              ])
            ]),
            const SizedBox(height: 8),
            const Text('Real-time monitoring and insights', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 24),
            FutureBuilder<Map<String, dynamic>>(
              future: _metricsFuture,
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) return Center(child: SizedBox(height: 120, child: CircularProgressIndicator()));
                final metrics = snap.hasData ? snap.data! : <String, dynamic>{};
                return Column(children: [
                  _buildSummaryGrid(context, appState, metrics, _selectedWindow),
                  const SizedBox(height: 12),
                  _buildNarrativeCard(context, appState, metrics, _selectedWindow),
                  const SizedBox(height: 16),
                  _buildWeatherCard(context, appState),
                  const SizedBox(height: 24),
                  _buildAlertsAndInsights(context, appState, metrics, _selectedWindow),
                ]);
              },
            ),
          ],
        ),
      ),
    );
  }
}

Widget _summaryCard(BuildContext context, {required String title, required String value, String? subtitle}) {
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withAlpha((0.9 * 255).round()), fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                if (subtitle != null) ...[const SizedBox(height: 6), Text(subtitle, style: TextStyle(color: Theme.of(context).disabledColor))],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildSummaryGrid(BuildContext context, AppState appState, Map<String, dynamic> metrics, String window) {
  return LayoutBuilder(builder: (context, constraints) {
    final isWide = constraints.maxWidth > 900;

    // Helper to prefer metric values from the gathered metrics, falling back to AppState
    String greenhouseTitle() {
      final g = metrics['greenhouse'] as Map<String, dynamic>?;
      if (g != null) {
        final avg = g['avgTemp'];
        final hum = g['avgHumidity'];
        return avg != null
            ? hum != null
                ? "${(avg as double).toStringAsFixed(1)}°C · H ${(hum as double).toStringAsFixed(0)}%"
                : "${(avg as double).toStringAsFixed(1)}°C"
            : '—';
      }
      return appState.greenhouseAvgTemp != null
          ? appState.greenhouseAvgHumidity != null
              ? "${appState.greenhouseAvgTemp!.toStringAsFixed(1)}°C · H ${appState.greenhouseAvgHumidity!.toStringAsFixed(0)}%"
              : "${appState.greenhouseAvgTemp!.toStringAsFixed(1)}°C"
          : '—';
    }

    final cards = [
      _summaryCard(
        context,
        title: 'Greenhouse',
        value: greenhouseTitle(),
        subtitle: metrics['greenhouse'] != null ? 'Count: ${(metrics['greenhouse'] as Map)['count'] ?? 0} rows ($window)' : null,
      ),
      _summaryCard(
        context,
        title: 'Irrigation',
        value: metrics['irrigation'] != null && (metrics['irrigation'] as Map)['flowAvg'] != null
            ? '${((metrics['irrigation'] as Map)['flowAvg'] as double).toStringAsFixed(1)} L/min'
            : (appState.irrigationFlowSum != null ? '${appState.irrigationFlowSum!.toStringAsFixed(1)} L/min' : '—'),
        subtitle: metrics['irrigation'] != null ? 'Pumps: ${(metrics['irrigation'] as Map)['pumpsOn'] ?? appState.irrigationPumpsOn}/${(metrics['irrigation'] as Map)['pumpsTotal'] ?? appState.irrigationTotalPumps} ($window)' : '${appState.irrigationPumpsOn}/${appState.irrigationTotalPumps} Pumps Active',
      ),
      _summaryCard(
        context,
        title: 'Soil',
        value: metrics['soil'] != null && (metrics['soil'] as Map)['avgMoisture'] != null
            ? '${((metrics['soil'] as Map)['avgMoisture'] as double).toStringAsFixed(1)}%'
            : (appState.soilAvgMoisture != null ? '${appState.soilAvgMoisture!.toStringAsFixed(1)}%' : '—'),
        subtitle: metrics['soil'] != null && (metrics['soil'] as Map)['avgPh'] != null
            ? 'pH ${((metrics['soil'] as Map)['avgPh'] as double).toStringAsFixed(2)}'
            : (appState.soilAvgPh != null ? 'pH ${appState.soilAvgPh!.toStringAsFixed(2)}' : null),
      ),
      _summaryCard(
        context,
        title: 'Crop Vision',
        value: metrics['crop'] != null ? '${(metrics['crop'] as Map)['threats'] ?? 0} Threats Detected' : '${appState.cropThreatsCount} Threats Detected',
        subtitle: metrics['crop'] != null && (metrics['crop'] as Map)['topLabel'] != null && (metrics['crop'] as Map)['topConf'] != null
            ? '${(metrics['crop'] as Map)['topLabel']} - ${(((metrics['crop'] as Map)['topConf'] as double) * 100).toStringAsFixed(1)}%'
            : (appState.topCropThreatLabel != null && appState.topCropThreatConfidence != null ? '${appState.topCropThreatLabel} - ${(appState.topCropThreatConfidence! * 100).toStringAsFixed(2)}%' : null),
      ),
    ];

    if (isWide) {
      return GridView.count(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: cards,
      );
    } else {
      return Column(children: cards.map((c) => Padding(padding: const EdgeInsets.only(bottom: 12), child: c)).toList());
    }
  });
}

Widget _buildWeatherCard(BuildContext context, AppState appState) {
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: main weather block (expands)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Weather', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (appState.currentTemperature != null)
                  // Use Wrap so items flow to the next line on narrow widths
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      Icon(_mapWeatherCodeToIcon(appState.currentWeatherCode ?? 0), size: 28),
                      Text('${appState.currentTemperature!.toStringAsFixed(1)}°C', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      TextButton(onPressed: () => _showSetLocationDialog(context, appState), child: const Text('Change Location')),
                    ],
                  )
                else
                  Wrap(
                    spacing: 12,
                    children: [
                      const Text('Set your farm\'s location to see the weather'),
                      ElevatedButton(onPressed: () => _showSetLocationDialog(context, appState), child: const Text('Set Location')),
                    ],
                  ),
              ],
            ),
          ),

          // Right: three-day forecast — allow horizontal scrolling to avoid overflow
          if (appState.threeDayForecast.isNotEmpty)
            SizedBox(
              height: 72,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: appState.threeDayForecast.map((d) {
                    final date = DateTime.parse(d['date'] as String);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${date.month}/${date.day}', style: const TextStyle(fontSize: 12)),
                          const SizedBox(height: 4),
                          Text('${(d['max'] as double).round()}°/${(d['min'] as double).round()}°', style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          // End of children for Row
        ],
      ),
    ),
  );
}

IconData _mapWeatherCodeToIcon(int code) {
  if (code == 0) return Icons.wb_sunny;
  if (code == 1 || code == 2 || code == 3) return Icons.wb_cloudy;
  if (code >= 45 && code <= 48) return Icons.foggy;
  if (code >= 51 && code <= 67) return Icons.grain;
  if (code >= 71 && code <= 77) return Icons.ac_unit;
  if (code >= 80 && code <= 86) return Icons.umbrella;
  if (code >= 95) return Icons.thunderstorm;
  return Icons.help_outline;
}

void _showSetLocationDialog(BuildContext context, AppState appState) {
  final TextEditingController controller = TextEditingController();
  final geo = GeocodingService();
  showDialog<void>(context: context, builder: (ctx) {
    String? error;
    bool loading = false;
    return StatefulBuilder(builder: (ctx2, setState) {
      return AlertDialog(
        title: const Text('Set farm location'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: controller, decoration: const InputDecoration(labelText: 'City name')),
          if (error != null) Padding(padding: const EdgeInsets.only(top:8), child: Text(error!, style: const TextStyle(color: Colors.red))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx2).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: loading ? null : () async {
              final city = controller.text.trim();
              if (city.isEmpty) {
                setState(() { error = 'Enter a city name'; });
                return;
              }
              setState(() { loading = true; error = null; });
              final coords = await geo.getCoordinatesForCity(city);
              if (coords == null) {
                setState(() { loading = false; error = 'No location found'; });
                return;
              }
              await appState.setWeatherLocation(coords['lat']!, coords['lon']!);
              Navigator.of(ctx2).pop();
            },
            child: const Text('Search & Save'),
          ),
        ],
      );
    });
  });
}

Widget _buildAlertsAndInsights(BuildContext context, AppState appState, Map<String, dynamic> metrics, String window) {
  final alerts = <String>[];
  final gh = metrics['greenhouse'] as Map<String, dynamic>?;
  final soil = metrics['soil'] as Map<String, dynamic>?;
  if (gh != null && gh['avgTemp'] != null && (gh['avgTemp'] as double) > 35) alerts.add('High greenhouse temperature (${(gh['avgTemp'] as double).toStringAsFixed(1)}°C)');
  if (soil != null && soil['avgMoisture'] != null && (soil['avgMoisture'] as double) < 25) alerts.add('Low soil moisture (${(soil['avgMoisture'] as double).toStringAsFixed(1)}%)');

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (alerts.isNotEmpty)
        Card(
          color: Colors.red.withAlpha(13),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Alerts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
                const SizedBox(height: 8),
                ...alerts.map((a) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(a, style: const TextStyle(color: Colors.red)))),
              ],
            ),
          ),
        ),

      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Insights', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Combined system health: ${alerts.isEmpty ? 'OK' : 'Degraded'}'),
              const SizedBox(height: 6),
              Text('Window: $window  •  Last update: ${DateTime.now().toLocal().toIso8601String()}'),
              const SizedBox(height: 12),
              // Windowed metric highlights
              if (gh != null) ...[
                Text('Greenhouse — Avg ${(gh['avgTemp'] as double?)?.toStringAsFixed(1) ?? '—'}°C, Hum ${(gh['avgHumidity'] as double?)?.toStringAsFixed(0) ?? '—'}% (n=${gh['count'] ?? 0})'),
              ],
              if (soil != null) ...[
                Text('Soil — Moisture ${(soil['avgMoisture'] as double?)?.toStringAsFixed(1) ?? '—'}%, pH ${(soil['avgPh'] as double?)?.toStringAsFixed(2) ?? '—'} (n=${soil['count'] ?? 0})'),
              ],
              if (metrics['irrigation'] != null)
                Text('Irrigation — Flow avg ${(metrics['irrigation'] as Map)['flowAvg'] != null ? (metrics['irrigation'] as Map)['flowAvg'].toStringAsFixed(1) : '—'} L/min'),
              if (metrics['crop'] != null)
                Text('Crop Vision — ${(metrics['crop'] as Map)['threats'] ?? 0} issues in window'),
            ],
          ),
        ),
      ),
    ],
  );
}

Widget _buildNarrativeCard(BuildContext context, AppState appState, Map<String, dynamic> metrics, String window) {
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Farm Narrative', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: () async {
                  // Generate a quick AI-style summary (local fallback). Pass the full windowed metrics.
                  final scaffold = ScaffoldMessenger.of(context);
                  scaffold.showSnackBar(const SnackBar(content: Text('Generating summary...')));
                  try {
                    final txt = await AiIntegration.generateDetailedSummary(metrics, window: window);
                    scaffold.hideCurrentSnackBar();
                    showDialog<void>(context: context, builder: (ctx) => AlertDialog(title: const Text('AI Summary'), content: Text(txt), actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close'))]));
                  } catch (e) {
                    scaffold.hideCurrentSnackBar();
                    scaffold.showSnackBar(const SnackBar(content: Text('Failed to generate summary')));
                  }
                },
                icon: const Icon(Icons.smart_toy),
                label: const Text('Generate AI Summary'),
                style: ElevatedButton.styleFrom(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Local heuristics preview — prefer windowed metrics when available
          Text(_localNarrativePreview(appState), style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 12),
          Text('Tip: enable real AI by supplying an API key at build time via --dart-define=AI_STUDIO_KEY=<key>. The app will then allow remote generation if you implement calls in lib/services/ai_integration.dart.', style: TextStyle(color: Theme.of(context).disabledColor, fontSize: 12)),
        ],
      ),
    ),
  );
}

String _localNarrativePreview(AppState s) {
  final parts = <String>[];
  if (s.greenhouseAvgTemp != null) parts.add('Greenhouse ${s.greenhouseAvgTemp!.toStringAsFixed(1)}°C');
  if (s.greenhouseAvgHumidity != null) parts.add('Humidity ${s.greenhouseAvgHumidity!.toStringAsFixed(0)}%');
  if (s.soilAvgMoisture != null) parts.add('Soil ${s.soilAvgMoisture!.toStringAsFixed(1)}%');
  if (s.soilAvgPh != null) parts.add('pH ${s.soilAvgPh!.toStringAsFixed(2)}');
  if (s.irrigationFlowSum != null) parts.add('Irrigation ${s.irrigationFlowSum!.toStringAsFixed(1)} L/min');
  if (s.cropThreatsCount > 0) parts.add('${s.cropThreatsCount} crop issues');
  if (parts.isEmpty) return 'No recent telemetry available to generate a narrative.';
  return parts.join(' · ');
}


// Resolve key in a row for candidate keys (case-insensitive exact then substring)
String? resolveKeyInRow(Map<String, dynamic> row, List<String> candidates) {
  final present = row.keys.map((k) => k.toString()).toList();
  for (final c in candidates) {
    for (final k in present) {
      if (k.toLowerCase() == c.toLowerCase()) return k;
    }
  }
  for (final c in candidates) {
    for (final k in present) {
      if (k.toLowerCase().contains(c.toLowerCase())) return k;
    }
  }
  return null;
}

/// Gather windowed metrics for the overview page.
Future<Map<String, dynamic>> _gatherOverviewMetrics(String windowKey) async {
  final ApiService api = ApiService();
  final now = DateTime.now().toUtc();
  Duration dur;
  if (windowKey == '1h') dur = Duration(hours: 1);
  else if (windowKey == '24h') dur = Duration(hours: 24);
  else dur = Duration(days: 7);
  final lower = now.subtract(dur);
  final prevLower = lower.subtract(dur);
  final prevUpper = lower;

  double? toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(RegExp(r'[^0-9.\-]'), ''));
  }

  double? avg(List<double> xs) => xs.isEmpty ? null : xs.reduce((a, b) => a + b) / xs.length;

  final result = <String, dynamic>{};

  // Greenhouse metrics
  try {
    final ghRaw = await api.fetchAllGroupRaw('greenhouse');
    final rows = <Map<String, dynamic>>[];
    if (ghRaw != null) {
      for (final v in ghRaw.values) {
        if (v is Map && v['data'] is Map && v['data']['items'] is List) {
          for (final it in v['data']['items']) {
            if (it is Map) {
              rows.add(Map<String, dynamic>.from(it));
            }
          }
        } else if (v is Map) {
          rows.add(Map<String, dynamic>.from(v));
        }
      }
    }
    final sel = rows.where((r) {
      final ts = UiHelpers.parseTimestamp(r['TIMESTAMP_READING'] ?? r['timestamp_reading'] ?? r['created_at'] ?? r['CREATED_AT'] ?? r['Timestamp'] ?? r['timestamp'] ?? r['T']);
      return ts != null && ts.toUtc().isAfter(lower);
    }).toList();
    final temps = <double>[];
    final hums = <double>[];
    DateTime? last;
    for (final r in sel) {
      final tKey = resolveKeyInRow(r, ['temperature', 'temp', 'temperature_bmp280', 'temp_c']);
      final hKey = resolveKeyInRow(r, ['humidity', 'hum', 'rh']);
      final ts = UiHelpers.parseTimestamp(r['TIMESTAMP_READING'] ?? r['timestamp_reading'] ?? r['created_at'] ?? r['CREATED_AT'] ?? r['Timestamp'] ?? r['timestamp'] ?? r['T']);
      if (ts != null) {
        if (last == null || ts.isAfter(last)) {
          last = ts;
        }
      }
      final td = tKey != null ? toDouble(r[tKey]) : null;
      final hd = hKey != null ? toDouble(r[hKey]) : null;
      if (td != null) temps.add(td);
      if (hd != null) hums.add(hd);
    }
    // previous window comparison for simple trend
    final prevSel = rows.where((r) {
      final ts = UiHelpers.parseTimestamp(r['TIMESTAMP_READING'] ?? r['timestamp_reading'] ?? r['created_at'] ?? r['CREATED_AT'] ?? r['Timestamp'] ?? r['timestamp'] ?? r['T']);
      return ts != null && ts.toUtc().isAfter(prevLower) && ts.toUtc().isBefore(prevUpper);
    }).toList();
    final prevTemps = <double>[];
    for (final r in prevSel) {
      final tKey = resolveKeyInRow(r, ['temperature', 'temp', 'temperature_bmp280', 'temp_c']);
      final td = tKey != null ? toDouble(r[tKey]) : null;
      if (td != null) prevTemps.add(td);
    }
    result['greenhouse'] = {
      'avgTemp': avg(temps),
      'avgHumidity': avg(hums),
      'count': sel.length,
      'lastUpdate': last?.toUtc().toIso8601String(),
      'prevAvgTemp': avg(prevTemps),
    };
  } catch (_) {}

  // --- Irrigation ---
  try {
    final irrRaw = await api.fetchAllGroupRaw('irrigation');
    final items = <Map<String, dynamic>>[];
    if (irrRaw != null) {
      final node = irrRaw['irrigation_telemetry'] ?? irrRaw.values.firstWhere((_) => true, orElse: () => null);
      if (node is Map && node['data'] is Map && node['data']['items'] is List) {
        for (final it in node['data']['items']) {
          if (it is Map) {
            items.add(Map<String, dynamic>.from(it));
          }
        }
      }
    }
    final sel = items.where((r) {
      final ts = UiHelpers.parseTimestamp(r['timestamp'] ?? r['created_at'] ?? r['CREATED_AT'] ?? r['T']);
      return ts != null && ts.toUtc().isAfter(lower);
    }).toList();
    final flows = <double>[];
    int pumpsOn = 0;
    final pumpIds = <dynamic>{};
    DateTime? last;
    for (final r in sel) {
      final fKey = resolveKeyInRow(r, ['flow', 'flowRate', 'flow_rate', 'flowrate', 'flow_lmin', 'flow_l_min']);
      final pKey = resolveKeyInRow(r, ['pumpState', 'pump_state', 'pumpStatus', 'pump_status']);
      final id = resolveKeyInRow(r, ['device_id', 'id', 'DEVICE_ID']);
      final ts = UiHelpers.parseTimestamp(r['timestamp'] ?? r['created_at'] ?? r['CREATED_AT'] ?? r['T']);
      if (ts != null) {
        if (last == null || ts.isAfter(last)) {
          last = ts;
        }
      }
      final fd = fKey != null ? toDouble(r[fKey]) : null;
      if (fd != null) flows.add(fd);
      final ps = pKey != null ? (r[pKey]?.toString() ?? '') : '';
      if (ps.toUpperCase() == 'ON') pumpsOn += 1;
      if (id != null) pumpIds.add(r[id]);
    }
    result['irrigation'] = {
      'flowAvg': avg(flows),
      'flowSum': flows.isNotEmpty ? flows.reduce((a, b) => a + b) : null,
      'pumpsOn': pumpsOn,
      'pumpsTotal': pumpIds.length,
      'count': sel.length,
      'lastUpdate': last?.toUtc().toIso8601String(),
    };
  } catch (_) {}

  // --- Soil ---
  try {
    final allSoil = await api.fetchSoilGroupHistory(limit: 500, offset: 0);
    final rows = <Map<String, dynamic>>[];
    if (allSoil != null) rows.addAll(allSoil);
    final sel = rows.where((r) {
      final ts = UiHelpers.parseTimestamp(r['CREATED_AT'] ?? r['created_at'] ?? r['timestamp'] ?? r['Timestamp'] ?? r['T']);
      return ts != null && ts.toUtc().isAfter(lower);
    }).toList();
    final moist = <double>[];
    final phs = <double>[];
    DateTime? last;
    for (final r in sel) {
      final mKey = resolveKeyInRow(r, ['moisture', 'moisture_pct', 'moisture_pct']);
      final pKey = resolveKeyInRow(r, ['ph', 'pH']);
      final ts = UiHelpers.parseTimestamp(r['CREATED_AT'] ?? r['created_at'] ?? r['timestamp'] ?? r['Timestamp'] ?? r['T']);
      if (ts != null) {
        if (last == null || ts.isAfter(last)) {
          last = ts;
        }
      }
      final md = mKey != null ? toDouble(r[mKey]) : null;
      final pd = pKey != null ? toDouble(r[pKey]) : null;
      if (md != null) moist.add(md);
      if (pd != null) phs.add(pd);
    }
    result['soil'] = {
      'avgMoisture': avg(moist),
      'avgPh': avg(phs),
      'count': sel.length,
      'lastUpdate': last?.toUtc().toIso8601String(),
    };
  } catch (_) {}

  // --- Crop Vision ---
  try {
    final cvRaw = await api.fetchAllGroupRaw('crop_vision');
    final items = <Map<String, dynamic>>[];
    if (cvRaw != null) {
      for (final v in cvRaw.values) {
        if (v is Map && v['data'] is Map && v['data']['items'] is List) {
          for (final it in v['data']['items']) {
            if (it is Map) {
              items.add(Map<String, dynamic>.from(it));
            }
          }
        }
      }
    }
    final sel = items.where((r) {
      final ts = UiHelpers.parseTimestamp(r['timestamp'] ?? r['created_at'] ?? r['CREATED_AT'] ?? r['T']);
      return ts != null && ts.toUtc().isAfter(lower);
    }).toList();
    int threats = 0;
    String? topLabel;
    double topConf = -1.0;
    DateTime? last;
    for (final r in sel) {
      final lab = (r['label'] ?? r['disease'] ?? '').toString();
      final conf = toDouble(r['confidence'] ?? r['score'] ?? r['probability']) ?? 0.0;
      final ts = UiHelpers.parseTimestamp(r['timestamp'] ?? r['created_at'] ?? r['CREATED_AT'] ?? r['T']);
      if (ts != null) {
        if (last == null || ts.isAfter(last)) {
          last = ts;
        }
      }
      if (lab.toLowerCase() != 'healthy' && lab.toLowerCase() != 'unknown' && lab.isNotEmpty) threats += 1;
      if (conf > topConf) {
        topConf = conf;
        topLabel = lab;
      }
    }
    result['crop'] = {'threats': threats, 'topLabel': topLabel, 'topConf': topConf >= 0 ? topConf : null, 'count': sel.length, 'lastUpdate': last?.toUtc().toIso8601String()};
  } catch (_) {}

  return result;
}
// End of overview page helpers