import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../shared/widgets/primary_button.dart";
import "../application/auth_controller.dart";

class PhoneAuthScreen extends ConsumerStatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  ConsumerState<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends ConsumerState<PhoneAuthScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);

    ref.listen(authControllerProvider, (previous, next) {
      if ((next.error ?? "").isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!)),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text("Phone Verification")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: "Phone number",
                hintText: "+91XXXXXXXXXX",
              ),
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: "Send OTP",
              loading: state.loading,
              onPressed: () async {
                await ref.read(authControllerProvider.notifier).sendOtp(_phoneController.text.trim());
              },
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Enter OTP",
              ),
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: "Verify",
              loading: state.loading,
              onPressed: () async {
                final ok = await ref.read(authControllerProvider.notifier).verifyOtp(_otpController.text.trim());
                if (ok && context.mounted) {
                    context.go("/home");
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
