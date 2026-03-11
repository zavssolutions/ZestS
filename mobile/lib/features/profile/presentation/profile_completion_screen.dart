import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../data/profile_providers.dart";
import "../../../app/app_startup.dart";

class ProfileCompletionScreen extends ConsumerStatefulWidget {
  const ProfileCompletionScreen({super.key});

  @override
  ConsumerState<ProfileCompletionScreen> createState() => _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState extends ConsumerState<ProfileCompletionScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  DateTime? _dob;
  bool _saving = false;

  Future<void> _submit() async {
    if (_saving) return;
    final first = _firstNameController.text.trim();
    final last = _lastNameController.text.trim();
    if (first.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("First name is required")),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(profileRepositoryProvider).updateProfile(
            firstName: first,
            lastName: last,
            dob: _dob,
          );
      ref.invalidate(cachedProfileProvider);
      ref.invalidate(startupDestinationProvider);
      
      if (!mounted) return;
      context.go("/home");
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Unable to save profile: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 12, 1, 1),
      firstDate: DateTime(1950, 1, 1),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => _dob = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Complete Profile")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Let’s set up your profile",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _firstNameController,
              decoration: const InputDecoration(labelText: "First name"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _lastNameController,
              decoration: const InputDecoration(labelText: "Last name"),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _pickDob,
              child: Text(_dob == null ? "Select DOB (optional)" : "DOB: ${_dob!.toLocal().toIso8601String().split("T")[0]}"),
            ),
            const SizedBox(height: 12),
            const Text("Favorite sport: Skating"),
            const Spacer(),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: Text(_saving ? "Saving..." : "Continue"),
            ),
          ],
        ),
      ),
    );
  }
}
