import 'dart:async';

/// Lightweight AI integration shim.
///
/// This file intentionally does NOT call any external AI service by default.
/// To enable a real AI provider, build the app with a compile-time key and
/// implement the network call here. For safety we do not embed nor use any
/// API key shipped in source control.

class AiIntegration {
  /// Generate a short human-friendly summary for the overview page.
  ///
  /// - If the app was built with a compile-time AI key via
  ///   `--dart-define=AI_STUDIO_KEY=<your_key>` you can extend this method
  ///   to call your provider. Right now this returns a locally generated
  ///   summary based on the provided `metrics` map.
  // If someone supplies a build-time key we still don't ship network code
  // here to avoid accidental key usage. The presence of a key can be used
  // by advanced users to toggle behavior in a fork of the app.
  static String generateSummary(Map<String, dynamic> metrics) {
    const aiKey = String.fromEnvironment('AI_STUDIO_KEY');
    if (aiKey.isNotEmpty) {
      // Placeholder: advanced users can implement a provider call here.
      // For safety we still fall back to the local generator unless a
      // concrete provider implementation is added.
      return _localSummary(metrics, source: 'AI (stubbed)');
    }

    // Local heuristic summary
    return _localSummary(metrics, source: 'Local heuristics');
  }

  static String _localSummary(Map<String, dynamic> m, {required String source}) {
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
      parts.add('$heat greenhouse temperature at ${ghTemp.toStringAsFixed(1)}°C with ${ghHum.toStringAsFixed(0)}% humidity.');
    } else if (ghTemp != null) {
      parts.add('Greenhouse temperature is ${ghTemp.toStringAsFixed(1)}°C.');
    }

    if (soil != null) {
      final soilMsg = soil < 25 ? 'soil is dry' : (soil > 60 ? 'soil is wet' : 'soil moisture is in a healthy range');
      parts.add('${soilMsg} (${soil.toStringAsFixed(1)}%).');
    }
    if (soilPh != null) parts.add('Soil pH ${soilPh.toStringAsFixed(2)}.');

    if (irrFlow != null) {
      parts.add('Irrigation flow ${irrFlow.toStringAsFixed(1)} L/min; $pumpsOn pumps active.');
    }

    if (threats != null && threats > 0) {
      parts.add('Crop vision detected $threats potential issues — inspect recent detections.');
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
  static Future<String> generateDetailedSummary(Map<String, dynamic> metrics, {String window = '24h'}) async {
    const aiKey = String.fromEnvironment('AI_STUDIO_KEY');
    // If provider is configured, an integration would go here. For now
    // produce a structured human-readable report using the available metrics.
    final buf = StringBuffer();
    buf.writeln('Farm summary for the past ${window == '1h' ? '1 hour' : window == '24h' ? '24 hours' : '7 days'}:');
    try {
      final gh = metrics['greenhouse'] as Map<String, dynamic>?;
      final so = metrics['soil'] as Map<String, dynamic>?;
      final ir = metrics['irrigation'] as Map<String, dynamic>?;
      final cv = metrics['crop'] as Map<String, dynamic>?;

      if (gh != null) {
        buf.writeln('- Greenhouse: ${gh['count'] ?? 0} samples. Avg temp ${gh['avgTemp'] != null ? (gh['avgTemp'] as double).toStringAsFixed(1) + '°C' : '—'}, avg humidity ${gh['avgHumidity'] != null ? (gh['avgHumidity'] as double).toStringAsFixed(0) + '%' : '—'}');
        if (gh['prevAvgTemp'] != null && gh['avgTemp'] != null) {
          final prev = gh['prevAvgTemp'] as double? ?? 0.0;
          final curr = gh['avgTemp'] as double? ?? 0.0;
          final diff = (curr - prev);
          final pct = prev != 0 ? (diff / prev * 100) : 0.0;
          buf.writeln('  • Temperature change vs previous window: ${diff.toStringAsFixed(1)}°C (${pct.toStringAsFixed(1)}%)');
        }
      }

      if (so != null) {
        buf.writeln('- Soil: ${so['count'] ?? 0} samples. Avg moisture ${so['avgMoisture'] != null ? (so['avgMoisture'] as double).toStringAsFixed(1) + '%' : '—'}, avg pH ${so['avgPh'] != null ? (so['avgPh'] as double).toStringAsFixed(2) : '—'}');
      }

      if (ir != null) {
        buf.writeln('- Irrigation: ${(ir['count'] ?? 0)} samples. Avg flow ${ir['flowAvg'] != null ? (ir['flowAvg'] as double).toStringAsFixed(1) + ' L/min' : '—'}, pumps on: ${ir['pumpsOn'] ?? 0}/${ir['pumpsTotal'] ?? 0}');
      }

      if (cv != null) {
        buf.writeln('- Crop vision: ${cv['count'] ?? 0} detections. Issues: ${cv['threats'] ?? 0}${cv['topLabel'] != null ? ' (top: ${cv['topLabel']} ${(cv['topConf'] != null ? ((cv['topConf'] as double) * 100).toStringAsFixed(1) + '%' : '')})' : ''}');
      }
    } catch (_) {}

    buf.writeln('\n(Generated by local summarizer${aiKey.isNotEmpty ? ' — remote AI available (stubbed)' : ''})');
    return buf.toString();
  }
}
