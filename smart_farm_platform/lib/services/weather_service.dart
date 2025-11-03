import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WeatherData {
  final double currentTemp;
  final int weatherCode;
  final List<DailyForecast> daily;

  WeatherData({required this.currentTemp, required this.weatherCode, required this.daily});
}

class DailyForecast {
  final DateTime date;
  final double minTemp;
  final double maxTemp;
  final int weatherCode;
  DailyForecast({required this.date, required this.minTemp, required this.maxTemp, required this.weatherCode});
}

class WeatherService {
  // Preference keys
  static const _prefLat = 'farm_lat';
  static const _prefLon = 'farm_lon';

  /// Save the user-selected farm location to shared preferences.
  Future<void> saveLocation(double lat, double lon) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_prefLat, lat);
      await prefs.setDouble(_prefLon, lon);
    } catch (_) {}
  }

  /// Load the previously saved location, or null when not set.
  Future<Map<String, double>?> loadLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lat = prefs.getDouble(_prefLat);
      final lon = prefs.getDouble(_prefLon);
      if (lat != null && lon != null) return {'lat': lat, 'lon': lon};
    } catch (_) {}
    return null;
  }

  Future<WeatherData?> fetchWeather() async {
    try {
      final loc = await loadLocation();
      if (loc == null) return null; // no location set
      final latitude = loc['lat']!;
      final longitude = loc['lon']!;
      final url = 'https://api.open-meteo.com/v1/forecast?latitude=$latitude&longitude=$longitude&current_weather=true&daily=weathercode,temperature_2m_max,temperature_2m_min&timezone=UTC';
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final current = body['current_weather'];
        final double currTemp = (current != null && current['temperature'] != null) ? (current['temperature'] as num).toDouble() : double.nan;
        final int currCode = (current != null && current['weathercode'] != null) ? (current['weathercode'] as int) : 0;
        final List<DailyForecast> days = [];
        if (body['daily'] is Map) {
          final daily = body['daily'] as Map<String, dynamic>;
          final dates = daily['time'] as List<dynamic>? ?? [];
          final mins = daily['temperature_2m_min'] as List<dynamic>? ?? [];
          final maxs = daily['temperature_2m_max'] as List<dynamic>? ?? [];
          final codes = daily['weathercode'] as List<dynamic>? ?? [];
          for (var i = 0; i < dates.length && i < 7; i++) {
            final date = DateTime.parse(dates[i].toString());
            final minT = (i < mins.length && mins[i] != null) ? (mins[i] as num).toDouble() : double.nan;
            final maxT = (i < maxs.length && maxs[i] != null) ? (maxs[i] as num).toDouble() : double.nan;
            final code = (i < codes.length && codes[i] != null) ? (codes[i] as int) : 0;
            days.add(DailyForecast(date: date, minTemp: minT, maxTemp: maxT, weatherCode: code));
          }
        }
        return WeatherData(currentTemp: currTemp, weatherCode: currCode, daily: days);
      }
    } catch (e) {
      debugPrint('fetchWeather error: $e');
    }
    return null;
  }

  IconData iconForCode(int code) {
    // Simplified mapping
    if (code == 0) return Icons.wb_sunny;
    if (code == 1 || code == 2 || code == 3) return Icons.wb_cloudy;
    if (code >= 45 && code <= 48) return Icons.foggy;
    if (code >= 51 && code <= 67) return Icons.grain; // drizzle/rain
    if (code >= 71 && code <= 77) return Icons.ac_unit; // snow/ice
    if (code >= 80 && code <= 86) return Icons.umbrella;
    if (code >= 95) return Icons.thunderstorm;
    return Icons.help_outline;
  }
}
