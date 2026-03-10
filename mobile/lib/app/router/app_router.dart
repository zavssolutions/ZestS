import "dart:async";

import "package:app_links/app_links.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../features/auth/presentation/login_screen.dart";
import "../../features/auth/presentation/phone_auth_screen.dart";
import "../../features/events/presentation/event_detail_screen.dart";
import "../../features/home/presentation/about_screen.dart";
import "../../features/home/presentation/home_screen.dart";
import "../../features/onboarding/presentation/onboarding_screen.dart";
import "../../features/profile/presentation/profile_screen.dart";
import "../../features/profile/presentation/profile_completion_screen.dart";
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
      GoRoute(path: "/home", builder: (context, state) => const HomeScreen()),
      GoRoute(path: "/profile", builder: (context, state) => const ProfileScreen()),
      GoRoute(path: "/profile-complete", builder: (context, state) => const ProfileCompletionScreen()),
      GoRoute(path: "/about", builder: (context, state) => const AboutScreen()),
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
    }
  });
  ref.onDispose(() => subscription.cancel());
});

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
