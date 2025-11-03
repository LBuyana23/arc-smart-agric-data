import 'package:flutter/material.dart';
import '../services/api_service.dart';

typedef HistoryBuilder = Widget Function(BuildContext context, List<Map<String, dynamic>> rows, int page, void Function(int delta) changePage);

typedef HistoryFetcher = Future<List<Map<String, dynamic>>?> Function(int offset, int limit);

class PaginatedHistory extends StatefulWidget {
  final String group;
  final String source;
  final int limit;
  final HistoryBuilder builder;
  final HistoryFetcher? fetcher;

  const PaginatedHistory({super.key, required this.group, required this.source, this.limit = 10, required this.builder, this.fetcher});

  @override
  State<PaginatedHistory> createState() => _PaginatedHistoryState();
}

class _PaginatedHistoryState extends State<PaginatedHistory> {
  final ApiService _api = ApiService();
  int _page = 0;
  late Future<List<Map<String, dynamic>>?> _futureRows;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final offset = _page * widget.limit;
    if (widget.fetcher != null) {
      _futureRows = widget.fetcher!(offset, widget.limit);
    } else {
      _futureRows = _api.fetchGroupHistory(widget.group, widget.source, limit: widget.limit, offset: offset);
    }
  }

  void _changePage(int delta) {
    setState(() {
      _page = (_page + delta).clamp(0, 1 << 30);
      _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>?>(
      future: _futureRows,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return SizedBox(height: 80, child: Center(child: CircularProgressIndicator()));
        final rows = snap.hasData && snap.data != null ? List<Map<String, dynamic>>.from(snap.data!) : <Map<String, dynamic>>[];
        final showPager = rows.isNotEmpty || _page > 0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            widget.builder(context, rows, _page, _changePage),
            if (showPager) ...[
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(onPressed: _page == 0 ? null : () => _changePage(-1), icon: Icon(Icons.chevron_left), label: Text('Prev')),
                  SizedBox(width: 8),
                  Text('Page ${_page + 1}', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color)),
                  SizedBox(width: 8),
                  TextButton.icon(onPressed: rows.length < widget.limit ? null : () => _changePage(1), icon: Icon(Icons.chevron_right), label: Text('Next')),
                ],
              )
            ]
          ],
        );
      },
    );
  }
}
