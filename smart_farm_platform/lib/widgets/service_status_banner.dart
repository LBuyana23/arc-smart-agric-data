import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class ServiceStatusBanner extends StatelessWidget {
  final ServiceStatus status;
  final VoidCallback? onRetry;

  const ServiceStatusBanner({super.key, required this.status, this.onRetry});

  Color _statusColor(BuildContext context) {
    switch (status.state) {
      case BackendState.online:
        return Colors.greenAccent.shade400;
      case BackendState.warming:
        return Colors.orangeAccent.shade400;
      case BackendState.offline:
        return Colors.redAccent.shade200;
    }
  }

  IconData _statusIcon() {
    switch (status.state) {
      case BackendState.online:
        return Icons.check_circle_outline;
      case BackendState.warming:
        return Icons.hourglass_empty;
      case BackendState.offline:
        return Icons.wifi_off;
    }
  }

  String _latencyLabel() {
    if (status.latency == null) return '';
    final ms = status.latency!.inMilliseconds;
    if (ms >= 1000) {
      final seconds = status.latency!.inMilliseconds / 1000.0;
      return '${seconds.toStringAsFixed(seconds >= 10 ? 0 : 1)}s';
    }
    return '${ms}ms';
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(context);
    final latency = _latencyLabel();
    final showRetry = onRetry != null && status.state != BackendState.online;
    return AnimatedSlide(
      duration: const Duration(milliseconds: 250),
      offset: const Offset(0, 0),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: 1.0,
        child: Align(
          alignment: Alignment.topCenter,
          child: Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.cardBackground.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: color.withValues(alpha: 0.65),
                width: 1.2,
              ),
              boxShadow: const [
                BoxShadow(
                  blurRadius: 16,
                  spreadRadius: -12,
                  offset: Offset(0, 12),
                  color: Colors.black45,
                ),
              ],
            ),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                Icon(_statusIcon(), color: color, size: 18),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: Text(
                    status.displayMessage,
                    style: TextStyle(color: color, fontWeight: FontWeight.w600),
                    softWrap: true,
                  ),
                ),
                if (latency.isNotEmpty)
                  Text(
                    '($latency)',
                    style: TextStyle(color: AppTheme.mutedForeground),
                  ),
                if (showRetry)
                  TextButton.icon(
                    onPressed: onRetry,
                    style: TextButton.styleFrom(foregroundColor: color),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Retry'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
