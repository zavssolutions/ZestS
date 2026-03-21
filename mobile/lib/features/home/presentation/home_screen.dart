import "package:cached_network_image/cached_network_image.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:share_plus/share_plus.dart";
import "package:intl/intl.dart";
import "package:skeletonizer/skeletonizer.dart";
import "package:url_launcher/url_launcher.dart";

import "../../../features/auth/application/auth_controller.dart";
import "../../../features/events/data/event_model.dart";
import "../../../features/events/data/events_repository.dart";
import "../../../features/home/data/banner_model.dart";
import "../../../features/home/data/banners_repository.dart";
import "../../../features/home/data/tip_repository.dart";
import "banner_view_screen.dart";
import "../../../features/profile/data/profile_model.dart";
import "../../../features/profile/data/profile_providers.dart";

enum _HomeTab { dashboard, search, schedule, home }

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  _HomeTab _tab = _HomeTab.home;

  @override
  Widget build(BuildContext context) {
    final pointsAsync = ref.watch(userPointsProvider);
    final isLoggedIn = ref.watch(cachedProfileProvider).valueOrNull != null;
    final tabs = isLoggedIn
        ? const <_HomeTab>[_HomeTab.dashboard, _HomeTab.search, _HomeTab.schedule, _HomeTab.home]
        : const <_HomeTab>[_HomeTab.search, _HomeTab.schedule, _HomeTab.home];
    final selectedTab = tabs.contains(_tab) ? _tab : _HomeTab.home;
    final selectedIndex = tabs.indexOf(selectedTab);

    Widget body;
    switch (selectedTab) {
      case _HomeTab.dashboard:
        body = const _DashboardPage();
        break;
      case _HomeTab.search:
        body = const _SearchPage();
        break;
      case _HomeTab.schedule:
        body = const _SchedulePage();
        break;
      case _HomeTab.home:
        body = const _HomePage();
        break;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("ZestS Home"),
        actions: [
          pointsAsync.when(
            data: (points) => Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  "$points",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.cyan),
                ),
              ),
            ),
            error: (_, __) => const SizedBox.shrink(),
            loading: () => const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
            ),
          ),
        ],
      ),
      drawer: const _HomeDrawer(),
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (value) => setState(() => _tab = tabs[value]),
        destinations: [
          if (isLoggedIn) _animatedDestination(0, Icons.dashboard_outlined, "MyDashboard"),
          _animatedDestination(isLoggedIn ? 1 : 0, Icons.search, "Search"),
          _animatedDestination(isLoggedIn ? 2 : 1, Icons.calendar_month, "MySchedule"),
          _animatedDestination(isLoggedIn ? 3 : 2, Icons.home_filled, "Home"),
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
                    Navigator.pop(context);
                    context.go("/home");
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
    final tipAsync = ref.watch(tipOfDayProvider);
    final profileAsync = ref.watch(cachedProfileProvider);
    final isLoggedIn = profileAsync.valueOrNull != null;

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
          child: Stack(
            children: [
              ClipRRect(
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
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text("Compete", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              Positioned(
                bottom: 8,
                right: 8,
                child: IconButton.filledTonal(
                  icon: const Icon(Icons.share, size: 20),
                  onPressed: () {
                    Share.share(shareText);
                  },
                ),
              ),
            ],
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
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                "assets/images/zests_logo.png",
                height: 130,
                width: double.infinity,
                fit: BoxFit.contain,
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text("Compete", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            Positioned(
              bottom: 8,
              right: 8,
              child: IconButton.filledTonal(
                icon: const Icon(Icons.share, size: 20),
                onPressed: () {
                  Share.share("Check out ZestS!\nhttps://zests.app.link/home");
                },
              ),
            ),
          ],
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
    );

    final tipWidget = tipAsync.when(
      data: (tip) {
        final content = tip.content.trim().isEmpty ? "Stay hydrated before training." : tip.content.trim();
        if (!tip.isUrl) {
          return Card(child: ListTile(title: Text(content)));
        }
        return Card(
          child: ListTile(
            title: Text(content),
            trailing: const Icon(Icons.open_in_new),
            onTap: () async {
              final uri = Uri.tryParse(content);
              if (uri != null) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
        );
      },
      error: (error, _) => const Card(child: ListTile(title: Text("Stay hydrated before training."))),
      loading: () => const Card(child: ListTile(title: Text("Loading tip..."))),
    );

    return eventsAsync.when(
      data: (events) {
        final displayedEvents = isLoggedIn ? events : events.take(1).toList();
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  bannerWidget,
                  const SizedBox(height: 12),
                  const _SectionTitle("Tip of the day"),
                  tipWidget,
                  const SizedBox(height: 16),
                  const _SectionTitle("Dashboard"),
                  const Card(child: ListTile(title: Text("Coming soon"))),
                  const SizedBox(height: 16),
                  _SectionTitle("Events (${events.length})"),
                ]),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final e = displayedEvents[index];
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
                  childCount: displayedEvents.length,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 12),
                  const _SectionTitle("Leaderboard"),
                  const Card(child: ListTile(title: Text("Top skaters this week"))),
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
                  const _SectionTitle("Tip of the day"),
                  tipWidget,
                  const SizedBox(height: 16),
                  const _SectionTitle("Dashboard"),
                  const Card(child: ListTile(title: Text("Coming soon"))),
                  const SizedBox(height: 16),
                  const _SectionTitle("Events"),
                  const Card(
                    child: ListTile(
                      title: Text("Events are not available right now."),
                      subtitle: Text("Please try again in a little while."),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const _SectionTitle("Leaderboard"),
                  const Card(child: ListTile(title: Text("Top skaters this week"))),
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
    final profile = ref.watch(cachedProfileProvider).valueOrNull;
    if (profile == null) {
      return const Center(child: Text("Login required to view dashboard"));
    }

    switch (profile.role) {
      case "parent": return _ParentDashboard(profile: profile);
      case "kid":
      case "skater": return _SkaterDashboard();
      case "admin": return _AdminDashboard();
      case "organizer": return _OrganizerDashboard();
      case "sponsor": return _SponsorDashboard();
      default: return const Center(child: Text("MyDashboard coming soon"));
    }
  }
}

class _ParentDashboard extends ConsumerStatefulWidget {
  final ProfileModel profile;
  const _ParentDashboard({required this.profile});
  @override
  ConsumerState<_ParentDashboard> createState() => _ParentDashboardState();
}

class _ParentDashboardState extends ConsumerState<_ParentDashboard> {
  ProfileModel? selectedKid;

  @override
  Widget build(BuildContext context) {
    final kidsAsync = ref.watch(kidsProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("My Kids", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text("Add Kid"),
              onPressed: () => _showAddKidDialog(context, ref),
            ),
          ],
        ),
        kidsAsync.when(
          data: (kids) {
            if (kids.isEmpty) {
              return const Card(child: Padding(padding: EdgeInsets.all(16), child: Text("No kids added yet.")));
            }
            return DropdownButtonFormField<ProfileModel>(
              decoration: const InputDecoration(labelText: "Select Kid"),
              value: selectedKid ?? kids.first,
              items: kids.map((appKid) {
                return DropdownMenuItem(value: appKid, child: Text(appKid.displayName));
              }).toList(),
              onChanged: (val) => setState(() => selectedKid = val),
            );
          },
          error: (e, st) => Text("Error loading kids: $e"),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
        const SizedBox(height: 24),
        if (selectedKid != null) ...[
          Text("${selectedKid!.displayName}'s Events", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Card(child: ListTile(title: Text("No registered events."))),
          const SizedBox(height: 16),
          Text("${selectedKid!.displayName}'s Results", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Card(child: ListTile(title: Text("No past results."))),
        ] else if (kidsAsync.valueOrNull?.isNotEmpty == true) ...[
          Text("${kidsAsync.value!.first.displayName}'s Events", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Card(child: ListTile(title: Text("No registered events."))),
          const SizedBox(height: 16),
          Text("${kidsAsync.value!.first.displayName}'s Results", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Card(child: ListTile(title: Text("No past results."))),
        ]
      ],
    );
  }
}

class _SkaterDashboard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        Text("My Registered Events", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Card(child: ListTile(title: Text("No registered events."))),
        SizedBox(height: 16),
        Text("My Past Results", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Card(child: ListTile(title: Text("No results available."))),
      ],
    );
  }
}

class _AdminDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      padding: const EdgeInsets.all(16),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      children: [
        _AdminCard(title: "Manage Events", icon: Icons.event, onTap: () {}),
        _AdminCard(title: "Manage Users", icon: Icons.people, onTap: () {}),
        _AdminCard(title: "Manage Results", icon: Icons.emoji_events, onTap: () {}),
        _AdminCard(title: "Notifications", icon: Icons.notifications, onTap: () {}),
      ],
    );
  }
}

class _AdminCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  const _AdminCard({required this.title, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Colors.cyan),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _OrganizerDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text("Organizer Actions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        const Card(child: ListTile(leading: Icon(Icons.event), title: Text("View Events"))),
        const Card(child: ListTile(leading: Icon(Icons.leaderboard), title: Text("View Leaderboard"))),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.campaign),
          label: const Text("Reach out for publishing / advertisement"),
        ),
      ],
    );
  }
}

class _SponsorDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text("Sponsor Portal", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        const Card(child: ListTile(leading: Icon(Icons.event), title: Text("View Events"))),
        const Card(child: ListTile(leading: Icon(Icons.leaderboard), title: Text("View Leaderboard"))),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.handshake),
          label: const Text("Reach out for publishing / advertisement"),
        ),
      ],
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
