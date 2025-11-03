import 'package:flutter/material.dart';
// Charting removed for irrigation page — charts are not needed; keep table-only UI
import '../theme/app_theme.dart';
// sensor_data model import unused by current UI
// irrigation_data model import removed (we read raw subgroup payloads directly)
import '../services/api_service.dart';
import '../widgets/no_data_placeholder.dart';
import '../utils/ui_helpers.dart';
import '../widgets/paginated_history.dart';

class IrrigationPage extends StatefulWidget {
  const IrrigationPage({super.key});

  @override
  State<IrrigationPage> createState() => _IrrigationPageState();
}

class _IrrigationPageState extends State<IrrigationPage> with AutomaticKeepAliveClientMixin {
  // _selectedTimeRange removed - time-series UI is not used currently
  // Representative-row helper removed; irrigation page now renders raw subgroup history directly.

  @override
  Widget build(BuildContext context) {
    super.build(context);
  final api = ApiService();
  final source = api.getSource('irrigation');

    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(
                        child: Text(
                          'Irrigation',
                          style: TextStyle(
                            color: AppTheme.foreground,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (source != null) ...[SizedBox(width: 8), Chip(label: Text(source, style: TextStyle(fontSize: 12)), backgroundColor: Colors.black12)]
                    ]),
                    Text(
                      'Water flow monitoring and analysis',
                      style: TextStyle(
                        color: AppTheme.mutedForeground,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('CSV export feature - Coming soon'),
                      backgroundColor: AppTheme.primaryGreen,
                    ),
                  );
                },
                icon: Icon(Icons.download),
                label: Text('Export CSV'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: AppTheme.darkBackground,
                ),
              ),
            ],
          ),
          SizedBox(height: 24),
          // Render a section per irrigation subgroup (charts + last 10 rows table)
          FutureBuilder<Map<String, dynamic>?>(
            future: api.fetchAllGroupRaw('irrigation'),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) return SizedBox(height: 80, child: Center(child: CircularProgressIndicator()));
              if (!snap.hasData || snap.data == null || (snap.data as Map).isEmpty) return NoDataPlaceholder(message: 'No irrigation sources found');
              final map = Map<String, dynamic>.from(snap.data as Map);

              return Column(
                children: map.entries.map((entry) {
                  final src = entry.key;

                  return Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(UiHelpers.groupLabel('Irrigation', src), style: TextStyle(color: AppTheme.foreground, fontSize: 18, fontWeight: FontWeight.w700)),
                        SizedBox(height: 8),
                        PaginatedHistory(
                          group: 'irrigation',
                          source: src,
                          limit: 10,
                          builder: (context, rows, page, changePage) {
                            if (rows.isEmpty) return Text('No history available');

                            // Sort rows newest-first by timestamp. Rows without timestamps are pushed to the end.
                            rows.sort((a, b) {
                              final ta = UiHelpers.parseTimestamp(a['CREATED_AT'] ?? a['Timestamp'] ?? a['timestamp'] ?? a['T']);
                              final tb = UiHelpers.parseTimestamp(b['CREATED_AT'] ?? b['Timestamp'] ?? b['timestamp'] ?? b['T']);
                              if (ta == null && tb == null) return 0;
                              if (ta == null) return 1; // a after b
                              if (tb == null) return -1; // a before b
                              // descending: newest first
                              return tb.compareTo(ta);
                            });

                            // rows is now newest-first; take the first 10 (latest) to display
                            final recent = rows.length > 10 ? rows.sublist(0, 10) : rows;

                            final cols = rows.first.keys.toList();
                            final isExpanded = false; // irrigation uses a fixed compact display here
                            final displayCols = UiHelpers.pickDefaultCols(cols, 'irrigation', hasImage: false, expanded: isExpanded);

                            // Ensure a total/volume flow column is present for user clarity.
                            // Accept common variants and insert after the flow rate column when possible.
                            final totalCandidates = ['TOTAL_VOLUME', 'total_volume', 'totalVolume', 'total_flow', 'totalFlow'];
                            String? totalKey;
                            for (final k in totalCandidates) {
                              if (cols.contains(k)) { totalKey = k; break; }
                            }
                            if (totalKey != null && !displayCols.contains(totalKey)) {
                              // try to insert after the flow rate column if present
                              final flowCandidates = ['FLOW_RATE_LMIN', 'flow_rate_Lmin', 'flow_rate_lmin', 'flowRateLmin', 'flow_rate', 'flowRate'];
                              int insertAt = displayCols.length;
                              for (final f in flowCandidates) {
                                final idx = displayCols.indexOf(f);
                                if (idx >= 0) { insertAt = idx + 1; break; }
                              }
                              if (insertAt > displayCols.length) insertAt = displayCols.length;
                              try {
                                displayCols.insert(insertAt, totalKey);
                              } catch (_) {
                                // fallback: append
                                displayCols.add(totalKey);
                              }
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Recent raw rows (last ${recent.length} rows — click to view details)', style: TextStyle(color: AppTheme.mutedForeground))),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    columns: displayCols.map((c) => DataColumn(label: Text(UiHelpers.friendlyName(c)))).toList(),
                                    rows: recent.map((r) => DataRow(cells: displayCols.map((c) => DataCell(SizedBox(width: 140, child: Text(UiHelpers.formatCell(r[c], c))))).toList(), onSelectChanged: (_) => _showSourceDetail(context, src, r))).toList(),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
          SizedBox(height: 24),
          // Raw data table is rendered inside the FutureBuilder above so it can include latest data
        ],
      ),
    );
  }

  // Charting helpers removed — irrigation page no longer contains charts.

  void _showSourceDetail(BuildContext context, String src, Map<String, dynamic> payload) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Source: $src'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: payload.entries.map((e) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [Text(e.key, style: TextStyle(fontWeight: FontWeight.w600)), SizedBox(width: 8), Expanded(child: Text(e.value?.toString() ?? ''))],
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('Close'))],
        );
      },
    );
  }

  // Legacy snapshot card and helpers removed — irrigation page now renders per-subgroup only
  
  @override
  bool get wantKeepAlive => true;
}
