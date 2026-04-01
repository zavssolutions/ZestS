import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "dart:convert";
import "../../../core/api_client.dart";

final dbDumpProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final dio = ref.read(dioProvider);
  final resp = await dio.get("/admin/debug/db-dump");
  return resp.data as Map<String, dynamic>;
});

class AdminDebugScreen extends ConsumerWidget {
  const AdminDebugScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dumpAsync = ref.watch(dbDumpProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Database Debug Dump"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(dbDumpProvider),
          ),
        ],
      ),
      body: dumpAsync.when(
        data: (dump) {
          final tableNames = dump.keys.toList()..sort();
          if (tableNames.isEmpty) {
            return const Center(child: Text("No tables found."));
          }
          return ListView.builder(
            itemCount: tableNames.length,
            itemBuilder: (context, index) {
              final tableName = tableNames[index];
              final tableData = dump[tableName] as Map<String, dynamic>;
              final rows = tableData["rows"] as List<dynamic>? ?? [];
              final error = tableData["error"];

              return ExpansionTile(
                title: Text(tableName, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: error != null 
                  ? Text("Error: $error", style: const TextStyle(color: Colors.red, fontSize: 12))
                  : Text("${tableData["count"] ?? 0} rows found (first 50)", style: const TextStyle(fontSize: 12)),
                children: [
                   if (rows.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12.0),
                      color: Colors.grey.shade100,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SelectableText(
                          const JsonEncoder.withIndent('  ').convert(rows),
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                        ),
                      )
                    )
                  else if (error == null)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text("This table appears to be empty."),
                    ),
                ],
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text("Failed to fetch DB dump: $err", textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(dbDumpProvider),
                  child: const Text("Retry"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
