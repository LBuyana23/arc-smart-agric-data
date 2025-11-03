// lib/models/crop_vision_data.dart

class CropVisionData {
  final String timestamp;
  final String cropId;
  final String disease;
  final String growthStage;
  final int? pestCount;
  final String recommendation;
  final double? ndvi;

  CropVisionData({
    required this.timestamp,
    required this.cropId,
    required this.disease,
    required this.growthStage,
    this.pestCount,
    this.recommendation = 'none',
    this.ndvi,
  });

  factory CropVisionData.fromJson(Map<String, dynamic> json) {
    dynamic get(List<String> keys) {
      for (final k in keys) {
        if (json.containsKey(k)) return json[k];
      }
      return null;
    }
    num? numify(dynamic v) => v is num ? v : (v == null ? null : double.tryParse(v.toString()));
    int? intify(dynamic v) => v is int ? v : (v == null ? null : int.tryParse(v.toString()));

    return CropVisionData(
      timestamp: (get(['Timestamp', 'timestamp']) ?? '').toString(),
      cropId: (get(['Crop_ID', 'crop_id', 'cropId']) ?? '').toString(),
      disease: (get(['Disease', 'disease']) ?? 'none').toString(),
      growthStage: (get(['Growth_stage', 'growth_stage', 'growthStage']) ?? '').toString(),
      pestCount: intify(get(['Pest_count', 'pest_count', 'pestCount'])),
      recommendation: (get(['Recommendation', 'recommendation']) ?? 'none').toString(),
      ndvi: numify(get(['NDVI', 'ndvi']))?.toDouble(),
    );
  }
}
