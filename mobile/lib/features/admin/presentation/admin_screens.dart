import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:image_picker/image_picker.dart";
import "package:dio/dio.dart";
import "package:go_router/go_router.dart";
import "admin_debug_screen.dart";

import "../../../core/api_client.dart";
import "../../events/data/events_repository.dart";

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
    final latCtrl = TextEditingController();
    final lngCtrl = TextEditingController();
    final organizerCtrl = TextEditingController();
    final priceCtrl = TextEditingController(text: "0.0");
    DateTime startDate = DateTime.now().add(const Duration(days: 30));
    DateTime endDate = DateTime.now().add(const Duration(days: 31));

    String? bannerUrl;
    bool uploading = false;
    final categories = <Map<String, dynamic>>[
      {
        "name": "General",
        "price": 0.0,
        "category_type": "Road",
        "skate_type": "Inline",
        "distance": "500m",
        "age_group": "8-10",
      }
    ];

    final categoryTypes = ["Road", "Rink", "ICE", "Artistic"];
    final skateTypes = ["Inline", "Quad", "toy inline", "tenacity"];
    final distances = ["200m", "500m", "1000m"];
    final ageGroups = ["4-6", "6-8", "8-10", "10-12", "12-15", "above 15"];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text("Create Event"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: "Event Title")),
                TextField(controller: descCtrl, decoration: const InputDecoration(labelText: "Description"), maxLines: 2),
                
                const SizedBox(height: 12),
                const Text("Common Details", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.cyan)),
                TextField(controller: organizerCtrl, decoration: const InputDecoration(labelText: "Organizer Email")),
                TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: "Base Price (₹)"), keyboardType: TextInputType.number),
                
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text("Starts: ${startDate.toLocal().toString().split(' ')[0]}"),
                  trailing: const Icon(Icons.calendar_month),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: ctx,
                      initialDate: startDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      setDialogState(() {
                        startDate = date;
                        if (endDate.isBefore(startDate)) {
                          endDate = startDate.add(const Duration(hours: 2));
                        }
                      });
                    }
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text("Ends: ${endDate.toLocal().toString().split(' ')[0]}"),
                  trailing: const Icon(Icons.calendar_month),
                  onTap: () async {
                    // Fix: Reset endDate to startDate if it's before to avoid crash
                    DateTime pickerInitialDate = endDate.isBefore(startDate) ? startDate : endDate;
                    final date = await showDatePicker(
                      context: ctx,
                      initialDate: pickerInitialDate,
                      firstDate: startDate,
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) setDialogState(() => endDate = date);
                  },
                ),

                const SizedBox(height: 12),
                TextField(controller: locationCtrl, decoration: const InputDecoration(labelText: "Location/Venue Name")),
                TextField(controller: cityCtrl, decoration: const InputDecoration(labelText: "City")),
                
                const SizedBox(height: 12),
                // ── Banner Image Picker ──
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
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: TextField(controller: latCtrl, decoration: const InputDecoration(labelText: "Lat"), keyboardType: TextInputType.number)),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: lngCtrl, decoration: const InputDecoration(labelText: "Lng"), keyboardType: TextInputType.number)),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Event Categories", style: TextStyle(fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, color: Colors.cyan),
                      onPressed: () {
                        setDialogState(() {
                          categories.add({
                            "name": "", 
                            "price": double.tryParse(priceCtrl.text) ?? 0.0,
                            "category_type": "Road",
                            "skate_type": "Inline",
                            "distance": "500m",
                            "age_group": "8-10",
                          });
                        });
                      },
                    ),
                  ],
                ),
                ...categories.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final cat = entry.value;
                  return Card(
                    margin: const EdgeInsets.only(top: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  decoration: const InputDecoration(labelText: "Category Name (e.g. Speed 500m)"),
                                  onChanged: (v) => cat["name"] = v,
                                  controller: TextEditingController(text: cat["name"])..selection = TextSelection.collapsed(offset: cat["name"].length),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                onPressed: () {
                                  setDialogState(() {
                                    categories.removeAt(idx);
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: cat["category_type"],
                                  items: categoryTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12)))).toList(),
                                  onChanged: (v) => setDialogState(() => cat["category_type"] = v),
                                  decoration: const InputDecoration(labelText: "Cat Type"),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: cat["skate_type"],
                                  items: skateTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12)))).toList(),
                                  onChanged: (v) => setDialogState(() => cat["skate_type"] = v),
                                  decoration: const InputDecoration(labelText: "Skate"),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: cat["distance"],
                                  items: distances.map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 12)))).toList(),
                                  onChanged: (v) => setDialogState(() => cat["distance"] = v),
                                  decoration: const InputDecoration(labelText: "Distance"),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: cat["age_group"],
                                  items: ageGroups.map((g) => DropdownMenuItem(value: g, child: Text(g, style: const TextStyle(fontSize: 12)))).toList(),
                                  onChanged: (v) => setDialogState(() => cat["age_group"] = v),
                                  decoration: const InputDecoration(labelText: "Age"),
                                ),
                              ),
                            ],
                          ),
                          TextField(
                            decoration: const InputDecoration(labelText: "Price for this Category (₹)"),
                            keyboardType: TextInputType.number,
                            onChanged: (v) => cat["price"] = double.tryParse(v) ?? 0.0,
                            controller: TextEditingController(text: cat["price"].toString())..selection = TextSelection.collapsed(offset: cat["price"].toString().length),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            FilledButton(
              onPressed: () async {
                try {
                  await ref.read(dioProvider).post("/events", data: {
                    "title": titleCtrl.text,
                    "description": descCtrl.text,
                    "organizer_email": organizerCtrl.text,
                    "price": double.tryParse(priceCtrl.text) ?? 0.0,
                    "location_name": locationCtrl.text,
                    "venue_city": cityCtrl.text,
                    "banner_image_url": bannerUrl,
                    "latitude": double.tryParse(latCtrl.text),
                    "longitude": double.tryParse(lngCtrl.text),
                    "start_at_utc": startDate.toUtc().toIso8601String(),
                    "end_at_utc": endDate.toUtc().toIso8601String(),
                    "categories": categories.where((c) => (c["name"] as String).isNotEmpty).toList(),
                  });
                  ref.invalidate(adminEventsProvider);
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                } catch (e) {
                  if (ctx.mounted) {
                    String msg = e.toString();
                    if (e is DioException && e.response?.data != null) {
                      msg = "Validation Error: ${e.response?.data}";
                    }
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                      content: Text("Failed to create event: $msg"),
                      duration: const Duration(seconds: 10),
                    ));
                  }
                }
              },
              child: const Text("Create Event (Draft)"),
            ),
          ],
        ),
      ),
    );
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
              ),
            );
          },
        ),
        error: (e, _) => Center(child: Text("Error: $e")),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();

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
                await ref.read(dioProvider).post("/events/$eventId/categories", data: {
                  "name": nameCtrl.text,
                  "price": double.tryParse(priceCtrl.text) ?? 0,
                });
                ref.invalidate(eventCategoriesProvider(eventId));
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
              } catch (e) {
                if (!ctx.mounted) return;
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text("Error: $e")));
              }
            },
            child: const Text("Add"),
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
                      trailing: IconButton(
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
          error: (e, _) => ListView(children: [Center(child: Padding(padding: const EdgeInsets.all(20), child: Text("Error: $e")))]),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }

  void _showCreateBannerDialog(BuildContext context, WidgetRef ref) {
    final titleCtrl = TextEditingController();
    String? bannerUrl;
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
                  await ref.read(dioProvider).post("/admin/banners", data: {
                    "title": titleCtrl.text,
                    "image_url": bannerUrl ?? "",
                    "placement": "home_top",
                  });
                  ref.invalidate(adminBannersProvider);
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text("Error: $e")));
                }
              },
              child: const Text("Save"),
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
