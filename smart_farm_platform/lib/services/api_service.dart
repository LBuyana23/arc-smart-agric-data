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

enum BackendState { online, warming, offline }

class ServiceStatus {
  final BackendState state;
  final Duration? latency;
  final String? message;
  final Object? error;
  final DateTime updatedAt;

  const ServiceStatus({required this.state, required this.updatedAt, this.latency, this.message, this.error});

  factory ServiceStatus.initial() => ServiceStatus(state: BackendState.warming, updatedAt: DateTime.now(), message: 'Connecting to farm services...');

  factory ServiceStatus.online({Duration? latency, String? message}) => ServiceStatus(
        state: BackendState.online,
        latency: latency,
        message: message ?? 'Farm services online',
        updatedAt: DateTime.now(),
      );

  factory ServiceStatus.warming({Duration? latency, String? message, Object? error}) => ServiceStatus(
        state: BackendState.warming,
        latency: latency,
        message: message ?? 'Warming up backend...',
        error: error,
        updatedAt: DateTime.now(),
      );

  factory ServiceStatus.offline({Duration? latency, String? message, Object? error}) => ServiceStatus(
        state: BackendState.offline,
        latency: latency,
        message: message ?? 'Backend unreachable',
        error: error,
        updatedAt: DateTime.now(),
      );

  String get displayMessage => message ??
      (state == BackendState.online
          ? 'Farm services online'
          : state == BackendState.warming
              ? 'Warming up backend...'
              : 'Backend unreachable');
}

class ApiService {
  // Singleton so polling starts only once when the app constructs ApiService()
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  // Public generative constructor intended for tests and subclassing.
  ApiService.raw();

  // By default polling is disabled to avoid starting timers during widget
  // tests. Call [enablePolling()] from your app's main() to activate
  // background polling in normal runs.
  static bool _pollingEnabled = false;

  ApiService._internal() {
    // Load persisted list caches from Hive before starting polling so UI
    // can read persisted history immediately on app start.
    _loadPersistedListCache();
    if (_pollingEnabled) {
      _startPolling();
    }
  }

  /// Enable background polling for the singleton ApiService. Safe to call
  /// multiple times; polling will only be started once.
  void enablePolling({int intervalSeconds = 6}) {
    if (_pollingEnabled) return;
    _pollingEnabled = true;
    // Start polling if the singleton has already been constructed.
    // If polling was enabled before construction, _internal will start it.
    try {
      _startPolling(intervalSeconds: intervalSeconds);
    } catch (_) {}
  }
  // Base API URL can be configured at build time via --dart-define=API_BASE_URL=<url>
  // Default to the provided Render-hosted Flask app for convenience.
  // Example: flutter run --dart-define=API_BASE_URL=https://smart-farm-api-g25w.onrender.com/api
  final String _baseUrl = const String.fromEnvironment('API_BASE_URL', defaultValue: 'https://smart-farm-api-g25w.onrender.com/api');

  /// Public accessor for UI/settings to show where the API calls are directed.
  String get baseUrl => _baseUrl;

  // Simple client-side cache: map endpoint -> {ts: epochSeconds, data: parsedObject}
  final Map<String, Map<String, dynamic>> _cache = {};

  // Keep simple source metadata per key (live|cache|stale_cache|debug)
  final Map<String, String> _source = {};
  // Per-key numeric history buffers. Each key maps to metric name -> list of recent double values.
  final Map<String, Map<String, List<double>>> _history = {};
  final int _historyLength = 30;
  // Simple in-memory cache for list-style history endpoints (group/source).
  final Map<String, List<Map<String, dynamic>>> _listCache = {};
  final Map<String, int> _listCacheTs = {};
  final Map<String, Map<String, dynamic>> _oracleGroupCache = {};
  final Map<String, int> _oracleGroupCacheTs = {};
  final String _historyCacheBox = 'history_cache';
  final http.Client _client = http.Client();
  final ValueNotifier<ServiceStatus> serviceStatus = ValueNotifier<ServiceStatus>(ServiceStatus.initial());

  void _publishStatus(ServiceStatus next) {
    try {
      final current = serviceStatus.value;
      final sameState = current.state == next.state;
      final sameMessage = (current.message ?? '') == (next.message ?? '');
      final currentLatency = current.latency?.inMilliseconds ?? -1;
      final nextLatency = next.latency?.inMilliseconds ?? -1;
      final latencyClose = (currentLatency - nextLatency).abs() < 150;
      if (sameState && sameMessage && latencyClose) return;
      serviceStatus.value = next;
    } catch (_) {
      serviceStatus.value = next;
    }
  }

  Future<http.Response> _resilientGet(
    Uri uri, {
    Duration timeout = const Duration(seconds: 60),
    int maxAttempts = 3,
    bool updateStatus = true,
    String? debugLabel,
  }) async {
    final sw = Stopwatch()..start();
    Object? lastError;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final resp = await _client.get(uri).timeout(timeout);
        if (resp.statusCode >= 500 && attempt + 1 < maxAttempts) {
          lastError = Exception('HTTP ${resp.statusCode}');
          if (updateStatus) {
            _publishStatus(ServiceStatus.warming(
              latency: sw.elapsed,
              message: '${debugLabel ?? uri.host}: ${resp.statusCode} — retrying (${attempt + 1}/$maxAttempts)',
            ));
          }
          await Future.delayed(Duration(milliseconds: 350 * (attempt + 1)));
          continue;
        }

        if (updateStatus) {
          final latency = sw.elapsed;
          final bool slow = latency > const Duration(seconds: 4) || attempt > 0 || resp.statusCode >= 300;
          if (slow) {
            _publishStatus(ServiceStatus.warming(
              latency: latency,
              message: resp.statusCode >= 400
                  ? '${debugLabel ?? uri.host}: ${resp.statusCode} — showing cached data'
                  : 'Backend responding slowly (${latency.inSeconds}s)...',
            ));
          } else {
            _publishStatus(ServiceStatus.online(latency: latency));
          }
        }
        return resp;
      } on TimeoutException catch (e) {
        lastError = e;
        if (updateStatus) {
          _publishStatus(ServiceStatus.warming(
            latency: sw.elapsed,
            message: 'Timeout contacting ${debugLabel ?? uri.host} (attempt ${attempt + 1}/$maxAttempts)',
            error: e,
          ));
        }
      } catch (e) {
        lastError = e;
        if (updateStatus) {
          _publishStatus(ServiceStatus.warming(
            latency: sw.elapsed,
            message: 'Error contacting ${debugLabel ?? uri.host} — retrying (${attempt + 1}/$maxAttempts)',
            error: e,
          ));
        }
      }

      if (attempt + 1 < maxAttempts) {
        await Future.delayed(Duration(milliseconds: 450 * (attempt + 1)));
      }
    }

    if (updateStatus) {
      _publishStatus(ServiceStatus.offline(
        latency: sw.elapsed,
        message: 'Unable to reach ${debugLabel ?? uri.host}. Showing cached data when available.',
        error: lastError,
      ));
    }

    if (lastError is TimeoutException) throw lastError;
    if (lastError is Exception) throw lastError;
    throw Exception('GET $uri failed after $maxAttempts attempts');
  }

  DateTime? _parseTimestamp(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    final s = raw.toString();
    final parsed = DateTime.tryParse(s);
    if (parsed != null) return parsed;
    final numVal = int.tryParse(s);
    if (numVal != null) {
      if (s.length > 11) return DateTime.fromMillisecondsSinceEpoch(numVal);
      return DateTime.fromMillisecondsSinceEpoch(numVal * 1000);
    }
    return null;
  }

  Uri _buildOracleUri(String baseUrl, {required int offset, required int limit}) {
    final uri = Uri.parse(baseUrl);
    final params = Map<String, String>.from(uri.queryParameters);
    params['offset'] = offset.toString();
    params['limit'] = limit.toString();
    return uri.replace(queryParameters: params);
  }

  Future<_OraclePage?> _fetchOraclePage(String baseUrl, {int offset = 0, int limit = 200}) async {
    try {
      final uri = _buildOracleUri(baseUrl, offset: offset, limit: limit);
      final resp = await _resilientGet(
        uri,
        timeout: const Duration(seconds: 60),
        maxAttempts: 2,
        updateStatus: false,
        debugLabel: 'oracle:${uri.host}',
      );
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        if (body is Map<String, dynamic>) {
          final itemsRaw = body['items'];
          final items = <Map<String, dynamic>>[];
          if (itemsRaw is List) {
            for (final item in itemsRaw) {
              if (item is Map) {
                items.add(Map<String, dynamic>.from(item));
              }
            }
          }
          final hasMore = (body['hasMore'] == true) || (body['has_more'] == true) || (body['more'] == true);
          final pageLimit = body['limit'] is int
              ? body['limit'] as int
              : (body['limit'] is String && int.tryParse(body['limit'] as String) != null ? int.parse(body['limit'] as String) : limit);
          final pageOffset = body['offset'] is int
              ? body['offset'] as int
              : (body['offset'] is String && int.tryParse(body['offset'] as String) != null ? int.parse(body['offset'] as String) : offset);
          return _OraclePage(items: items, hasMore: hasMore, limit: pageLimit, offset: pageOffset);
        }
      }
    } catch (e) {
      if (kDebugMode) print('fetchOraclePage error for $baseUrl: $e');
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> _fetchOracleAll(String baseUrl, {int pageSize = 200, int maxPages = 50}) async {
    final combined = <Map<String, dynamic>>[];
    var offset = 0;
    for (var page = 0; page < maxPages; page++) {
      final result = await _fetchOraclePage(baseUrl, offset: offset, limit: pageSize);
      if (result == null) break;
      if (result.items.isNotEmpty) {
        combined.addAll(result.items);
      }
      if (!result.hasMore || result.items.isEmpty) {
        break;
      }
      offset = result.offset + result.limit;
    }
    return combined;
  }

  bool _hasUsableBridgePayload(Map<String, dynamic> body) {
    for (final entry in body.entries) {
      final val = entry.value;
      if (val is Map) {
        if (val.containsKey('error') && val.length == 1) {
          continue;
        }
        final data = val['data'];
        if (data is Map && data['items'] is List && (data['items'] as List).isNotEmpty) {
          return true;
        }
        if (!val.containsKey('data')) {
          return true;
        }
      }
    }
    return false;
  }

  Future<Map<String, dynamic>> _fetchOracleCropVisionFallback() async {
    const endpoints = {
      'crop_vision_g4': 'https://oracleapex.com/ords/g3_data/crop_vision_g4/',
      'crop_vision_g5': 'https://oracleapex.com/ords/g3_data/crop-vision/crop_g5/',
    };
    final currentTs = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final cache = _oracleGroupCache['crop_vision'];
    final cacheTs = _oracleGroupCacheTs['crop_vision'];
    if (cache != null && cacheTs != null && currentTs - cacheTs < 300) {
      final clone = <String, dynamic>{};
      cache.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          clone[key] = Map<String, dynamic>.from(value);
        } else {
          clone[key] = value;
        }
      });
      return clone;
    }
    final now = currentTs;
    final result = <String, dynamic>{};
    for (final entry in endpoints.entries) {
      final items = await _fetchOracleAll(entry.value);
      if (items.isEmpty) continue;
      final normalized = <Map<String, dynamic>>[];
      for (final raw in items) {
        final row = Map<String, dynamic>.from(raw);
        row['SOURCE'] = entry.key;
        row['source'] = entry.key;
        row.putIfAbsent('GROUP_ID', () => entry.key.endsWith('g4') ? '4' : entry.key.endsWith('g5') ? '5' : entry.key);
        final groupId = row['GROUP_ID'];
        if (groupId != null) {
          row.putIfAbsent('group_id', () => groupId);
        }
        normalized.add(row);
      }
      result[entry.key] = {
        '_source': 'oracle_apex',
        '_fetched_ts': now,
        'data': {'items': normalized},
      };
      final cacheKey = 'crop_vision/detections/${entry.key.toLowerCase()}';
      _listCache[cacheKey] = normalized;
      _listCacheTs[cacheKey] = now;
      await _persistListCache(cacheKey, normalized);
      final exactCacheKey = 'crop_vision/detections/${entry.key}';
      _listCache[exactCacheKey] = normalized;
      _listCacheTs[exactCacheKey] = now;
    }
    if (result.isNotEmpty) {
      _source['crop_vision'] = 'oracle_apex';
      final cacheSnapshot = <String, dynamic>{};
      result.forEach((key, value) {
        cacheSnapshot[key] = value is Map<String, dynamic> ? Map<String, dynamic>.from(value) : value;
      });
      _oracleGroupCache['crop_vision'] = cacheSnapshot;
      _oracleGroupCacheTs['crop_vision'] = now;
    }
    return result;
  }

  Future<Map<String, dynamic>> _fetchOracleGreenhouseFallback() async {
    const endpoints = {
      'greenhouse_g1': 'https://oracleapex.com/ords/g3_data/greenhouse_group1/',
      'greenhouse_iot': 'https://oracleapex.com/ords/g3_data/iot/greenhouse/',
    };
    final currentTs = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final cache = _oracleGroupCache['greenhouse'];
    final cacheTs = _oracleGroupCacheTs['greenhouse'];
    if (cache != null && cacheTs != null && currentTs - cacheTs < 300) {
      final clone = <String, dynamic>{};
      cache.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          clone[key] = Map<String, dynamic>.from(value);
        } else {
          clone[key] = value;
        }
      });
      return clone;
    }
    final now = currentTs;
    final result = <String, dynamic>{};
    for (final entry in endpoints.entries) {
      final items = await _fetchOracleAll(entry.value);
      if (items.isEmpty) continue;
      final normalized = <Map<String, dynamic>>[];
      for (final raw in items) {
        final row = Map<String, dynamic>.from(raw);
        final isIot = entry.key.toLowerCase() == 'greenhouse_iot';
        row['SOURCE'] = entry.key;
        row['source'] = entry.key;
        if (entry.key == 'greenhouse_g1') {
          row.putIfAbsent('GROUP_ID', () => '1');
        } else if (isIot) {
          row['GROUP_ID'] = '9';
        } else {
          row.putIfAbsent('GROUP_ID', () => entry.key);
        }
        final groupId = row['GROUP_ID'];
        if (groupId != null) {
          row['group_id'] = groupId;
        }
        normalized.add(row);
      }
      result[entry.key] = {
        '_source': 'oracle_apex',
        '_fetched_ts': now,
        'data': {'items': normalized},
      };
      final cacheKey = 'greenhouse/${entry.key.toLowerCase()}';
      _listCache[cacheKey] = normalized;
      _listCacheTs[cacheKey] = now;
      await _persistListCache(cacheKey, normalized);
      final exactCacheKey = 'greenhouse/${entry.key}';
      _listCache[exactCacheKey] = normalized;
      _listCacheTs[exactCacheKey] = now;
      if (entry.key.toLowerCase() == 'greenhouse_iot') {
        const alias = 'greenhouse/greenhouse_g9';
        _listCache[alias] = normalized;
        _listCacheTs[alias] = now;
        await _persistListCache(alias, normalized);
      }
    }
    if (result.isNotEmpty) {
      _source['greenhouse'] = 'oracle_apex';
      final cacheSnapshot = <String, dynamic>{};
      result.forEach((key, value) {
        cacheSnapshot[key] = value is Map<String, dynamic> ? Map<String, dynamic>.from(value) : value;
      });
      _oracleGroupCache['greenhouse'] = cacheSnapshot;
      _oracleGroupCacheTs['greenhouse'] = now;
    }
    return result;
  }

  /// Load persisted list caches from Hive into the in-memory caches.
  void _loadPersistedListCache() {
    try {
      if (!Hive.isBoxOpen(_historyCacheBox)) return;
      final box = Hive.box(_historyCacheBox);
      for (final k in box.keys) {
        try {
          final v = box.get(k);
          if (v is Map) {
            final ts = v['ts'] is int ? v['ts'] as int : DateTime.now().millisecondsSinceEpoch ~/ 1000;
            final payload = v['list'];
            if (payload is List) {
              final list = payload.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map)).toList();
              _listCache[k.toString()] = list;
              _listCacheTs[k.toString()] = ts;
            }
          }
        } catch (_) {}
      }
    } catch (e) {
      if (kDebugMode) print('loadPersistedListCache error: $e');
    }
  }

  /// Persist a list cache entry to Hive.
  Future<void> _persistListCache(String cacheKey, List<Map<String, dynamic>> list) async {
    try {
      if (!Hive.isBoxOpen(_historyCacheBox)) return;
      final box = Hive.box(_historyCacheBox);
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await box.put(cacheKey, {'ts': now, 'list': list});
      _listCacheTs[cacheKey] = now;
    } catch (e) {
      if (kDebugMode) print('persistListCache error for $cacheKey: $e');
    }
  }

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

  /// Generic background fetch helper used by cache-first fetchers.
  /// It requests /api/`<group>`/all, picks a payload, parses it with [parser],
  /// calls [onParsed] to allow the caller to persist/pushHistory, updates the
  /// in-memory cache and emits the parsed value to [controller] when fresher
  /// data is available.
  Future<void> _backgroundFetchGroup<T>({
    required String group,
    required String key,
    required T Function(Map<String, dynamic>) parser,
    required StreamController<T> controller,
    required Future<void> Function(T parsed, Map<String, dynamic> payload) onParsed,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    try {
      final uri = Uri.parse('$_baseUrl/$group/all');
      final resp = await _resilientGet(
        uri,
        timeout: const Duration(seconds: 120),
        debugLabel: '$group/all',
      );
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final payload = _pickSourcePayload(body);
        if (payload != null && !payload.containsKey('error')) {
          final parsed = parser(payload);
          // Only update cache when we have a newer fetch timestamp or no cache
          final existing = _cache[key];
          final existingTs = existing != null ? (existing['ts'] as int? ?? 0) : 0;
          if (now >= existingTs) {
            _cache[key] = {'ts': now, 'data': parsed};
          }
          try {
            await onParsed(parsed, payload);
          } catch (_) {}
          _maybeEmit(key, parsed, controller);
        }
      }
    } catch (e) {
      if (kDebugMode) print('backgroundFetchGroup $group error: $e');
    }
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
    try {
      _client.close();
    } catch (_) {}
  }

  /// Fetches the latest sensor readings from the greenhouse (with short cache).
  Future<GreenhouseData> fetchLatestGreenhouseData() async {
    final key = 'greenhouse';
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final entry = _cache[key];
    // Cache-first: if we have an in-memory cached value, return it immediately
    // so the UI can show the most-recently available data. Then schedule a
    // background refresh which will update the cache and emit to listeners if
    // fresher data becomes available.
    if (entry != null) {
      // Fire-and-forget background refresh
      _backgroundFetchGroup<GreenhouseData>(
        group: 'greenhouse',
        key: key,
        parser: (m) => GreenhouseData.fromJson(m),
        controller: _greenhouseController,
        onParsed: (parsed, payload) async {
          _source[key] = payload['_source']?.toString() ?? 'live';
          // persist payload for offline fallback
          try {
            await Hive.box('greenhouse_data').put('latest', jsonEncode(payload));
          } catch (_) {}
          _pushHistory(key, 'temperature', parsed.temperature);
          _pushHistory(key, 'humidity', parsed.humidity);
          if (parsed.lightIntensity != null) _pushHistory(key, 'light', parsed.lightIntensity!);
          if (parsed.co2 != null) _pushHistory(key, 'co2', parsed.co2!);
        },
      );
      return entry['data'] as GreenhouseData;
    }

    // No in-memory cache available: perform a network fetch and fall back to
    // persistent Hive cache if needed.
    await _backgroundFetchGroup<GreenhouseData>(
      group: 'greenhouse',
      key: key,
      parser: (m) => GreenhouseData.fromJson(m),
      controller: _greenhouseController,
      onParsed: (parsed, payload) async {
        _source[key] = payload['_source']?.toString() ?? 'live';
        try {
          await Hive.box('greenhouse_data').put('latest', jsonEncode(payload));
        } catch (_) {}
        _pushHistory(key, 'temperature', parsed.temperature);
        _pushHistory(key, 'humidity', parsed.humidity);
        if (parsed.lightIntensity != null) _pushHistory(key, 'light', parsed.lightIntensity!);
        if (parsed.co2 != null) _pushHistory(key, 'co2', parsed.co2!);
      },
    );

    // If background fetch populated the cache, return it. Otherwise try Hive.
    final after = _cache[key];
    if (after != null) return after['data'] as GreenhouseData;

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

    throw Exception('No greenhouse data available');
  }

  /// Fetches the latest irrigation readings from the system.
  Future<IrrigationData> fetchLatestIrrigationData() async {
    final key = 'irrigation';
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final entry = _cache[key];
    // Cache-first behavior: return in-memory cache immediately and refresh
    // in background, otherwise fetch now and fall back to Hive.
    if (entry != null) {
      _backgroundFetchGroup<IrrigationData>(
        group: 'irrigation',
        key: key,
        parser: (m) => IrrigationData.fromJson(m),
        controller: _irrigationController,
        onParsed: (parsed, payload) async {
          _source[key] = payload['_source']?.toString() ?? 'live';
          try {
            await Hive.box('irrigation_data').put('latest', jsonEncode(payload));
          } catch (_) {}
          _pushHistory(key, 'flow', parsed.flowRateLmin);
          _pushHistory(key, 'total_volume', parsed.totalVolume);
        },
      );
      return entry['data'] as IrrigationData;
    }

    await _backgroundFetchGroup<IrrigationData>(
      group: 'irrigation',
      key: key,
      parser: (m) => IrrigationData.fromJson(m),
      controller: _irrigationController,
      onParsed: (parsed, payload) async {
        _source[key] = payload['_source']?.toString() ?? 'live';
        try {
          await Hive.box('irrigation_data').put('latest', jsonEncode(payload));
        } catch (_) {}
        _pushHistory(key, 'flow', parsed.flowRateLmin);
        _pushHistory(key, 'total_volume', parsed.totalVolume);
      },
    );

    final after = _cache[key];
    if (after != null) return after['data'] as IrrigationData;

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
    if (entry != null) {
      _backgroundFetchGroup<SoilData>(
        group: 'soil',
        key: key,
        parser: (m) => SoilData.fromJson(m),
        controller: _soilController,
        onParsed: (parsed, payload) async {
          _source[key] = payload['_source']?.toString() ?? 'live';
          try {
            await Hive.box('soil_data').put('latest', jsonEncode(payload));
          } catch (_) {}
          _pushHistory(key, 'moisture', parsed.moisturePct);
          _pushHistory(key, 'soil_temp', parsed.temperature);
        },
      );
      return entry['data'] as SoilData;
    }

    await _backgroundFetchGroup<SoilData>(
      group: 'soil',
      key: key,
      parser: (m) => SoilData.fromJson(m),
      controller: _soilController,
      onParsed: (parsed, payload) async {
        _source[key] = payload['_source']?.toString() ?? 'live';
        try {
          await Hive.box('soil_data').put('latest', jsonEncode(payload));
        } catch (_) {}
        _pushHistory(key, 'moisture', parsed.moisturePct);
        _pushHistory(key, 'soil_temp', parsed.temperature);
      },
    );

    final after = _cache[key];
    if (after != null) return after['data'] as SoilData;
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
    if (entry != null) {
      _backgroundFetchGroup<CropVisionData>(
        group: 'crop_vision',
        key: key,
        parser: (m) => CropVisionData.fromJson(m),
        controller: _cropVisionController,
        onParsed: (parsed, payload) async {
          _source[key] = payload['_source']?.toString() ?? 'live';
          try {
            await Hive.box('crop_vision_data').put('latest', jsonEncode(payload));
          } catch (_) {}
          if (parsed.ndvi != null) _pushHistory(key, 'ndvi', parsed.ndvi!);
        },
      );
      return entry['data'] as CropVisionData;
    }

    await _backgroundFetchGroup<CropVisionData>(
      group: 'crop_vision',
      key: key,
      parser: (m) => CropVisionData.fromJson(m),
      controller: _cropVisionController,
      onParsed: (parsed, payload) async {
        _source[key] = payload['_source']?.toString() ?? 'live';
        try {
          await Hive.box('crop_vision_data').put('latest', jsonEncode(payload));
        } catch (_) {}
        if (parsed.ndvi != null) _pushHistory(key, 'ndvi', parsed.ndvi!);
      },
    );

    final after = _cache[key];
    if (after != null) return after['data'] as CropVisionData;
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

  /// Trigger a warmup cycle against all primary groups. Helpful when the
  /// backend is hosted on a cold-start platform and may need a nudge after
  /// periods of inactivity.
  Future<void> warmupBackend() async {
    Future<void> safe(Future<void> Function() fn) async {
      try {
        await fn();
      } catch (_) {}
    }

    await Future.wait([
      safe(() async => await fetchAllGroupRaw('greenhouse')),
      safe(() async => await fetchAllGroupRaw('irrigation')),
      safe(() async => await fetchAllGroupRaw('soil')),
      safe(() async => await fetchAllGroupRaw('crop_vision')),
    ]);
  }

  /// Return the last known source metadata for a particular key, or null.
  String? getSource(String key) => _source[key];

  /// Fetch the aggregated map of sources for a logical group from the bridge.
  /// Returns a Map where keys are source names (e.g. 'G6') and values are
  /// the normalized payload maps returned by the bridge. Returns null on
  /// network error.
  Future<Map<String, dynamic>?> fetchAllGroupRaw(String group) async {
    Map<String, dynamic>? normalized;
    try {
      final resp = await _resilientGet(
        Uri.parse('$_baseUrl/$group/all'),
        timeout: const Duration(seconds: 120),
        debugLabel: '$group/all',
      );
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        if (body is Map<String, dynamic>) {
          normalized = body.map((k, v) => MapEntry(k.toString(), v));
          if (_hasUsableBridgePayload(normalized)) {
            return normalized;
          }
        }
      }
    } catch (e) {
      if (kDebugMode) print('fetchAllGroupRaw error for $group: $e');
    }

    final lower = group.toLowerCase();
    if (lower == 'crop_vision') {
      final fallback = await _fetchOracleCropVisionFallback();
      if (normalized == null || normalized.isEmpty) {
        return fallback.isNotEmpty ? fallback : normalized;
      }
  final Map<String, dynamic> base = normalized;
  final data = Map<String, dynamic>.from(base);
      if (fallback.isNotEmpty) {
        fallback.forEach((key, value) {
          final existing = data[key];
          bool hasItems = false;
          if (existing is Map) {
            final data = existing['data'];
            if (data is Map && data['items'] is List && (data['items'] as List).isNotEmpty) {
              hasItems = true;
            }
          }
          if (!hasItems) {
            data[key] = value;
          }
        });
      }
      return data;
    }

    if (lower == 'greenhouse') {
      final fallback = await _fetchOracleGreenhouseFallback();
      if (normalized == null || normalized.isEmpty) {
        return fallback.isNotEmpty ? fallback : normalized;
      }
  final Map<String, dynamic> base = normalized;
  final data = Map<String, dynamic>.from(base);
      if (fallback.isNotEmpty) {
        fallback.forEach((key, value) {
          final existing = data[key];
          bool hasItems = false;
          if (existing is Map) {
            final data = existing['data'];
            if (data is Map && data['items'] is List && (data['items'] as List).isNotEmpty) {
              hasItems = true;
            }
          }
          if (!hasItems) {
            data[key] = value;
          }
        });
      }
      return data;
    }

    return normalized;
  }

  /// Fetch up to 10 raw history rows for a particular group/source from the bridge.
  /// Returns a list of maps (each map is a raw row with original upstream column names)
  /// or null on network/error.
  /// Fetch up to [limit] raw history rows for a particular group/source from the bridge.
  /// Returns a list of maps (each map is a raw row with original upstream column names)
  /// or null on network/error.
  Future<List<Map<String, dynamic>>?> fetchGroupHistory(String group, String source, {int limit = 10, int offset = 0, String? duration}) async {
    if (group.toLowerCase() == 'crop_vision') {
      return fetchCropVisionDetections(source: source, limit: limit, offset: offset);
    }
    final cacheKey = '$group/$source';
  // If we have a cached list, return it immediately (cache-first) and
    // trigger a background refresh to update it.
    final cachedList = _listCache[cacheKey];
    if (cachedList != null) {
      // Fire-and-forget refresh
      () async {
        try {
          final fetchLimit = offset > 0 ? (offset + limit) : limit;
          final params = <String>[];
          params.add('limit=$fetchLimit');
          if (duration != null && duration.isNotEmpty) params.add('duration=${Uri.encodeQueryComponent(duration)}');
          if (offset > 0) params.add('offset=$offset');
          final query = params.isNotEmpty ? '?${params.join('&')}' : '';
          final uri = Uri.parse('$_baseUrl/$group/history/$source$query');
          final resp = await _resilientGet(
            uri,
            timeout: const Duration(seconds: 120),
            debugLabel: '$group/history/$source',
          );
          if (resp.statusCode == 200) {
            final body = jsonDecode(resp.body);
            if (body is List) {
              final list = body.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map)).toList();
              _listCache[cacheKey] = list;
              _listCacheTs[cacheKey] = DateTime.now().millisecondsSinceEpoch ~/ 1000;
              await _persistListCache(cacheKey, list);
            }
          }
        } catch (_) {}
      }();
      // Return a client-sliced copy for offset/limit semantics
      if (offset > 0) {
        if (cachedList.length <= offset) return <Map<String, dynamic>>[];
        final end = (offset + limit) < cachedList.length ? (offset + limit) : cachedList.length;
        return cachedList.sublist(offset, end);
      }
      return List<Map<String, dynamic>>.from(cachedList);
    }

    // If no list cache, try returning the group's persisted latest payload
    // (one-row) immediately so the UI has something to show while the
    // background network fetch populates the full history.
    try {
      final box = Hive.box('${group}_data');
      final latest = box.get('latest');
      if (latest != null && latest is String) {
        final body = jsonDecode(latest) as Map<String, dynamic>;
        final one = <Map<String, dynamic>>[Map<String, dynamic>.from(body)];
        _listCache[cacheKey] = one;
        _listCacheTs[cacheKey] = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        if (offset > 0) {
          if (one.length <= offset) return <Map<String, dynamic>>[];
          final end = (offset + limit) < one.length ? (offset + limit) : one.length;
          return one.sublist(offset, end);
        }
        return one;
      }
    } catch (_) {}

    // Try the direct per-source history endpoint first. If the bridge
    // replies with a sentinel like {"error":"not yet cached"} we'll
    // attempt to force-refresh that source on the bridge and retry a
    // few times before falling back to discovery via /api/<group>/all.
    Future<List<Map<String, dynamic>>?> tryDirectFetch(String src, {int retries = 3}) async {
      final fetchLimit = offset > 0 ? (offset + limit) : limit;
      final params = <String>[];
      params.add('limit=$fetchLimit');
      if (duration != null && duration.isNotEmpty) params.add('duration=${Uri.encodeQueryComponent(duration)}');
      if (offset > 0) params.add('offset=$offset');
      final query = params.isNotEmpty ? '?${params.join('&')}' : '';
      final uri = Uri.parse('$_baseUrl/$group/history/$src$query');

      for (var attempt = 0; attempt < retries; attempt++) {
        try {
          final resp = await _resilientGet(
            uri,
            timeout: const Duration(seconds: 120),
            debugLabel: '$group/history/$src',
          );
          if (resp.statusCode == 200) {
            final body = jsonDecode(resp.body);
            if (body is List) {
              final list = body.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map)).toList();
              _listCache[cacheKey] = list;
              _listCacheTs[cacheKey] = DateTime.now().millisecondsSinceEpoch ~/ 1000;
              await _persistListCache(cacheKey, list);
              return list;
            }

            // If bridge returned a sentinel error like {"error":"not yet cached"}
            if (body is Map && body['error'] != null) {
              final err = body['error'].toString();
              if (err.toLowerCase().contains('not yet cached') || err.toLowerCase().contains('not cached')) {
                // Ask bridge to refresh this source and then wait before retrying.
                try {
                  if (kDebugMode) print('fetchGroupHistory: bridge not yet cached for $group/$src, attempting force_refresh (attempt ${attempt + 1})');
                  await forceRefreshGroupSource(group, src);
                } catch (_) {}
                // exponential backoff before next retry
                final backoff = Duration(seconds: 1 << attempt);
                await Future.delayed(backoff);
                continue; // retry
              }
            }
          } else if (resp.statusCode == 404) {
            // quickly return null on 404 so caller can try discovery options
            return null;
          }
        } catch (e) {
          if (kDebugMode) print('tryDirectFetch error for $group/$src: $e');
        }
      }
      return null;
    }

    try {
      final direct = await tryDirectFetch(source, retries: 3);
      if (direct != null) {
        if (offset > 0) {
          if (direct.length <= offset) return <Map<String, dynamic>>[];
          final end = (offset + limit) < direct.length ? (offset + limit) : direct.length;
          return direct.sublist(offset, end);
        }
        return direct;
      }
    } catch (e) {
      if (kDebugMode) print('fetchGroupHistory direct try error for $group/$source: $e');
    }
    // If direct per-source history endpoint failed (404 or other), attempt
    // to discover the canonical source id from /api/<group>/all and retry.
    try {
      final all = await fetchAllGroupRaw(group);
      if (all != null && all.isNotEmpty) {
        // Build candidate list: exact, case-insensitive, contains, prefixed
        final candidates = <String>[];
        candidates.add(source);
        candidates.add(source.toLowerCase());
        candidates.add(source.toUpperCase());
        // If source looks like a short id (e.g. "6" or "g6"), also try group-prefixed keys
        candidates.add('${group}_$source');
        candidates.add('${group}_g$source');

        // Add any keys from /all that contain the requested source string
        for (final k in all.keys) {
          final ks = k.toString();
          if (ks.toLowerCase() == source.toLowerCase() || ks.toLowerCase().contains(source.toLowerCase())) {
            candidates.add(ks);
          }
        }

        // Deduplicate while preserving order
        final seen = <String>{};
        final dedup = <String>[];
        for (final c in candidates) {
          final cc = c.toString();
          if (!seen.contains(cc)) {
            seen.add(cc);
            dedup.add(cc);
          }
        }

        for (final cand in dedup) {
          try {
            final candList = await tryDirectFetch(cand, retries: 2);
            if (candList != null) {
              if (offset > 0) {
                if (candList.length <= offset) return <Map<String, dynamic>>[];
                final end = (offset + limit) < candList.length ? (offset + limit) : candList.length;
                return candList.sublist(offset, end);
              }
              return candList;
            }
          } catch (_) {}
        }
      }
    } catch (_) {}

    // Final fallback: try a group-wide consolidated history endpoint if present
    try {
      final params = <String>[];
      final fetchLimit = offset > 0 ? (offset + limit) : limit;
      if (fetchLimit > 0) params.add('limit=$fetchLimit');
      if (duration != null && duration.isNotEmpty) params.add('duration=${Uri.encodeQueryComponent(duration)}');
      if (offset > 0) params.add('offset=$offset');
      final query = params.isNotEmpty ? '?${params.join('&')}' : '';
      final uri = Uri.parse('$_baseUrl/$group/history_by_group$query');
      final resp = await _resilientGet(
        uri,
        timeout: const Duration(seconds: 120),
        debugLabel: '$group/history_by_group',
      );
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        if (body is List) {
          final list = body.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map)).toList();
          _listCache[cacheKey] = list;
          _listCacheTs[cacheKey] = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          await _persistListCache(cacheKey, list);
          if (offset > 0) {
            if (list.length <= offset) return <Map<String, dynamic>>[];
            final end = (offset + limit) < list.length ? (offset + limit) : list.length;
            return list.sublist(offset, end);
          }
          return list;
        }
      }
    } catch (_) {}

    return null;
  }

  Future<List<Map<String, dynamic>>> fetchCropVisionDetections({String? source, int limit = 10, int offset = 0}) async {
    final normSource = source?.toLowerCase().trim();
    final cacheKey = 'crop_vision/detections/${normSource ?? 'all'}';
    final cached = _listCache[cacheKey];
    if (cached != null) {
      if (offset >= cached.length) return <Map<String, dynamic>>[];
      final end = limit <= 0
          ? cached.length
          : ((offset + limit) > cached.length ? cached.length : (offset + limit));
      return List<Map<String, dynamic>>.from(cached.sublist(offset, end));
    }

    final raw = await fetchAllGroupRaw('crop_vision');
    if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];

    final rows = <Map<String, dynamic>>[];
    raw.forEach((key, value) {
      final keyStr = key.toString();
      if (normSource != null) {
        final kLower = keyStr.toLowerCase();
        final matchesSource = kLower == normSource ||
            kLower.endsWith('_$normSource') ||
            kLower.contains(normSource) ||
            normSource.replaceAll(RegExp(r'^crop_vision_'), '') == kLower.replaceAll(RegExp(r'^crop_vision_'), '');
        if (!matchesSource) return;
      }

      if (value is Map) {
        if (value['data'] is Map && value['data']['items'] is List) {
          for (final item in value['data']['items']) {
            if (item is Map) {
              final row = Map<String, dynamic>.from(item);
              row.putIfAbsent('SOURCE', () => keyStr);
              row.putIfAbsent('source', () => keyStr);
              row.putIfAbsent('_fetched_ts', () => value['_fetched_ts'] ?? value['_fetched_ts_seconds']);
              rows.add(row);
            }
          }
        } else {
          final row = Map<String, dynamic>.from(value);
          row.putIfAbsent('SOURCE', () => keyStr);
          row.putIfAbsent('source', () => keyStr);
          rows.add(row);
        }
      }
    });

    rows.sort((a, b) {
      final ta = _parseTimestamp(a['timestamp'] ?? a['created_at'] ?? a['CREATED_AT'] ?? a['Timestamp'] ?? a['T']);
      final tb = _parseTimestamp(b['timestamp'] ?? b['created_at'] ?? b['CREATED_AT'] ?? b['Timestamp'] ?? b['T']);
      if (ta == null && tb == null) return 0;
      if (ta == null) return 1;
      if (tb == null) return -1;
      return tb.compareTo(ta);
    });

    _listCache[cacheKey] = rows;
    _listCacheTs[cacheKey] = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _persistListCache(cacheKey, rows);

  if (offset >= rows.length) return <Map<String, dynamic>>[];
  final end = limit <= 0
    ? rows.length
    : ((offset + limit) > rows.length ? rows.length : (offset + limit));
    return List<Map<String, dynamic>>.from(rows.sublist(offset, end));
  }
  /// Fetch consolidated history rows for soil groups 7,8,10 from a dedicated
  /// endpoint. The endpoint is expected to return a JSON list of rows where
  /// each row is a map with the original column names (including GROUP_ID and CREATED_AT).
  /// Fetch consolidated history rows for soil groups (7,8,10).
  /// If [limit] is provided it will be sent as a query parameter to the
  /// backend endpoint (e.g. ?limit=5). Returns null on network/error.
  Future<List<Map<String, dynamic>>?> fetchSoilGroupHistory({int? limit, int offset = 0, bool synthetic = false}) async {
    final cacheKey = 'soil/history_by_group?synthetic=${synthetic ? 1 : 0}&limit=${limit ?? 0}&offset=$offset';
    final cached = _listCache[cacheKey];
    if (cached != null) {
      if (offset > 0) {
        if (cached.length <= offset) return <Map<String, dynamic>>[];
        final end = (offset + (limit ?? 0)) < cached.length ? (offset + (limit ?? 0)) : cached.length;
        return cached.sublist(offset, end);
      }

      // Fire-and-forget background refresh to update the persisted cache
      (() async {
        try {
          final params = <String>[];
          final fetchLimit = (limit ?? 0) + (offset > 0 ? offset : 0);
          if (fetchLimit > 0) params.add('limit=$fetchLimit');
          if (synthetic) params.add('synthetic=1');
          final query = params.isNotEmpty ? '?${params.join('&')}' : '';
          final uri = Uri.parse('$_baseUrl/soil/history_by_group$query');
          final resp = await _resilientGet(
            uri,
            timeout: const Duration(seconds: 120),
            debugLabel: 'soil/history_by_group',
          );
          if (resp.statusCode == 200) {
            final body = jsonDecode(resp.body);
            if (body is List) {
              final list = body.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map)).toList();
              _listCache[cacheKey] = list;
              _listCacheTs[cacheKey] = DateTime.now().millisecondsSinceEpoch ~/ 1000;
              await _persistListCache(cacheKey, list);
            }
          }
        } catch (_) {}
      })();

      return List<Map<String, dynamic>>.from(cached);
    }

    try {
  final params = <String>[];
  final fetchLimit = (limit ?? 0) + (offset > 0 ? offset : 0);
      if (fetchLimit > 0) params.add('limit=$fetchLimit');
      if (synthetic) params.add('synthetic=1');
      final query = params.isNotEmpty ? '?${params.join('&')}' : '';
      final uri = Uri.parse('$_baseUrl/soil/history_by_group$query');
      final resp = await _resilientGet(
        uri,
        timeout: const Duration(seconds: 120),
        debugLabel: 'soil/history_by_group',
      );
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        if (body is List) {
          final list = body.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map)).toList();
          _listCache[cacheKey] = list;
          _listCacheTs[cacheKey] = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          await _persistListCache(cacheKey, list);
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

  /// Drop cached list history for an entire group so subsequent fetches hit the bridge.
  void invalidateGroupCache(String group) {
    final prefix = '$group/';
    final keys = _listCache.keys.where((k) => k.startsWith(prefix)).toList();
    for (final key in keys) {
      _listCache.remove(key);
      _listCacheTs.remove(key);
    }
  }

  /// Fetch the entire bridge payload (/api/all) and persist it into Hive
  /// box 'historical_data' along with a timestamp. Also cleans up entries
  /// older than 7 days.
  Future<void> fetchAllData() async {
    try {
      final uri = Uri.parse('$_baseUrl/all');
      final resp = await _resilientGet(
        uri,
        timeout: const Duration(seconds: 120),
        debugLabel: 'all',
      );
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

class _OraclePage {
  final List<Map<String, dynamic>> items;
  final bool hasMore;
  final int limit;
  final int offset;

  _OraclePage({required this.items, required this.hasMore, required this.limit, required this.offset});
}