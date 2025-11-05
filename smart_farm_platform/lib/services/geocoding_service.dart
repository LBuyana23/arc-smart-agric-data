import 'dart:convert';
import 'package:http/http.dart' as http;

class CitySuggestion {
  final String name;
  final String? country;
  final String? admin1;
  final double latitude;
  final double longitude;
  final String? timezone;

  const CitySuggestion({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.country,
    this.admin1,
    this.timezone,
  });
}

class GeocodingService {
  /// Query Open-Meteo geocoding API for [cityName] and return detailed
  /// suggestions including administrative regions. Used to surface a list
  /// of candidate locations in the UI so users can confirm the exact site.
  Future<List<CitySuggestion>> searchCities(
    String cityName, {
    int limit = 6,
  }) async {
    if (cityName.trim().isEmpty) return const [];
    try {
      final url = Uri.parse(
        'https://geocoding-api.open-meteo.com/v1/search?name=${Uri.encodeComponent(cityName)}&count=$limit&language=en&format=json',
      );
      final resp = await http.get(url).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return const [];
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final results = body['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) return const [];
      return results.whereType<Map<String, dynamic>>().map((entry) {
        final name = entry['name']?.toString() ?? '';
        final country = entry['country']?.toString();
        final admin1 = entry['admin1']?.toString();
        final timezone = entry['timezone']?.toString();
        final lat = (entry['latitude'] as num?)?.toDouble();
        final lon = (entry['longitude'] as num?)?.toDouble();
        if (name.isEmpty || lat == null || lon == null) {
          return null;
        }
        return CitySuggestion(
          name: name,
          country: country,
          admin1: admin1,
          timezone: timezone,
          latitude: lat,
          longitude: lon,
        );
      }).whereType<CitySuggestion>().toList();
    } catch (_) {
      return const [];
    }
  }

  /// Legacy helper: returns only coordinates for the top match.
  Future<Map<String, double>?> getCoordinatesForCity(String cityName) async {
    final suggestions = await searchCities(cityName, limit: 1);
    if (suggestions.isEmpty) return null;
    final first = suggestions.first;
    return {'lat': first.latitude, 'lon': first.longitude};
  }
}
