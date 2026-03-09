import "package:cached_network_image/cached_network_image.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:intl/intl.dart";
import "package:skeletonizer/skeletonizer.dart";

import "../../../features/auth/application/auth_controller.dart";
import "../../../features/events/data/events_repository.dart";
import "../../../features/profile/data/profile_providers.dart";

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
      body: eventsAsync.when(
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
      ),
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
