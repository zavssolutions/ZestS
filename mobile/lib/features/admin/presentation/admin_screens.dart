import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/api_client.dart";

// ── Providers ──────────────────────────────────────────────────────

final adminStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final dio = ref.read(dioProvider);
  final resp = await dio.get("/admin/stats");
  return resp.data as Map<String, dynamic>;
});

final adminEventsProvider = FutureProvider<List<dynamic>>((ref) async {
  final dio = ref.read(dioProvider);
  final resp = await dio.get("/admin/events");
  return resp.data as List<dynamic>;
});

final adminUsersProvider = FutureProvider.family<List<dynamic>, String?>((ref, search) async {
  final dio = ref.read(dioProvider);
  final query = search != null && search.isNotEmpty ? "?search=$search" : "";
  final resp = await dio.get("/admin/users$query");
  return resp.data as List<dynamic>;
});

final adminBannersProvider = FutureProvider<List<dynamic>>((ref) async {
  final dio = ref.read(dioProvider);
  final resp = await dio.get("/admin/banners");
  return resp.data as List<dynamic>;
});

final adminSponsorsProvider = FutureProvider<List<dynamic>>((ref) async {
  final dio = ref.read(dioProvider);
  final resp = await dio.get("/admin/sponsors");
  return resp.data as List<dynamic>;
});

final adminIssuesProvider = FutureProvider<List<dynamic>>((ref) async {
  final dio = ref.read(dioProvider);
  final resp = await dio.get("/admin/support-issues");
  return resp.data as List<dynamic>;
});

final adminLogsProvider = FutureProvider<List<dynamic>>((ref) async {
  final dio = ref.read(dioProvider);
  final resp = await dio.get("/admin/logs?limit=100");
  return resp.data as List<dynamic>;
});

final adminEventResultsProvider = FutureProvider.family<List<dynamic>, String?>((ref, eventId) async {
  final dio = ref.read(dioProvider);
  final query = eventId != null ? "?event_id=$eventId" : "";
  final resp = await dio.get("/admin/event-results$query");
  return resp.data as List<dynamic>;
});

// ── Admin Dashboard ────────────────────────────────────────────────

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminStatsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("Admin Dashboard")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          statsAsync.when(
            data: (stats) {
              final trend = stats["trend"] as Map<String, dynamic>? ?? {};
              return Column(
                children: [
                  Row(children: [
                    _statCard("Total Users", "${stats["total_users"]}", trend["users_delta"]),
                    _statCard("Active Today", "${stats["active_users_today"]}", null),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    _statCard("Total Events", "${stats["total_events"]}", trend["events_delta"]),
                    _statCard("Regs Today", "${stats["registrations_today"]}", trend["registrations_delta"]),
                  ]),
                ],
              );
            },
            error: (e, _) => Center(child: Text("Error: $e")),
            loading: () => const Center(child: CircularProgressIndicator()),
          ),
          const SizedBox(height: 16),
          _navTile(context, Icons.event, "Events", "/admin/events"),
          _navTile(context, Icons.people, "Users", "/admin/users"),
          _navTile(context, Icons.image, "Banners", "/admin/banners"),
          _navTile(context, Icons.star, "Sponsors", "/admin/sponsors"),
          _navTile(context, Icons.emoji_events, "Event Results", "/admin/results"),
          _navTile(context, Icons.support_agent, "User Issues", "/admin/issues"),
          _navTile(context, Icons.receipt_long, "Logs", "/admin/logs"),
          _navTile(context, Icons.article, "Misc (Pages)", "/admin/misc"),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, dynamic delta) {
    final trendText = delta != null ? (delta > 0 ? "+$delta" : "$delta") : "";
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              if (trendText.isNotEmpty)
                Text(trendText, style: TextStyle(
                  fontSize: 12,
                  color: delta > 0 ? Colors.green : Colors.red,
                )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navTile(BuildContext context, IconData icon, String label, String route) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => _screenForRoute(route)),
        ),
      ),
    );
  }

  Widget _screenForRoute(String route) {
    switch (route) {
      case "/admin/events":
        return const AdminEventsScreen();
      case "/admin/users":
        return const AdminUsersScreen();
      case "/admin/banners":
        return const AdminBannersScreen();
      case "/admin/sponsors":
        return const AdminSponsorsScreen();
      case "/admin/results":
        return const AdminResultsScreen();
      case "/admin/issues":
        return const AdminIssuesScreen();
      case "/admin/logs":
        return const AdminLogsScreen();
      case "/admin/misc":
        return const AdminMiscScreen();
      default:
        return const Scaffold(body: Center(child: Text("Unknown")));
    }
  }
}

// ── Admin Events Screen ────────────────────────────────────────────

class AdminEventsScreen extends ConsumerWidget {
  const AdminEventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(adminEventsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("Events Management")),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateEventDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: eventsAsync.when(
        data: (events) => ListView.builder(
          itemCount: events.length,
          itemBuilder: (context, index) {
            final e = events[index] as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: ListTile(
                title: Text(e["title"] ?? ""),
                subtitle: Text("Status: ${e["status"]} · ${e["venue_city"] ?? ""}"),
                trailing: PopupMenuButton<String>(
                  onSelected: (action) => _handleEventAction(context, ref, e, action),
                  itemBuilder: (_) => [
                    if (e["status"] == "draft")
                      const PopupMenuItem(value: "publish", child: Text("Publish")),
                    const PopupMenuItem(value: "cancel", child: Text("Cancel Event")),
                    const PopupMenuItem(value: "delete", child: Text("Delete")),
                  ],
                ),
              ),
            );
          },
        ),
        error: (e, _) => Center(child: Text("Error: $e")),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  void _handleEventAction(BuildContext context, WidgetRef ref, Map<String, dynamic> event, String action) async {
    final dio = ref.read(dioProvider);
    try {
      if (action == "publish") {
        await dio.put("/admin/events/${event["id"]}", data: {"status": "published"});
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Event published. Notifications sent.")));
      } else if (action == "cancel") {
        await dio.put("/admin/events/${event["id"]}", data: {"status": "canceled"});
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Event cancelled. Notifications sent.")));
      } else if (action == "delete") {
        await dio.delete("/admin/events/${event["id"]}");
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Event deleted")));
      }
      ref.invalidate(adminEventsProvider);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  void _showCreateEventDialog(BuildContext context, WidgetRef ref) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    final cityCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Create Event"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: "Title")),
              TextField(controller: descCtrl, decoration: const InputDecoration(labelText: "Description"), maxLines: 3),
              TextField(controller: locationCtrl, decoration: const InputDecoration(labelText: "Location name")),
              TextField(controller: cityCtrl, decoration: const InputDecoration(labelText: "City")),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          FilledButton(
            onPressed: () async {
              final now = DateTime.now().toUtc();
              try {
                await ref.read(dioProvider).post("/events", data: {
                  "title": titleCtrl.text,
                  "description": descCtrl.text,
                  "location_name": locationCtrl.text,
                  "venue_city": cityCtrl.text,
                  "start_at_utc": now.add(const Duration(days: 30)).toIso8601String(),
                  "end_at_utc": now.add(const Duration(days: 31)).toIso8601String(),
                });
                ref.invalidate(adminEventsProvider);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
              } catch (e) {
                if (!ctx.mounted) return;
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text("Error: $e")));
              }
            },
            child: const Text("Save (Draft)"),
          ),
        ],
      ),
    );
  }
}

// ── Admin Users Screen ─────────────────────────────────────────────

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  String _search = "";

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(adminUsersProvider(_search.isEmpty ? null : _search));

    return Scaffold(
      appBar: AppBar(title: const Text("Users Management")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(labelText: "Search users", prefixIcon: Icon(Icons.search)),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          Expanded(
            child: usersAsync.when(
              data: (users) => ListView.builder(
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final u = users[index] as Map<String, dynamic>;
                  return ListTile(
                    leading: CircleAvatar(child: Text("${u["first_name"]?[0] ?? "?"}")),
                    title: Text("${u["first_name"] ?? ""} ${u["last_name"] ?? ""}"),
                    subtitle: Text("${u["role"]} · ${u["email"] ?? u["mobile_no"] ?? ""}"),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () async {
                        await ref.read(dioProvider).delete("/admin/users/${u["id"]}");
                        ref.invalidate(adminUsersProvider(_search.isEmpty ? null : _search));
                      },
                    ),
                  );
                },
              ),
              error: (e, _) => Center(child: Text("Error: $e")),
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Admin Banners Screen ───────────────────────────────────────────

class AdminBannersScreen extends ConsumerWidget {
  const AdminBannersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bannersAsync = ref.watch(adminBannersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("Banners Management")),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateBannerDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: bannersAsync.when(
        data: (banners) => ListView.builder(
          itemCount: banners.length,
          itemBuilder: (context, index) {
            final b = banners[index] as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: ListTile(
                title: Text(b["title"] ?? "Banner"),
                subtitle: Text("Placement: ${b["placement"]} · Active: ${b["is_active"]}"),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () async {
                    await ref.read(dioProvider).delete("/admin/banners/${b["id"]}");
                    ref.invalidate(adminBannersProvider);
                  },
                ),
              ),
            );
          },
        ),
        error: (e, _) => Center(child: Text("Error: $e")),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  void _showCreateBannerDialog(BuildContext context, WidgetRef ref) {
    final titleCtrl = TextEditingController();
    final imageCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Create Banner"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: "Title")),
            TextField(controller: imageCtrl, decoration: const InputDecoration(labelText: "Image URL")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          FilledButton(
            onPressed: () async {
              await ref.read(dioProvider).post("/admin/banners", data: {
                "title": titleCtrl.text,
                "image_url": imageCtrl.text,
                "placement": "home_top",
              });
              ref.invalidate(adminBannersProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }
}

// ── Admin Sponsors Screen ──────────────────────────────────────────

class AdminSponsorsScreen extends ConsumerWidget {
  const AdminSponsorsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sponsorsAsync = ref.watch(adminSponsorsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("Sponsors Management")),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateSponsorDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: sponsorsAsync.when(
        data: (sponsors) => ListView.builder(
          itemCount: sponsors.length,
          itemBuilder: (context, index) {
            final s = sponsors[index] as Map<String, dynamic>;
            return ListTile(
              title: Text(s["name"] ?? ""),
              subtitle: Text(s["website_url"] ?? ""),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () async {
                  await ref.read(dioProvider).delete("/admin/sponsors/${s["id"]}");
                  ref.invalidate(adminSponsorsProvider);
                },
              ),
            );
          },
        ),
        error: (e, _) => Center(child: Text("Error: $e")),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  void _showCreateSponsorDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final logoCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add Sponsor"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Name")),
            TextField(controller: logoCtrl, decoration: const InputDecoration(labelText: "Logo URL")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          FilledButton(
            onPressed: () async {
              await ref.read(dioProvider).post("/admin/sponsors", data: {
                "name": nameCtrl.text,
                "logo_url": logoCtrl.text,
              });
              ref.invalidate(adminSponsorsProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }
}

// ── Admin Results Screen ───────────────────────────────────────────

class AdminResultsScreen extends ConsumerWidget {
  const AdminResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(adminEventResultsProvider(null));

    return Scaffold(
      appBar: AppBar(title: const Text("Event Results")),
      body: resultsAsync.when(
        data: (results) {
          if (results.isEmpty) return const Center(child: Text("No results yet"));
          return ListView.builder(
            itemCount: results.length,
            itemBuilder: (context, index) {
              final r = results[index] as Map<String, dynamic>;
              return ListTile(
                leading: CircleAvatar(child: Text("#${r["rank"] ?? "-"}")),
                title: Text("User: ${r["user_id"]?.toString().substring(0, 8) ?? ""}..."),
                subtitle: Text("Points: ${r["points_earned"]} · Time: ${r["timing_ms"]}ms"),
              );
            },
          );
        },
        error: (e, _) => Center(child: Text("Error: $e")),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

// ── Admin Issues Screen ────────────────────────────────────────────

class AdminIssuesScreen extends ConsumerWidget {
  const AdminIssuesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final issuesAsync = ref.watch(adminIssuesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("User Issues")),
      body: issuesAsync.when(
        data: (issues) {
          if (issues.isEmpty) return const Center(child: Text("No issues"));
          return ListView.builder(
            itemCount: issues.length,
            itemBuilder: (context, index) {
              final i = issues[index] as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: ListTile(
                  title: Text(i["message"] ?? ""),
                  subtitle: Text("Status: ${i["status"]} · ${i["email"] ?? ""}"),
                  trailing: i["status"] == "open"
                      ? TextButton(
                          onPressed: () async {
                            await ref.read(dioProvider).put("/admin/support-issues/${i["id"]}", data: {"status": "resolved"});
                            ref.invalidate(adminIssuesProvider);
                          },
                          child: const Text("Resolve"),
                        )
                      : const Text("✅"),
                ),
              );
            },
          );
        },
        error: (e, _) => Center(child: Text("Error: $e")),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

// ── Admin Logs Screen ──────────────────────────────────────────────

class AdminLogsScreen extends ConsumerWidget {
  const AdminLogsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(adminLogsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("Audit Logs")),
      body: logsAsync.when(
        data: (logs) {
          if (logs.isEmpty) return const Center(child: Text("No logs"));
          return ListView.builder(
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final l = logs[index] as Map<String, dynamic>;
              return ListTile(
                dense: true,
                leading: Icon(
                  l["level"] == "ERROR" ? Icons.error : Icons.info_outline,
                  color: l["level"] == "ERROR" ? Colors.red : Colors.grey,
                  size: 18,
                ),
                title: Text("${l["action"]} · ${l["entity_type"]}", style: const TextStyle(fontSize: 13)),
                subtitle: Text("${l["created_at"]}", style: const TextStyle(fontSize: 11)),
              );
            },
          );
        },
        error: (e, _) => Center(child: Text("Error: $e")),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

// ── Admin Misc Screen (Static Pages) ───────────────────────────────

class AdminMiscScreen extends ConsumerWidget {
  const AdminMiscScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pages = ["about-us", "terms-and-conditions", "privacy-policy", "faqs"];
    final labels = ["About Us", "Terms & Conditions", "Privacy Policy", "FAQs"];

    return Scaffold(
      appBar: AppBar(title: const Text("Static Pages")),
      body: ListView.builder(
        itemCount: pages.length,
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: ListTile(
              title: Text(labels[index]),
              trailing: const Icon(Icons.edit),
              onTap: () => _showEditPageDialog(context, ref, pages[index], labels[index]),
            ),
          );
        },
      ),
    );
  }

  void _showEditPageDialog(BuildContext context, WidgetRef ref, String slug, String title) async {
    final dio = ref.read(dioProvider);
    String currentContent = "";
    try {
      final resp = await dio.get("/pages/$slug");
      currentContent = resp.data["content"] ?? "";
    } catch (_) {
      // page may not exist
    }
    final ctrl = TextEditingController(text: currentContent);

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Edit $title"),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: ctrl,
            maxLines: 12,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          FilledButton(
            onPressed: () async {
              try {
                await dio.put("/admin/pages/$slug", data: {"content": ctrl.text});
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$title updated")));
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }
}
