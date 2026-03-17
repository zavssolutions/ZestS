import "package:cached_network_image/cached_network_image.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:intl/intl.dart";
import "package:skeletonizer/skeletonizer.dart";

import "../../../features/auth/application/auth_controller.dart";
import "../../../features/events/data/event_model.dart";
import "../../../features/events/data/events_repository.dart";
import "../../../features/home/data/banner_model.dart";
import "../../../features/home/data/banners_repository.dart";
import "banner_view_screen.dart";
import "../../../features/profile/data/profile_model.dart";
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
    final pages = <Widget>[
      const _DashboardPage(),
      const _SearchPage(),
      const _SchedulePage(),
      const _HomePage(),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text("ZestS Home")),
      drawer: const _HomeDrawer(),
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
}

class _HomeDrawer extends ConsumerWidget {
  const _HomeDrawer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(cachedProfileProvider);
    return Drawer(
      child: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => ListView(
          children: [
            const UserAccountsDrawerHeader(
              accountName: Text("Guest"),
              accountEmail: Text(""),
            ),
            const ListTile(
              leading: Icon(Icons.warning_amber),
              title: Text("We couldn't load your profile."),
              subtitle: Text("You can still browse events."),
            ),
            ListTile(
              leading: const Icon(Icons.login),
              title: const Text("Login / Sign Up"),
              onTap: () => context.push("/login"),
            ),
          ],
        ),
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
                  onTap: () => context.push("/settings"),
                ),
              ListTile(
                leading: const Icon(Icons.help_outline),
                title: const Text("Support / Help"),
                onTap: () => context.push("/support"),
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text("About Us"),
                onTap: () => context.push("/about"),
              ),
              if (profile?.role == "admin")
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings),
                  title: const Text("Admin Dashboard"),
                  onTap: () => context.push("/admin"),
                ),
              if (!isSubProfile && profile != null)
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text("Logout"),
                  onTap: () async {
                    await ref.read(authControllerProvider.notifier).logout();
                    if (!context.mounted) return;
                    context.go("/login");
                  },
                ),
              if (profile == null)
                ListTile(
                  leading: const Icon(Icons.login),
                  title: const Text("Login / Sign Up"),
                  onTap: () => context.push("/login"),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _HomePage extends ConsumerWidget {
  const _HomePage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(upcomingEventsProvider);
    final bannersAsync = ref.watch(bannersProvider);

    final bannerWidget = bannersAsync.when(
      data: (banners) {
        final banner = banners.isNotEmpty ? banners.first : null;
        final imageUrl = banner?.imageUrl ?? "assets/images/zests_logo.png";
        final isAsset = imageUrl.startsWith("assets/");

        final shareText = banner != null
            ? [
                if ((banner.title ?? "").trim().isNotEmpty) banner.title!.trim(),
                if ((banner.linkUrl ?? "").trim().isNotEmpty) banner.linkUrl!.trim(),
                imageUrl.trim(),
              ].join("\n")
            : "Check out ZestS!";

        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            context.push(
              "/banner",
              extra: BannerViewArgs(
                title: banner?.title?.trim().isNotEmpty == true ? banner!.title!.trim() : "ZestS",
                image: imageUrl,
                isAsset: isAsset,
                deepLinkUrl: banner?.shareUrl ?? "https://zests.app.link/home",
                shareText: shareText,
              ),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: isAsset
                ? Image.asset(imageUrl, height: 130, width: double.infinity, fit: BoxFit.contain)
                : CachedNetworkImage(
                    imageUrl: imageUrl,
                    height: 130,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                    errorWidget: (context, url, error) => Image.asset(
                      "assets/images/zests_logo.png",
                      height: 130,
                      width: double.infinity,
                      fit: BoxFit.contain,
                    ),
                  ),
          ),
        );
      },
      error: (error, _) => InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push(
          "/banner",
          extra: const BannerViewArgs(
            title: "ZestS",
            image: "assets/images/zests_logo.png",
            isAsset: true,
            deepLinkUrl: "https://zests.app.link/home",
            shareText: "Check out ZestS!",
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(
            "assets/images/zests_logo.png",
            height: 130,
            width: double.infinity,
            fit: BoxFit.contain,
          ),
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
    );

    return eventsAsync.when(
      data: (events) {
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  bannerWidget,
                  const SizedBox(height: 12),
                  const _SectionTitle("Common Dashboard"),
                  const _QuickStats(),
                  const SizedBox(height: 12),
                  const _SectionTitle("Leaderboard"),
                  const Card(child: ListTile(title: Text("Top skaters this week"))),
                  const SizedBox(height: 12),
                  const _SectionTitle("Events"),
                ]),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final e = events[index];
                    return Card(
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
                    );
                  },
                  childCount: events.length,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 12),
                  const _SectionTitle("Streaks & Rewards"),
                  const Card(child: ListTile(title: Text("Daily streak: 2 days"))),
                  const SizedBox(height: 12),
                  const _SectionTitle("Tip of the day"),
                  const Card(child: ListTile(title: Text("Stay hydrated before training."))),
                ]),
              ),
            ),
          ],
        );
      },
      error: (error, stackTrace) {
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  bannerWidget,
                  const SizedBox(height: 12),
                  const _SectionTitle("Common Dashboard"),
                  const _QuickStats(),
                  const SizedBox(height: 12),
                  const _SectionTitle("Leaderboard"),
                  const Card(child: ListTile(title: Text("Top skaters this week"))),
                  const SizedBox(height: 12),
                  const _SectionTitle("Events"),
                  const Card(
                    child: ListTile(
                      title: Text("Events are not available right now."),
                      subtitle: Text("Please try again in a little while."),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const _SectionTitle("Streaks & Rewards"),
                  const Card(child: ListTile(title: Text("Daily streak: 0 days"))),
                  const SizedBox(height: 12),
                  const _SectionTitle("Tip of the day"),
                  const Card(child: ListTile(title: Text("Stay hydrated before training."))),
                ]),
              ),
            ),
          ],
        );
      },
      loading: () => Skeletonizer(
        enabled: true,
        child: ListView.builder(
          itemCount: 8,
          itemBuilder: (context, index) => const Card(child: ListTile(title: Text("Loading"))),
        ),
      ),
    );
  }
}

class _DashboardPage extends ConsumerWidget {
  const _DashboardPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(cachedProfileProvider);
    final kidsAsync = ref.watch(kidsProvider);

    return profileAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Dashboard is temporarily unavailable."),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => ref.invalidate(cachedProfileProvider),
                child: const Text("Retry"),
              ),
            ],
          ),
        ),
      ),
      data: (profile) {
        if (profile == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Login required for dashboard"),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.push("/login"),
                  child: const Text("Login / Sign Up"),
                ),
              ],
            ),
          );
        }
        final isParent = profile.role == "parent";
        if (!isParent) {
          return const Center(child: Text("Dashboard is available for parent profiles."));
        }
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const _SectionTitle("MyDashboard"),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () => _showAddKidDialog(context, ref),
                    icon: const Icon(Icons.person_add),
                    label: const Text("Add Kid"),
                  ),
                  const SizedBox(height: 12),
                  const _SectionTitle("Kids"),
                ]),
              ),
            ),
            kidsAsync.when(
              data: (kids) {
                if (kids.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text("No kids added yet."),
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final kid = kids[index];
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.child_friendly),
                            title: Text(kid.displayName),
                            subtitle: Text("Role: ${kid.role}"),
                          ),
                        );
                      },
                      childCount: kids.length,
                    ),
                  ),
                );
              },
              error: (error, stackTrace) => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text("Kids list is unavailable right now."),
                ),
              ),
              loading: () => const SliverToBoxAdapter(
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 16),
                  const _SectionTitle("Registered events"),
                  const Card(child: ListTile(title: Text("No registrations yet"))),
                ]),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SchedulePage extends ConsumerWidget {
  const _SchedulePage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(cachedProfileProvider);
    final registrationsAsync = ref.watch(registrationsProvider);

    if (profileAsync.valueOrNull == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Login required to view schedule"),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.push("/login"),
              child: const Text("Login / Sign Up"),
            ),
          ],
        ),
      );
    }

    return registrationsAsync.when(
      data: (registrations) {
        if (registrations.isEmpty) {
          return const Center(child: Text("No scheduled events yet"));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: registrations.length,
          itemBuilder: (context, index) {
            final r = registrations[index];
            return Card(
              child: ListTile(
                title: Text(r.event?.title ?? "Event"),
                subtitle: Text("${r.userName} · ${r.status}"),
              ),
            );
          },
        );
      },
      error: (error, stackTrace) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("We couldn't load your schedule."),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => ref.invalidate(registrationsProvider),
                child: const Text("Retry"),
              ),
            ],
          ),
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}

class _SearchPage extends ConsumerStatefulWidget {
  const _SearchPage();

  @override
  ConsumerState<_SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<_SearchPage> {
  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    final resultsAsync = ref.watch(searchResultsProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            decoration: const InputDecoration(
              labelText: "Search events",
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) => ref.read(searchQueryProvider.notifier).state = value,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: resultsAsync.when(
              data: (events) {
                if (query.trim().isEmpty) {
                  return const Center(child: Text("Type to search events"));
                }
                if (events.isEmpty) {
                  return const Center(child: Text("No results"));
                }
                return ListView.builder(
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    final event = events[index];
                    return Card(
                      child: ListTile(
                        title: Text(event.title),
                        subtitle: Text(event.locationName),
                        onTap: () => context.push("/events/${event.id}"),
                      ),
                    );
                  },
                );
              },
              error: (error, stackTrace) => const Center(child: Text("Search failed")),
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickStats extends StatelessWidget {
  const _QuickStats();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(child: Card(child: ListTile(title: Text("Events"), subtitle: Text("12")))),
        Expanded(child: Card(child: ListTile(title: Text("Rewards"), subtitle: Text("85")))),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
    );
  }
}

Future<void> _showAddKidDialog(BuildContext context, WidgetRef ref) async {
  final firstController = TextEditingController();
  final lastController = TextEditingController();
  DateTime? dob;
  String gender = "unspecified";

  await showDialog<void>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
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
                      setState(() {
                        dob = picked;
                      });
                    }
                  },
                  child: Text(dob == null ? "Select DOB" : "DOB: ${dob!.toLocal().toIso8601String().split("T")[0]}"),
                ),
                DropdownButtonFormField<String>(
                  initialValue: gender,
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
                    if (!context.mounted) return;
                    Navigator.pop(context);
                  } catch (e) {
                    if (!context.mounted) return;
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
    },
  );
}
