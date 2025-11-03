// lib/models/soil_data.dart

class SoilData {
  final String timestamp;
  final double moisturePct;
  final double temperature;
  final double ec;
  final double ph;
  final double? nitrogen;
  final double? phosphorus;
  final double? potassium;

  SoilData({
    required this.timestamp,
    required this.moisturePct,
    required this.temperature,
    required this.ec,
    required this.ph,
    this.nitrogen,
    this.phosphorus,
    this.potassium,
  });

  factory SoilData.fromJson(Map<String, dynamic> json) {
    dynamic get(String a, String b) => json[a] ?? json[b];
    num? nify(dynamic v) => v is num ? v : (v == null ? null : double.tryParse(v.toString()));
    return SoilData(
      timestamp: (get('Timestamp', 'timestamp') ?? '').toString(),
      moisturePct: (nify(get('moisture_pct', 'moisture')) ?? 0.0).toDouble(),
      temperature: (nify(get('temperature', 'Temperature')) ?? 0.0).toDouble(),
      ec: (nify(get('ec', 'EC')) ?? 0.0).toDouble(),
      ph: (nify(get('ph', 'pH')) ?? 0.0).toDouble(),
      nitrogen: nify(get('Nitrogen(N)', 'nitrogen'))?.toDouble(),
      phosphorus: nify(get('Phosphorus(P)', 'phosphorus'))?.toDouble(),
      potassium: nify(get('Potassium(K)', 'potassium'))?.toDouble(),
    );
  }
}
