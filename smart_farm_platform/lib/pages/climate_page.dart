import 'package:flutter/material.dart';

// ClimatePage removed: endpoint not available. Keep a minimal placeholder so
// any remaining imports or navigation targets won't crash the app.
class ClimatePage extends StatelessWidget {
  const ClimatePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.cloud_off, size: 48),
            SizedBox(height: 12),
            Text('Climate data is not available', style: TextStyle(fontSize: 18)),
            SizedBox(height: 8),
            Text('This page has been disabled because the backend does not provide climate data.'),
          ],
        ),
      ),
    );
  }
}
