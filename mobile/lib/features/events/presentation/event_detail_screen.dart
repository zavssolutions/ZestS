import "package:cached_network_image/cached_network_image.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:url_launcher/url_launcher.dart";

import "../data/event_model.dart";
import "../data/events_repository.dart";

class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({required this.eventId, super.key});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(upcomingEventsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text("Event")),
      body: eventsAsync.when(
        data: (events) {
          EventModel? event;
          for (final candidate in events) {
            if (candidate.id == eventId) {
              event = candidate;
              break;
            }
          }
          if (event == null) {
            return const Center(child: Text("Event not found"));
          }
          final eventData = event;

          final mapUrl = (eventData.latitude != null && eventData.longitude != null)
              ? Uri.parse("https://www.google.com/maps?q=${eventData.latitude},${eventData.longitude}")
              : null;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (eventData.bannerImageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(imageUrl: eventData.bannerImageUrl!, height: 180, fit: BoxFit.cover),
                ),
              const SizedBox(height: 16),
              Text(eventData.title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(eventData.description ?? ""),
              const SizedBox(height: 8),
              Text("Location: ${eventData.locationName}"),
              Text("City: ${eventData.venueCity ?? "-"}"),
              const SizedBox(height: 16),
              if (mapUrl != null)
                FilledButton.tonal(
                  onPressed: () => launchUrl(mapUrl),
                  child: const Text("Open in Maps"),
                ),
              const SizedBox(height: 8),
                FilledButton(
                onPressed: () async {
                  final link = await ref.read(eventsRepositoryProvider).createShareLink(eventData.id);
                  await Clipboard.setData(ClipboardData(text: link));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(content: Text("Share link copied")));
                  }
                },
                child: const Text("Share Event"),
              ),
            ],
          );
        },
        error: (error, stackTrace) => const Center(child: Text("Unable to load event")),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
