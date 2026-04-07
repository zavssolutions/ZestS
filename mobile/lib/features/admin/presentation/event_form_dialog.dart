import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:image_picker/image_picker.dart";
import "package:dio/dio.dart";
import "../../../core/api_client.dart";
import "../../events/data/event_model.dart";
import "../../profile/data/profile_providers.dart";

void showEventFormDialog(BuildContext context, WidgetRef ref, {EventModel? event, VoidCallback? onSuccess}) {
  final isEdit = event != null;
  final titleCtrl = TextEditingController(text: event?.title);
  final descCtrl = TextEditingController(text: event?.description);
  final locationCtrl = TextEditingController(text: event?.locationName);
  final cityCtrl = TextEditingController(text: event?.venueCity);
  final latCtrl = TextEditingController(text: event?.latitude?.toString() ?? "");
  final lngCtrl = TextEditingController(text: event?.longitude?.toString() ?? "");
  // Mobile only shows IDs usually, but for creation we might need email.
  final organizerCtrl = TextEditingController(); 
  final priceCtrl = TextEditingController(text: event?.price.toString() ?? "0.0");
  
  DateTime startDate = event != null ? event.startAtUtc : DateTime.now().add(const Duration(days: 30));
  DateTime endDate = event != null ? event.endAtUtc : DateTime.now().add(const Duration(days: 31));

  String? bannerUrl = event?.bannerImageUrl;
  bool uploading = false;
  final categories = <Map<String, dynamic>>[];

  final categoryTypes = ["Road", "Rink", "ICE", "Artistic"];
  final skateTypes = ["Inline", "Quad", "toy inline", "tenacity"];
  final distances = ["200m", "500m", "1000m"];
  final ageGroups = ["4-6", "6-8", "8-10", "10-12", "12-15", "above 15"];

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Text(isEdit ? "Edit Event" : "Create Event"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
              const SizedBox(height: 16),
              if (!isEdit) ...[
                 const Divider(),
                 const Text("Initial Categories (Opt)", style: TextStyle(fontWeight: FontWeight.bold)),
                 // Simplification: only allow basic category addition for new events here.
                 // For complex management, use the dedicated category management screen.
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          FilledButton(
            onPressed: () async {
              try {
                final payload = {
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
                  await ref.read(dioProvider).post("/events", data: payload);
                } else {
                  // Admin endpoint for everything, or Organizer endpoint?
                  // Backends now have /admin/events/{id} and /events/{id}
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
      ),
    ),
  );
}
