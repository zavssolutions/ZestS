import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:image_picker/image_picker.dart";
import "package:dio/dio.dart";
import "../../../core/api_client.dart";
import "../../events/data/event_model.dart";
import "../../events/data/events_repository.dart";
import "../../profile/data/profile_providers.dart";
import "event_category_selector.dart";

void showEventFormDialog(BuildContext context, WidgetRef ref, {EventModel? event, VoidCallback? onSuccess}) {
  final isEdit = event != null;
  final titleCtrl = TextEditingController(text: event?.title);
  final descCtrl = TextEditingController(text: event?.description);
  final locationCtrl = TextEditingController(text: event?.locationName);
  final cityCtrl = TextEditingController(text: event?.venueCity);
  final latCtrl = TextEditingController(text: event?.latitude?.toString() ?? "");
  final lngCtrl = TextEditingController(text: event?.longitude?.toString() ?? "");
  final organizerCtrl = TextEditingController(); 
  final priceCtrl = TextEditingController(text: event?.price.toString() ?? "0.0");

  DateTime startDate = event != null ? event.startAtUtc : DateTime.now().add(const Duration(days: 30));
  DateTime endDate = event != null ? event.endAtUtc : DateTime.now().add(const Duration(days: 31));

  String? bannerUrl = event?.bannerImageUrl;
  bool uploading = false;

  // New multi-select category selections (for create mode)
  final categorySelections = EventCategorySelections();

  // Legacy categories list (for edit mode – shows existing categories)
  List<Map<String, dynamic>> categories = [];
  bool loadingCategories = false;

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        if (isEdit && categories.isEmpty && !loadingCategories) {
          loadingCategories = true;
          Future.microtask(() async {
            try {
              final existing = await ref.read(eventsRepositoryProvider).fetchEventCategories(event!.id);
              setDialogState(() {
                categories = existing.map((c) => {
                  "id": c.id,
                  "name": c.name,
                  "skate_type": null,
                  "age_group": null,
                  "distance": null,
                  "gender": null,
                  "price": c.price,
                }).toList();
                loadingCategories = false;
              });
            } catch (e) {
              setDialogState(() => loadingCategories = false);
            }
          });
        }

        return AlertDialog(
          title: Text(isEdit ? "Edit Event" : "Create Event"),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Event Metadata (unchanged) ─────────────────
                  TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: "Event Title")),
                  TextField(controller: descCtrl, decoration: const InputDecoration(labelText: "Description"), maxLines: 2),
                  const SizedBox(height: 12),
                  if (!isEdit) TextField(controller: organizerCtrl, decoration: const InputDecoration(labelText: "Organizer Email")),
                  TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: "Base Price (₹)"), keyboardType: TextInputType.number),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text("Starts: ${startDate.toLocal().toString().split(' ')[0]}"),
                    trailing: const Icon(Icons.calendar_month),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: ctx,
                        initialDate: startDate,
                        firstDate: DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                      );
                      if (date != null) setDialogState(() => startDate = date);
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text("Ends: ${endDate.toLocal().toString().split(' ')[0]}"),
                    trailing: const Icon(Icons.calendar_month),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: ctx,
                        initialDate: endDate,
                        firstDate: startDate,
                        lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                      );
                      if (date != null) setDialogState(() => endDate = date);
                    },
                  ),
                  TextField(controller: locationCtrl, decoration: const InputDecoration(labelText: "Location Name")),
                  TextField(controller: cityCtrl, decoration: const InputDecoration(labelText: "City")),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: latCtrl, decoration: const InputDecoration(labelText: "Latitude"), keyboardType: TextInputType.number)),
                      const SizedBox(width: 12),
                      Expanded(child: TextField(controller: lngCtrl, decoration: const InputDecoration(labelText: "Longitude"), keyboardType: TextInputType.number)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (bannerUrl != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(bannerUrl!, height: 100, width: double.infinity, fit: BoxFit.cover),
                    ),
                    const SizedBox(height: 8),
                  ],
                  OutlinedButton.icon(
                    onPressed: uploading ? null : () async {
                      final picker = ImagePicker();
                      final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                      if (image == null) return;
                      setDialogState(() => uploading = true);
                      try {
                        final formData = FormData.fromMap({"file": await MultipartFile.fromFile(image.path, filename: image.name)});
                        final resp = await ref.read(dioProvider).post("/uploads/image", data: formData);
                        setDialogState(() { bannerUrl = resp.data["url"]; uploading = false; });
                      } catch (e) { setDialogState(() => uploading = false); }
                    },
                    icon: uploading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.image),
                    label: Text(uploading ? "Uploading..." : "Banner Image"),
                  ),

                  // ── Categories Section ─────────────────────────
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 8),

                  if (isEdit) ...[
                    // Edit mode: show existing categories as a list
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Existing Categories", style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (loadingCategories) const Center(child: CircularProgressIndicator()),
                    if (!loadingCategories && categories.isEmpty) const Text("No categories found.", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ...categories.asMap().entries.map((entry) {
                      final cat = entry.value;
                      return ListTile(
                        title: Text(cat["name"]),
                        subtitle: Text("₹${cat["price"]}", style: const TextStyle(fontSize: 11)),
                        dense: true,
                      );
                    }),
                  ] else ...[
                    // Create mode: new grouped checkbox selector
                    Row(
                      children: [
                        Icon(Icons.category, size: 20, color: Theme.of(ctx).colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          "Event Categories",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Theme.of(ctx).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Select all applicable options. Categories will be generated from the combination of your selections.",
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 12),
                    EventCategorySelectorWidget(
                      selections: categorySelections,
                      onChanged: () => setDialogState(() {}),
                    ),
                    const SizedBox(height: 12),

                    // Preview count of generated categories
                    Builder(builder: (_) {
                      final generated = categorySelections.toCategoryPayloads(
                        price: double.tryParse(priceCtrl.text) ?? 0.0,
                      );
                      if (generated.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(ctx).colorScheme.tertiaryContainer.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Theme.of(ctx).colorScheme.tertiary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, size: 18, color: Theme.of(ctx).colorScheme.tertiary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "${generated.length} categor${generated.length == 1 ? 'y' : 'ies'} will be created from your selections.",
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(ctx).colorScheme.onTertiaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            FilledButton(
              onPressed: () async {
                try {
                  final payload = <String, dynamic>{
                    "title": titleCtrl.text,
                    "description": descCtrl.text,
                    "location_name": locationCtrl.text,
                    "venue_city": cityCtrl.text,
                    "banner_image_url": bannerUrl,
                    "latitude": double.tryParse(latCtrl.text),
                    "longitude": double.tryParse(lngCtrl.text),
                    "start_at_utc": startDate.toUtc().toIso8601String(),
                    "end_at_utc": endDate.toUtc().toIso8601String(),
                  };
                  if (!isEdit) {
                    payload["organizer_email"] = organizerCtrl.text;
                    payload["price"] = double.tryParse(priceCtrl.text) ?? 0.0;
                    // Generate categories from the multi-select checkbox state
                    payload["categories"] = categorySelections.toCategoryPayloads(
                      price: double.tryParse(priceCtrl.text) ?? 0.0,
                    );
                    await ref.read(dioProvider).post("/events", data: payload);
                  } else {
                    final url = (ref.read(cachedProfileProvider).value?.role == "admin") 
                      ? "/admin/events/${event.id}" 
                      : "/events/${event.id}";
                    payload["price"] = double.tryParse(priceCtrl.text) ?? 0.0;
                    await ref.read(dioProvider).put(url, data: payload);
                  }
                  if (onSuccess != null) onSuccess();
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text("Action failed: $e")));
                }
              },
              child: Text(isEdit ? "Update" : "Create"),
            ),
          ],
        );
      },
    ),
  );
}

