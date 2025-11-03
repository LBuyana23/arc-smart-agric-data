import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class DataCatalogPage extends StatefulWidget {
  const DataCatalogPage({super.key});

  @override
  State<DataCatalogPage> createState() => _DataCatalogPageState();
}

class _DataCatalogPageState extends State<DataCatalogPage> {
  // Catalog not implemented server-side yet. Show an informational placeholder
  final List<Map<String, String>> _rows = [];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Data Catalog', style: TextStyle(color: AppTheme.foreground, fontSize: 32, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text('Browse stored Oracle records and table metadata', style: TextStyle(color: AppTheme.mutedForeground)),
          SizedBox(height: 24),

          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Available Tables', style: TextStyle(color: AppTheme.foreground, fontSize: 18, fontWeight: FontWeight.w600)),
                  SizedBox(height: 12),
                  _rows.isEmpty
                      ? Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('No catalog available. Implement /catalog on the bridge to populate this list.', style: TextStyle(color: AppTheme.mutedForeground)),
                        )
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: [
                              DataColumn(label: Text('Table', style: TextStyle(color: AppTheme.foreground))),
                              DataColumn(label: Text('Rows', style: TextStyle(color: AppTheme.foreground))),
                              DataColumn(label: Text('Last Updated', style: TextStyle(color: AppTheme.foreground))),
                              DataColumn(label: Text('Actions', style: TextStyle(color: AppTheme.foreground))),
                            ],
                            rows: _rows.map((r) {
                              return DataRow(cells: [
                                DataCell(Text(r['table']!, style: TextStyle(color: AppTheme.foreground))),
                                DataCell(Text(r['rows']!, style: TextStyle(color: AppTheme.foreground))),
                                DataCell(Text(r['last']!, style: TextStyle(color: AppTheme.mutedForeground))),
                                DataCell(Row(children: [
                                  TextButton(onPressed: () {}, child: Text('View')),
                                  TextButton(onPressed: () {}, child: Text('Export')),
                                ])),
                              ]);
                            }).toList(),
                          ),
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
