// lib/services/api_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/greenhouse_data.dart';
import '../models/irrigation_data.dart';
import '../models/soil_data.dart';
import '../models/crop_vision_data.dart';
// Climate data removed (endpoint not available)
// Import your other models here as you create them
// import '../models/soil_data.dart';

class ApiService {
  // Singleton so polling starts only once when the app constructs ApiService()
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  // Public generative constructor intended for tests and subclassing.
  ApiService.raw();

  ApiService._internal() {
    _startPolling();
  }
  // !!! ================================================================= !!!
  // !!! ===           UPDATE THIS IP ADDRESS TO MATCH YOUR PC           === !!!
  // !!! ================================================================= !!!
  // Development-friendly default: localhost. Replace with your production host as needed.
  final String _baseUrl = "http://127.0.0.1:5000/api"; // <-- change this if running the API elsewhere

  /// Public accessor for UI/settings to show where the API calls are directed.
  String get baseUrl => _baseUrl;

  // Simple client-side cache: map endpoint -> {ts: epochSeconds, data: parsedObject}
  final Map<String, Map<String, dynamic>> _cache = {};
  final int _cacheTtlSeconds = 30;

  // Keep simple source metadata per key (live|cache|stale_cache|debug)
  final Map<String, String> _source = {};
  // Per-key numeric history buffers. Each key maps to metric name -> list of recent double values.
  final Map<String, Map<String, List<double>>> _history = {};
  final int _historyLength = 30;

  // Track last emitted JSON for each stream key to avoid pushing identical
  // values repeatedly which causes unnecessary rebuilds in Flutter widgets.
  final Map<String, String> _lastEmittedJson = {};

  void _maybeEmit<T>(String key, T value, StreamController<T> controller) {
    try {
      final s = jsonEncode(value);
      if (_lastEmittedJson[key] != s) {
        controller.add(value);
        _lastEmittedJson[key] = s;
      }
    } catch (_) {
      // Fallback: if value isn't JSON-encodable, compare toString
      final s = value.toString();
      if (_lastEmittedJson[key] != s) {
        controller.add(value);
        _lastEmittedJson[key] = s;
      }
    }
  }

  void _pushHistory(String key, String metric, double value) {
    _history.putIfAbsent(key, () => {});
    final metricMap = _history[key]!;
    metricMap.putIfAbsent(metric, () => <double>[]);
    final list = metricMap[metric]!;
    list.add(value);
    if (list.length > _historyLength) list.removeAt(0);
  }

  /// Returns an immutable copy of the recent values for metric under key.
  List<double> getHistory(String key, String metric) => List.unmodifiable(_history[key]?[metric] ?? []);

  // Helper to select a single source payload from the bridge's /api/<group>/all
  // response. Prefer the 'DEFAULT' source if present, otherwise pick the first
  // available mapping value. Returns null when no usable payload found.
  Map<String, dynamic>? _pickSourcePayload(Map<String, dynamic> all) {
    // New selection policy:
    // 1. Prefer any source where _source == 'live'.
    // 2. If multiple live sources, select the one with the highest _fetched_ts.
    // 3. If no live sources, select the one with the highest _fetched_ts overall.
    // The aggregated 'all' map is expected to be Map<sourceName, payloadMap>.
    if (all.isEmpty) return null;

    List<Map<String, dynamic>> entries = [];
    for (final val in all.values) {
      if (val is Map<String, dynamic>) entries.add(Map<String, dynamic>.from(val));
    }

    if (entries.isEmpty) return null;

    int tsFor(Map<String, dynamic> m) {
      final t = m['_fetched_ts'] ?? m['_fetched_ts_seconds'] ?? m['fetched_ts'];
      if (t is int) return t;
      if (t is double) return t.toInt();
      if (t is String && int.tryParse(t) != null) return int.parse(t);
      return 0;
    }

    // Filter live entries
  final live = entries.where((e) => (e['_source']?.toString() ?? '').toLowerCase() == 'live').toList();
  final List<Map<String, dynamic>> candidates = live.isNotEmpty ? live : entries;

  // Pick the one with highest _fetched_ts
  candidates.sort((a, b) => tsFor(b).compareTo(tsFor(a)));
    return candidates.first;
  }

  /// Return cached parsed data for a key, or null if none available.
  T? getCached<T>(String key) {
    final entry = _cache[key];
    if (entry == null) return null;
    return entry['data'] as T;
  }
  // Streams for live updates. UI pages subscribe to these to receive live data.
  final StreamController<GreenhouseData> _greenhouseController = StreamController<GreenhouseData>.broadcast();
  final StreamController<IrrigationData> _irrigationController = StreamController<IrrigationData>.broadcast();
  final StreamController<SoilData> _soilController = StreamController<SoilData>.broadcast();
  final StreamController<CropVisionData> _cropVisionController = StreamController<CropVisionData>.broadcast();
  Stream<GreenhouseData> get greenhouseStream => _greenhouseController.stream;
  Stream<IrrigationData> get irrigationStream => _irrigationController.stream;
  Stream<SoilData> get soilStream => _soilController.stream;
  Stream<CropVisionData> get cropVisionStream => _cropVisionController.stream;
  // Climate stream removed (endpoint not available)

  final Map<String, Timer> _pollTimers = {};


  void _startPolling({int intervalSeconds = 6}) {
    // Re-enable all group polling for normal operation.
    // Prime data sources on startup sequentially to avoid overwhelming the
    // backend with simultaneous requests. We intentionally start this
    // async helper without awaiting so startup remains non-blocking.
    _initialPrimeSequentially();

    // Set periodic timers for each group. Intervals are configurable by
    // adjusting the `intervalSeconds` base value.
    _pollTimers['greenhouse'] = Timer.periodic(Duration(seconds: intervalSeconds * 5), (_) async {
      try {
        final g = await fetchLatestGreenhouseData();
        _maybeEmit('greenhouse', g, _greenhouseController);
      } catch (_) {}
    });

    _pollTimers['irrigation'] = Timer.periodic(Duration(seconds: intervalSeconds * 3), (_) async {
      try {
        final i = await fetchLatestIrrigationData();
        _maybeEmit('irrigation', i, _irrigationController);
      } catch (_) {}
    });

    _pollTimers['soil'] = Timer.periodic(Duration(seconds: intervalSeconds * 4), (_) async {
      try {
        final s = await fetchLatestSoilData();
        _maybeEmit('soil', s, _soilController);
      } catch (_) {}
    });

    _pollTimers['crop_vision'] = Timer.periodic(Duration(seconds: intervalSeconds * 6), (_) async {
      try {
        final c = await fetchLatestCropVisionData();
        _maybeEmit('crop_vision', c, _cropVisionController);
      } catch (_) {}
    });

    // Periodically fetch the full /api/all snapshot and persist it for insights
    // (We store this timer inside _pollTimers to keep cancellation centralized.)
    _pollTimers['all_snapshot'] = Timer.periodic(Duration(minutes: 5), (_) async {
      try {
        await fetchAllData();
      } catch (_) {}
    });

  }

  Future<void> _initialPrimeSequentially() async {
    try {
      try {
        final g = await fetchLatestGreenhouseData();
        _maybeEmit('greenhouse', g, _greenhouseController);
      } catch (_) {}
      try {
        final i = await fetchLatestIrrigationData();
        _maybeEmit('irrigation', i, _irrigationController);
      } catch (_) {}
      try {
        final s = await fetchLatestSoilData();
        _maybeEmit('soil', s, _soilController);
      } catch (_) {}
      try {
        final c = await fetchLatestCropVisionData();
        _maybeEmit('crop_vision', c, _cropVisionController);
      } catch (_) {}
    } catch (_) {}

    // timers are set in _startPolling where intervalSeconds is in scope.
  }

  /// Call during app shutdown if you need to clear resources.
  void dispose() {
    for (final t in _pollTimers.values) {
      t.cancel();
    }
    _greenhouseController.close();
    _irrigationController.close();
    _soilController.close();
    _cropVisionController.close();
  // Climate controller removed
  }

  /// Fetches the latest sensor readings from the greenhouse (with short cache).
  Future<GreenhouseData> fetchLatestGreenhouseData() async {
    final key = 'greenhouse';
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final entry = _cache[key];
    if (entry != null && (now - (entry['ts'] as int) < _cacheTtlSeconds)) {
      return entry['data'] as GreenhouseData;
    }
    try {
  // Request aggregated sources endpoint and pick a single payload to parse
  final response = await http.get(Uri.parse('$_baseUrl/greenhouse/all')).timeout(const Duration(seconds: 120));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final payload = _pickSourcePayload(body);
        if (payload != null) {
          // source metadata
          _source[key] = payload['_source']?.toString() ?? 'live';
          final parsed = GreenhouseData.fromJson(payload);
          _cache[key] = {'ts': now, 'data': parsed};
          // persist selected payload JSON so we can fall back when offline
          try {
            await Hive.box('greenhouse_data').put('latest', jsonEncode(payload));
          } catch (_) {}
          _pushHistory(key, 'temperature', parsed.temperature);
          _pushHistory(key, 'humidity', parsed.humidity);
          if (parsed.lightIntensity != null) _pushHistory(key, 'light', parsed.lightIntensity!);
          if (parsed.co2 != null) _pushHistory(key, 'co2', parsed.co2!);
          return parsed;
        }
      }
    } catch (e) {
      if (kDebugMode) print('fetchLatestGreenhouseData error: $e');
    }

    // network failed: try returning in-memory stale cache first
    if (entry != null) return entry['data'] as GreenhouseData;

    // next try persistent Hive cache
    try {
      final cached = Hive.box('greenhouse_data').get('latest');
      if (cached != null && cached is String) {
        final body = jsonDecode(cached) as Map<String, dynamic>;
        final parsed = GreenhouseData.fromJson(body);
        _cache[key] = {'ts': now, 'data': parsed};
        _source[key] = 'offline';
        return parsed;
      }
    } catch (e) {
      if (kDebugMode) print('greenhouse hive read error: $e');
    }

  // No cached data available and unable to fetch from network.
  // Do not fabricate synthetic data. Let callers handle absence of data.
  throw Exception('No greenhouse data available');
  }

  /// Fetches the latest irrigation readings from the system.
  Future<IrrigationData> fetchLatestIrrigationData() async {
    final key = 'irrigation';
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final entry = _cache[key];
    if (entry != null && (now - (entry['ts'] as int) < _cacheTtlSeconds)) {
      return entry['data'] as IrrigationData;
    }
    try {
  final response = await http.get(Uri.parse('$_baseUrl/irrigation/all')).timeout(const Duration(seconds: 120));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final payload = _pickSourcePayload(body);
        if (payload != null) {
          _source[key] = payload['_source']?.toString() ?? 'live';
          final parsed = IrrigationData.fromJson(payload);
          _cache[key] = {'ts': now, 'data': parsed};
          try {
            await Hive.box('irrigation_data').put('latest', jsonEncode(payload));
          } catch (_) {}
          _pushHistory(key, 'flow', parsed.flowRateLmin);
          _pushHistory(key, 'total_volume', parsed.totalVolume);
          return parsed;
        }
      }
    } catch (e) {
      if (kDebugMode) print('fetchLatestIrrigationData error: $e');
    }

    if (entry != null) return entry['data'] as IrrigationData;
    try {
      final cached = Hive.box('irrigation_data').get('latest');
      if (cached != null && cached is String) {
        final body = jsonDecode(cached) as Map<String, dynamic>;
        final parsed = IrrigationData.fromJson(body);
        _cache[key] = {'ts': now, 'data': parsed};
        _source[key] = 'offline';
        return parsed;
      }
    } catch (e) {
      if (kDebugMode) print('irrigation hive read error: $e');
    }

  throw Exception('No irrigation data available');
  }

  // You will add your other functions here later
  //
  Future<SoilData> fetchLatestSoilData() async {
    final key = 'soil';
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final entry = _cache[key];
    if (entry != null && (now - (entry['ts'] as int) < _cacheTtlSeconds)) {
      return entry['data'] as SoilData;
    }
    try {
  final response = await http.get(Uri.parse('$_baseUrl/soil/all')).timeout(const Duration(seconds: 120));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final payload = _pickSourcePayload(body);
        if (payload != null) {
          _source[key] = payload['_source']?.toString() ?? 'live';
          final parsed = SoilData.fromJson(payload);
          _cache[key] = {'ts': now, 'data': parsed};
          try {
            await Hive.box('soil_data').put('latest', jsonEncode(payload));
          } catch (_) {}
          _pushHistory(key, 'moisture', parsed.moisturePct);
          _pushHistory(key, 'soil_temp', parsed.temperature);
          return parsed;
        }
      }
    } catch (e) {
      if (kDebugMode) print('fetchLatestSoilData error: $e');
    }

  if (entry != null) return entry['data'] as SoilData;
    try {
      final cached = Hive.box('soil_data').get('latest');
      if (cached != null && cached is String) {
        final body = jsonDecode(cached) as Map<String, dynamic>;
        final parsed = SoilData.fromJson(body);
        _cache[key] = {'ts': now, 'data': parsed};
        _source[key] = 'offline';
        return parsed;
      }
    } catch (e) {
      if (kDebugMode) print('soil hive read error: $e');
    }

  throw Exception('No soil data available');
  }

  Future<CropVisionData> fetchLatestCropVisionData() async {
    final key = 'crop_vision';
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final entry = _cache[key];
    if (entry != null && (now - (entry['ts'] as int) < _cacheTtlSeconds)) {
      return entry['data'] as CropVisionData;
    }
    try {
  final response = await http.get(Uri.parse('$_baseUrl/crop_vision/all')).timeout(const Duration(seconds: 120));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final payload = _pickSourcePayload(body);
        if (payload != null) {
          _source[key] = payload['_source']?.toString() ?? 'live';
          final parsed = CropVisionData.fromJson(payload);
          _cache[key] = {'ts': now, 'data': parsed};
          try {
            await Hive.box('crop_vision_data').put('latest', jsonEncode(payload));
          } catch (_) {}
          if (parsed.ndvi != null) _pushHistory(key, 'ndvi', parsed.ndvi!);
          return parsed;
        }
      }
    } catch (e) {
      if (kDebugMode) print('fetchLatestCropVisionData error: $e');
    }

  if (entry != null) return entry['data'] as CropVisionData;
    try {
      final cached = Hive.box('crop_vision_data').get('latest');
      if (cached != null && cached is String) {
        final body = jsonDecode(cached) as Map<String, dynamic>;
        final parsed = CropVisionData.fromJson(body);
        _cache[key] = {'ts': now, 'data': parsed};
        _source[key] = 'offline';
        return parsed;
      }
    } catch (e) {
      if (kDebugMode) print('crop_vision hive read error: $e');
    }

    throw Exception('No crop vision data available');
  }

  // Climate endpoint removed; method deleted.

  // Public refresh helpers: call the fetch method and push the result onto the
  // corresponding stream so UI callers can trigger an immediate retry and the
  // StreamBuilder listeners will update.
  Future<void> refreshGreenhouse() async {
    final g = await fetchLatestGreenhouseData();
    _greenhouseController.add(g);
  }

  Future<void> refreshIrrigation() async {
    final i = await fetchLatestIrrigationData();
    _irrigationController.add(i);
  }

  Future<void> refreshSoil() async {
    final s = await fetchLatestSoilData();
    _soilController.add(s);
  }

  Future<void> refreshCropVision() async {
    final c = await fetchLatestCropVisionData();
    _cropVisionController.add(c);
  }

  /// Return the last known source metadata for a particular key, or null.
  String? getSource(String key) => _source[key];

  /// Fetch the aggregated map of sources for a logical group from the bridge.
  /// Returns a Map where keys are source names (e.g. 'G6') and values are
  /// the normalized payload maps returned by the bridge. Returns null on
  /// network error.
  Future<Map<String, dynamic>?> fetchAllGroupRaw(String group) async {
    try {
  final resp = await http.get(Uri.parse('$_baseUrl/$group/all')).timeout(const Duration(seconds: 120));
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        return body.map((k, v) => MapEntry(k.toString(), v));
      }
    } catch (e) {
      if (kDebugMode) print('fetchAllGroupRaw error for $group: $e');
    }
    return null;
  }

  /// Fetch up to 10 raw history rows for a particular group/source from the bridge.
  /// Returns a list of maps (each map is a raw row with original upstream column names)
  /// or null on network/error.
  /// Fetch up to [limit] raw history rows for a particular group/source from the bridge.
  /// Returns a list of maps (each map is a raw row with original upstream column names)
  /// or null on network/error.
  Future<List<Map<String, dynamic>>?> fetchGroupHistory(String group, String source, {int limit = 10, int offset = 0, String? duration}) async {
    try {
      // If offset is requested but backend doesn't support offset, request a larger
      // window (offset + limit) and slice client-side. If backend supports offset
      // it will ignore the extra limit or respect offset; this approach is
      // conservative and works across bridges.
      final fetchLimit = offset > 0 ? (offset + limit) : limit;
      final params = <String>[];
      params.add('limit=$fetchLimit');
      if (duration != null && duration.isNotEmpty) params.add('duration=${Uri.encodeQueryComponent(duration)}');
      if (offset > 0) params.add('offset=$offset');
      final query = params.isNotEmpty ? '?${params.join('&')}' : '';
      final uri = Uri.parse('$_baseUrl/$group/history/$source$query');
  final resp = await http.get(uri).timeout(const Duration(seconds: 120));
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        if (body is List) {
          final list = body.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map)).toList();
          if (offset > 0) {
            if (list.length <= offset) return <Map<String, dynamic>>[];
            final end = (offset + limit) < list.length ? (offset + limit) : list.length;
            return list.sublist(offset, end);
          }
          return list;
        }
      }
    } catch (e) {
      if (kDebugMode) print('fetchGroupHistory error for $group/$source: $e');
    }
    return null;
  }

  /// Fetch consolidated history rows for soil groups 7,8,10 from a dedicated
  /// endpoint. The endpoint is expected to return a JSON list of rows where
  /// each row is a map with the original column names (including GROUP_ID and CREATED_AT).
  /// Fetch consolidated history rows for soil groups (7,8,10).
  /// If [limit] is provided it will be sent as a query parameter to the
  /// backend endpoint (e.g. ?limit=5). Returns null on network/error.
  Future<List<Map<String, dynamic>>?> fetchSoilGroupHistory({int? limit, int offset = 0, bool synthetic = false}) async {
    try {
      final params = <String>[];
      final fetchLimit = (limit != null ? limit : 0) + (offset > 0 ? offset : 0);
      if (fetchLimit > 0) params.add('limit=$fetchLimit');
      if (synthetic) params.add('synthetic=1');
  final query = params.isNotEmpty ? '?${params.join('&')}' : '';
  final uri = Uri.parse('$_baseUrl/soil/history_by_group$query');
  final resp = await http.get(uri).timeout(const Duration(seconds: 120));
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        if (body is List) {
          final list = body.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map)).toList();
          if (offset > 0) {
            if (list.length <= offset) return <Map<String, dynamic>>[];
            final end = (offset + (limit ?? 0)) < list.length ? (offset + (limit ?? 0)) : list.length;
            return list.sublist(offset, end);
          }
          return list;
        }
      }
    } catch (e) {
      if (kDebugMode) print('fetchSoilGroupHistory error: $e');
    }
    return null;
  }

  /// Request the bridge to force-refresh a specific group/source pair synchronously.
  /// Returns true when the refresh endpoint returned 200.
  Future<bool> forceRefreshGroupSource(String group, String source) async {
    try {
      final uri = Uri.parse('$_baseUrl/force_refresh/$group/$source');
  final resp = await http.post(uri).timeout(const Duration(seconds: 120));
      return resp.statusCode == 200;
    } catch (e) {
      if (kDebugMode) print('forceRefreshGroupSource error: $e');
      return false;
    }
  }

  /// Fetch the entire bridge payload (/api/all) and persist it into Hive
  /// box 'historical_data' along with a timestamp. Also cleans up entries
  /// older than 7 days.
  Future<void> fetchAllData() async {
    try {
      final uri = Uri.parse('$_baseUrl/all');
      final resp = await http.get(uri).timeout(const Duration(seconds: 120));
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        final box = Hive.box('historical_data');
        final nowMillis = DateTime.now().toUtc().millisecondsSinceEpoch;
        final key = nowMillis.toString();
        // Store as a map with ts and payload
        await box.put(key, {'ts': nowMillis, 'payload': body});

        // Cleanup: remove entries older than 7 days
        final cutoff = DateTime.now().toUtc().subtract(Duration(days: 7)).millisecondsSinceEpoch;
        final toRemove = <dynamic>[];
        for (final k in box.keys) {
          try {
            final v = box.get(k);
            if (v is Map && v['ts'] is int && v['ts'] < cutoff) toRemove.add(k);
          } catch (_) {}
        }
        for (final k in toRemove) {
          await box.delete(k);
        }
      }
    } catch (e) {
      if (kDebugMode) print('fetchAllData error: $e');
    }
  }

}