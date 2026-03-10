import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/api_client.dart";

class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key});

  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();
  bool _sending = false;

  Future<void> _submit() async {
    if (_sending) return;
    final message = _messageController.text.trim();
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
        data: {"email": _emailController.text.trim(), "message": message},
      );
      _messageController.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Issue submitted")),
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
              decoration: const InputDecoration(labelText: "Email (optional)"),
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
