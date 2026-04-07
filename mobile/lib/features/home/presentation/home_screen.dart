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
import "../../../features/admin/presentation/admin_screens.dart";
import "../../../features/profile/data/kid_provider.dart";
import "../../../core/constants.dart";

enum HomeTab { dashboard, search, schedule, home }

final homeTabProvider = StateProvider<HomeTab>((ref) => HomeTab.home);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {

  @override
  Widget build(BuildContext context) {
    final pointsAsync = ref.watch(userPointsProvider);
    final profileAsync = ref.watch(cachedProfileProvider);
    final isLoggedIn = profileAsync.valueOrNull != null;
    final currentTab = ref.watch(homeTabProvider);
    final tabs = isLoggedIn
        ? const <HomeTab>[HomeTab.dashboard, HomeTab.search, HomeTab.schedule, HomeTab.home]
        : const <HomeTab>[HomeTab.search, HomeTab.schedule, HomeTab.home];
    final selectedTab = tabs.contains(currentTab) ? currentTab : HomeTab.home;
    final selectedIndex = tabs.indexOf(selectedTab);

    Widget body;
    switch (selectedTab) {
      case HomeTab.dashboard:
        body = const _DashboardPage();
        break;
      case HomeTab.search:
        body = const _SearchPage();
        break;
      case HomeTab.schedule:
        body = const _SchedulePage();
        break;
      case HomeTab.home:
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
        onDestinationSelected: (value) => ref.read(homeTabProvider.notifier).state = tabs[value],
        destinations: [
          if (isLoggedIn) _animatedDestination(HomeTab.dashboard, Icons.dashboard_outlined, "MyDashboard"),
          _animatedDestination(HomeTab.search, Icons.search, "Search"),
          _animatedDestination(HomeTab.schedule, Icons.calendar_month, "MySchedule"),
          _animatedDestination(HomeTab.home, Icons.home_filled, "Home"),
        ],
      ),
    );
  }

  NavigationDestination _animatedDestination(HomeTab tab, IconData icon, String label) {
    final selected = ref.watch(homeTabProvider) == tab;
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

final List<EventModel> _skeletonEvents = List.generate(
  3,
  (i) => EventModel(
    id: "skeleton_$i",
    title: "Loading Event Name...",
    description: "Loading description...",
    locationName: "Loading location...",
    venueCity: "City",
    startAtUtc: DateTime.now(),
    endAtUtc: DateTime.now().add(const Duration(hours: 2)),
    bannerImageUrl: null,
    latitude: null,
    longitude: null,
    status: "published",
    price: 0,
  ),
);

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
        if (banners.isEmpty) {
          return const _BannerCarousel(banners: []);
        }
        return _BannerCarousel(banners: banners);
      },
      error: (error, _) => const _BannerCarousel(banners: []),
      loading: () => const SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator()),
      ),
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

    final List<EventModel> events = eventsAsync.valueOrNull ?? [];
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
              const SizedBox(height: 12),
              eventsAsync.when(
                data: (e) => _SectionTitle("Events (${e.length})"),
                loading: () => const _SectionTitle("Events"),
                error: (_, __) => const _SectionTitle("Events"),
              ),
            ]),
          ),
        ),
        eventsAsync.when(
          data: (e) => SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: _EventCarousel(events: displayedEvents),
            ),
          ),
          loading: () => SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: Skeletonizer(
                enabled: true,
                child: _EventCarousel(events: _skeletonEvents),
              ),
            ),
          ),
          error: (error, _) => SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: Card(
                child: ListTile(
                  title: const Text("Events are not available right now."),
                  subtitle: const Text("Please try again in a little while."),
                ),
              ),
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
      case "parent": return const _ParentDashboard();
      case "kid":
      case "skater": return _SkaterDashboard();
      case "admin": return _AdminDashboard();
      case "organizer": return _OrganizerDashboard();
      case "sponsor": return _SponsorDashboard();
      default: return const Center(child: Text("MyDashboard coming soon"));
    }
  }
}

class _ParentDashboard extends ConsumerWidget {
  const _ParentDashboard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kidsAsync = ref.watch(kidsProvider);
    final selectedKidId = ref.watch(selectedKidProvider);

    return kidsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text("Error loading kids: $e")),
      data: (kids) {
        if (kids.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("No kids added yet."),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => _showAddKidDialog(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text("Add Your First Kid"),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            _HorizontalKidSwitcher(kids: kids),
            const Divider(height: 1),
            Expanded(
              child: selectedKidId == null
                  ? _KidSelectorOverview(kids: kids)
                  : _KidDetailsView(kid: kids.firstWhere((k) => k.id == selectedKidId)),
            ),
          ],
        );
      },
    );
  }
}

class _HorizontalKidSwitcher extends ConsumerWidget {
  final List<ProfileModel> kids;
  const _HorizontalKidSwitcher({required this.kids});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedKidId = ref.watch(selectedKidProvider);

    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: kids.length,
        itemBuilder: (context, index) {
          final kid = kids[index];
          final isSelected = selectedKidId == kid.id;
          return Padding(
            padding: const EdgeInsets.only(right: 20),
            child: GestureDetector(
              onTap: () => ref.read(selectedKidProvider.notifier).selectKid(kid.id),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.cyan : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 28,
                      backgroundImage: kid.profilePictureUrl != null && kid.profilePictureUrl!.isNotEmpty
                          ? CachedNetworkImageProvider(imageUrl(kid.profilePictureUrl))
                          : null,
                      child: kid.profilePictureUrl == null ? const Icon(Icons.person, size: 30) : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    kid.firstName ?? "Kid",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.cyan : null,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _KidSelectorOverview extends ConsumerWidget {
  final List<ProfileModel> kids;
  const _KidSelectorOverview({required this.kids});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "My Kids",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (kids.length < 3)
                TextButton.icon(
                  onPressed: () => _showAddKidDialog(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text("Add Kid"),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ...kids.map((kid) => Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text("${kid.firstName} ${kid.lastName ?? ''}"),
              subtitle: Text("DOB: ${kid.dobDateTime?.toLocal().toIso8601String().split('T')[0] ?? 'N/A'}"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => ref.read(selectedKidProvider.notifier).selectKid(kid.id),
            ),
          )),
        ],
      ),
    );
  }
}

class _KidDetailsView extends ConsumerWidget {
  final ProfileModel kid;
  const _KidDetailsView({required this.kid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => ref.read(selectedKidProvider.notifier).clearSelection(),
              ),
              const SizedBox(width: 8),
              Text(
                "${kid.firstName}'s Dashboard",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: "Points",
                  value: "0",
                  icon: Icons.stars,
                  color: Colors.purple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  label: "Rank",
                  value: "-",
                  icon: Icons.leaderboard,
                  color: Colors.cyan,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              _DashboardActionCard(
                title: "Register Event",
                icon: Icons.event_available,
                color: Colors.green,
                onTap: () {
                   // When registering, we should pass the kid ID
                   // I'll update EventDetailScreen next
                },
              ),
              _DashboardActionCard(
                title: "Progress",
                icon: Icons.trending_up,
                color: Colors.blue,
                onTap: () {},
              ),
              _DashboardActionCard(
                title: "Certificates",
                icon: Icons.workspace_premium,
                color: Colors.amber,
                onTap: () {},
              ),
              _DashboardActionCard(
                title: "Edit Info",
                icon: Icons.edit,
                color: Colors.grey,
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SkaterDashboard extends ConsumerWidget {
  const _SkaterDashboard();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Skater Dashboard',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: "My Points",
                  value: "0",
                  icon: Icons.stars,
                  color: Colors.purple,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  label: "My Rank",
                  value: "-",
                  icon: Icons.leaderboard,
                  color: Colors.cyan,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              _DashboardActionCard(
                title: "Register Event",
                icon: Icons.event_available,
                color: Colors.green,
                onTap: () {},
              ),
              _DashboardActionCard(
                title: "My Results",
                icon: Icons.emoji_events,
                color: Colors.amber,
                onTap: () {},
              ),
              _DashboardActionCard(
                title: "Leaderboard",
                icon: Icons.assessment,
                color: Colors.blue,
                onTap: () {},
              ),
              _DashboardActionCard(
                title: "Refer & Earn",
                icon: Icons.share,
                color: Colors.pink,
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdminDashboard extends StatelessWidget {
  const _AdminDashboard();
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Admin Dashboard',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              Expanded(
                child: _StatCard(label: "Active Events", value: "...", icon: Icons.event, color: Colors.blue),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _StatCard(label: "Total Users", value: "...", icon: Icons.people, color: Colors.indigo),
              ),
            ],
          ),
          const SizedBox(height: 24),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              _DashboardActionCard(
                title: "Manage Events",
                icon: Icons.edit_calendar,
                color: Colors.deepOrange,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminEventsScreen())),
              ),
              _DashboardActionCard(
                title: "Manage Users",
                icon: Icons.manage_accounts,
                color: Colors.blueGrey,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminUsersScreen())),
              ),
              _DashboardActionCard(
                title: "Manage Results",
                icon: Icons.fact_check,
                color: Colors.amber,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminResultsScreen())),
              ),
              _DashboardActionCard(
                title: "Notifications",
                icon: Icons.campaign,
                color: Colors.redAccent,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _AdminNotificationsScreen())),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrganizerDashboard extends StatelessWidget {
  const _OrganizerDashboard();
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Organizer Dashboard',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              Expanded(
                child: _StatCard(label: "My Events", value: "...", icon: Icons.event, color: Colors.blue),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _StatCard(label: "Registrations", value: "...", icon: Icons.how_to_reg, color: Colors.teal),
              ),
            ],
          ),
          const SizedBox(height: 24),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              _DashboardActionCard(
                title: "Create Event",
                icon: Icons.add_circle_outline,
                color: Colors.green,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminEventsScreen())),
              ),
              _DashboardActionCard(
                title: "My Events",
                icon: Icons.event_note,
                color: Colors.blue,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminEventsScreen())),
              ),
              _DashboardActionCard(
                title: "Results",
                icon: Icons.emoji_events_outlined,
                color: Colors.amber,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminResultsScreen())),
              ),
              _DashboardActionCard(
                title: "Publishing",
                icon: Icons.ads_click,
                color: Colors.purple,
                onTap: () => context.push("/support", extra: "Interested in publishing/advertisement."),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SponsorDashboard extends StatelessWidget {
  const _SponsorDashboard();
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sponsor Portal',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              Expanded(
                child: _StatCard(label: "Brand Reach", value: "...", icon: Icons.trending_up, color: Colors.indigo),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _StatCard(label: "Active Ads", value: "0", icon: Icons.campaign, color: Colors.deepOrange),
              ),
            ],
          ),
          const SizedBox(height: 24),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              _DashboardActionCard(
                title: "View Events",
                icon: Icons.event,
                color: Colors.blue,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminEventsScreen())),
              ),
              _DashboardActionCard(
                title: "Leaderboard",
                icon: Icons.emoji_events,
                color: Colors.amber,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminResultsScreen())),
              ),
              _DashboardActionCard(
                title: "Sponsorship",
                icon: Icons.handshake,
                color: Colors.green,
                onTap: () => context.push("/support", extra: "Interested in sponsorship."),
              ),
              _DashboardActionCard(
                title: "Brand Ads",
                icon: Icons.campaign_outlined,
                color: Colors.purple,
                onTap: () => context.push("/support", extra: "Interested in advertisement."),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: color.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: color.withOpacity(0.2))),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: color)),
            Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color.withOpacity(0.8))),
          ],
        ),
      ),
    );
  }
}

class _DashboardActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _DashboardActionCard({required this.title, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(height: 12),
              Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SchedulePage extends ConsumerWidget {
  const _SchedulePage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(cachedProfileProvider);
    final kidsAsync = ref.watch(kidsProvider);
    final registrationsAsync = ref.watch(registrationsProvider);
    final selectedKidId = ref.watch(selectedKidProvider);

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

    final parent = profileAsync.value!;
    final allProfiles = [parent, ...kidsAsync.valueOrNull ?? []];

    return Column(
      children: [
        if (parent.role == "parent") ...[
          _HorizontalKidSwitcher(kids: kidsAsync.valueOrNull ?? []),
          const Divider(height: 1),
        ],
        Expanded(
          child: registrationsAsync.when(
            data: (registrations) {
              // Filter by selected kid if parent role
              final filteredRegistrations = parent.role == "parent" && selectedKidId != null
                  ? registrations.where((r) => r.userId == selectedKidId).toList()
                  : registrations;

              if (filteredRegistrations.isEmpty) {
                return const Center(child: Text("No scheduled events for this profile"));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filteredRegistrations.length + 1, // +1 for the header note
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.amber.shade900),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              "Meet Zest representative at Venue",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final r = filteredRegistrations[index - 1];
                  final event = r.event;
                  if (event == null) return const SizedBox.shrink();

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  event.title,
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.cyan.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  r.categoryName ?? "Registration",
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.cyan),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _IconTextRow(
                            icon: Icons.calendar_today,
                            text: DateFormat.yMMMd().add_jm().format(event.startAtUtc.toLocal()),
                          ),
                          const SizedBox(height: 8),
                          _IconTextRow(
                            icon: Icons.location_on_outlined,
                            text: "${event.locationName}${event.venueCity != null ? ", ${event.venueCity}" : ""}",
                          ),
                          const SizedBox(height: 8),
                          _IconTextRow(
                            icon: Icons.person_outline,
                            text: r.userName,
                          ),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Status: ${r.status.toUpperCase()}",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: r.status == "confirmed" ? Colors.green : Colors.orange,
                                ),
                              ),
                              const Icon(Icons.qr_code, size: 20, color: Colors.grey),
                            ],
                          ),
                        ],
                      ),
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
          ),
        ),
      ],
    );
  }
}

class _IconTextRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _IconTextRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
          ),
        ),
      ],
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
            decoration: InputDecoration(
              labelText: "Search events",
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.arrow_forward),
                onPressed: () {
                  // Trigger search if not real-time, but here it's already real-time.
                  // This provides a "button" feel as requested.
                  FocusScope.of(context).unfocus();
                },
              ),
            ),
            textInputAction: TextInputAction.search,
            onChanged: (value) {
              ref.read(searchQueryProvider.notifier).state = value;
              if (value.trim().isEmpty) {
                // Optionally clear results immediately
                ref.invalidate(searchResultsProvider);
              }
            },
            onSubmitted: (value) => ref.read(searchQueryProvider.notifier).state = value,
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
  final nameController = TextEditingController();
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
                  controller: nameController,
                  decoration: const InputDecoration(labelText: "Full Name"),
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
                  final fullName = nameController.text.trim();
                  if (fullName.isEmpty || dob == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Full name and DOB are required")),
                    );
                    return;
                  }
                  try {
                    await ref.read(profileRepositoryProvider).addKid(
                          firstName: fullName,
                          lastName: "",
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

class _AdminNotificationsScreen extends StatelessWidget {
  const _AdminNotificationsScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Notifications")),
      body: const Center(
        child: Text("Notification management coming soon."),
      ),
    );
  }
}
class _BannerCarousel extends StatefulWidget {
  final List<BannerModel> banners;
  const _BannerCarousel({required this.banners});

  @override
  State<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<_BannerCarousel> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) {
      return SizedBox(
        height: 160,
        child: _buildSingleBanner(
          title: "ZestS",
          imageUrlPath: "assets/images/zests_logo.png",
          isAsset: true,
          shareText: "Check out ZestS!",
          deepLinkUrl: "https://zests.app.link/home",
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 160,
          child: PageView.builder(
            controller: _controller,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemCount: widget.banners.length,
            itemBuilder: (context, index) {
              final b = widget.banners[index];
              final isAsset = b.imageUrl.startsWith("assets/");
              final shareText = [
                if ((b.title ?? "").trim().isNotEmpty) b.title!.trim(),
                if ((b.linkUrl ?? "").trim().isNotEmpty) b.linkUrl!.trim(),
                b.imageUrl.trim(),
              ].join("\n");

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _buildSingleBanner(
                  title: b.title?.trim().isNotEmpty == true ? b.title!.trim() : "ZestS",
                  imageUrlPath: b.imageUrl,
                  isAsset: isAsset,
                  shareText: shareText,
                  deepLinkUrl: b.shareUrl ?? "https://zests.app.link/home",
                ),
              );
            },
          ),
        ),
        if (widget.banners.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.banners.length,
                (index) => Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentPage == index ? Colors.cyan : Colors.grey.withAlpha(100),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSingleBanner({
    required String title,
    required String imageUrlPath,
    required bool isAsset,
    required String shareText,
    required String deepLinkUrl,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        context.push(
          "/banner",
          extra: BannerViewArgs(
            title: title,
            image: isAsset ? imageUrlPath : imageUrl(imageUrlPath),
            isAsset: isAsset,
            deepLinkUrl: deepLinkUrl,
            shareText: shareText,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(20),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              isAsset
                  ? Container(
                      color: Colors.grey[100],
                      width: double.infinity,
                      height: double.infinity,
                      child: Image.asset(imageUrlPath, fit: BoxFit.contain),
                    )
                  : CachedNetworkImage(
                      imageUrl: imageUrl(imageUrlPath),
                      height: double.infinity,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                      errorWidget: (context, url, error) => Image.asset(
                        "assets/images/zests_logo.png",
                        fit: BoxFit.contain,
                      ),
                    ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withAlpha(150),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 12,
                left: 12,
                right: 48,
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Positioned(
                bottom: 4,
                right: 4,
                child: IconButton(
                  icon: const Icon(Icons.share, color: Colors.white, size: 20),
                  onPressed: () => Share.share(shareText),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventCarousel extends StatelessWidget {
  final List<EventModel> events;
  const _EventCarousel({required this.events});

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const Card(
        child: ListTile(title: Text("No upcoming events")),
      );
    }

    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: events.length,
        itemBuilder: (context, index) {
          final e = events[index];
          return Container(
            width: 280,
            margin: const EdgeInsets.only(right: 16, bottom: 8, top: 4),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => context.push("/events/${e.id}"),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        child: e.bannerImageUrl != null && e.bannerImageUrl!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: imageUrl(e.bannerImageUrl),
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorWidget: (context, url, error) => _buildLogoPlaceholder(),
                              )
                            : _buildLogoPlaceholder(),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Flexible(
                            child: Text(
                              e.title,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Flexible(
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    DateFormat.yMMMd().format(e.startAtUtc.toLocal()),
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Flexible(
                            child: Row(
                              children: [
                                const Icon(Icons.location_on, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    e.locationName,
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLogoPlaceholder() {
    return Container(
      color: Colors.grey[100],
      width: double.infinity,
      child: Center(
        child: Image.asset(
          "assets/images/zests_logo.png",
          height: 60,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
