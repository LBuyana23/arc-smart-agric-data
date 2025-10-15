import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class AppState extends ChangeNotifier {
  bool _isSidebarCollapsed = false;
  String _currentPage = 'Overview';
  List<double> _liveData = List.generate(60, (i) => 20 + Random().nextDouble() * 10);
  Timer? _liveDataTimer;
  String _currentInsight = 'Analyzing farm data patterns...';
  double _insightConfidence = 0.85;
  Timer? _insightTimer;
  String _systemStatus = 'stable';
  
  bool get isSidebarCollapsed => _isSidebarCollapsed;
  String get currentPage => _currentPage;
  List<double> get liveData => _liveData;
  String get currentInsight => _currentInsight;
  double get insightConfidence => _insightConfidence;
  String get systemStatus => _systemStatus;

  final List<String> _insights = [
    'Soil moisture has dropped 8% in Zone A. Consider increasing irrigation by 15%.',
    'Optimal temperature range maintained for 96.3% of the past 24 hours.',
    'Wind patterns suggest potential storm activity. Review crop protection measures.',
    'Water usage efficiency improved by 12% compared to last week.',
    'pH levels trending slightly acidic. Nutrient adjustment may be beneficial.',
    'Humidity levels optimal for current crop growth stage.',
  ];

  AppState() {
    _startLiveDataSimulation();
    _startInsightRotation();
    _simulateSystemStatus();
  }

  void toggleSidebar() {
    _isSidebarCollapsed = !_isSidebarCollapsed;
    notifyListeners();
  }

  void setCurrentPage(String page) {
    _currentPage = page;
    notifyListeners();
  }

  void _startLiveDataSimulation() {
    _liveDataTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      _liveData.removeAt(0);
      _liveData.add(20 + Random().nextDouble() * 10);
      notifyListeners();
    });
  }

  void _startInsightRotation() {
    _insightTimer = Timer.periodic(Duration(seconds: 15), (timer) {
      final random = Random();
      _currentInsight = _insights[random.nextInt(_insights.length)];
      _insightConfidence = 0.75 + random.nextDouble() * 0.2;
      notifyListeners();
    });
  }

  void _simulateSystemStatus() {
    Timer.periodic(Duration(seconds: 30), (timer) {
      final random = Random();
      final statuses = ['stable', 'delayed', 'disconnected'];
      _systemStatus = statuses[random.nextInt(100) < 90 ? 0 : random.nextInt(statuses.length)];
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _liveDataTimer?.cancel();
    _insightTimer?.cancel();
    super.dispose();
  }
}
