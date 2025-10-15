import 'package:flutter/material.dart';
import '../models/sensor_data.dart';
import '../theme/app_theme.dart';

class WeatherOverview extends StatelessWidget {
  const WeatherOverview({super.key});

  WeatherData get _weatherData => WeatherData(
        location: 'Cape Town Greenhouse #1',
        temperature: 22.5,
        description: 'Partly Cloudy',
        humidity: 65,
        rainProbability: 20,
        windSpeed: 12.3,
        sunrise: '06:23',
        sunset: '19:47',
        forecast: [
          DayForecast(day: 'Mon', icon: '☀️', high: 24, low: 16),
          DayForecast(day: 'Tue', icon: '⛅', high: 23, low: 15),
          DayForecast(day: 'Wed', icon: '🌧', high: 20, low: 14),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final weather = _weatherData;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              weather.location,
              style: TextStyle(
                color: AppTheme.mutedForeground,
                fontSize: 14,
              ),
            ),
            SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${weather.temperature.toStringAsFixed(1)}°',
                  style: TextStyle(
                    color: AppTheme.foreground,
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 8),
                      Text(
                        weather.description,
                        style: TextStyle(
                          color: AppTheme.foreground,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '⛅',
                        style: TextStyle(fontSize: 32),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),
            Row(
              children: [
                _buildWeatherDetail(Icons.water_drop, '${weather.humidity}%', 'Humidity'),
                SizedBox(width: 24),
                _buildWeatherDetail(Icons.umbrella, '${weather.rainProbability}%', 'Rain'),
                SizedBox(width: 24),
                _buildWeatherDetail(Icons.air, '${weather.windSpeed} km/h', 'Wind'),
              ],
            ),
            SizedBox(height: 24),
            Row(
              children: [
                Icon(Icons.wb_sunny, color: Colors.orange, size: 16),
                SizedBox(width: 8),
                Text(
                  weather.sunrise,
                  style: TextStyle(color: AppTheme.mutedForeground, fontSize: 12),
                ),
                SizedBox(width: 24),
                Icon(Icons.nightlight, color: Colors.indigo, size: 16),
                SizedBox(width: 8),
                Text(
                  weather.sunset,
                  style: TextStyle(color: AppTheme.mutedForeground, fontSize: 12),
                ),
              ],
            ),
            SizedBox(height: 24),
            Divider(color: AppTheme.border),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: weather.forecast.map((day) => _buildForecastDay(day)).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherDetail(IconData icon, String value, String label) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.mutedForeground, size: 16),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: AppTheme.foreground,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: AppTheme.mutedForeground,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForecastDay(DayForecast day) {
    return Column(
      children: [
        Text(
          day.day,
          style: TextStyle(
            color: AppTheme.mutedForeground,
            fontSize: 12,
          ),
        ),
        SizedBox(height: 8),
        Text(
          day.icon,
          style: TextStyle(fontSize: 24),
        ),
        SizedBox(height: 8),
        Text(
          '${day.high}°',
          style: TextStyle(
            color: AppTheme.foreground,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          '${day.low}°',
          style: TextStyle(
            color: AppTheme.mutedForeground,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
