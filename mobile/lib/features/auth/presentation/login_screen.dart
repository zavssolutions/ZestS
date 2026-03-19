import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:url_launcher/url_launcher.dart";

import "../../../app/app_startup.dart";
import "../../../core/constants.dart";
import "../../../shared/widgets/primary_button.dart";
import "../../../shared/widgets/zests_logo.dart";
import "../application/auth_controller.dart";

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _acceptedTerms = false;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final remoteConfigAsync = ref.watch(remoteConfigProvider);

    ref.listen(authControllerProvider, (previous, next) {
      if ((next.error ?? "").isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!)),
        );
      }
    });

    final phoneEnabled = remoteConfigAsync.valueOrNull?.phoneAuthEnabled ?? true;
    final googleEnabled = remoteConfigAsync.valueOrNull?.googleAuthEnabled ?? true;

    return Scaffold(
      appBar: AppBar(title: const Text("Login")),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              const Center(child: ZestsLogo(size: 90)),
              const SizedBox(height: 24),
              const Text(
                "Login to continue",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _acceptedTerms,
                onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
                title: GestureDetector(
                  onTap: () async {
                    await launchUrl(Uri.parse(kTermsPageUrl));
                  },
                  child: const Text("I agree to Terms and Conditions"),
                ),
              ),
              const SizedBox(height: 10),
              if (googleEnabled)
                PrimaryButton(
                  label: "Authenticate with Google",
                  loading: authState.loading,
                  onPressed: !_acceptedTerms
                      ? null
                      : () async {
                          final ok = await ref.read(authControllerProvider.notifier).signInWithGoogle();
                          if (ok && context.mounted) {
                            context.go("/");
                          }
                        },
                ),
              const SizedBox(height: 10),
              if (phoneEnabled)
                OutlinedButton(
                  onPressed: !_acceptedTerms ? null : () => context.push("/phone-auth"),
                  child: const Text("Verify with Phone Number"),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
