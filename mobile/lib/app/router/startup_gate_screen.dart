import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../app_startup.dart";
import "../../shared/widgets/app_loading_screen.dart";

class StartupGateScreen extends ConsumerWidget {
  const StartupGateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startup = ref.watch(startupDestinationProvider);

    return startup.when(
      loading: () => const AppLoadingScreen(),
      error: (error, stackTrace) => const Scaffold(body: Center(child: Text("Startup failed"))),
      data: (destination) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          switch (destination) {
            case StartupDestination.home:
              context.go("/home");
              break;
            case StartupDestination.onboarding:
              context.go("/onboarding");
              break;
            case StartupDestination.login:
              context.go("/login");
              break;
            case StartupDestination.forceUpdate:
              context.go("/force-update");
              break;
            case StartupDestination.profileCompletion:
              context.go("/profile-complete");
              break;
          }
        });
        return const AppLoadingScreen();
      },
    );
  }
}
