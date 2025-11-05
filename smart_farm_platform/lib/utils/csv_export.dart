import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';

/// Minimal CSV export helper used by pages. This fetches up to 200 history rows
/// per source for [group], aggregates them and shows the CSV in a dialog with
/// a copy-to-clipboard action.
Future<void> exportGroupToCsv(BuildContext context, String group, ApiService api) async {
  try {
    final all = await api.fetchAllGroupRaw(group);
    if (all == null || all.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No sources found for $group')));
      return;
    }

    final rows = <Map<String, dynamic>>[];
    for (final src in all.keys) {
      try {
        final hist = await api.fetchGroupHistory(group, src, limit: 200, offset: 0);
        if (hist != null) {
          for (final r in hist) {
            final copy = Map<String, dynamic>.from(r);
            copy['__source'] = src;
            rows.add(copy);
          }
        }
      } catch (_) {}
    }

    if (rows.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No history rows available for $group')));
      return;
    }

    // Build header as union of keys, place __source first if present
    final keys = <String>{};
    for (final r in rows) {
      keys.addAll(r.keys.map((k) => k.toString()));
    }
    final header = <String>[];
    if (keys.contains('__source')) header.add('__source');
    header.addAll(keys.where((k) => k != '__source'));

    String quote(String s) {
      final safe = s.replaceAll('"', '""');
      return '"$safe"';
    }

    final sb = StringBuffer();
    sb.writeln(header.map((h) => quote(h)).join(','));
    for (final r in rows) {
      final line = header.map((h) {
        final v = r[h];
        if (v == null) return quote('');
        return quote(v.toString());
      }).join(',');
      sb.writeln(line);
    }

    final csv = sb.toString();

    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('CSV export — $group'),
        content: SizedBox(width: 800, height: 400, child: SingleChildScrollView(child: SelectableText(csv))),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: csv));
              if (!context.mounted) return;
              Navigator.of(context).pop();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('CSV copied to clipboard')));
            },
            child: Text('Copy'),
          ),
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('Close')),
        ],
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
  }
}
