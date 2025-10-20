// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/greenhouse_data.dart';
import '../models/irrigation_data.dart';

class ApiService {
  // Change this base IP if your PC IP changes. Use http (no https) since the Flask server is local.
  static const String _baseIp = '172.30.114.34';
  // static const String _baseUrl = 'http://$_baseIp:5000'; // Removed unused _baseUrl

  // Endpoints
  static String get _greenhouseUrl => 'http://$_baseIp:5000/api/greenhouse/latest';
  static String get _irrigationUrl => 'http://$_baseIp:5000/api/irrigation/latest';

  final http.Client _client;

  ApiService([http.Client? client]) : _client = client ?? http.Client();

  Future<GreenhouseData> fetchLatestGreenhouseData() async {
    final resp = await _client.get(Uri.parse(_greenhouseUrl)).timeout(Duration(seconds: 10));
    if (resp.statusCode != 200) {
      throw Exception('Failed to fetch greenhouse data: ${resp.statusCode}');
    }
    final Map<String, dynamic> json = jsonDecode(resp.body) as Map<String, dynamic>;
    return GreenhouseData.fromJson(json);
  }

  Future<IrrigationData> fetchLatestIrrigationData() async {
    final resp = await _client.get(Uri.parse(_irrigationUrl)).timeout(Duration(seconds: 10));
    if (resp.statusCode != 200) {
      throw Exception('Failed to fetch irrigation data: ${resp.statusCode}');
    }
    final Map<String, dynamic> json = jsonDecode(resp.body) as Map<String, dynamic>;
    return IrrigationData.fromJson(json);
  }
}
