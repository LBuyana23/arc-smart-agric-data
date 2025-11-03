import 'package:flutter/material.dart';

class NoDataPlaceholder extends StatelessWidget {
  final VoidCallback? onRetry;
  final String title;
  final String message;
  const NoDataPlaceholder({super.key, this.onRetry, this.title = 'Data Unavailable', this.message = 'Could not fetch the latest data from the server. Please check your connection and try again.'});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 48, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
            SizedBox(height: 12),
            Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            SizedBox(height: 8),
            Text(message, style: TextStyle(fontSize: 14), textAlign: TextAlign.center),
            if (onRetry != null) ...[
              SizedBox(height: 16),
              ElevatedButton(onPressed: onRetry, child: Text('Retry'))
            ]
          ],
        ),
      ),
    );
  }
}
