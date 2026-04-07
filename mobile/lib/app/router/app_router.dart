import "dart:async";

import "package:app_links/app_links.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../features/auth/presentation/login_screen.dart";
import "../../features/auth/presentation/phone_auth_screen.dart";
import "../../features/auth/presentation/email_auth_screen.dart";
import "../../features/events/presentation/event_detail_screen.dart";
import "../../features/home/presentation/about_screen.dart";
import "../../features/home/presentation/banner_view_screen.dart";
import "../../features/home/presentation/home_screen.dart";
import "../../features/onboarding/presentation/onboarding_screen.dart";
import "../../features/profile/presentation/profile_screen.dart";
import "../../features/profile/presentation/add_kid_screen.dart";
import "../../features/support/presentation/support_screen.dart";
import "../../features/settings/presentation/settings_screen.dart";
import "../../features/profile/data/profile_providers.dart";
import "../../core/storage.dart";
import "../../core/api_client.dart";
import "../../features/profile/presentation/profile_completion_screen.dart";
import "../../features/admin/presentation/admin_screens.dart";
import "../../features/home/data/banner_model.dart";
import "../../features/home/data/banners_repository.dart";
import "startup_gate_screen.dart";

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: "/",
    routes: [
      GoRoute(path: "/", builder: (context, state) => const StartupGateScreen()),
      GoRoute(path: "/onboarding", builder: (context, state) => const OnboardingScreen()),
      GoRoute(path: "/login", builder: (context, state) => const LoginScreen()),
      GoRoute(path: "/phone-auth", builder: (context, state) => const PhoneAuthScreen()),
      GoRoute(path: "/email-auth", builder: (context, state) => const EmailAuthScreen()),
      GoRoute(path: "/home", builder: (context, state) => const HomeScreen()),
      GoRoute(path: "/profile", builder: (context, state) => const ProfileScreen()),
      GoRoute(path: "/profile/add-kid", builder: (context, state) => const AddKidScreen()),
      GoRoute(path: "/support", builder: (context, state) => SupportScreen(prefilledMessage: state.extra as String?)),
      GoRoute(path: "/settings", builder: (context, state) => const SettingsScreen()),
      GoRoute(path: "/profile-complete", builder: (context, state) => const ProfileCompletionScreen()),
      GoRoute(path: "/about", builder: (context, state) => const AboutScreen()),
      GoRoute(
        path: "/banner",
        builder: (context, state) => BannerViewScreen(args: state.extra! as BannerViewArgs),
      ),
      GoRoute(
        path: "/banner/:bannerId",
        builder: (context, state) => _AsyncBannerRoute(bannerId: state.pathParameters["bannerId"]!),
      ),
      GoRoute(path: "/admin", builder: (context, state) => const AdminDashboardScreen()),
      GoRoute(
        path: "/events/:eventId",
        builder: (context, state) => EventDetailScreen(eventId: state.pathParameters["eventId"]!),
      ),
      GoRoute(
        path: "/force-update",
        builder: (context, state) => const _ForceUpdateScreen(),
      ),
    ],
  );

  ref.onDispose(router.dispose);
  ref.watch(appLinksBootstrapProvider(router));
  return router;
});

final appLinksBootstrapProvider = Provider.family<void, GoRouter>((ref, router) {
  final appLinks = AppLinks();
  late final StreamSubscription subscription;
  subscription = appLinks.uriLinkStream.listen((uri) {
    final segments = uri.pathSegments;
    if (segments.length >= 2 && segments[0] == "event") {
      final eventId = segments[1];
      router.go("/events/$eventId");
      final referrer = uri.queryParameters["referrer"];
      if (referrer != null && referrer.isNotEmpty) {
        _handleReferral(ref, eventId, referrer);
      }
    } else if (segments.length >= 2 && segments[0] == "banner") {
      final bannerId = segments[1];
      router.go("/banner/$bannerId");
    }
  });
  ref.onDispose(() => subscription.cancel());
});

Future<void> _handleReferral(Ref ref, String eventId, String referrerId) async {
  final profile = await ref.read(profileRepositoryProvider).readCachedProfile();
  if (profile == null) {
    return;
  }
  final prefs = await ref.read(sharedPreferencesProvider.future);
  final key = "referral_install_${eventId}_$referrerId";
  final installed = prefs.getBool(key) ?? false;
  final payload = {"referrer_user_id": referrerId, "referred_user_id": profile.id};
  if (!installed) {
    await ref.read(dioProvider).post("/events/$eventId/referrals/install", data: payload);
    await prefs.setBool(key, true);
  }
  await ref.read(dioProvider).post("/events/$eventId/referrals/view", data: payload);
}

class _ForceUpdateScreen extends StatelessWidget {
  const _ForceUpdateScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            "Update required. Please install the latest app version.",
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _AsyncBannerRoute extends ConsumerStatefulWidget {
  const _AsyncBannerRoute({required this.bannerId});

  final String bannerId;

  @override
  ConsumerState<_AsyncBannerRoute> createState() => _AsyncBannerRouteState();
}

class _AsyncBannerRouteState extends ConsumerState<_AsyncBannerRoute> {
  BannerModel? _banner;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBanner();
  }

  Future<void> _loadBanner() async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get<Map<String, dynamic>>("/banners/${widget.bannerId}");
      if (response.data != null) {
        if (mounted) {
          setState(() {
            _banner = BannerModel.fromJson(response.data!);
          });
        }
      } else {
        throw Exception("Banner not found");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Unable to load banner.";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Error")),
        body: Center(child: Text(_error!)),
      );
    }
    if (_banner == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final shareText = [
      if ((_banner!.title ?? "").trim().isNotEmpty) _banner!.title!.trim(),
      if ((_banner!.linkUrl ?? "").trim().isNotEmpty) _banner!.linkUrl!.trim(),
      _banner!.imageUrl.trim(),
    ].join("\n");

    return BannerViewScreen(
      args: BannerViewArgs(
        title: _banner!.title ?? "Banner",
        image: _banner!.imageUrl,
        isAsset: _banner!.imageUrl.startsWith("assets/"),
        deepLinkUrl: _banner!.shareUrl ?? "https://zests.app.link/banner/${_banner!.id}",
        shareText: shareText,
      ),
    );
  }
}
