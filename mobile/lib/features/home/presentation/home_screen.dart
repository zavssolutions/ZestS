import "package:cached_network_image/cached_network_image.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:intl/intl.dart";
import "package:skeletonizer/skeletonizer.dart";

import "../../../features/auth/application/auth_controller.dart";
import "../../../features/events/data/event_model.dart";
import "../../../features/events/data/events_repository.dart";
import "../../../features/profile/data/profile_model.dart";
import "../../../features/profile/data/profile_providers.dart";
import "../../../features/profile/data/profile_repository.dart";

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _tab = 3;

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(upcomingEventsProvider);
    final profileAsync = ref.watch(cachedProfileProvider);
    final kidsAsync = ref.watch(kidsProvider);
    final registrationsAsync = ref.watch(registrationsProvider);

    final pages = <Widget>[
      _buildDashboard(context, profileAsync, kidsAsync),
      _buildSearch(),
      _buildSchedule(registrationsAsync),
      _buildHome(eventsAsync),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text("ZestS Home")),
      drawer: Drawer(
        child: profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => const Center(child: Text("Unable to load profile")),
          data: (profile) {
            final isSubProfile = profile?.isSubProfile ?? false;
            return ListView(
              children: [
                UserAccountsDrawerHeader(
                  accountName: Text(profile?.displayName ?? "Guest"),
                  accountEmail: Text(profile?.role ?? ""),
                ),
                ListTile(
                  leading: const Icon(Icons.person),
                  title: const Text("My Profile"),
                  onTap: () => context.push("/profile"),
                ),
                if (!isSubProfile)
                  ListTile(
                    leading: const Icon(Icons.settings),
                    title: const Text("Settings"),
                    onTap: () {},
                  ),
                ListTile(
                  leading: const Icon(Icons.help_outline),
                  title: const Text("Support / Help"),
                  onTap: () {},
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text("About Us"),
                  onTap: () => context.push("/about"),
                ),
                if (!isSubProfile)
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text("Logout"),
                    onTap: () async {
                      await ref.read(authControllerProvider.notifier).logout();
                      if (!context.mounted) return;
                      context.go("/login");
                    },
                  ),
              ],
            );
          },
        ),
      ),
      body: pages[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (value) => setState(() => _tab = value),
        destinations: [
          _animatedDestination(0, Icons.dashboard_outlined, "MyDashboard"),
          _animatedDestination(1, Icons.search, "Search"),
          _animatedDestination(2, Icons.calendar_month, "MySchedule"),
          _animatedDestination(3, Icons.home_filled, "Home"),
        ],
      ),
    );
  }

  Widget _buildHome(AsyncValue<List<EventModel>> eventsAsync) {
    return eventsAsync.when(
      data: (events) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionTitle("Banner"),
            Container(
              height: 130,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(child: Text("Featured Banner")),
            ),
            const SizedBox(height: 12),
            _sectionTitle("Common Dashboard"),
            _quickStats(),
            const SizedBox(height: 12),
            _sectionTitle("Leaderboard"),
            const Card(child: ListTile(title: Text("Top skaters this week"))),
            const SizedBox(height: 12),
            _sectionTitle("Events"),
            ...events.map(
              (e) => Card(
                child: ListTile(
                  leading: e.bannerImageUrl != null
                      ? CachedNetworkImage(imageUrl: e.bannerImageUrl!, width: 54, fit: BoxFit.cover)
                      : const Icon(Icons.event),
                  title: Text(e.title),
                  subtitle: Text(
                    "${DateFormat.yMMMd().add_jm().format(e.startAtUtc.toLocal())} - ${e.locationName}",
                  ),
                  onTap: () => context.push("/events/${e.id}"),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _sectionTitle("Streaks & Rewards"),
            const Card(child: ListTile(title: Text("Daily streak: 2 days"))),
            const SizedBox(height: 12),
            _sectionTitle("Tip of the day"),
            const Card(child: ListTile(title: Text("Stay hydrated before training."))),
          ],
        );
      },
      error: (error, stackTrace) => const Center(child: Text("Unable to load home data")),
      loading: () => Skeletonizer(
        enabled: true,
        child: ListView.builder(
          itemCount: 8,
          itemBuilder: (context, index) => const Card(child: ListTile(title: Text("Loading"))),
        ),
      ),
    );
  }

  Widget _buildDashboard(
    BuildContext context,
    AsyncValue<ProfileModel?> profileAsync,
    AsyncValue<List<ProfileModel>> kidsAsync,
  ) {
    return profileAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => const Center(child: Text("Unable to load dashboard")),
      data: (profile) {
        if (profile == null) {
          return const Center(child: Text("Login required for dashboard"));
        }
        final isParent = profile.role == "parent";
        if (!isParent) {
          return const Center(child: Text("Dashboard is available for parent profiles."));
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionTitle("MyDashboard"),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => _showAddKidDialog(context),
              icon: const Icon(Icons.person_add),
              label: const Text("Add Kid"),
            ),
            const SizedBox(height: 12),
            _sectionTitle("Kids"),
            kidsAsync.when(
              data: (kids) {
                if (kids.isEmpty) {
                  return const Text("No kids added yet.");
                }
                return Column(
                  children: kids
                      .map(
                        (kid) => Card(
                          child: ListTile(
                            leading: const Icon(Icons.child_friendly),
                            title: Text(kid.displayName),
                            subtitle: Text("Role: ${kid.role}"),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
              error: (error, stackTrace) => const Text("Unable to load kids"),
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
            const SizedBox(height: 16),
            _sectionTitle("Registered events"),
            const Card(child: ListTile(title: Text("No registrations yet"))),
          ],
        );
      },
    );
  }

  Widget _buildSchedule(AsyncValue<List<RegistrationModel>> registrationsAsync) {
    return registrationsAsync.when(
      data: (registrations) {
        if (registrations.isEmpty) {
          return const Center(child: Text("No scheduled events yet"));
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: registrations
              .map(
                (r) => Card(
                  child: ListTile(
                    title: Text(r.event?.title ?? "Event"),
                    subtitle: Text("${r.userName} · ${r.status}"),
                  ),
                ),
              )
              .toList(),
        );
      },
      error: (error, stackTrace) => const Center(child: Text("Unable to load schedule")),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildSearch() {
    return const Center(child: Text("Search coming soon"));
  }

  Future<void> _showAddKidDialog(BuildContext context) async {
    final firstController = TextEditingController();
    final lastController = TextEditingController();
    DateTime? dob;
    String gender = "unspecified";

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Add Kid"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: firstController,
                decoration: const InputDecoration(labelText: "First name"),
              ),
              TextField(
                controller: lastController,
                decoration: const InputDecoration(labelText: "Last name"),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().subtract(const Duration(days: 365 * 8)),
                    firstDate: DateTime(2010, 1, 1),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    dob = picked;
                  }
                },
                child: Text(dob == null ? "Select DOB" : "DOB: ${dob!.toLocal().toIso8601String().split("T")[0]}"),
              ),
              DropdownButtonFormField<String>(
                value: gender,
                items: const [
                  DropdownMenuItem(value: "male", child: Text("Male")),
                  DropdownMenuItem(value: "female", child: Text("Female")),
                  DropdownMenuItem(value: "other", child: Text("Other")),
                  DropdownMenuItem(value: "unspecified", child: Text("Unspecified")),
                ],
                onChanged: (value) => gender = value ?? "unspecified",
                decoration: const InputDecoration(labelText: "Gender"),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            FilledButton(
              onPressed: () async {
                final first = firstController.text.trim();
                final last = lastController.text.trim();
                if (first.isEmpty || dob == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("First name and DOB are required")),
                  );
                  return;
                }
                try {
                  await ref.read(profileRepositoryProvider).addKid(
                        firstName: first,
                        lastName: last,
                        dob: dob!,
                        gender: gender,
                      );
                  ref.invalidate(kidsProvider);
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Unable to add kid: $e")),
                  );
                }
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  Widget _quickStats() {
    return Row(
      children: const [
        Expanded(child: Card(child: ListTile(title: Text("Events"), subtitle: Text("12")))),
        Expanded(child: Card(child: ListTile(title: Text("Rewards"), subtitle: Text("85")))),
      ],
    );
  }

  NavigationDestination _animatedDestination(int index, IconData icon, String label) {
    final selected = _tab == index;
    return NavigationDestination(
      icon: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        scale: selected ? 1.15 : 1,
        child: Icon(icon, color: selected ? Colors.cyan : null),
      ),
      label: label,
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
    );
  }
}
