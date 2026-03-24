import "package:cached_network_image/cached_network_image.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:url_launcher/url_launcher.dart";
import "package:share_plus/share_plus.dart";

import "../data/event_model.dart";
import "../data/events_repository.dart";
import "../../profile/data/profile_providers.dart";
import "../../profile/data/profile_model.dart";

class EventDetailScreen extends ConsumerStatefulWidget {
  const EventDetailScreen({required this.eventId, super.key});

  final String eventId;

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  String? _selectedCategoryId;
  String? _selectedUserId;

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(upcomingEventsProvider);
    final categoriesAsync = ref.watch(eventCategoriesProvider(widget.eventId));
    final profileAsync = ref.watch(cachedProfileProvider);
    final kidsAsync = ref.watch(kidsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Event"),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () async {
              try {
                final link = await ref.read(eventsRepositoryProvider).createShareLink(widget.eventId);
                if (link.isNotEmpty) {
                  await Share.share("Check out this event: $link");
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Share failed: $e")));
                }
              }
            },
          ),
        ],
      ),
      body: eventsAsync.when(
        data: (events) {
          EventModel? event;
          for (final candidate in events) {
            if (candidate.id == widget.eventId) {
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
              const SizedBox(height: 16),
              _buildRegistrationSection(categoriesAsync, profileAsync, kidsAsync),
            ],
          );
        },
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text("This event is not available right now."),
                SizedBox(height: 8),
                Text("Please go back and try another event."),
              ],
            ),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildRegistrationSection(
    AsyncValue<List<EventCategoryModel>> categoriesAsync,
    AsyncValue<ProfileModel?> profileAsync,
    AsyncValue<List<ProfileModel>> kidsAsync,
  ) {
    return categoriesAsync.when(
      data: (categories) {
        if (categories.isEmpty) {
          return const Text("No categories available for registration yet.");
        }
        _selectedCategoryId ??= categories.first.id;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Register"),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedCategoryId,
              items: categories
                  .map(
                    (c) => DropdownMenuItem(
                      value: c.id,
                      child: Text("${c.name} (₹${c.price.toStringAsFixed(0)})"),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _selectedCategoryId = value),
              decoration: const InputDecoration(labelText: "Category"),
            ),
            const SizedBox(height: 8),
            profileAsync.when(
              data: (profile) {
                if (profile == null) {
                  return const Text("Login required to register" );
                }
                if (profile.role == "parent") {
                  return kidsAsync.when(
                    data: (kids) {
                      final options = [profile, ...kids];
                      _selectedUserId ??= options.first.id;
                      return DropdownButtonFormField<String>(
                        value: _selectedUserId,
                        items: options
                            .map(
                              (user) => DropdownMenuItem(
                                value: user.id,
                                child: Text(user.displayName),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(() => _selectedUserId = value),
                        decoration: const InputDecoration(labelText: "Register for"),
                      );
                    },
                    error: (error, stackTrace) => const Text("Kid profiles are unavailable right now."),
                    loading: () => const Center(child: CircularProgressIndicator()),
                  );
                }
                _selectedUserId = null;
                return const SizedBox.shrink();
              },
              error: (error, stackTrace) => const Text("Profile information is unavailable right now."),
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
            const SizedBox(height: 12),
            profileAsync.when(
              data: (profile) {
                final isLoggedIn = profile != null;
                final needsProfileCompletion = profile != null && !profile.hasCompletedProfile;
                final enabled = _selectedCategoryId != null && isLoggedIn && !needsProfileCompletion;
                return FilledButton(
                  onPressed: !enabled
                      ? () {
                          if (!isLoggedIn) {
                            context.push("/login");
                            return;
                          }
                          if (needsProfileCompletion) {
                            context.push("/profile-complete");
                            return;
                          }
                        }
                      : () async {
                          try {
                            await ref.read(eventsRepositoryProvider).registerForEvent(
                                  eventId: widget.eventId,
                                  categoryId: _selectedCategoryId!,
                                  userId: _selectedUserId,
                                );
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Registration submitted")),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Registration failed: $e")),
                              );
                            }
                          }
                        },
                  child: Text(
                    !isLoggedIn
                        ? "Login to Register"
                        : needsProfileCompletion
                            ? "Complete Profile to Register"
                            : "Register",
                  ),
                );
              },
              error: (error, stackTrace) => const FilledButton(
                onPressed: null,
                child: Text("Register"),
              ),
              loading: () => const FilledButton(
                onPressed: null,
                child: Text("Register"),
              ),
            ),
          ],
        );
      },
      error: (error, stackTrace) => const Text("Categories are not available right now."),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}
