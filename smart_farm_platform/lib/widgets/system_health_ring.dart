import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';

class SystemHealthRing extends StatefulWidget {
  const SystemHealthRing({super.key});

  @override
  State<SystemHealthRing> createState() => _SystemHealthRingState();
}

class _SystemHealthRingState extends State<SystemHealthRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = context.watch<AppState>().systemStatus;
    final color = _getStatusColor(status);
    final message = _getStatusMessage(status);

    return Tooltip(
      message: message,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withAlpha((0.2 * 255).round()),
              border: Border.all(
                color: color.withAlpha(((0.5 + _controller.value * 0.5) * 255).round()),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withAlpha((_controller.value * 0.3 * 255).round()),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'stable':
        return AppTheme.primaryGreen;
      case 'delayed':
        return Colors.orange;
      case 'disconnected':
        return Colors.red;
      default:
        return AppTheme.primaryGreen;
    }
  }

  String _getStatusMessage(String status) {
    switch (status) {
      case 'stable':
        return 'System connection is stable';
      case 'delayed':
        return 'Connection experiencing delays';
      case 'disconnected':
        return 'System disconnected';
      default:
        return 'System status unknown';
    }
  }
}
