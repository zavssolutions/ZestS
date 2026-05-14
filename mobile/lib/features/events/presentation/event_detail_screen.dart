import "package:cached_network_image/cached_network_image.dart";
import "package:flutter/material.dart";
import "package:flutter/material.dart";
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
import "../../admin/presentation/admin_screens.dart";
import "../../admin/presentation/event_form_dialog.dart";
import "../../home/presentation/home_screen.dart";

class EventDetailScreen extends ConsumerStatefulWidget {
  const EventDetailScreen({required this.eventId, super.key});

  final String eventId;

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  final Set<String> _selSkates = {};
  final Set<String> _selDistances = {};
  final Set<String> _selAgeGroups = {};
  final Set<String> _selGenders = {};
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
                  await Share.shareUri(Uri.parse(link));
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
              Text("Location: ${eventData.locationName ?? "TBD"}"),
              Text("City: ${eventData.venueCity ?? "-"}"),
              const SizedBox(height: 16),
              if (mapUrl != null)
                FilledButton.tonal(
                  onPressed: () => launchUrl(mapUrl),
                  child: const Text("Open in Maps"),
                ),
              const SizedBox(height: 16),
              _buildRegistrationSection(categoriesAsync, profileAsync, kidsAsync, ref.watch(registrationsProvider)),
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
    AsyncValue<List<RegistrationModel>> registrationsAsync,
  ) {
    return categoriesAsync.when(
      data: (categories) {
        if (categories.isEmpty) {
          return const Text("No categories available for registration yet.");
        }

        // Determine available groups
        final skateTypes = categories.map((c) => c.skateType).whereType<String>().toSet().toList()..sort();
        final distances = categories.map((c) => c.distance).whereType<String>().toSet().toList()..sort();
        final ageGroups = categories.map((c) => c.ageGroup).whereType<String>().toSet().toList()..sort();
        final genderGroups = categories.map((c) => c.gender).whereType<String>().toSet().toList()..sort();

        // Calculate which categories are "fully selected" based on intersections
        final Set<String> activeCategoryIds = {};
        for (final cat in categories) {
          bool matches = true;
          if (skateTypes.isNotEmpty && !(_selSkates.contains(cat.skateType))) matches = false;
          if (distances.isNotEmpty && !(_selDistances.contains(cat.distance))) matches = false;
          if (ageGroups.isNotEmpty && !(_selAgeGroups.contains(cat.ageGroup))) matches = false;
          if (genderGroups.isNotEmpty && !(_selGenders.contains(cat.gender))) matches = false;
          if (matches) activeCategoryIds.add(cat.id);
        }

        bool allGroupsSelected = true;
        if (skateTypes.isNotEmpty && _selSkates.isEmpty) allGroupsSelected = false;
        if (distances.isNotEmpty && _selDistances.isEmpty) allGroupsSelected = false;
        if (ageGroups.isNotEmpty && _selAgeGroups.isEmpty) allGroupsSelected = false;
        if (genderGroups.isNotEmpty && _selGenders.isEmpty) allGroupsSelected = false;

        void toggleAttr(Set<String> selSet, String value) {
          setState(() {
            if (selSet.contains(value)) {
              selSet.remove(value);
            } else {
              selSet.add(value);
            }
          });
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Select Categories", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            registrationsAsync.when(
              data: (myRegs) {
                final currentUserId = _selectedUserId ?? profileAsync.value?.id;
                final mySelectedRegs = myRegs.where((r) => r.userId == currentUserId && r.status != "cancelled").toList();
                
                // Calculate cumulative price
                double totalPrice = 0;
                for (final catId in activeCategoryIds) {
                  final cat = categories.firstWhere((c) => c.id == catId);
                  final alreadyReg = mySelectedRegs.any((r) => r.categoryId == cat.id);
                  if (!alreadyReg) {
                    totalPrice += cat.price;
                  }
                }

                return Column(
                  children: [
                    if (skateTypes.isNotEmpty)
                      _buildBorderedGroup(
                        title: "Skate Types",
                        icon: Icons.roller_skating,
                        items: skateTypes.map((st) {
                          final isRegistered = mySelectedRegs.any((r) => categories.firstWhere((c) => c.id == r.categoryId).skateType == st);
                          final groupVal = isRegistered ? st : (_selSkates.isNotEmpty ? _selSkates.first : null);
                          return _buildAttrRadio(
                            label: st,
                            value: st,
                            groupValue: groupVal,
                            onChanged: isRegistered ? null : (val) {
                              if (val != null) {
                                setState(() {
                                  _selSkates.clear();
                                  _selSkates.add(val);
                                });
                              }
                            },
                          );
                        }).toList(),
                      ),
                    if (distances.isNotEmpty)
                      _buildBorderedGroup(
                        title: "Distances",
                        icon: Icons.straighten,
                        items: distances.map((d) {
                          final isRegistered = mySelectedRegs.any((r) => categories.firstWhere((c) => c.id == r.categoryId).distance == d);
                          final groupVal = isRegistered ? d : (_selDistances.isNotEmpty ? _selDistances.first : null);
                          return _buildAttrRadio(
                            label: d,
                            value: d,
                            groupValue: groupVal,
                            onChanged: isRegistered ? null : (val) {
                              if (val != null) {
                                setState(() {
                                  _selDistances.clear();
                                  _selDistances.add(val);
                                });
                              }
                            },
                          );
                        }).toList(),
                      ),
                    if (ageGroups.isNotEmpty)
                      _buildBorderedGroup(
                        title: "Age / Grade Categories",
                        icon: Icons.group,
                        items: ageGroups.map((ag) {
                          final isRegistered = mySelectedRegs.any((r) => categories.firstWhere((c) => c.id == r.categoryId).ageGroup == ag);
                          final groupVal = isRegistered ? ag : (_selAgeGroups.isNotEmpty ? _selAgeGroups.first : null);
                          return _buildAttrRadio(
                            label: ag,
                            value: ag,
                            groupValue: groupVal,
                            onChanged: isRegistered ? null : (val) {
                              if (val != null) {
                                setState(() {
                                  _selAgeGroups.clear();
                                  _selAgeGroups.add(val);
                                });
                              }
                            },
                          );
                        }).toList(),
                      ),
                    if (genderGroups.isNotEmpty)
                      _buildBorderedGroup(
                        title: "Gender",
                        icon: Icons.person_search,
                        items: genderGroups.map((g) {
                          final isRegistered = mySelectedRegs.any((r) => categories.firstWhere((c) => c.id == r.categoryId).gender == g);
                          final groupVal = isRegistered ? g : (_selGenders.isNotEmpty ? _selGenders.first : null);
                          return _buildAttrRadio(
                            label: g.toUpperCase(),
                            value: g,
                            groupValue: groupVal,
                            onChanged: isRegistered ? null : (val) {
                              if (val != null) {
                                setState(() {
                                  _selGenders.clear();
                                  _selGenders.add(val);
                                });
                              }
                            },
                          );
                        }).toList(),
                      ),
                    
                    if (totalPrice > 0) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Total Registration Fee:", style: Theme.of(context).textTheme.titleMedium),
                            Text("₹${totalPrice.toStringAsFixed(0)}", 
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Text("Error loading registrations: $e"),
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
                        initialValue: _selectedUserId,
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
                final enabled = isLoggedIn && !needsProfileCompletion && allGroupsSelected && activeCategoryIds.isNotEmpty;
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
                          if (!allGroupsSelected) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Please select at least one item from every available group")),
                            );
                            return;
                          }
                          if (activeCategoryIds.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("No category matches this combination")),
                            );
                            return;
                          }
                        }
                      : () async {
                          try {
                            await ref.read(eventsRepositoryProvider).registerForMultipleCategories(
                                  eventId: widget.eventId,
                                  categoryIds: activeCategoryIds.toList(),
                                  userId: _selectedUserId,
                                );
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Registration submitted successfuly!")),
                              );
                              ref.invalidate(registrationsProvider);
                              // Navigation to My Schedule
                              ref.read(homeTabProvider.notifier).state = HomeTab.schedule;
                              if (context.mounted) {
                                context.go("/home");
                              }
                            }
                          } catch (e) {
                            if (mounted) {
                              final errorStr = e.toString();
                              if (errorStr.contains("Already registered")) {
                                _showAlreadyRegisteredDialog(context);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Registration failed: $e")),
                                );
                              }
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

  void _showAlreadyRegisteredDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Notice"),
        content: const Text("Already registered, contact administrator."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  Widget _buildBorderedGroup({
    required String title,
    required IconData icon,
    required List<Widget> items,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -10,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: Theme.of(context).primaryColor),
                  const SizedBox(width: 4),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 0,
              children: items,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttrCheckbox({
    required String label,
    required bool selected,
    required ValueChanged<bool?>? onChanged,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(
          value: selected,
          onChanged: onChanged,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        Text(label, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 8),
      ],
    );
  }
  Widget _buildAttrRadio({
    required String label,
    required String value,
    required String? groupValue,
    required ValueChanged<String?>? onChanged,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Radio<String>(
          value: value,
          groupValue: groupValue,
          onChanged: onChanged,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        Text(label, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 8),
      ],
    );
  }
}
