// lib/models/irrigation_data.dart
class IrrigationData {
  final String timestamp;
  final double flowRateLmin;
  final double totalVolume;
  final double waterUsedCycle;
  final String pumpState;

  IrrigationData({
    required this.timestamp,
    required this.flowRateLmin,
    required this.totalVolume,
    required this.waterUsedCycle,
    required this.pumpState,
  });

  factory IrrigationData.fromJson(Map<String, dynamic> json) {
    // support both TitleCase and snake_case keys
    dynamic get(String a, String b) => json[a] ?? json[b];

    return IrrigationData(
      timestamp: get("Timestamp", "timestamp") ?? "",
      flowRateLmin: (get("flow_rate_Lmin", "flow_rate_Lmin") ?? get("flowRateLmin", "flowRateLmin") ?? 0).toDouble(),
      totalVolume: (get("total_volume", "total_volume") ?? 0).toDouble(),
      waterUsedCycle: (get("water_used_cycle", "water_used_cycle") ?? 0).toDouble(),
      pumpState: (get("pump_state", "pump_state") ?? "UNKNOWN").toString(),
    );
  }
}
