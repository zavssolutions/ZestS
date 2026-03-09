import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/api_client.dart";

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text("About Us")),
      body: FutureBuilder(
        future: ref.read(dioProvider).get<Map<String, dynamic>>("/pages/about-us"),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            if (snapshot.hasError) {
              return const Center(child: Text("Unable to load About Us"));
            }
            return const Center(child: CircularProgressIndicator());
          }
          final response = snapshot.data as Response<Map<String, dynamic>>;
          final data = response.data ?? {};
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text((data["content"] as String?) ?? ""),
          );
        },
      ),
    );
  }
}
