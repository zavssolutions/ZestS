import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:image_picker/image_picker.dart";
import "package:dio/dio.dart";
import "package:go_router/go_router.dart";
import "admin_debug_screen.dart";

import "../../../core/api_client.dart";
import "../../events/data/events_repository.dart";
import "event_form_dialog.dart";
import "../../events/data/event_model.dart";

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
          _navTile(context, Icons.bug_report, "Debug: DB Dump", "/admin/debug"),
          _navTile(context, Icons.article, "Misc (Pages)", "/admin/misc"),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () async {
              try {
                final resp = await ref.read(dioProvider).post("/notifications/test");
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Test sent to ${resp.data["devices_notified"]} devices")),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                }
              }
            },
            icon: const Icon(Icons.notification_add),
            label: const Text("Send Test Notification to All"),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _populateE2EData(context, ref),
            icon: const Icon(Icons.data_thresholding),
            label: const Text("Populate E2E Demo Data (100+ simulated users)"),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.orange),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _clearDatabaseRecords(context, ref),
            icon: const Icon(Icons.delete_forever),
            label: const Text("Clear All Database Records"),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );
  }

  Future<void> _populateE2EData(BuildContext context, WidgetRef ref) async {
    final dio = ref.read(dioProvider);
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      await dio.post("/admin/debug/seed");

      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Successfully generated Massive E2E Simulation Data!")),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        String message = e.toString();
        if (e is DioException && e.response?.data != null) {
          final data = e.response!.data;
          if (data is Map && data.containsKey("detail")) {
            message = data["detail"].toString();
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $message")));
      }
    }
  }

  Future<void> _clearDatabaseRecords(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Clear All Data?"),
        content: const Text("This will brutally wipe ALL users, events, and results from the database. Are you absolutely sure?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Destructive Delete"),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final dio = ref.read(dioProvider);
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      await dio.post("/admin/debug/clear");

      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Database has been completely cleared of dynamic data.")),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        String message = e.toString();
        if (e is DioException && e.response?.data != null) {
          final data = e.response!.data;
          if (data is Map && data.containsKey("detail")) {
            message = data["detail"].toString();
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error clearing data: $message")));
      }
    }
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
      case "/admin/debug":
        return const AdminDebugScreen();
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
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(adminEventsProvider),
        child: eventsAsync.when(
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
                    itemBuilder: (_) {
                      final status = e["status"]?.toString().toLowerCase();
                      final isCanceled = status == "canceled";
                      return [
                        const PopupMenuItem(value: "manage_categories", child: Text("Manage Categories")),
                        const PopupMenuItem(value: "edit", child: Text("Edit Event")),
                        if (status == "draft") const PopupMenuItem(value: "publish", child: Text("Publish")),
                        if (!isCanceled) const PopupMenuItem(value: "cancel", child: Text("Cancel Event")),
                        if (!isCanceled) const PopupMenuItem(value: "delete", child: Text("Delete")),
                      ];
                    },
                  ),
                ),
              );
            },
          ),
          error: (e, _) => ListView(children: [Center(child: Padding(padding: const EdgeInsets.all(20), child: Text("Error: $e")))]),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
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
        // Add confirmation
        if (!context.mounted) return;
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Cancel Event?"),
            content: const Text("This will notify all registered users. This action cannot be undone."),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("No")),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Yes, Cancel")),
            ],
          ),
        );
        if (confirm != true) return;

        await dio.put("/admin/events/${event["id"]}", data: {"status": "canceled"});
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Event cancelled. Notifications sent.")));
      } else if (action == "delete") {
        // Add confirmation for delete too
        if (!context.mounted) return;
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Delete Event?"),
            content: const Text("Are you sure you want to permanently delete this event?"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                child: const Text("Delete"),
              ),
            ],
          ),
        );
        if (confirm != true) return;

        await dio.delete("/admin/events/${event["id"]}");
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Event deleted")));
      } else if (action == "manage_categories") {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AdminEventCategoriesScreen(
              eventId: event["id"],
              eventTitle: event["title"],
            ),
          ),
        );
        return;
      } else if (action == "edit") {
        final ev = EventModel.fromJson(event);
        showEventFormDialog(context, ref, event: ev, onSuccess: () => ref.invalidate(adminEventsProvider));
        return;
      }
      ref.invalidate(adminEventsProvider);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  void _showCreateEventDialog(BuildContext context, WidgetRef ref) {
    showEventFormDialog(context, ref, onSuccess: () => ref.invalidate(adminEventsProvider));
  }
}

// ── Admin Event Categories Screen ──────────────────────────────────

class AdminEventCategoriesScreen extends ConsumerWidget {
  const AdminEventCategoriesScreen({
    required this.eventId,
    required this.eventTitle,
    super.key,
  });

  final String eventId;
  final String eventTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(eventCategoriesProvider(eventId));

    return Scaffold(
      appBar: AppBar(title: Text("Categories: $eventTitle")),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddCategoryDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: categoriesAsync.when(
        data: (categories) => ListView.builder(
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final c = categories[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: ListTile(
                title: Text(c.name),
                subtitle: Text("Price: ₹${c.price}"),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () => _showAddCategoryDialog(context, ref, category: c),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                      onPressed: () => _deleteCategory(context, ref, c.id),
                    ),
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

  void _showAddCategoryDialog(BuildContext context, WidgetRef ref, {EventCategoryModel? category}) {
    final isEdit = category != null;
    final nameCtrl = TextEditingController(text: category?.name);
    final priceCtrl = TextEditingController(text: category?.price.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add Category"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Category Name")),
            TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: "Price"), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          FilledButton(
            onPressed: () async {
              try {
                final data = {
                  "name": nameCtrl.text,
                  "price": double.tryParse(priceCtrl.text) ?? 0,
                };
                if (isEdit) {
                  await ref.read(dioProvider).put("/events/$eventId/categories/${category.id}", data: data);
                } else {
                  await ref.read(dioProvider).post("/events/$eventId/categories", data: data);
                }
                ref.invalidate(eventCategoriesProvider(eventId));
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
              } catch (e) {
                if (!ctx.mounted) return;
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text("Error: $e")));
              }
            },
            child: Text(isEdit ? "Update" : "Add"),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCategory(BuildContext context, WidgetRef ref, String categoryId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Category?"),
        content: const Text("Are you sure? This cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await ref.read(dioProvider).delete("/events/$eventId/categories/$categoryId");
      ref.invalidate(eventCategoriesProvider(eventId));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Delete failed: $e")));
    }
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
      appBar: AppBar(
        title: const Text("Users Management"),
        actions: [
          usersAsync.when(
            data: (users) => Center(child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text("Total: ${users.length}", style: const TextStyle(fontWeight: FontWeight.bold)),
            )),
            error: (_, __) => const SizedBox(),
            loading: () => const SizedBox(),
          ),
        ],
      ),
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
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(adminUsersProvider(_search.isEmpty ? null : _search)),
              child: usersAsync.when(
                data: (users) => ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final u = users[index] as Map<String, dynamic>;
                    final isKid = u["parent_id"] != null;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isKid ? Colors.orange.shade100 : Colors.blue.shade100,
                        child: Text("${u["first_name"]?[0] ?? "?"}"),
                      ),
                      title: Text("${u["first_name"] ?? "No Name"} ${u["last_name"] ?? ""}"),
                      subtitle: Text("${u["role"]}${isKid ? " (Kid)" : ""} · ${u["email"] ?? u["mobile_no"] ?? "No contact"}"),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            onPressed: () => _showEditUserDialog(context, ref, u),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text("Delete User?"),
                                  content: const Text("This will remove all associated data. Continue?"),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("No")),
                                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Yes, Delete")),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await ref.read(dioProvider).delete("/admin/users/${u["id"]}");
                                ref.invalidate(adminUsersProvider(_search.isEmpty ? null : _search));
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
                error: (e, _) => ListView(children: [Center(child: Padding(padding: const EdgeInsets.all(20), child: Text("Error: $e")))]),
                loading: () => const Center(child: CircularProgressIndicator()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditUserDialog(BuildContext context, WidgetRef ref, Map<String, dynamic> user) {
    String selectedRole = user["role"] ?? "parent";
    final roles = ["parent", "organizer", "admin", "trainer", "skater", "kid"];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text("Edit User Role"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("User: ${user["first_name"]} ${user["last_name"] ?? ""}"),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedRole,
                items: roles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: (v) => setDialogState(() => selectedRole = v!),
                decoration: const InputDecoration(labelText: "Role"),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            FilledButton(
              onPressed: () async {
                try {
                  await ref.read(dioProvider).put("/admin/users/${user["id"]}", data: {"role": selectedRole});
                  ref.invalidate(adminUsersProvider(_search.isEmpty ? null : _search));
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text("Error: $e")));
                }
              },
              child: const Text("Update"),
            ),
          ],
        ),
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
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(adminBannersProvider),
        child: bannersAsync.when(
          data: (banners) => ListView.builder(
            itemCount: banners.length,
            itemBuilder: (context, index) {
              final b = banners[index] as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: ListTile(
                  title: Text(b["title"] ?? "Banner"),
                  subtitle: Text("Placement: ${b["placement"]} · Active: ${b["is_active"]}"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () => _showBannerDialog(context, ref, banner: b),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                        onPressed: () async {
                          await ref.read(dioProvider).delete("/admin/banners/${b["id"]}");
                          ref.invalidate(adminBannersProvider);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          error: (e, _) => ListView(children: [Center(child: Padding(padding: const EdgeInsets.all(20), child: Text("Error: $e")))]),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }

  void _showCreateBannerDialog(BuildContext context, WidgetRef ref) {
    _showBannerDialog(context, ref);
  }

  void _showBannerDialog(BuildContext context, WidgetRef ref, {Map<String, dynamic>? banner}) {
    final isEdit = banner != null;
    final titleCtrl = TextEditingController(text: banner?["title"]);
    String? bannerUrl = banner?["image_url"];
    bool uploading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text("Create Banner"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: "Title")),
              const SizedBox(height: 12),
              if (bannerUrl != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(bannerUrl!, height: 120, width: double.infinity, fit: BoxFit.cover),
                ),
                const SizedBox(height: 8),
              ],
              OutlinedButton.icon(
                onPressed: uploading
                    ? null
                    : () async {
                        final picker = ImagePicker();
                        final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                        if (image == null) return;
                        setDialogState(() => uploading = true);
                        try {
                          final formData = FormData.fromMap({
                            "file": await MultipartFile.fromFile(image.path, filename: image.name),
                          });
                          final resp = await ref.read(dioProvider).post("/uploads/image", data: formData);
                          setDialogState(() {
                            bannerUrl = resp.data["url"];
                            uploading = false;
                          });
                        } catch (e) {
                          setDialogState(() => uploading = false);
                          if (!ctx.mounted) return;
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text("Upload failed: $e")));
                        }
                      },
                icon: uploading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.image),
                label: Text(uploading ? "Uploading..." : (bannerUrl != null ? "Change Image" : "Pick Banner Image")),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            FilledButton(
              onPressed: () async {
                try {
                  final data = {
                    "title": titleCtrl.text,
                    "image_url": bannerUrl ?? "",
                    "placement": banner?["placement"] ?? "home_top",
                    "is_active": banner?["is_active"] ?? true,
                  };
                  if (isEdit) {
                    await ref.read(dioProvider).put("/admin/banners/${banner["id"]}", data: data);
                  } else {
                    await ref.read(dioProvider).post("/admin/banners", data: data);
                  }
                  ref.invalidate(adminBannersProvider);
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text("Error: $e")));
                }
              },
              child: Text(isEdit ? "Update" : "Save"),
            ),
          ],
        ),
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
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: () => _showSponsorDialog(context, ref, sponsor: s),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () async {
                      await ref.read(dioProvider).delete("/admin/sponsors/${s["id"]}");
                      ref.invalidate(adminSponsorsProvider);
                    },
                  ),
                ],
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
    _showSponsorDialog(context, ref);
  }

  void _showSponsorDialog(BuildContext context, WidgetRef ref, {Map<String, dynamic>? sponsor}) {
    final isEdit = sponsor != null;
    final nameCtrl = TextEditingController(text: sponsor?["name"]);
    final logoCtrl = TextEditingController(text: sponsor?["logo_url"]);

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
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () => _showEditResultDialog(context, ref, r),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                      onPressed: () => _deleteResult(context, ref, r["id"]),
                    ),
                  ],
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

  void _showEditResultDialog(BuildContext context, WidgetRef ref, Map<String, dynamic> result) {
    final rankCtrl = TextEditingController(text: result["rank"]?.toString());
    final pointsCtrl = TextEditingController(text: result["points_earned"]?.toString());
    final timeCtrl = TextEditingController(text: result["timing_ms"]?.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Edit Result"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: rankCtrl, decoration: const InputDecoration(labelText: "Rank"), keyboardType: TextInputType.number),
            TextField(controller: pointsCtrl, decoration: const InputDecoration(labelText: "Points"), keyboardType: TextInputType.number),
            TextField(controller: timeCtrl, decoration: const InputDecoration(labelText: "Timing (ms)"), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          FilledButton(
            onPressed: () async {
              try {
                await ref.read(dioProvider).put("/admin/event-results/${result["id"]}", data: {
                  "rank": int.tryParse(rankCtrl.text),
                  "points_earned": int.tryParse(pointsCtrl.text),
                  "timing_ms": int.tryParse(timeCtrl.text),
                });
                ref.invalidate(adminEventResultsProvider(null));
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text("Error: $e")));
              }
            },
            child: const Text("Update"),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteResult(BuildContext context, WidgetRef ref, String resultId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Result?"),
        content: const Text("Are you sure? This result will be permanently removed."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await ref.read(dioProvider).delete("/admin/event-results/$resultId");
      ref.invalidate(adminEventResultsProvider(null));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Delete failed: $e")));
    }
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
