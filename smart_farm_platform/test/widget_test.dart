// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:provider/provider.dart';
import 'package:smart_farm_platform/providers/app_state.dart' as real;
import 'package:smart_farm_platform/pages/overview_page.dart';
import 'package:smart_farm_platform/services/api_service.dart';
import 'package:smart_farm_platform/models/greenhouse_data.dart';

class FakeAppState extends ChangeNotifier {
  bool get isSidebarCollapsed => false;
  String get currentPage => 'Overview';
  List<double> get liveData => List.generate(60, (i) => 20 + i * 0.1);
  String get currentInsight => 'Fake insight for tests';
  double get insightConfidence => 0.8;
  String get systemStatus => 'stable';
}

class _FakeApiService extends ApiService {
  _FakeApiService() : super();

  @override
  Future<GreenhouseData> fetchLatestGreenhouseData() async {
    return GreenhouseData(
      timestamp: DateTime.now().toIso8601String(),
      temperature: 22.5,
      humidity: 55.0,
      pressure: 101.2,
      co2: 420,
      lightIntensity: 1200,
    );
  }
}

void main() {
  testWidgets('App builds and shows overview title', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => real.AppState(startSimulations: false),
        child: MaterialApp(home: OverviewPage(api: _FakeApiService())),
      ),
    );
    await tester.pump();

    expect(find.text('Dashboard Overview'), findsOneWidget);
  });
}
