import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "app_startup.dart";
import "router/app_router.dart";
import "theme/app_theme.dart";

class ZestsApp extends ConsumerWidget {
  const ZestsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(appStartupProvider);
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: "ZestS",
      theme: buildAppTheme(),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
