import 'package:flutter/material.dart';

class SensorData {
  final String name;
  final double value;
  final String unit;
  final double threshold;
  final IconData icon;

  SensorData({
    required this.name,
    required this.value,
    required this.unit,
    required this.threshold,
    required this.icon,
  });
}

class WeatherData {
  final String location;
  final double temperature;
  final String description;
  final int humidity;
  final int rainProbability;
  final double windSpeed;
  final String sunrise;
  final String sunset;
  final List<DayForecast> forecast;

  WeatherData({
    required this.location,
    required this.temperature,
    required this.description,
    required this.humidity,
    required this.rainProbability,
    required this.windSpeed,
    required this.sunrise,
    required this.sunset,
    required this.forecast,
  });
}

class DayForecast {
  final String day;
  final String icon;
  final int high;
  final int low;

  DayForecast({
    required this.day,
    required this.icon,
    required this.high,
    required this.low,
  });
}

class IrrigationSnapshot {
  final double waterFlow;
  final double delta;
  final DateTime timestamp;

  IrrigationSnapshot({
    required this.waterFlow,
    required this.delta,
    required this.timestamp,
  });
}

class TimeSeriesData {
  final DateTime timestamp;
  final double value;

  TimeSeriesData({
    required this.timestamp,
    required this.value,
  });
}
