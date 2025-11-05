import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Lightweight AI integration shim.
///
/// This file intentionally does NOT call any external AI service by default.
/// To enable a real AI provider, build the app with a compile-time key and
/// implement the network call here. For safety we do not embed nor use any
/// API key shipped in source control.

class AiIntegration {
  static String _resolveApiKey() {
    const googleKey = String.fromEnvironment('GOOGLE_AI_API_KEY', defaultValue: '');
    if (googleKey.isNotEmpty) return googleKey;
    const aiStudioKey = String.fromEnvironment('AI_STUDIO_KEY', defaultValue: '');
    if (aiStudioKey.isNotEmpty) return aiStudioKey;
    const genericKey = String.fromEnvironment('AI_API_KEY', defaultValue: '');
    if (genericKey.isNotEmpty) return genericKey;
    return '';
  }

  static String _resolveApiUrl() {
    const googleBase = String.fromEnvironment(
      'GOOGLE_AI_API_BASE',
      defaultValue: '',
    );
    if (googleBase.isNotEmpty) return googleBase;
    const genericUrl = String.fromEnvironment(
      'AI_API_URL',
      defaultValue: '',
    );
    if (genericUrl.isNotEmpty) return genericUrl;
    return 'https://generativelanguage.googleapis.com';
  }

  static String _resolveModel({bool detailed = false}) {
    const detailedModel = String.fromEnvironment(
      'GOOGLE_AI_MODEL_DETAILED',
      defaultValue: '',
    );
    const defaultModel = String.fromEnvironment(
      'GOOGLE_AI_MODEL',
      defaultValue: '',
    );
    const genericModel = String.fromEnvironment(
      'AI_MODEL',
      defaultValue: '',
    );
    if (detailed && detailedModel.isNotEmpty) return detailedModel;
    if (defaultModel.isNotEmpty) return defaultModel;
    if (genericModel.isNotEmpty) return genericModel;
    return detailed ? 'models/gemini-1.5-pro' : 'models/gemini-1.5-flash';
  }

  static String _normalizeModelName(String model) {
    final trimmed = model.trim();
    if (trimmed.isEmpty) return 'models/gemini-1.5-flash';
    return trimmed.startsWith('models/') ? trimmed : 'models/$trimmed';
  }

  static bool get hasRemoteProvider => _resolveApiKey().isNotEmpty;
  /// Generate a short human-friendly summary for the overview page.
  ///
  /// - If the app was built with a compile-time AI key via
  ///   `--dart-define=AI_STUDIO_KEY=<your_key>` you can extend this method
  ///   to call your provider. Right now this returns a locally generated
  ///   summary based on the provided `metrics` map.
  // If someone supplies a build-time key we still don't ship network code
  // here to avoid accidental key usage. The presence of a key can be used
  // by advanced users to toggle behavior in a fork of the app.
  /// Synchronous (local) summary generator kept for fast UI reasons.
  ///
  /// For production-grade AI, use [generateSummaryAsync] which will
  /// call the configured remote provider (if configured) and fall back to
  /// the local generator on error or when keys are missing.
  static String generateSummary(Map<String, dynamic> metrics) {
    return _localSummary(metrics, source: 'Local heuristics');
  }

  /// Asynchronous summary generator which will call a remote AI provider
  /// when environment defines `AI_API_KEY` and `AI_API_URL` at build time
  /// (via `--dart-define=AI_API_KEY=... --dart-define=AI_API_URL=...`).
  ///
  /// Behaviour:
  /// - If provider is configured, attempt a network call with retries and
  ///   sensible timeouts.
  /// - On any failure return the local summary as a safe fallback.
  static Future<String> generateSummaryAsync(
    Map<String, dynamic> metrics,
  ) async {
    final apiKey = _resolveApiKey();
    final apiUrl = _resolveApiUrl();
    final model = _normalizeModelName(_resolveModel());
    if (apiKey.isEmpty || apiUrl.isEmpty) {
      return _localSummary(metrics, source: 'Local heuristics');
    }

    final prompt = _buildPromptFromMetrics(metrics, brief: true);
    try {
      final out = await _callProviderWithRetries(
        apiUrl,
        apiKey,
        prompt,
        model: model,
      );
      if (out != null && out.trim().isNotEmpty) return out.trim();
    } catch (_) {}

    return _localSummary(
      metrics,
      source: 'Local heuristics (provider fallback)',
    );
  }

  static String _localSummary(
    Map<String, dynamic> m, {
    required String source,
  }) {
    final parts = <String>[];
    final ghTemp = m['greenhouseAvgTemp'];
    final ghHum = m['greenhouseAvgHumidity'];
    final soil = m['soilAvgMoisture'];
    final soilPh = m['soilAvgPh'];
    final irrFlow = m['irrigationFlowSum'];
    final pumpsOn = m['irrigationPumpsOn'];
    final threats = m['cropThreatsCount'];

    if (ghTemp != null && ghHum != null) {
      final heat = ghTemp > 30 ? 'High' : (ghTemp < 18 ? 'Low' : 'Optimal');
      parts.add(
        '$heat greenhouse temperature at ${ghTemp.toStringAsFixed(1)}°C with ${ghHum.toStringAsFixed(0)}% humidity.',
      );
    } else if (ghTemp != null) {
      parts.add('Greenhouse temperature is ${ghTemp.toStringAsFixed(1)}°C.');
    }

    if (soil != null) {
      final soilMsg = soil < 25
          ? 'soil is dry'
          : (soil > 60 ? 'soil is wet' : 'soil moisture is in a healthy range');
      parts.add('$soilMsg (${soil.toStringAsFixed(1)}%).');
    }
    if (soilPh != null) {
      parts.add('Soil pH ${soilPh.toStringAsFixed(2)}.');
    }

    if (irrFlow != null) {
      parts.add(
        'Irrigation flow ${irrFlow.toStringAsFixed(1)} L/min; $pumpsOn pumps active.',
      );
    }

    if (threats != null && threats > 0) {
      parts.add(
        'Crop vision detected $threats potential issues — inspect recent detections.',
      );
    } else {
      parts.add('No active crop threats detected.');
    }

    parts.add('(Summary source: $source)');
    return parts.join(' ');
  }

  /// Generate a more detailed window-aware summary. This accepts the
  /// structured `metrics` map produced by the overview page and a `window`
  /// label such as '1h', '24h' or '7d'. If an AI key is present this method
  /// currently remains a safe stub; users may extend it to call an external
  /// provider, but by default it will return a local detailed narrative.
  static Future<String> generateDetailedSummary(
    Map<String, dynamic> metrics, {
    String window = '24h',
  }) async {
    final apiKey = _resolveApiKey();
    final apiUrl = _resolveApiUrl();
    final model = _normalizeModelName(_resolveModel(detailed: true));

    // If an AI provider is configured, attempt to generate a narrative using it.
    if (apiKey.isNotEmpty && apiUrl.isNotEmpty) {
      final prompt = _buildPromptFromMetrics(
        metrics,
        brief: false,
        window: window,
      );
      try {
        final providerResult = await _callProviderWithRetries(
          apiUrl,
          apiKey,
          prompt,
          model: model,
        );
        if (providerResult != null && providerResult.trim().isNotEmpty) {
          return providerResult.trim();
        }
      } catch (_) {
        // fall through to local generator
      }
    }

    // Local structured human-readable report using the available metrics.
    final buf = StringBuffer();
    buf.writeln(
      'Farm summary for the past ${window == '1h'
          ? '1 hour'
          : window == '24h'
          ? '24 hours'
          : '7 days'}:',
    );
    try {
      final gh = metrics['greenhouse'] as Map<String, dynamic>?;
      final so = metrics['soil'] as Map<String, dynamic>?;
      final ir = metrics['irrigation'] as Map<String, dynamic>?;
      final cv = metrics['crop'] as Map<String, dynamic>?;

      if (gh != null) {
        buf.writeln(
          '- Greenhouse: ${gh['count'] ?? 0} samples. Avg temp ${gh['avgTemp'] != null ? '${(gh['avgTemp'] as double).toStringAsFixed(1)}°C' : '—'}, avg humidity ${gh['avgHumidity'] != null ? '${(gh['avgHumidity'] as double).toStringAsFixed(0)}%' : '—'}',
        );
        if (gh['prevAvgTemp'] != null && gh['avgTemp'] != null) {
          final prev = gh['prevAvgTemp'] as double? ?? 0.0;
          final curr = gh['avgTemp'] as double? ?? 0.0;
          final diff = (curr - prev);
          final pct = prev != 0 ? (diff / prev * 100) : 0.0;
          buf.writeln(
            '  • Temperature change vs previous window: ${diff.toStringAsFixed(1)}°C (${pct.toStringAsFixed(1)}%)',
          );
        }
      }

      if (so != null) {
        buf.writeln(
          '- Soil: ${so['count'] ?? 0} samples. Avg moisture ${so['avgMoisture'] != null ? '${(so['avgMoisture'] as double).toStringAsFixed(1)}%' : '—'}, avg pH ${so['avgPh'] != null ? (so['avgPh'] as double).toStringAsFixed(2) : '—'}',
        );
      }

      if (ir != null) {
        buf.writeln(
          '- Irrigation: ${ir['count'] ?? 0} samples. Avg flow ${ir['flowAvg'] != null ? '${(ir['flowAvg'] as double).toStringAsFixed(1)} L/min' : '—'}, pumps on: ${ir['pumpsOn'] ?? 0}/${ir['pumpsTotal'] ?? 0}',
        );
      }

      if (cv != null) {
        final topLabel = cv['topLabel'];
        final topConfRaw = cv['topConf'];
        final topConf = topConfRaw is num
            ? topConfRaw.toDouble()
            : topConfRaw as double?;
        final confidenceLabel = topConf != null
            ? ' ${(topConf * 100).toStringAsFixed(1)}%'
            : '';
        final topSummary = topLabel != null
            ? ' (top: $topLabel$confidenceLabel)'
            : '';
        buf.writeln(
          '- Crop vision: ${cv['count'] ?? 0} detections. Issues: ${cv['threats'] ?? 0}$topSummary',
        );
      }
    } catch (_) {}

    buf.writeln(
      '\n(Generated by local summarizer${hasRemoteProvider ? ' — Google AI fallback due to unavailable response' : ''})',
    );
    return buf.toString();
  }

  // Build a simple prompt from metrics. Kept conservative to avoid leaking
  // internal structure to external providers; callers should review.
  static String _buildPromptFromMetrics(
    Map<String, dynamic> metrics, {
    bool brief = true,
    String window = '24h',
  }) {
    final sb = StringBuffer();
    if (brief) {
      sb.writeln(
        'Provide a short human-friendly summary (1-2 sentences) of the following farm metrics for the past ${window == '1h'
            ? '1 hour'
            : window == '24h'
            ? '24 hours'
            : '7 days'}:',
      );
    } else {
      sb.writeln(
        'Provide a detailed report for the past ${window == '1h'
            ? '1 hour'
            : window == '24h'
            ? '24 hours'
            : '7 days'}, including notable changes and recommendations:',
      );
    }
    // Keep prompt small: enumerate known high-level keys if present.
    void addIf(String key, String label) {
      if (metrics.containsKey(key) && metrics[key] != null) {
        sb.writeln('$label: ${metrics[key]}');
      }
    }

    addIf('greenhouseAvgTemp', 'Greenhouse average temperature');
    addIf('greenhouseAvgHumidity', 'Greenhouse average humidity');
    addIf('soilAvgMoisture', 'Soil average moisture');
    addIf('soilAvgPh', 'Soil average pH');
    addIf('irrigationFlowSum', 'Irrigation flow sum');
    addIf('irrigationPumpsOn', 'Irrigation pumps active');
    addIf('cropThreatsCount', 'Detected crop issues');

    sb.writeln('\nRespond succinctly.');
    return sb.toString();
  }

  // Call the configured provider with a simple retry/backoff strategy.
  static Future<String?> _callProviderWithRetries(
    String apiUrl,
    String apiKey,
    String prompt, {
    int maxAttempts = 3,
    String? model,
  }) async {
    var attempt = 0;
    while (attempt < maxAttempts) {
      try {
        return await _callProvider(apiUrl, apiKey, prompt, model: model);
      } catch (e) {
        attempt++;
        if (attempt >= maxAttempts) {
          rethrow;
        }
        // exponential backoff
        await Future.delayed(Duration(milliseconds: 250 * (1 << attempt)));
      }
    }
    return null;
  }

  static Future<String?> _callProvider(
    String apiUrl,
    String apiKey,
    String prompt,
    {String? model}
  ) async {
    if (apiUrl.contains('generativelanguage.googleapis.com')) {
      return _callGoogleGenerativeLanguage(
        apiUrl,
        apiKey,
        prompt,
        model: model,
      );
    }

    // Special-case known provider URL patterns (e.g., Google Generative Language)
    String effectiveUrl = apiUrl;
    if (apiUrl.contains('generativelanguage')) {
      // If user provided the base host (https://generativelanguage.googleapis.com)
      // target the Text-Bison model generate endpoint by default.
      if (!apiUrl.contains('/v1/')) {
        final trimmed = apiUrl.replaceFirst(RegExp(r'/*\z'), '');
        final resolvedModel = _normalizeModelName(model ?? _resolveModel());
        effectiveUrl = '$trimmed/v1/$resolvedModel:generate';
      }
    }
    var uri = Uri.parse(effectiveUrl);
    final client = HttpClient();
    client.connectionTimeout = Duration(seconds: 8);
    try {
      // Google Generative Language expects API key as query param or
      // Authorization header for OAuth2. Many simple API keys are accepted
      // via ?key=...; prefer that when the host is generativelanguage.
      if (apiUrl.contains('generativelanguage') &&
          !uri.queryParameters.containsKey('key')) {
        // append key as query parameter
        final mapped = Map<String, String>.from(uri.queryParameters);
        mapped['key'] = apiKey;
        uri = uri.replace(queryParameters: mapped);
      }

      final req = await client.postUrl(uri);
      req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      // If API key looks like a Bearer token, set Authorization header too.
      if (apiKey.trim().toLowerCase().startsWith('bearer ')) {
        req.headers.set(HttpHeaders.authorizationHeader, apiKey.trim());
      }

      // Build provider-specific body shapes.
      Map<String, dynamic> bodyMap;
      if (apiUrl.contains('generativelanguage')) {
        bodyMap = {
          'prompt': {'text': prompt},
          'maxOutputTokens': 300,
        };
      } else {
        bodyMap = {'prompt': prompt, 'max_tokens': 300};
      }
      final body = jsonEncode(bodyMap);
      req.add(utf8.encode(body));
      final resp = await req.close().timeout(Duration(seconds: 10));
      final respBody = await resp.transform(utf8.decoder).join();
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw Exception('AI provider error: ${resp.statusCode}');
      }
      // Try to parse structured responses used by many providers (OpenAI-style)
      try {
        final json = jsonDecode(respBody);
        if (json is Map<String, dynamic>) {
          // OpenAI-style
          if (json.containsKey('choices') &&
              json['choices'] is List &&
              json['choices'].isNotEmpty) {
            final first = json['choices'][0];
            if (first is Map && first.containsKey('text')) {
              return first['text'].toString();
            }
            if (first is Map &&
                first.containsKey('message') &&
                first['message'] is Map &&
                first['message']['content'] != null) {
              return first['message']['content'].toString();
            }
          }
          // Google Generative Language: look for 'candidates' or 'output' fields
          if (json.containsKey('candidates') &&
              json['candidates'] is List &&
              json['candidates'].isNotEmpty) {
            final first = json['candidates'][0];
            if (first is Map && first.containsKey('output')) {
              return first['output'].toString();
            }
            if (first is Map && first.containsKey('content')) {
              return first['content'].toString();
            }
            if (first is Map && first.containsKey('text')) {
              return first['text'].toString();
            }
          }
          if (json.containsKey('result')) {
            return json['result'].toString();
          }
          if (json.containsKey('summary')) {
            return json['summary'].toString();
          }
        }
      } catch (_) {
        // ignore parse errors and return raw body as a fallback
      }
      return respBody;
    } finally {
      client.close(force: true);
    }
  }

  static Future<String?> _callGoogleGenerativeLanguage(
    String apiUrl,
    String apiKey,
    String prompt, {
    String? model,
  }) async {
    final normalizedModel = _normalizeModelName(model ?? _resolveModel());
    final versionMatch = RegExp(r'/v1beta?/').firstMatch(apiUrl);
    final versionSegment = versionMatch != null ? versionMatch.group(0)! : '/v1beta/';
    final base = apiUrl.split(RegExp(r'/v1beta?/'))[0].replaceFirst(RegExp(r'/+\z'), '');
    final endpoint = apiUrl.contains(':generateContent')
        ? apiUrl
        : '$base$versionSegment$normalizedModel:generateContent';

    Uri uri = Uri.parse(endpoint);
    if (!uri.queryParameters.containsKey('key')) {
      final qp = Map<String, String>.from(uri.queryParameters);
      qp['key'] = apiKey;
      uri = uri.replace(queryParameters: qp);
    }

    final client = HttpClient();
    client.connectionTimeout = Duration(seconds: 8);
    try {
      final req = await client.postUrl(uri);
      req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      final bodyMap = {
        'contents': [
          {
            'parts': [
              {'text': prompt},
            ],
          },
        ],
        'generationConfig': {
          'temperature': 0.3,
          'topP': 0.95,
          'topK': 40,
          'maxOutputTokens': 640,
        },
      };
      req.add(utf8.encode(jsonEncode(bodyMap)));
      final resp = await req.close().timeout(Duration(seconds: 15));
      final respBody = await resp.transform(utf8.decoder).join();
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw Exception('AI provider error: ${resp.statusCode}: $respBody');
      }
      try {
        final json = jsonDecode(respBody);
        if (json is Map<String, dynamic>) {
          final candidates = json['candidates'];
          if (candidates is List && candidates.isNotEmpty) {
            final first = candidates.first;
            if (first is Map<String, dynamic>) {
              final content = first['content'];
              if (content is Map<String, dynamic>) {
                final parts = content['parts'];
                if (parts is List) {
                  for (final part in parts) {
                    if (part is Map<String, dynamic> && part['text'] != null) {
                      return part['text'].toString();
                    }
                  }
                }
              }
              if (first['output'] != null) {
                return first['output'].toString();
              }
              if (first['text'] != null) {
                return first['text'].toString();
              }
            }
          }
          if (json['output'] != null) return json['output'].toString();
          if (json['text'] != null) return json['text'].toString();
        }
      } catch (_) {
        // ignore parse errors and return raw body as fallback
      }
      return respBody;
    } finally {
      client.close(force: true);
    }
  }
}
