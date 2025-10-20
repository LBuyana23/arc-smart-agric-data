// lib/models/greenhouse_data.dart
class GreenhouseData {
  final String timestamp;
  final double temperature;
  final double humidity;
  final double pressure;
  final double? co2;
  final double? lightIntensity;

  GreenhouseData({
    required this.timestamp,
    required this.temperature,
    required this.humidity,
    required this.pressure,
    this.co2,
    this.lightIntensity,
  });

  factory GreenhouseData.fromJson(Map<String, dynamic> json) {
    return GreenhouseData(
      timestamp: json["Timestamp"] ?? json["timestamp"] ?? "",
      temperature: (json["Temperature"] ?? json["temperature"] ?? 0).toDouble(),
      humidity: (json["Humidity"] ?? json["humidity"] ?? 0).toDouble(),
      pressure: (json["Pressure"] ?? json["pressure"] ?? 0).toDouble(),
      co2: json.containsKey("CO2") ? (json["CO2"] as num).toDouble() : null,
      lightIntensity: json.containsKey("Light_Intensity")
          ? (json["Light_Intensity"] as num).toDouble()
          : null,
    );
  }
}
