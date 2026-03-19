import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

import "../../../core/constants.dart";
import "../../../core/storage.dart";
import "../../../shared/widgets/zests_logo.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  final _slides = const [
    "Track your matches",
    "Compete with the best.",
    "Join the ZestS community.",
  ];

  Future<void> _finish() async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setBool(kFirstOpenKey, false);
    if (!mounted) {
      return;
    }
    context.go("/home");
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _index == _slides.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            const ZestsLogo(size: 80),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _slides[i],
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: isLast
                    ? _finish
                    : () => _controller.nextPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                        ),
                child: Text(isLast ? "Continue" : "Next"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
