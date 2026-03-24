import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/api_client.dart";

class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({this.prefilledMessage, super.key});

  final String? prefilledMessage;

  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  late final TextEditingController _emailController;
  late final TextEditingController _messageController;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _messageController = TextEditingController(text: widget.prefilledMessage);
  }

  Future<void> _submit() async {
    if (_sending) return;
    final email = _emailController.text.trim();
    final message = _messageController.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Email is required")),
      );
      return;
    }
    
    // Simple email regex validation
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid email address")),
      );
      return;
    }

    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter your issue")),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      await ref.read(dioProvider).post(
        "/support/issues",
        data: {"email": email, "message": message},
      );
      _emailController.clear();
      _messageController.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Issue submitted. Admins have been notified.")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to submit: $e")),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Support")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: "Email"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _messageController,
              maxLines: 6,
              decoration: const InputDecoration(labelText: "Describe your issue"),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _sending ? null : _submit,
              child: Text(_sending ? "Sending..." : "Submit"),
            ),
          ],
        ),
      ),
    );
  }
}
