// lib/models/greenhouse_data.dart

class GreenhouseData {
  final String timestamp;
  final double temperature;
  final double humidity;
  final double? pressure;
  final double? co2;
  final double? lightIntensity;
  final double? co;
  final double? lpg;
  final double? smoke;
  final double? methaneLevel;
  final double? propaneLevel;
  final double? butaneLevel;
  final double? hydrogenLevel;
  final double? alcoholLevel;
  final double? ammoniaLevel;
  final double? benzeneLevel;
  final double? tolueneLevel;

  GreenhouseData({
    required this.timestamp,
    required this.temperature,
    required this.humidity,
    this.pressure,
    this.co,
    this.lpg,
    this.smoke,
    this.co2,
    this.lightIntensity,
    this.methaneLevel,
    this.propaneLevel,
    this.butaneLevel,
    this.hydrogenLevel,
    this.alcoholLevel,
    this.ammoniaLevel,
    this.benzeneLevel,
    this.tolueneLevel,
  });

  // This factory constructor safely creates a GreenhouseData object from JSON.
  // It handles missing data and different capitalizations from the API.
  factory GreenhouseData.fromJson(Map<String, dynamic> json) {
    dynamic get(List<String> keys) {
      for (final k in keys) {
        if (json.containsKey(k)) return json[k];
      }
      return null;
    }

    num? numify(dynamic v) => v is num ? v : (v == null ? null : double.tryParse(v.toString()));

    return GreenhouseData(
      timestamp: (get(['Timestamp', 'timestamp']) ?? '').toString(),
      temperature: (numify(get(['Temperature', 'temperature'])) ?? 0).toDouble(),
      humidity: (numify(get(['Humidity', 'humidity'])) ?? 0).toDouble(),
      pressure: numify(get(['Pressure', 'pressure']))?.toDouble(),
      co: numify(get(['CO', 'co']))?.toDouble(),
      lpg: numify(get(['lpg']))?.toDouble(),
      smoke: numify(get(['Smoke', 'smoke']))?.toDouble(),
      co2: numify(get(['CO2', 'co2']))?.toDouble(),
      lightIntensity: numify(get(['Light_Intensity', 'light_intensity', 'Light Intensity']))?.toDouble(),
      methaneLevel: numify(get(['methane_level', 'methane']))?.toDouble(),
      propaneLevel: numify(get(['propane_level', 'propane']))?.toDouble(),
      butaneLevel: numify(get(['butane_level', 'butane']))?.toDouble(),
      hydrogenLevel: numify(get(['hydrogen_level', 'hydrogen']))?.toDouble(),
      alcoholLevel: numify(get(['alcohol_level', 'alcohol']))?.toDouble(),
      ammoniaLevel: numify(get(['ammonia_level', 'ammonia']))?.toDouble(),
      benzeneLevel: numify(get(['benzene_level', 'benzene']))?.toDouble(),
      tolueneLevel: numify(get(['toluene_level', 'toluene']))?.toDouble(),
    );
  }
}