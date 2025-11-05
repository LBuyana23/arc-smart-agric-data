import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import 'system_health_ring.dart';

class MainSidebar extends StatelessWidget {
  const MainSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isCollapsed = appState.isSidebarCollapsed;

    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      width: isCollapsed ? 56 : 256,
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        border: Border(
          right: BorderSide(color: AppTheme.border),
        ),
      ),
      child: Column(
        children: [
          _buildHeader(context, isCollapsed),
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(vertical: 8),
              children: [
                if (!isCollapsed) _buildSectionLabel('Main'),
                _buildMenuItem(context, Icons.dashboard, 'Overview', isCollapsed),
                if (!isCollapsed) _buildSectionLabel('Data Groups'),
                _buildMenuItem(context, Icons.water_drop, 'Irrigation', isCollapsed),
                _buildMenuItem(context, Icons.terrain, 'Soil', isCollapsed),
                _buildMenuItem(context, Icons.grass, 'Crop Vision', isCollapsed),
                _buildMenuItem(context, Icons.park, 'Greenhouse', isCollapsed),
                if (!isCollapsed) _buildSectionLabel('Platform'),
                // Data Catalog and API & Integrations removed per user request
                _buildMenuItem(context, Icons.settings, 'Settings', isCollapsed),
              ],
            ),
          ),
          _buildFooter(context, isCollapsed),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isCollapsed) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppTheme.border),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.eco, color: AppTheme.primaryGreen, size: 24),
          if (!isCollapsed) ...[
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Soil Sync',
                    style: TextStyle(
                      color: AppTheme.foreground,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Smart Farm Inc.',
                    style: TextStyle(
                      color: AppTheme.mutedForeground,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: AppTheme.mutedForeground,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, IconData icon, String label, bool isCollapsed) {
    final appState = context.watch<AppState>();
    final isSelected = appState.currentPage == label;

    // Only wrap the menu item in a Tooltip when the sidebar is collapsed.
    // Avoid passing empty tooltip messages which can cause odd overlay behaviour.
    final horizontalMargin = isCollapsed ? 4.0 : 8.0;
    final horizontalPadding = isCollapsed ? 6.0 : 12.0;
    final iconColor = isSelected ? AppTheme.primaryGreen : AppTheme.mutedForeground;

    Widget item = InkWell(
      onTap: () => appState.setCurrentPage(label),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: horizontalMargin, vertical: 2),
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryGreen.withAlpha((0.1 * 255).round()) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: AppTheme.primaryGreen.withAlpha((0.3 * 255).round()))
              : null,
        ),
        child: isCollapsed
            ? SizedBox(
                height: 24,
                child: Center(
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 20,
                  ),
                ),
              )
            : Row(
                children: [
                  Icon(
                    icon,
                    color: iconColor,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isSelected ? AppTheme.primaryGreen : AppTheme.foreground,
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
      ),
    );

    if (isCollapsed) {
      // Only show tooltips on desktop platforms. Tooltips on touch devices
      // can be intrusive (they stay open on long-press), so avoid them there.
      final showTip = defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux;
      if (showTip) return Tooltip(message: label, child: item);
      return item;
    }

    return item;
  }

  Widget _buildFooter(BuildContext context, bool isCollapsed) {
    final appState = context.watch<AppState>();
    final padding = EdgeInsets.symmetric(horizontal: isCollapsed ? 8 : 16, vertical: isCollapsed ? 12 : 16);

    Widget footerButton({required IconData icon, required VoidCallback onPressed, required String tooltip}) {
      return IconButton(
        icon: Icon(icon, size: 20),
        onPressed: onPressed,
        tooltip: tooltip,
        padding: EdgeInsets.all(isCollapsed ? 4 : 8),
        constraints: isCollapsed ? const BoxConstraints(minHeight: 36, minWidth: 36) : null,
        visualDensity: isCollapsed ? VisualDensity.compact : VisualDensity.standard,
      );
    }

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppTheme.border),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SystemHealthRing(),
          SizedBox(height: isCollapsed ? 8 : 12),
          if (isCollapsed)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                footerButton(
                  icon: Icons.search,
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => _CommandPalette(),
                    );
                  },
                  tooltip: 'Command Palette (⌘K)',
                ),
                const SizedBox(height: 8),
                footerButton(
                  icon: Icons.chevron_right,
                  onPressed: () => appState.toggleSidebar(),
                  tooltip: 'Open sidebar (⌘B)',
                ),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                footerButton(
                  icon: Icons.search,
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => _CommandPalette(),
                    );
                  },
                  tooltip: 'Command Palette (⌘K)',
                ),
                footerButton(
                  icon: Icons.chevron_left,
                  onPressed: () => appState.toggleSidebar(),
                  tooltip: 'Close sidebar (⌘B)',
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _CommandPalette extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.cardBackground,
      child: Container(
        width: 600,
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(
                hintText: 'Type a command or search...',
                prefixIcon: Icon(Icons.search, color: AppTheme.primaryGreen),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppTheme.border),
                ),
              ),
              autofocus: true,
            ),
            SizedBox(height: 16),
            ...['Overview', 'Irrigation', 'Soil', 'Greenhouse'].map((page) {
              return ListTile(
                leading: Icon(Icons.navigate_next, color: AppTheme.primaryGreen),
                title: Text('Go to $page'),
                onTap: () {
                  context.read<AppState>().setCurrentPage(page);
                  Navigator.pop(context);
                },
              );
            }),
          ],
        ),
      ),
    );
  }
}
