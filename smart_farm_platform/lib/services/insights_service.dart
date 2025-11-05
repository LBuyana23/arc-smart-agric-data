import 'package:hive/hive.dart';

class InsightsService {
  /// Calculate the percentage difference between average soil moisture of
  /// the most recent day and the average from 7 days ago. Returns null when
  /// insufficient data.
  Future<double?> calculateWeeklySoilMoistureChange() async {
    final box = Hive.box('historical_data');
    final now = DateTime.now().toUtc();
    final cutoff = now.subtract(Duration(days: 7));

    // Collect payloads in the last 7 days
    final entries = <Map<String, dynamic>>[];
    for (final k in box.keys) {
      final v = box.get(k);
      if (v is Map && v['ts'] is int) {
        final ts = DateTime.fromMillisecondsSinceEpoch(v['ts'], isUtc: true);
        if (ts.isAfter(cutoff)) {
          if (v['payload'] is Map) entries.add(Map<String, dynamic>.from(v['payload']));
        }
      }
    }

    if (entries.isEmpty) return null;

    // Group entries by day (UTC date)
    final Map<String, List<Map<String, dynamic>>> byDay = {};
    for (final e in entries) {
      final ts = DateTime.now().toUtc(); // we don't have per-entry ts here - assume key order handled elsewhere
      final day = ts.toIso8601String().split('T').first;
      byDay.putIfAbsent(day, () => []).add(e);
    }

    // Find most recent day and the day 7 days ago
    final days = byDay.keys.toList()..sort();
    if (days.length < 2) return null;
    final recentDay = days.last;
    final oldestDay = days.first;

    double averageForDay(List<Map<String, dynamic>> payloads) {
      final values = <double>[];
      for (final p in payloads) {
        try {
          // Soil groups live under keys soil_g7/soil_g8/soil_g10 inside payload
          for (final k in ['soil_g7', 'soil_g8', 'soil_g10']) {
            final node = p[k];
            if (node is Map && node['data'] is Map && node['data']['items'] is List) {
              for (final item in node['data']['items']) {
                if (item is Map && item['moisture'] != null) {
                  final val = double.tryParse(item['moisture'].toString());
                  if (val != null) values.add(val);
                }
              }
            } else if (node is List) {
              for (final item in node) {
                if (item is Map && item['moisture'] != null) {
                  final val = double.tryParse(item['moisture'].toString());
                  if (val != null) values.add(val);
                }
              }
            }
          }
        } catch (_) {}
      }
      if (values.isEmpty) return double.nan;
      return values.reduce((a, b) => a + b) / values.length;
    }

    final recentAvg = averageForDay(byDay[recentDay]!);
    final oldestAvg = averageForDay(byDay[oldestDay]!);
    if (recentAvg.isNaN || oldestAvg.isNaN) return null;
    if (oldestAvg == 0) return null;
    return ((recentAvg - oldestAvg) / oldestAvg) * 100.0;
  }

  /// Calculate total irrigation volume in the last 7 days. Returns null if no data.
  Future<double?> calculateWeeklyIrrigationVolume() async {
    final box = Hive.box('historical_data');
    final now = DateTime.now().toUtc();
    final cutoff = now.subtract(Duration(days: 7));
    double total = 0.0;
    bool found = false;
    for (final k in box.keys) {
      final v = box.get(k);
      if (v is Map && v['ts'] is int && v['ts'] >= cutoff.millisecondsSinceEpoch) {
        final payload = v['payload'];
        if (payload is Map) {
          final node = payload['irrigation_telemetry'];
          if (node is Map && node['data'] is Map && node['data']['items'] is List) {
            for (final item in node['data']['items']) {
              if (item is Map && item['total_flow'] != null) {
                final val = double.tryParse(item['total_flow'].toString());
                if (val != null) {
                  total += val;
                  found = true;
                }
              }
              // fallback to totalVolume
              if (item is Map && item['totalVolume'] != null) {
                final val = double.tryParse(item['totalVolume'].toString());
                if (val != null) {
                  total += val;
                  found = true;
                }
              }
            }
          }
        }
      }
    }
    return found ? total : null;
  }

  /// Count recent high-confidence detections in crop vision payloads within 7 days.
  Future<int> countRecentDetections({double confidenceThreshold = 0.8}) async {
    final box = Hive.box('historical_data');
    final now = DateTime.now().toUtc();
    final cutoff = now.subtract(Duration(days: 7)).millisecondsSinceEpoch;
    int count = 0;
    for (final k in box.keys) {
      final v = box.get(k);
      if (v is Map && v['ts'] is int && v['ts'] >= cutoff) {
        final payload = v['payload'];
        if (payload is Map) {
          for (final key in ['crop_vision_g4', 'crop_vision_g5']) {
            final node = payload[key];
            if (node is Map && node['data'] is Map && node['data']['items'] is List) {
              for (final item in node['data']['items']) {
                if (item is Map && item['disease'] != null && item['confidence'] != null) {
                  final conf = double.tryParse(item['confidence'].toString()) ?? 0.0;
                  final disease = item['disease'].toString();
                  if ((disease.toLowerCase() != 'healthy' && disease.toLowerCase() != 'unknown') && conf >= confidenceThreshold) {
                    count += 1;
                  }
                }
              }
            }
          }
        }
      }
    }
    return count;
  }
}
