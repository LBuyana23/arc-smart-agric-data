import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WeatherData {
  final double currentTemp;
  final int weatherCode;
  final List<DailyForecast> daily;
  final double? apparentTemp;
  final double? humidity;
  final double? windSpeed;

  WeatherData({
    required this.currentTemp,
    required this.weatherCode,
    required this.daily,
    this.apparentTemp,
    this.humidity,
    this.windSpeed,
  });
}

class DailyForecast {
  final DateTime date;
  final double minTemp;
  final double maxTemp;
  final int weatherCode;
  final double? precipitationProbability;
  final double? windSpeed;
  DailyForecast({
    required this.date,
    required this.minTemp,
    required this.maxTemp,
    required this.weatherCode,
    this.precipitationProbability,
    this.windSpeed,
  });
}

class WeatherService {
  // Preference keys
  static const _prefLat = 'farm_lat';
  static const _prefLon = 'farm_lon';
  static const _prefLabel = 'farm_location_label';
  static const _prefCountry = 'farm_location_country';
  static const _prefRegion = 'farm_location_region';
  static const _prefTimezone = 'farm_location_timezone';

  /// Save the user-selected farm location to shared preferences.
  Future<void> saveLocation(
    double lat,
    double lon, {
    String? label,
    String? country,
    String? admin,
    String? timezone,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_prefLat, lat);
      await prefs.setDouble(_prefLon, lon);
      if (label != null) {
        await prefs.setString(_prefLabel, label);
      } else {
        await prefs.remove(_prefLabel);
      }
      if (country != null) {
        await prefs.setString(_prefCountry, country);
      } else {
        await prefs.remove(_prefCountry);
      }
      if (admin != null) {
        await prefs.setString(_prefRegion, admin);
      } else {
        await prefs.remove(_prefRegion);
      }
      if (timezone != null) {
        await prefs.setString(_prefTimezone, timezone);
      } else {
        await prefs.remove(_prefTimezone);
      }
    } catch (_) {}
  }

  /// Load the previously saved location, or null when not set.
  Future<Map<String, dynamic>?> loadLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lat = prefs.getDouble(_prefLat);
      final lon = prefs.getDouble(_prefLon);
      if (lat != null && lon != null) {
        final label = prefs.getString(_prefLabel);
        final country = prefs.getString(_prefCountry);
        final region = prefs.getString(_prefRegion);
        final tz = prefs.getString(_prefTimezone);
        return {
          'lat': lat,
          'lon': lon,
          if (label != null) 'label': label,
          if (country != null) 'country': country,
          if (region != null) 'region': region,
          if (tz != null) 'timezone': tz,
        };
      }
    } catch (_) {}
    return null;
  }

  Future<WeatherData?> fetchWeather() async {
    try {
      final loc = await loadLocation();
      if (loc == null) return null; // no location set
  final latitude = (loc['lat'] as num).toDouble();
  final longitude = (loc['lon'] as num).toDouble();
      final url = 'https://api.open-meteo.com/v1/forecast?latitude=$latitude&longitude=$longitude&current_weather=true&current=temperature_2m,relative_humidity_2m,apparent_temperature,wind_speed_10m&daily=weathercode,temperature_2m_max,temperature_2m_min,precipitation_probability_max,wind_speed_10m_max&timezone=UTC';
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final currentWeather = body['current_weather'] as Map<String, dynamic>?;
        final current = body['current'] as Map<String, dynamic>?;
        final double currTemp = currentWeather != null && currentWeather['temperature'] != null
            ? (currentWeather['temperature'] as num).toDouble()
            : (current != null && current['temperature_2m'] != null)
                ? (current['temperature_2m'] as num).toDouble()
                : double.nan;
        final int currCode = currentWeather != null && currentWeather['weathercode'] != null
            ? (currentWeather['weathercode'] as int)
            : 0;
        final double? apparent = current != null && current['apparent_temperature'] != null
            ? (current['apparent_temperature'] as num).toDouble()
            : null;
        final double? humidity = current != null && current['relative_humidity_2m'] != null
            ? (current['relative_humidity_2m'] as num).toDouble()
            : null;
        final double? windSpeed = currentWeather != null && currentWeather['windspeed'] != null
            ? (currentWeather['windspeed'] as num).toDouble()
            : current != null && current['wind_speed_10m'] != null
                ? (current['wind_speed_10m'] as num).toDouble()
                : null;
        final List<DailyForecast> days = [];
        if (body['daily'] is Map) {
          final daily = body['daily'] as Map<String, dynamic>;
          final dates = daily['time'] as List<dynamic>? ?? [];
          final mins = daily['temperature_2m_min'] as List<dynamic>? ?? [];
          final maxs = daily['temperature_2m_max'] as List<dynamic>? ?? [];
          final codes = daily['weathercode'] as List<dynamic>? ?? [];
          final precip = daily['precipitation_probability_max'] as List<dynamic>? ?? [];
          final winds = daily['wind_speed_10m_max'] as List<dynamic>? ?? [];
          for (var i = 0; i < dates.length && i < 7; i++) {
            final date = DateTime.parse(dates[i].toString());
            final minT = (i < mins.length && mins[i] != null) ? (mins[i] as num).toDouble() : double.nan;
            final maxT = (i < maxs.length && maxs[i] != null) ? (maxs[i] as num).toDouble() : double.nan;
            final code = (i < codes.length && codes[i] != null) ? (codes[i] as int) : 0;
            final precipProb = (i < precip.length && precip[i] != null)
                ? (precip[i] as num).toDouble()
                : null;
            final windMax = (i < winds.length && winds[i] != null)
                ? (winds[i] as num).toDouble()
                : null;
            days.add(
              DailyForecast(
                date: date,
                minTemp: minT,
                maxTemp: maxT,
                weatherCode: code,
                precipitationProbability: precipProb,
                windSpeed: windMax,
              ),
            );
          }
        }
        return WeatherData(
          currentTemp: currTemp,
          weatherCode: currCode,
          daily: days,
          apparentTemp: apparent,
          humidity: humidity,
          windSpeed: windSpeed,
        );
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
