import 'dart:convert';
import 'package:http/http.dart' as http;

class GeocodingService {
  /// Query Open-Meteo geocoding API for [cityName]. Returns a map with
  /// 'lat' and 'lon' keys on success, or null when no result found.
  Future<Map<String, double>?> getCoordinatesForCity(String cityName) async {
    try {
      final url = Uri.parse('https://geocoding-api.open-meteo.com/v1/search?name=${Uri.encodeComponent(cityName)}&count=1');
      final resp = await http.get(url).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final results = body['results'] as List<dynamic>?;
        if (results != null && results.isNotEmpty) {
          final first = results.first as Map<String, dynamic>;
          final lat = (first['latitude'] as num?)?.toDouble();
          final lon = (first['longitude'] as num?)?.toDouble();
          if (lat != null && lon != null) return {'lat': lat, 'lon': lon};
        }
      }
    } catch (_) {}
    return null;
  }
}
