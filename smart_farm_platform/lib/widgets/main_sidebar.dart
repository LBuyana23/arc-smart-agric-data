import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
                _buildMenuItem(context, Icons.wb_sunny, 'Climate', isCollapsed),
                if (!isCollapsed) _buildSectionLabel('Platform'),
                _buildMenuItem(context, Icons.storage, 'Data Catalog', isCollapsed),
                _buildMenuItem(context, Icons.api, 'API & Integrations', isCollapsed),
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
                    'Data Platform',
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

    return Tooltip(
      message: isCollapsed ? label : '',
      child: InkWell(
        onTap: () => appState.setCurrentPage(label),
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryGreen.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isSelected
                ? Border.all(color: AppTheme.primaryGreen.withOpacity(0.3))
                : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? AppTheme.primaryGreen : AppTheme.mutedForeground,
                size: 20,
              ),
              if (!isCollapsed) ...[
                SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? AppTheme.primaryGreen : AppTheme.foreground,
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context, bool isCollapsed) {
    final appState = context.watch<AppState>();

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppTheme.border),
        ),
      ),
      child: Column(
        children: [
          SystemHealthRing(),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: Icon(Icons.search, size: 20),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => _CommandPalette(),
                  );
                },
                tooltip: 'Command Palette (⌘K)',
              ),
              if (!isCollapsed)
                IconButton(
                  icon: Icon(
                    isCollapsed ? Icons.chevron_right : Icons.chevron_left,
                    size: 20,
                  ),
                  onPressed: () => appState.toggleSidebar(),
                  tooltip: 'Toggle Sidebar (⌘B)',
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
            ...['Overview', 'Irrigation', 'Soil', 'Climate'].map((page) {
              return ListTile(
                leading: Icon(Icons.navigate_next, color: AppTheme.primaryGreen),
                title: Text('Go to $page'),
                onTap: () {
                  context.read<AppState>().setCurrentPage(page);
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}
