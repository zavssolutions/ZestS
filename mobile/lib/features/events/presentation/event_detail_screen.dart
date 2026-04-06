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
import "../../../features/profile/data/kid_provider.dart";
import "../../../core/constants.dart";
import "../../admin/presentation/event_form_dialog.dart";
import "../../admin/presentation/admin_screens.dart";

class EventDetailScreen extends ConsumerStatefulWidget {
  const EventDetailScreen({required this.eventId, super.key});

  final String eventId;

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  final Set<String> _selectedCategoryIds = {};
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
          eventsAsync.when(
            data: (events) {
              final event = events.firstWhere((e) => e.id == widget.eventId);
              final profile = profileAsync.value;
              final isOrganizer = profile?.role == "organizer";
              final isOwner = profile?.id == event.organizerUserId;
              final isDraft = event.status == "draft";
              
              if (isOrganizer && isOwner && isDraft) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.category),
                      tooltip: "Manage Categories",
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AdminEventCategoriesScreen(
                            eventId: event.id,
                            eventTitle: event.title,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit),
                      tooltip: "Edit Metadata",
                      onPressed: () => showEventFormDialog(
                        context,
                        ref,
                        event: event,
                        onSuccess: () => ref.invalidate(upcomingEventsProvider),
                      ),
                    ),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
            error: (_, __) => const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
          ),
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
              if (eventData.bannerImageUrl != null && eventData.bannerImageUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl(eventData.bannerImageUrl),
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(color: Colors.grey[200], child: const Center(child: CircularProgressIndicator())),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[200],
                      child: Image.asset(
                        "assets/images/zests_logo.png",
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
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

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Select Categories", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...categories.map((c) {
              final isSelected = _selectedCategoryIds.contains(c.id);
              return CheckboxListTile(
                title: Text(c.name),
                subtitle: Text("Price: ₹${c.price.toStringAsFixed(0)}"),
                value: isSelected,
                onChanged: (bool? value) {
                  setState(() {
                    if (value == true) {
                      _selectedCategoryIds.add(c.id);
                    } else {
                      _selectedCategoryIds.remove(c.id);
                    }
                  });
                },
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
              );
            }).toList(),
            const SizedBox(height: 8),
            profileAsync.when(
              data: (profile) {
                if (profile == null) {
                  return const Text("Login required to register" );
                }
                if (profile.role == "parent") {
                  return kidsAsync.when(
                    data: (kids) {
                      final activeKidId = ref.watch(selectedKidProvider);
                      final options = [profile, ...kids];
                      
                      // Initialize _selectedUserId if not already set
                      if (_selectedUserId == null) {
                        if (activeKidId != null && options.any((o) => o.id == activeKidId)) {
                          _selectedUserId = activeKidId;
                        } else {
                          _selectedUserId = options.first.id;
                        }
                      }

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
                        decoration: const InputDecoration(
                          labelText: "Register for",
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
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
                final enabled = _selectedCategoryIds.isNotEmpty && isLoggedIn && !needsProfileCompletion;
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
                          if (_selectedCategoryIds.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Please select at least one category")),
                            );
                            return;
                          }
                        }
                      : () async {
                          try {
                            await ref.read(eventsRepositoryProvider).registerForMultipleCategories(
                                  eventId: widget.eventId,
                                  categoryIds: _selectedCategoryIds.toList(),
                                  userId: _selectedUserId,
                                );
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Registration submitted successfuly!")),
                              );
                              // Optional: clear selection after success
                              setState(() => _selectedCategoryIds.clear());
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
