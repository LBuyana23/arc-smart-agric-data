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
// Tests use the real AppState provider; no injected ApiService is required

void main() {
  testWidgets('App builds and shows overview title', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => real.AppState(startSimulations: false),
        child: const MaterialApp(home: OverviewPage()),
      ),
    );
    await tester.pump();

    expect(find.text('Dashboard Overview'), findsOneWidget);
  });
}
