// lib/pages/overview_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_state.dart';
import '../services/geocoding_service.dart';
import '../services/ai_integration.dart';
import '../services/api_service.dart';
import '../utils/ui_helpers.dart';
import 'dart:async';
import '../widgets/service_status_banner.dart';

class OverviewPage extends StatefulWidget {
  const OverviewPage({super.key});

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  String _selectedWindow = '1h';
  Future<Map<String, dynamic>>? _metricsFuture;
  final ApiService _api = ApiService();
  late final ValueNotifier<ServiceStatus> _statusNotifier;

  void _loadMetrics() {
    _metricsFuture = _gatherOverviewMetrics(_api, _selectedWindow);
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
    _statusNotifier = _api.serviceStatus;
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
            ValueListenableBuilder<ServiceStatus>(
              valueListenable: _statusNotifier,
              builder: (context, status, _) {
                // Only show banner when not fully healthy or when latency is slow
                final shouldShow =
                    status.state != BackendState.online ||
                    (status.latency != null &&
                        status.latency! > const Duration(seconds: 4));
                if (!shouldShow) return const SizedBox.shrink();
                return ServiceStatusBanner(
                  status: status,
                  onRetry: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Reaching out to farm services...'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                    try {
                      await _api.warmupBackend();
                      if (mounted) {
                        setState(() {
                          _loadMetrics();
                        });
                      }
                    } finally {
                      messenger.hideCurrentSnackBar();
                    }
                  },
                );
              },
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 700;
                final titleWidget = Text(
                  'Dashboard Overview',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                );
                final windowSelector = Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    const Text('Window:'),
                    DropdownButton<String>(
                      value: _selectedWindow,
                      items: const [
                        DropdownMenuItem(
                          value: '1h',
                          child: Text('Past 1 Hour'),
                        ),
                        DropdownMenuItem(
                          value: '24h',
                          child: Text('Past 24 Hours'),
                        ),
                        DropdownMenuItem(
                          value: '7d',
                          child: Text('Past 7 Days'),
                        ),
                        DropdownMenuItem(
                          value: '14d',
                          child: Text('Past 14 Days'),
                        ),
                      ],
                      onChanged: _onWindowChanged,
                    ),
                  ],
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleWidget,
                      const SizedBox(height: 12),
                      windowSelector,
                    ],
                  );
                }

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: titleWidget),
                    const SizedBox(width: 16),
                    Flexible(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: windowSelector,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            const Text(
              'Real-time monitoring and insights',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            FutureBuilder<Map<String, dynamic>>(
              future: _metricsFuture,
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: SizedBox(
                      height: 120,
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                final metrics = snap.hasData ? snap.data! : <String, dynamic>{};
                return Column(
                  children: [
                    _buildSummaryGrid(
                      context,
                      appState,
                      metrics,
                      _selectedWindow,
                    ),
                    const SizedBox(height: 12),
                    _buildDataFreshnessCard(context, metrics, _selectedWindow),
                    const SizedBox(height: 12),
                    _buildNarrativeCard(
                      context,
                      appState,
                      metrics,
                      _selectedWindow,
                    ),
                    const SizedBox(height: 16),
                    _buildWeatherCard(context, appState),
                    const SizedBox(height: 24),
                    _buildAlertsAndInsights(
                      context,
                      appState,
                      metrics,
                      _selectedWindow,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

Widget _summaryCard(
  BuildContext context, {
  required String title,
  required String value,
  List<String>? details,
}) {
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withAlpha((0.9 * 255).round()),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (details != null && details.isNotEmpty)
                  ...details.map(
                    (line) => Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        line,
                        style: TextStyle(
                          color: Theme.of(context).disabledColor,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildSummaryGrid(
  BuildContext context,
  AppState appState,
  Map<String, dynamic> metrics,
  String window,
) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final isWide = constraints.maxWidth > 900;

      String greenhouseTitle() {
        final g = metrics['greenhouse'] as Map<String, dynamic>?;
        if (g != null) {
          final avg = g['avgTemp'];
          final hum = g['avgHumidity'];
          if (avg != null) {
            if (hum != null) {
              return '${(avg as double).toStringAsFixed(1)}°C · H ${(hum as double).toStringAsFixed(0)}%';
            }
            return '${(avg as double).toStringAsFixed(1)}°C';
          }
          return '—';
        }
        if (appState.greenhouseAvgTemp != null) {
          if (appState.greenhouseAvgHumidity != null) {
            return '${appState.greenhouseAvgTemp!.toStringAsFixed(1)}°C · H ${appState.greenhouseAvgHumidity!.toStringAsFixed(0)}%';
          }
          return '${appState.greenhouseAvgTemp!.toStringAsFixed(1)}°C';
        }
        return '—';
      }

      String? lastUpdateLabel(Map<String, dynamic>? section) {
        final raw = section?['lastUpdate'];
        if (raw == null) {
          return null;
        }
        final dt = UiHelpers.parseTimestamp(raw);
        if (dt == null) {
          return null;
        }
        return 'Last update: ${DateFormat('dd MMM HH:mm').format(dt.toLocal()).toUpperCase()}';
      }

      String staleBadge(Map<String, dynamic>? section) {
        if (section == null) return '';
        final stale = section['stale'] == true;
        if (!stale) return '';
        final last = UiHelpers.parseTimestamp(section['lastUpdate']);
        if (last == null) return '(stale)';
        final age = DateTime.now().toUtc().difference(last.toUtc());
        if (age.inMinutes < 60) {
          return '(stale • ${age.inMinutes}m old)';
        }
        if (age.inHours < 48) {
          return '(stale • ${age.inHours}h old)';
        }
        return '(stale • ${age.inDays}d old)';
      }

      final cards = [
        _summaryCard(
          context,
            title: 'Greenhouse',
          value: greenhouseTitle(),
          details: () {
            final gh = metrics['greenhouse'] as Map<String, dynamic>?;
            final details = <String>[];
            if (gh != null) {
              details.add('Count: ${gh['count'] ?? 0} rows ($window)');
              if (gh['stale'] == true) {
                details.add('Using fallback ${staleBadge(gh)}');
              }
              final last = lastUpdateLabel(gh);
              if (last != null) {
                details.add(last);
              }
              final prev = gh['prevAvgTemp'] as double?;
              final curr = gh['avgTemp'] as double?;
              if (prev != null && curr != null) {
                final diff = curr - prev;
                final sign = diff > 0 ? '+' : '';
                details.add('Trend vs prev: $sign${diff.toStringAsFixed(1)}°C');
              }
              final co2 = gh['avgCo2'] as double?;
              if (co2 != null) {
                details.add('CO₂ ${co2.toStringAsFixed(0)} ppm');
              }
              final pressure = gh['avgPressure'] as double?;
              if (pressure != null) {
                details.add('Pressure ${pressure.toStringAsFixed(0)} hPa');
              }
              final light = gh['avgLight'] as double?;
              if (light != null) {
                details.add('Light ${light.toStringAsFixed(0)} lux');
              }
              final dewPoint = gh['avgDewPoint'] as double?;
              if (dewPoint != null) {
                details.add('Dew point ${dewPoint.toStringAsFixed(1)}°C');
              }
              final extras = gh['extraMetrics'] as List<dynamic>?;
              if (extras != null && extras.isNotEmpty) {
                for (final entry in extras.take(4)) {
                  if (entry is Map) {
                    final key = entry['key']?.toString();
                    final avg = entry['avg'];
                    final double? value = avg is num ? avg.toDouble() : double.tryParse(avg.toString());
                    if (key != null && value != null) {
                      final label = UiHelpers.friendlyName(key);
                      details.add('$label ${value.toStringAsFixed(2)}');
                    }
                  }
                }
              }
            }
            return details;
          }(),
        ),
        _summaryCard(
          context,
          title: 'Irrigation',
          value: () {
            try {
              final irr = metrics['irrigation'] as Map<String, dynamic>?;
              if (irr != null) {
                final fa = irr['flowAvg'];
                if (fa != null) {
                  return '${(fa as double).toStringAsFixed(1)} L/min';
                }
                final fs = irr['flowSum'];
                if (fs != null) {
                  return '${(fs as double).toStringAsFixed(1)} L/min (sum)';
                }
              }
            } catch (_) {}
            if (appState.irrigationFlowSum != null) {
              return '${appState.irrigationFlowSum!.toStringAsFixed(1)} L/min';
            }
            return '—';
          }(),
          details: () {
            try {
              final irr = metrics['irrigation'] as Map<String, dynamic>?;
              if (irr != null) {
                final on = irr['pumpsOn'] ?? appState.irrigationPumpsOn;
                final tot = irr['pumpsTotal'] ?? appState.irrigationTotalPumps;
                final details = <String>[
                  'Pumps: ${on ?? 0}/${tot ?? 0} ($window)',
                ];
                if (irr['stale'] == true) {
                  details.add('Using fallback ${staleBadge(irr)}');
                }
                final last = lastUpdateLabel(irr);
                if (last != null) {
                  details.add(last);
                }
                if (irr['count'] != null) {
                  details.add('Samples: ${irr['count']}');
                }
                final flowSum = irr['flowSum'] as double?;
                if (flowSum != null) {
                  details.add('Flow total ${flowSum.toStringAsFixed(1)} L');
                }
                final avgPressure = irr['avgPressure'] as double?;
                if (avgPressure != null) {
                  details.add(
                    'Pressure avg ${avgPressure.toStringAsFixed(1)}',
                  );
                }
                final valve = irr['avgValvePosition'] as double?;
                if (valve != null) {
                  final normalized = valve <= 1.0 && valve >= 0
                      ? valve * 100
                      : valve;
                  details.add(
                    'Valve position avg ${normalized.toStringAsFixed(0)}%',
                  );
                }
                final tank = irr['avgTankLevel'] as double?;
                if (tank != null) {
                  final normalized = tank <= 1.0 && tank >= 0
                      ? tank * 100
                      : tank;
                  details.add(
                    'Tank level avg ${normalized.toStringAsFixed(0)}%',
                  );
                }
                final extras = irr['extraMetrics'] as List<dynamic>?;
                if (extras != null && extras.isNotEmpty) {
                  for (final entry in extras.take(4)) {
                    if (entry is Map) {
                      final key = entry['key']?.toString();
                      final avg = entry['avg'];
                      final double? value = avg is num
                          ? avg.toDouble()
                          : double.tryParse(avg.toString());
                      if (key != null && value != null) {
                        final label = UiHelpers.friendlyName(key);
                        details.add('$label ${value.toStringAsFixed(2)}');
                      }
                    }
                  }
                }
                return details;
              }
            } catch (_) {}
            return <String>[
              '${appState.irrigationPumpsOn}/${appState.irrigationTotalPumps} Pumps Active',
            ];
          }(),
        ),
        _summaryCard(
          context,
      title: 'Soil',
          value:
              metrics['soil'] != null &&
                  (metrics['soil'] as Map)['avgMoisture'] != null
              ? '${((metrics['soil'] as Map)['avgMoisture'] as double).toStringAsFixed(1)}%'
              : (appState.soilAvgMoisture != null
                    ? '${appState.soilAvgMoisture!.toStringAsFixed(1)}%'
                    : '—'),
          details: () {
            try {
              final soil = metrics['soil'] as Map<String, dynamic>?;
              if (soil != null) {
                final details = <String>[];
                if (soil['avgPh'] != null) {
                  details.add(
                    'pH ${(soil['avgPh'] as double).toStringAsFixed(2)}',
                  );
                }
                final temp = soil['avgTemp'] as double?;
                if (temp != null) {
                  details.add(
                    'Temperature ${temp.toStringAsFixed(1)}°C',
                  );
                }
                final ec = soil['avgEc'] as double?;
                if (ec != null) {
                  details.add('EC ${ec.toStringAsFixed(2)} dS/m');
                }
                if (soil['stale'] == true) {
                  details.add('Using fallback ${staleBadge(soil)}');
                }
                final last = lastUpdateLabel(soil);
                if (last != null) {
                  details.add(last);
                }
                details.add('Samples: ${soil['count'] ?? 0}');
                final extras = soil['extraMetrics'] as List<dynamic>?;
                if (extras != null && extras.isNotEmpty) {
                  for (final entry in extras.take(4)) {
                    if (entry is Map) {
                      final key = entry['key']?.toString();
                      final avg = entry['avg'];
                      final double? value = avg is num
                          ? avg.toDouble()
                          : double.tryParse(avg.toString());
                      if (key != null && value != null) {
                        final label = UiHelpers.friendlyName(key);
                        details.add('$label ${value.toStringAsFixed(2)}');
                      }
                    }
                  }
                }
                if (details.isNotEmpty) {
                  return details;
                }
              }
              if (appState.soilAvgPh != null) {
                return <String>['pH ${appState.soilAvgPh!.toStringAsFixed(2)}'];
              }
            } catch (_) {}
            try {
              final irr = metrics['irrigation'] as Map<String, dynamic>?;
              if (irr != null && irr['flowAvg'] != null) {
                return <String>[
                  'No soil windowed metrics — showing irrigation instead',
                ];
              }
            } catch (_) {}
            return const <String>[];
          }(),
        ),
        _summaryCard(
          context,
          title: 'Crop Vision',
          value: metrics['crop'] != null
              ? '${(metrics['crop'] as Map)['threats'] ?? 0} Threats Detected'
              : '${appState.cropThreatsCount} Threats Detected',
          details: () {
            final crop = metrics['crop'] as Map<String, dynamic>?;
            if (crop != null) {
              final details = <String>[];
              if (crop['topLabel'] != null && crop['topConf'] != null) {
                details.add(
                  '${crop['topLabel']} - ${((crop['topConf'] as double) * 100).toStringAsFixed(1)}%',
                );
              }
              if (crop['stale'] == true) {
                details.add('Using fallback ${staleBadge(crop)}');
              }
              final last = lastUpdateLabel(crop);
              if (last != null) {
                details.add(last);
              }
              details.add('Detections analysed: ${crop['count'] ?? 0}');
              return details;
            }
            if (appState.topCropThreatLabel != null &&
                appState.topCropThreatConfidence != null) {
              return <String>[
                '${appState.topCropThreatLabel} - ${(appState.topCropThreatConfidence! * 100).toStringAsFixed(2)}%',
              ];
            }
            return const <String>[];
          }(),
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
      }

      return Column(
        children: cards
            .map(
              (c) =>
                  Padding(padding: const EdgeInsets.only(bottom: 12), child: c),
            )
            .toList(),
      );
    },
  );
}

Widget _buildDataFreshnessCard(
  BuildContext context,
  Map<String, dynamic> metrics,
  String window,
) {
  Duration windowDuration;
  switch (window) {
    case '1h':
      windowDuration = const Duration(hours: 1);
      break;
    case '7d':
      windowDuration = const Duration(days: 7);
      break;
    case '14d':
      windowDuration = const Duration(days: 14);
      break;
    case '24h':
    default:
      windowDuration = const Duration(hours: 24);
      break;
  }

  String formatAge(Duration age) {
    if (age.inSeconds < 60) return '${age.inSeconds}s ago';
    if (age.inMinutes < 60) return '${age.inMinutes}m ago';
    if (age.inHours < 24) return '${age.inHours}h ago';
    return '${age.inDays}d ago';
  }

  double? freshnessScore(DateTime? lastUpdate) {
    if (lastUpdate == null) return null;
    final age = DateTime.now().toUtc().difference(lastUpdate.toUtc());
    if (windowDuration.inSeconds == 0) return null;
    final normalized = 1 - (age.inSeconds / (windowDuration.inSeconds * 1.5));
    final clamped = normalized.clamp(0.0, 1.0);
    return clamped.toDouble();
  }

  Color freshnessColor(double score) {
    if (score >= 0.66) return Colors.greenAccent.shade400;
    if (score >= 0.33) return Colors.orangeAccent.shade200;
    return Colors.redAccent.shade200;
  }

  Widget buildRow(String label, Map<String, dynamic>? section) {
    final last = UiHelpers.parseTimestamp(section?['lastUpdate']);
    final score = freshnessScore(last);
    final ageLabel = last == null
        ? 'No recent data'
        : formatAge(DateTime.now().toUtc().difference(last.toUtc()));
    final count = section?['count'];
    final stale = section?['stale'] == true;
    final coverage = section?['coverage'] as double?;
    final coverageLabel = coverage != null
        ? 'Coverage ${(coverage * 100).clamp(0, 100).toStringAsFixed(0)}%'
        : null;
    final detailsText = <String>[
    section == null
      ? 'Waiting for first payload...'
      : 'Last sample: $ageLabel • Samples: ${count ?? 0}${stale ? ' • fallback' : ''}',
      if (coverageLabel != null) coverageLabel,
    ].join('  ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  detailsText,
                  style: TextStyle(color: Theme.of(context).disabledColor),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (score != null)
            SizedBox(
              width: 140,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: score,
                  minHeight: 10,
                  backgroundColor: Theme.of(
                    context,
                  ).cardColor.withValues(alpha: 0.35),
                  valueColor: AlwaysStoppedAnimation(freshnessColor(score)),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('No data'),
            ),
        ],
      ),
    );
  }

  return Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Data Freshness',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Window: $window • Target coverage ≥ 66%',
            style: TextStyle(
              color: Theme.of(context).disabledColor,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          buildRow(
            'Greenhouse',
            metrics['greenhouse'] as Map<String, dynamic>?,
          ),
          buildRow(
            'Irrigation',
            metrics['irrigation'] as Map<String, dynamic>?,
          ),
          buildRow('Soil', metrics['soil'] as Map<String, dynamic>?),
          buildRow('Crop Vision', metrics['crop'] as Map<String, dynamic>?),
        ],
      ),
    ),
  );
}

Widget _buildWeatherCard(BuildContext context, AppState appState) {
  final locationTitle = appState.weatherLocationLabel ?? 'Farm location not set';
  final locationDetails = [
    if ((appState.weatherLocationRegion ?? '').isNotEmpty)
      appState.weatherLocationRegion,
    if ((appState.weatherLocationCountry ?? '').isNotEmpty)
      appState.weatherLocationCountry,
  ].whereType<String>().join(', ');
  final hasWeather = appState.currentTemperature != null;
  final timezone = appState.weatherTimezone;
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        'Weather',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _showSetLocationDialog(context, appState),
                      icon: const Icon(Icons.place),
                      label: Text(hasWeather ? 'Change location' : 'Set location'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  locationTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (locationDetails.isNotEmpty || timezone != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      [
                        if (locationDetails.isNotEmpty) locationDetails,
                        if (timezone != null) 'Timezone: $timezone',
                      ].join(' • '),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                const SizedBox(height: 12),
                if (hasWeather) ...[
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _weatherMetric(
                        icon: _mapWeatherCodeToIcon(appState.currentWeatherCode ?? 0),
                        title: 'Current',
                        value: '${appState.currentTemperature!.toStringAsFixed(1)}°C',
                      ),
                      if (appState.feelsLikeTemperature != null)
                        _weatherMetric(
                          icon: Icons.thermostat,
                          title: 'Feels like',
                          value: '${appState.feelsLikeTemperature!.toStringAsFixed(1)}°C',
                        ),
                      if (appState.humidityPercent != null)
                        _weatherMetric(
                          icon: Icons.water_drop,
                          title: 'Humidity',
                          value: '${appState.humidityPercent!.round()}%',
                        ),
                      if (appState.windSpeedKmh != null)
                        _weatherMetric(
                          icon: Icons.air,
                          title: 'Wind',
                          value: '${appState.windSpeedKmh!.toStringAsFixed(1)} km/h',
                        ),
                    ],
                  ),
                ] else ...[
                  Wrap(
                    spacing: 12,
                    children: const [
                      Icon(Icons.info_outline),
                      Text('Select a farm location to load the latest forecast.'),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Right: three-day forecast — allow horizontal scrolling to avoid overflow
          if (appState.threeDayForecast.isNotEmpty) ...[
            const SizedBox(width: 12),
            Flexible(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: appState.threeDayForecast.map((d) {
                    final date = DateTime.parse(d['date'] as String);
                    final precip = d['precip'] as double?;
                    final wind = d['wind'] as double?;
                    return Container(
                      width: 112,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${date.month}/${date.day}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${(d['max'] as double).round()}° / ${(d['min'] as double).round()}°',
                            style: const TextStyle(fontSize: 12),
                          ),
                          if (precip != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                'Rain: ${precip.round()}%',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          if (wind != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Wind: ${wind.toStringAsFixed(1)} km/h',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
          // End of children for Row
        ],
      ),
    ),
  );
}

Widget _weatherMetric({
  required IconData icon,
  required String title,
  required String value,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.grey.shade100,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade300),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            Text(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ],
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
  showDialog<void>(
    context: context,
    builder: (ctx) {
      String? error;
      bool loading = false;
      List<CitySuggestion> suggestions = const [];
      return StatefulBuilder(
        builder: (ctx2, setState) {
          Future<void> performLookup() async {
            final query = controller.text.trim();
            if (query.isEmpty) {
              setState(() {
                error = 'Enter a city, town, or farm name';
                suggestions = const [];
              });
              return;
            }
            setState(() {
              loading = true;
              error = null;
              suggestions = const [];
            });
            final results = await geo.searchCities(query, limit: 8);
            if (!ctx2.mounted) return;
            setState(() {
              loading = false;
              if (results.isEmpty) {
                error = 'No matching locations found';
              }
              suggestions = results;
            });
          }

          return AlertDialog(
            title: const Text('Set farm location'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  onSubmitted: (_) => performLookup(),
                  decoration: InputDecoration(
                    labelText: 'Search city or site',
                    suffixIcon: IconButton(
                      onPressed: loading ? null : performLookup,
                      icon: const Icon(Icons.search),
                    ),
                  ),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                if (loading)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: CircularProgressIndicator(),
                  ),
                if (!loading && suggestions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: SizedBox(
                      height: 260,
                      width: 420,
                      child: ListView.separated(
                        itemCount: suggestions.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, index) {
                          final suggestion = suggestions[index];
                          final subtitleParts = [
                            if ((suggestion.admin1 ?? '').isNotEmpty)
                              suggestion.admin1,
                            if ((suggestion.country ?? '').isNotEmpty)
                              suggestion.country,
                          ].whereType<String>().join(', ');
                          return ListTile(
                            title: Text(suggestion.name),
                            subtitle: Text(
                              [
                                if (subtitleParts.isNotEmpty) subtitleParts,
                                'Lat ${suggestion.latitude.toStringAsFixed(2)}, '
                                    'Lon ${suggestion.longitude.toStringAsFixed(2)}',
                              ].join(' • '),
                            ),
                            trailing: const Icon(Icons.check_circle_outline),
                            onTap: () async {
                              await appState.setWeatherLocation(
                                suggestion.latitude,
                                suggestion.longitude,
                                label: suggestion.name,
                                country: suggestion.country,
                                region: suggestion.admin1,
                                timezone: suggestion.timezone,
                              );
                              if (!ctx2.mounted) return;
                              Navigator.of(ctx2).pop();
                            },
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx2).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: loading ? null : performLookup,
                child: const Text('Search'),
              ),
            ],
          );
        },
      );
    },
  );
}

Widget _buildAlertsAndInsights(
  BuildContext context,
  AppState appState,
  Map<String, dynamic> metrics,
  String window,
) {
  final alerts = <String>[];
  final gh = metrics['greenhouse'] as Map<String, dynamic>?;
  final soil = metrics['soil'] as Map<String, dynamic>?;
  if (gh != null && gh['avgTemp'] != null && (gh['avgTemp'] as double) > 35) {
    alerts.add(
      'High greenhouse temperature (${(gh['avgTemp'] as double).toStringAsFixed(1)}°C)',
    );
  }
  if (soil != null &&
      soil['avgMoisture'] != null &&
      (soil['avgMoisture'] as double) < 25) {
    alerts.add(
      'Low soil moisture (${(soil['avgMoisture'] as double).toStringAsFixed(1)}%)',
    );
  }

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
                const Text(
                  'Alerts',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 8),
                ...alerts.map(
                  (a) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(a, style: const TextStyle(color: Colors.red)),
                  ),
                ),
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
              const Text(
                'Insights',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Combined system health: ${alerts.isEmpty ? 'OK' : 'Degraded'}',
              ),
              const SizedBox(height: 6),
              Text(
                'Window: $window  •  Last update: ${DateTime.now().toLocal().toIso8601String()}',
              ),
              const SizedBox(height: 12),
              // Windowed metric highlights
              if (gh != null) ...[
                Text(
                  'Greenhouse — Avg ${(gh['avgTemp'] as double?)?.toStringAsFixed(1) ?? '—'}°C, Hum ${(gh['avgHumidity'] as double?)?.toStringAsFixed(0) ?? '—'}% (n=${gh['count'] ?? 0})',
                ),
              ],
              if (soil != null) ...[
                Text(
                  'Soil — Moisture ${(soil['avgMoisture'] as double?)?.toStringAsFixed(1) ?? '—'}%, pH ${(soil['avgPh'] as double?)?.toStringAsFixed(2) ?? '—'} (n=${soil['count'] ?? 0})',
                ),
              ],
              if (metrics['irrigation'] != null)
                Text(
                  'Irrigation — Flow avg ${(metrics['irrigation'] as Map)['flowAvg'] != null ? (metrics['irrigation'] as Map)['flowAvg'].toStringAsFixed(1) : '—'} L/min',
                ),
              if (metrics['crop'] != null)
                Text(
                  'Crop Vision — ${(metrics['crop'] as Map)['threats'] ?? 0} issues in window',
                ),
            ],
          ),
        ),
      ),
    ],
  );
}

Widget _buildNarrativeCard(
  BuildContext context,
  AppState appState,
  Map<String, dynamic> metrics,
  String window,
) {
  final remoteReady = AiIntegration.hasRemoteProvider;
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 520;
              final actionButton = ElevatedButton.icon(
                onPressed: () async {
                  final scaffold = ScaffoldMessenger.of(context);
                  scaffold.showSnackBar(
                    SnackBar(
                      content: Text(
                        remoteReady
                            ? 'Generating summary with Google AI...'
                            : 'Generating local summary...',
                      ),
                    ),
                  );
                  try {
                    final txt = await AiIntegration.generateDetailedSummary(
                      metrics,
                      window: window,
                    );
                    scaffold.hideCurrentSnackBar();
                    if (!context.mounted) {
                      return;
                    }
                    showDialog<void>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('AI Summary'),
                        content: Text(txt),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    );
                  } catch (e) {
                    scaffold.hideCurrentSnackBar();
                    scaffold.showSnackBar(
                      const SnackBar(
                        content: Text('Failed to generate summary'),
                      ),
                    );
                  }
                },
                icon: Icon(remoteReady ? Icons.auto_awesome : Icons.smart_toy),
                label: Text(
                  remoteReady
                      ? 'Generate Google AI Summary'
                      : 'Generate AI Summary',
                ),
                style: ElevatedButton.styleFrom(),
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Farm Narrative',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    actionButton,
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Expanded(
                    child: Text(
                      'Farm Narrative',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  actionButton,
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          // Local heuristics preview — prefer windowed metrics when available
          Text(
            _combinedNarrativePreview(appState, metrics),
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 12),
          Text(
            remoteReady
                ? 'Google AI key detected. Summaries blend live metrics with Gemini responses when available.'
                : 'No AI key supplied — falling back to on-device heuristics.',
            style: TextStyle(
              color: Theme.of(context).disabledColor,
              fontSize: 12,
            ),
          ),
        ],
      ),
    ),
  );
}

String _combinedNarrativePreview(AppState s, Map<String, dynamic> metrics) {
  // Build a short, human-friendly narrative that explains current state and a single, actionable insight.
  final sentences = <String>[];

  // Greenhouse
  try {
    final gh = metrics['greenhouse'] as Map<String, dynamic>?;
    if (gh != null && gh['avgTemp'] != null) {
      final avg = (gh['avgTemp'] as double).toStringAsFixed(1);
      final hum = gh['avgHumidity'] != null
          ? ' at ${(gh['avgHumidity'] as double).toStringAsFixed(0)}% humidity'
          : '';
      String trend = '';
      if (gh['prevAvgTemp'] != null) {
        final prev = gh['prevAvgTemp'] as double;
        final cur = gh['avgTemp'] as double;
        final diff = cur - prev;
        if (diff.abs() >= 0.5) {
          trend = diff > 0 ? ' and rising' : ' and falling';
        }
      }
      sentences.add(
        'Greenhouse temperature $avg°C$hum$trend.'
            .replaceAll(r'$hum', hum)
            .replaceAll(r'$trend', trend),
      );
    }
  } catch (_) {}

  // Irrigation
  try {
    final irr = metrics['irrigation'] as Map<String, dynamic>?;
    if (irr != null) {
      if (irr['flowAvg'] != null) {
        final fa = (irr['flowAvg'] as double).toStringAsFixed(1);
        final pumpsOn = irr['pumpsOn'] ?? 0;
        final pumpsTot = irr['pumpsTotal'] ?? 0;
        sentences.add(
          'Irrigation running at $fa L/min across $pumpsTot pumps ($pumpsOn on).',
        );
      } else if (irr['flowSum'] != null) {
        final fs = (irr['flowSum'] as double).toStringAsFixed(1);
        sentences.add('Irrigation total in window: $fs L.');
      }
    }
  } catch (_) {}

  // Soil
  try {
    final soil = metrics['soil'] as Map<String, dynamic>?;
    if (soil != null && soil['avgMoisture'] != null) {
      final m = (soil['avgMoisture'] as double).toStringAsFixed(1);
      final ph = soil['avgPh'] != null
          ? ' pH ${(soil['avgPh'] as double).toStringAsFixed(2)}.'
          : '.';
      sentences.add('Soil moisture is $m%.$ph'.replaceAll(r'$ph', ph));
    } else if (s.soilAvgMoisture != null) {
      sentences.add(
        'No recent windowed soil telemetry; last known average moisture ${s.soilAvgMoisture!.toStringAsFixed(1)}%.',
      );
    }
  } catch (_) {}

  // Crop vision
  try {
    final crop = metrics['crop'] as Map<String, dynamic>?;
    if (crop != null && (crop['threats'] as int?) != null) {
      final threats = crop['threats'] as int;
      if (threats > 0) {
        final top = crop['topLabel'] ?? 'unknown';
        final conf = crop['topConf'] != null
            ? ' (${((crop['topConf'] as double) * 100).toStringAsFixed(0)}%)'
            : '';
        sentences.add(
          'Crop vision detected $threats potential issues; top: $top$conf.',
        );
      } else {
        sentences.add(
          'No notable crop issues detected in the selected window.',
        );
      }
    }
  } catch (_) {}

  // If nothing found, fall back to AppState quick summary
  if (sentences.isEmpty) {
    if (s.greenhouseAvgTemp != null) {
      sentences.add(
        'Greenhouse around ${s.greenhouseAvgTemp!.toStringAsFixed(1)}°C.',
      );
    }
    if (s.irrigationFlowSum != null) {
      sentences.add(
        'Irrigation recent flow ${s.irrigationFlowSum!.toStringAsFixed(1)} L/min.',
      );
    }
    if (s.soilAvgMoisture != null) {
      sentences.add('Soil ${s.soilAvgMoisture!.toStringAsFixed(1)}%.');
    }
    if (s.cropThreatsCount > 0) {
      sentences.add('Detected ${s.cropThreatsCount} crop issues.');
    }
  }

  // One simple actionable insight
  try {
    final soil = metrics['soil'] as Map<String, dynamic>?;
    final irr = metrics['irrigation'] as Map<String, dynamic>?;
    if (soil != null &&
        soil['avgMoisture'] != null &&
        (soil['avgMoisture'] as double) < 30) {
      sentences.add(
        'Insight: soil moisture is low — consider increasing irrigation in affected zones.',
      );
    } else if ((soil == null || soil['avgMoisture'] == null) &&
        irr != null &&
        irr['flowAvg'] == null) {
      sentences.add(
        'Insight: soil telemetry missing and irrigation flow data is unavailable — verify sensors and pump telemetry.',
      );
    } else if (irr != null &&
        irr['pumpsOn'] != null &&
        (irr['pumpsOn'] as int) == 0) {
      sentences.add(
        'Insight: no pumps currently active. If irrigation is expected, check pump controllers.',
      );
    }
  } catch (_) {}

  return sentences.join(' ');
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
Future<Map<String, dynamic>> _gatherOverviewMetrics(
  ApiService api,
  String windowKey,
) async {
  final now = DateTime.now().toUtc();
  Duration dur;
  if (windowKey == '1h') {
    dur = Duration(hours: 1);
  } else if (windowKey == '24h') {
    dur = Duration(hours: 24);
  } else if (windowKey == '14d') {
    dur = Duration(days: 14);
  } else {
    dur = Duration(days: 7);
  }
  final lower = now.subtract(dur);
  final prevLower = lower.subtract(dur);
  final prevUpper = lower;

  double? toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(RegExp(r'[^0-9.\-]'), ''));
  }

  double? avg(List<double> xs) =>
      xs.isEmpty ? null : xs.reduce((a, b) => a + b) / xs.length;
  final timestampKeys = [
    'TIMESTAMP_READING',
    'timestamp_reading',
    'CREATED_AT',
    'created_at',
    'Timestamp',
    'timestamp',
    'T',
    'recorded_at',
    'RECORDED_AT',
    'recorded_on',
    'RECORD_TIME',
    'record_time',
    'RECORD_DATE',
    'record_date',
    'DATE_RECORDED',
    'date_recorded',
    'MEASURED_AT',
    'measured_at',
    'measurement_time',
    'MEASUREMENT_TIME',
    'LOGGED_AT',
    'logged_at',
    'DATE',
    'date',
    'DATETIME',
    'datetime',
    'TIME_STAMP',
    'time_stamp',
    'EVENT_TS',
    'event_ts',
    'EVENT_TIME',
    'event_time',
    'READING_TIME',
    'reading_time',
    'captured_at',
    'CAPTURED_AT',
    'FETCHED_TS',
    'fetched_ts',
    'FETCH_TS',
    'fetch_ts',
  ];

  dynamic tsFromRow(Map<String, dynamic> row) {
    for (final key in timestampKeys) {
      if (row.containsKey(key)) return row[key];
    }
    return null;
  }

  DateTime? rowTimestamp(Map<String, dynamic> row) {
    return UiHelpers.parseTimestamp(tsFromRow(row));
  }

  MapEntry<DateTime, Map<String, dynamic>>? latestRow(
    Iterable<Map<String, dynamic>> rows,
  ) {
    Map<String, dynamic>? bestRow;
    DateTime? bestTs;
    for (final row in rows) {
      final ts = rowTimestamp(row);
      if (ts == null) continue;
      if (bestTs == null || ts.isAfter(bestTs)) {
        bestTs = ts;
        bestRow = row;
      }
    }
    if (bestRow == null || bestTs == null) return null;
    return MapEntry(bestTs, bestRow);
  }

  double? valueFromRow(
    Map<String, dynamic> row,
    List<String> candidates,
  ) {
    final key = resolveKeyInRow(row, candidates);
    if (key == null) return null;
    return toDouble(row[key]);
  }

  double? sum(List<double> xs) => xs.isEmpty ? null : xs.reduce((a, b) => a + b);

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
    const tempKeys = [
      'temperature',
      'temp',
      'temperature_bmp280',
      'temp_c',
      'TEMPERATURE',
      'temperature_c',
      'temp_deg_c',
      'temperature_value',
      'temperature_reading',
    ];
    const humKeys = [
      'humidity',
      'hum',
      'rh',
      'HUMIDITY',
      'humidity_pct',
      'humidity_percent',
    ];
    const co2Keys = [
      'co2',
      'co2_ppm',
      'CO2',
      'co2ppm',
      'CO2_PPM',
      'carbon_dioxide',
      'carbon_dioxide_ppm',
    ];
    const pressureKeys = [
      'pressure',
      'air_pressure',
      'pressure_hpa',
      'PRESSURE',
      'bmp280_pressure',
      'pressure_pa',
    ];
    const lightKeys = [
      'light',
      'light_lux',
      'LIGHT',
      'illumination',
      'lux',
      'LIGHT_LUX',
    ];
    const dewPointKeys = [
      'dew_point',
      'dewpoint',
      'dew_point_c',
      'dewPoint',
      'DewPoint',
      'dew_point_temperature',
    ];
    final knownKeysLower = <String>{
      for (final k in timestampKeys) k.toLowerCase(),
      for (final k in tempKeys) k.toLowerCase(),
      for (final k in humKeys) k.toLowerCase(),
      for (final k in co2Keys) k.toLowerCase(),
      for (final k in pressureKeys) k.toLowerCase(),
      for (final k in lightKeys) k.toLowerCase(),
      for (final k in dewPointKeys) k.toLowerCase(),
      'id',
      'device_id',
      'device',
      'sensor',
      'source',
      'source_name',
      'group',
      'group_id',
      'name',
      'label',
      'status',
    };
    final extraLists = <String, List<double>>{};
    void collectExtras(Map<String, dynamic> row) {
      row.forEach((rawKey, rawValue) {
        final key = rawKey.toString();
        final lower = key.toLowerCase();
        if (knownKeysLower.contains(lower)) return;
        if (lower.contains('timestamp')) return;
        if (lower.contains('id') && !lower.contains('idx')) return;
        final double? numeric = toDouble(rawValue);
        if (numeric == null) return;
        extraLists.putIfAbsent(key, () => <double>[]).add(numeric);
      });
    }
    final rowsWithTs = rows.where((r) => rowTimestamp(r) != null).toList();
    final sel = rowsWithTs.where((r) {
      final ts = rowTimestamp(r)!;
      return ts.toUtc().isAfter(lower);
    }).toList();
    final temps = <double>[];
    final hums = <double>[];
    final co2Vals = <double>[];
    final pressureVals = <double>[];
    final lightVals = <double>[];
  final dewPointVals = <double>[];
    DateTime? last;
    for (final r in sel) {
      final ts = rowTimestamp(r);
      if (ts != null) {
        final currentLast = last;
        if (currentLast == null) {
          last = ts;
        } else if (ts.isAfter(currentLast)) {
          last = ts;
        }
      }
      final td = valueFromRow(r, tempKeys);
      final hd = valueFromRow(r, humKeys);
      final cd = valueFromRow(r, co2Keys);
      final pd = valueFromRow(r, pressureKeys);
      final ld = valueFromRow(r, lightKeys);
  final dd = valueFromRow(r, dewPointKeys);
      if (td != null) temps.add(td);
      if (hd != null) hums.add(hd);
      if (cd != null) co2Vals.add(cd);
      if (pd != null) pressureVals.add(pd);
      if (ld != null) lightVals.add(ld);
  if (dd != null) dewPointVals.add(dd);
      collectExtras(r);
    }
    // previous window comparison for simple trend
    final prevSel = rowsWithTs.where((r) {
      final ts = rowTimestamp(r)!;
      return ts.toUtc().isAfter(prevLower) && ts.toUtc().isBefore(prevUpper);
    }).toList();
    final prevTemps = <double>[];
    for (final r in prevSel) {
      final td = valueFromRow(r, tempKeys);
      if (td != null) prevTemps.add(td);
    }
    var avgTempVal = avg(temps);
    var avgHumVal = avg(hums);
    var avgCo2Val = avg(co2Vals);
    var avgPressureVal = avg(pressureVals);
    var avgLightVal = avg(lightVals);
  var avgDewPointVal = avg(dewPointVals);
    final latestAny = latestRow(rowsWithTs);
    if (latestAny != null) {
      final latestTs = latestAny.key;
      final currentLast = last;
      if (currentLast == null) {
        last = latestTs;
      } else if (latestTs.isAfter(currentLast)) {
        last = latestTs;
      }
      avgTempVal ??= valueFromRow(latestAny.value, tempKeys);
      avgHumVal ??= valueFromRow(latestAny.value, humKeys);
      avgCo2Val ??= valueFromRow(latestAny.value, co2Keys);
      avgPressureVal ??= valueFromRow(latestAny.value, pressureKeys);
      avgLightVal ??= valueFromRow(latestAny.value, lightKeys);
      avgDewPointVal ??= valueFromRow(latestAny.value, dewPointKeys);
      if (sel.isEmpty && extraLists.isEmpty) {
        collectExtras(latestAny.value);
      }
    }
    final extraSummaries = <Map<String, dynamic>>[];
    extraLists.forEach((key, values) {
      final average = avg(values);
      if (average != null) {
        extraSummaries.add({'key': key, 'avg': average});
      }
    });
    extraSummaries.sort((a, b) {
      final ak = a['key']?.toString() ?? '';
      final bk = b['key']?.toString() ?? '';
      return ak.compareTo(bk);
    });
    result['greenhouse'] = {
      'avgTemp': avgTempVal,
      'avgHumidity': avgHumVal,
      'avgCo2': avgCo2Val,
      'avgPressure': avgPressureVal,
      'avgLight': avgLightVal,
      'avgDewPoint': avgDewPointVal,
      'count': sel.length,
      'lastUpdate': last?.toUtc().toIso8601String(),
      'prevAvgTemp': avg(prevTemps),
      'stale': sel.isEmpty && latestAny != null,
      'coverage': rowsWithTs.isEmpty ? null : sel.length / rowsWithTs.length,
      if (extraSummaries.isNotEmpty) 'extraMetrics': extraSummaries,
    };
  } catch (_) {}

  // --- Irrigation ---
  try {
    final irrRaw = await api.fetchAllGroupRaw('irrigation');
    final items = <Map<String, dynamic>>[];
    if (irrRaw != null) {
      final node =
          irrRaw['irrigation_telemetry'] ??
          irrRaw.values.firstWhere((_) => true, orElse: () => null);
      if (node is Map && node['data'] is Map && node['data']['items'] is List) {
        for (final it in node['data']['items']) {
          if (it is Map) {
            items.add(Map<String, dynamic>.from(it));
          }
        }
      }
    }
    const flowKeys = [
      'flow',
      'flowRate',
      'flow_rate',
      'flowrate',
      'flow_lmin',
      'flow_l_min',
      'flowrate_lpm',
      'flow_rate_lpm',
    ];
    const pumpStatusKeys = [
      'pumpState',
      'pump_state',
      'pumpStatus',
      'pump_status',
      'pump_status_code',
      'pump_state_code',
      'status',
    ];
    const pumpIdKeys = ['device_id', 'id', 'DEVICE_ID', 'pump_id'];
    const pressureKeys = [
      'pressure',
      'pressure_bar',
      'pressure_bars',
      'pressure_psi',
      'psi',
      'pressure_kpa',
      'line_pressure',
      'pump_pressure',
    ];
    const valvePctKeys = [
      'valve_open_pct',
      'valve_open_percent',
      'valve_position',
      'valve_percent',
      'valve_opening',
    ];
    const tankLevelKeys = [
      'tank_level',
      'tank_level_pct',
      'reservoir_level',
      'reservoir_pct',
      'water_level_pct',
    ];
    const volumeKeys = [
      'volume',
      'volume_l',
      'volume_liters',
      'total_volume',
      'total_flow',
      'liters_dispensed',
    ];
    final knownKeysLower = <String>{
      for (final k in timestampKeys) k.toLowerCase(),
      for (final k in flowKeys) k.toLowerCase(),
      for (final k in pumpStatusKeys) k.toLowerCase(),
      for (final k in pumpIdKeys) k.toLowerCase(),
      for (final k in pressureKeys) k.toLowerCase(),
      for (final k in valvePctKeys) k.toLowerCase(),
      for (final k in tankLevelKeys) k.toLowerCase(),
      for (final k in volumeKeys) k.toLowerCase(),
      'group',
      'group_id',
      'source',
      'source_id',
      'device',
      'device_serial',
      'id',
      'name',
      'label',
      'status_text',
    };
    final extraLists = <String, List<double>>{};
    void collectExtras(Map<String, dynamic> row) {
      row.forEach((rawKey, rawValue) {
        final key = rawKey.toString();
        final lower = key.toLowerCase();
        if (knownKeysLower.contains(lower)) return;
        if (lower.contains('timestamp')) return;
        if (lower.contains('id') && !lower.contains('index')) return;
        final numeric = toDouble(rawValue);
        if (numeric == null) return;
        extraLists.putIfAbsent(key, () => <double>[]).add(numeric);
      });
    }
    final rowsWithTs = items.where((r) => rowTimestamp(r) != null).toList();
    final sel = rowsWithTs.where((r) {
      final ts = rowTimestamp(r)!;
      return ts.toUtc().isAfter(lower);
    }).toList();
    final flows = <double>[];
    final pressures = <double>[];
    final valvePositions = <double>[];
    final tankLevels = <double>[];
    final volumes = <double>[];
    DateTime? last;
    for (final r in sel) {
      final ts = rowTimestamp(r);
      if (ts != null) {
        final currentLast = last;
        if (currentLast == null) {
          last = ts;
        } else if (ts.isAfter(currentLast)) {
          last = ts;
        }
      }
      final fd = valueFromRow(r, flowKeys);
      if (fd != null) flows.add(fd);
      final pd = valueFromRow(r, pressureKeys);
      if (pd != null) pressures.add(pd);
      final vd = valueFromRow(r, valvePctKeys);
      if (vd != null) valvePositions.add(vd);
      final tl = valueFromRow(r, tankLevelKeys);
      if (tl != null) tankLevels.add(tl);
      final vol = valueFromRow(r, volumeKeys);
      if (vol != null) volumes.add(vol);
      collectExtras(r);
    }

    final latestOverall = latestRow(rowsWithTs);
  final latestByPump = <dynamic, MapEntry<DateTime, Map<String, dynamic>>>{};
    for (final r in rowsWithTs) {
      final ts = rowTimestamp(r);
      if (ts == null) continue;
      final idKey = resolveKeyInRow(r, pumpIdKeys);
      final pumpId = idKey != null ? r[idKey] : null;
      if (pumpId == null) continue;
      final existing = latestByPump[pumpId];
      if (existing == null || ts.isAfter(existing.key)) {
        latestByPump[pumpId] = MapEntry(ts, r);
      }
    }

    bool pumpActiveFromRow(Map<String, dynamic> row) {
      final key = resolveKeyInRow(row, pumpStatusKeys);
      if (key == null) return false;
      final value = row[key];
      if (value == null) return false;
      final norm = value.toString().trim().toUpperCase();
      return norm == 'ON' || norm == 'ACTIVE' || norm == '1' || norm == 'TRUE';
    }

    var flowAvgVal = avg(flows);
    var flowSumVal = sum(flows);
    var avgPressureVal = avg(pressures);
    var avgValveOpenVal = avg(valvePositions);
    var avgTankLevelVal = avg(tankLevels);
    var volumeTotalVal = sum(volumes);
    if (flowAvgVal == null && latestByPump.isNotEmpty) {
      final fallbackFlows = latestByPump.values
          .map((entry) => valueFromRow(entry.value, flowKeys))
          .whereType<double>()
          .toList();
      flowAvgVal = avg(fallbackFlows);
      flowSumVal = sum(fallbackFlows);
    }
    if (avgPressureVal == null && latestByPump.isNotEmpty) {
      final fallbackPressures = latestByPump.values
          .map((entry) => valueFromRow(entry.value, pressureKeys))
          .whereType<double>()
          .toList();
      avgPressureVal = avg(fallbackPressures);
    }
    if (avgValveOpenVal == null && latestByPump.isNotEmpty) {
      final fallbackValve = latestByPump.values
          .map((entry) => valueFromRow(entry.value, valvePctKeys))
          .whereType<double>()
          .toList();
      avgValveOpenVal = avg(fallbackValve);
    }
    if (avgTankLevelVal == null && latestByPump.isNotEmpty) {
      final fallbackLevels = latestByPump.values
          .map((entry) => valueFromRow(entry.value, tankLevelKeys))
          .whereType<double>()
          .toList();
      avgTankLevelVal = avg(fallbackLevels);
    }
    if (volumeTotalVal == null && latestByPump.isNotEmpty) {
      final fallbackVolume = latestByPump.values
          .map((entry) => valueFromRow(entry.value, volumeKeys))
          .whereType<double>()
          .toList();
      volumeTotalVal = sum(fallbackVolume);
    }

    if (latestOverall != null) {
      final latestTs = latestOverall.key;
      final currentLast = last;
      if (currentLast == null) {
        last = latestTs;
      } else if (latestTs.isAfter(currentLast)) {
        last = latestTs;
      }
      if (sel.isEmpty && extraLists.isEmpty) {
        collectExtras(latestOverall.value);
      }
      avgPressureVal ??= valueFromRow(latestOverall.value, pressureKeys);
      avgValveOpenVal ??= valueFromRow(latestOverall.value, valvePctKeys);
      avgTankLevelVal ??=
          valueFromRow(latestOverall.value, tankLevelKeys);
      volumeTotalVal ??=
          valueFromRow(latestOverall.value, volumeKeys);
    }

    final pumpsOn = latestByPump.values
        .where((entry) => pumpActiveFromRow(entry.value))
        .length;

    if (extraLists.isEmpty && latestByPump.isNotEmpty) {
      for (final entry in latestByPump.values) {
        collectExtras(entry.value);
      }
    }

    final extraSummaries = <Map<String, dynamic>>[];
    extraLists.forEach((key, values) {
      final average = avg(values);
      if (average != null) {
        extraSummaries.add({'key': key, 'avg': average});
      }
    });
    extraSummaries.sort((a, b) {
      final ak = a['key']?.toString() ?? '';
      final bk = b['key']?.toString() ?? '';
      return ak.compareTo(bk);
    });

    result['irrigation'] = {
      'flowAvg': flowAvgVal,
      'flowSum': flowSumVal,
      'pumpsOn': pumpsOn,
      'pumpsTotal': latestByPump.length,
      'count': sel.length,
      'lastUpdate': last?.toUtc().toIso8601String(),
      'stale': sel.isEmpty && latestOverall != null,
      'coverage': rowsWithTs.isEmpty ? null : sel.length / rowsWithTs.length,
      'avgPressure': avgPressureVal,
      'avgValvePosition': avgValveOpenVal,
      'avgTankLevel': avgTankLevelVal,
      'volumeTotal': volumeTotalVal,
      if (extraSummaries.isNotEmpty) 'extraMetrics': extraSummaries,
    };
  } catch (_) {}

  // --- Soil ---
  try {
    final allSoil = await api.fetchSoilGroupHistory(limit: 500, offset: 0);
    final rows = <Map<String, dynamic>>[];
    if (allSoil != null) rows.addAll(allSoil);
    const moistureKeys = [
      'moisture',
      'moisture_pct',
      'soil_moisture',
      'moisture_percent',
    ];
    const phKeys = ['ph', 'pH', 'soil_ph'];
    const tempKeys = [
      'soil_temp',
      'soil_temperature',
      'temperature',
      'temp_c',
      'temperature_c',
      'temp_deg_c',
    ];
    const ecKeys = [
      'ec',
      'soil_ec',
      'electrical_conductivity',
      'soil_conductivity',
      'conductivity',
      'ec_ds_m',
    ];
    final knownKeysLower = <String>{
      for (final k in timestampKeys) k.toLowerCase(),
      for (final k in moistureKeys) k.toLowerCase(),
      for (final k in phKeys) k.toLowerCase(),
      for (final k in tempKeys) k.toLowerCase(),
      for (final k in ecKeys) k.toLowerCase(),
      'group',
      'group_id',
      'source',
      'sensor',
      'sensor_id',
      'device',
      'device_id',
      'id',
      'name',
      'label',
    };
    final extraLists = <String, List<double>>{};
    void collectExtras(Map<String, dynamic> row) {
      row.forEach((rawKey, rawValue) {
        final key = rawKey.toString();
        final lower = key.toLowerCase();
        if (knownKeysLower.contains(lower)) return;
        if (lower.contains('timestamp')) return;
        if (lower.contains('id') && !lower.contains('idx')) return;
        final numeric = toDouble(rawValue);
        if (numeric == null) return;
        extraLists.putIfAbsent(key, () => <double>[]).add(numeric);
      });
    }
    final rowsWithTs = rows.where((r) => rowTimestamp(r) != null).toList();
    final sel = rowsWithTs.where((r) {
      final ts = rowTimestamp(r)!;
      return ts.toUtc().isAfter(lower);
    }).toList();
    final moist = <double>[];
    final phs = <double>[];
    final temps = <double>[];
    final ecs = <double>[];
    DateTime? last;
    for (final r in sel) {
      final ts = rowTimestamp(r);
      if (ts != null) {
        final currentLast = last;
        if (currentLast == null) {
          last = ts;
        } else if (ts.isAfter(currentLast)) {
          last = ts;
        }
      }
      final md = valueFromRow(r, moistureKeys);
      final pd = valueFromRow(r, phKeys);
      final td = valueFromRow(r, tempKeys);
      final ec = valueFromRow(r, ecKeys);
      if (md != null) moist.add(md);
      if (pd != null) phs.add(pd);
      if (td != null) temps.add(td);
      if (ec != null) ecs.add(ec);
      collectExtras(r);
    }
    var avgMoist = avg(moist);
    var avgPh = avg(phs);
    var avgTemp = avg(temps);
    var avgEc = avg(ecs);
    final latestAny = latestRow(rowsWithTs);
    if (latestAny != null) {
      final latestTs = latestAny.key;
      final currentLast = last;
      if (currentLast == null) {
        last = latestTs;
      } else if (latestTs.isAfter(currentLast)) {
        last = latestTs;
      }
      avgMoist ??= valueFromRow(latestAny.value, moistureKeys);
      avgPh ??= valueFromRow(latestAny.value, phKeys);
      avgTemp ??= valueFromRow(latestAny.value, tempKeys);
      avgEc ??= valueFromRow(latestAny.value, ecKeys);
      if (sel.isEmpty && extraLists.isEmpty) {
        collectExtras(latestAny.value);
      }
    }
    final extraSummaries = <Map<String, dynamic>>[];
    extraLists.forEach((key, values) {
      final average = avg(values);
      if (average != null) {
        extraSummaries.add({'key': key, 'avg': average});
      }
    });
    extraSummaries.sort((a, b) {
      final ak = a['key']?.toString() ?? '';
      final bk = b['key']?.toString() ?? '';
      return ak.compareTo(bk);
    });
    result['soil'] = {
      'avgMoisture': avgMoist,
      'avgPh': avgPh,
      'avgTemp': avgTemp,
      'avgEc': avgEc,
      'count': sel.length,
      'lastUpdate': last?.toUtc().toIso8601String(),
      'stale': sel.isEmpty && latestAny != null,
      'coverage': rowsWithTs.isEmpty ? null : sel.length / rowsWithTs.length,
      if (extraSummaries.isNotEmpty) 'extraMetrics': extraSummaries,
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
    final rowsWithTs = items.where((r) => rowTimestamp(r) != null).toList();
    final sel = rowsWithTs.where((r) {
      final ts = rowTimestamp(r)!;
      return ts.toUtc().isAfter(lower);
    }).toList();
    int threats = 0;
    String? topLabel;
    double topConf = -1.0;
    DateTime? last;
    void consumeRow(Map<String, dynamic> r) {
      final labelKey = resolveKeyInRow(r, [
        'label',
        'disease',
        'class',
        'prediction',
        'predicted_label',
        'category',
        'issue',
      ]);
      final confidenceKey = resolveKeyInRow(r, [
        'confidence',
        'score',
        'probability',
        'accuracy',
        'confidence_score',
        'detection_confidence',
      ]);
      final lab = labelKey != null
          ? (r[labelKey]?.toString() ?? '')
          : (r['label'] ?? r['disease'] ?? '').toString();
      final conf = confidenceKey != null
          ? (toDouble(r[confidenceKey]) ?? 0.0)
          : (toDouble(r['confidence'] ?? r['score'] ?? r['probability']) ??
                0.0);
      final ts = rowTimestamp(r);
      if (ts != null) {
        final currentLast = last;
        if (currentLast == null) {
          last = ts;
        } else if (ts.isAfter(currentLast)) {
          last = ts;
        }
      }
      if (lab.toLowerCase() != 'healthy' &&
          lab.toLowerCase() != 'unknown' &&
          lab.isNotEmpty) {
        threats += 1;
      }
      if (conf > topConf) {
        topConf = conf;
        topLabel = lab;
      }
    }

    for (final r in sel) {
      consumeRow(r);
    }

    final latestAny = latestRow(rowsWithTs);
    if (sel.isEmpty && latestAny != null) {
      // Provide fallback context from last known detection.
      consumeRow(latestAny.value);
    }

    result['crop'] = {
      'threats': threats,
      'topLabel': topLabel,
      'topConf': topConf >= 0 ? topConf : null,
      'count': sel.length,
      'lastUpdate': last?.toUtc().toIso8601String(),
      'stale': sel.isEmpty && latestAny != null,
      'coverage': rowsWithTs.isEmpty ? null : sel.length / rowsWithTs.length,
    };
  } catch (_) {}

  return result;
}

// End of overview page helpers
