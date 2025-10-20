// lib/models/soil_data.dart

class SoilData {
  final double moisture;
  final double temperature;
  final double ec; // Electrical Conductivity
  final double ph;
  final double nitrogen;
  final double phosphorus;
  final double potassium;
  final int timestamp;

  SoilData({
    required this.moisture,
    required this.temperature,
    required this.ec,
    required this.ph,
    required this.nitrogen,
    required this.phosphorus,
    required this.potassium,
    required this.timestamp,
  });
}