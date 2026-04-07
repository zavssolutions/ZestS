import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../data/profile_providers.dart";

class AddKidScreen extends ConsumerStatefulWidget {
  const AddKidScreen({super.key});

  @override
  ConsumerState<AddKidScreen> createState() => _AddKidScreenState();
}

class _AddKidScreenState extends ConsumerState<AddKidScreen> {
  final _nameController = TextEditingController();
  DateTime? _dob;
  String _gender = "unspecified";
  String? _skateType;
  String? _ageGroup;
  bool _saving = false;

  final _skateTypes = ["Inline", "Quad", "Toy inline", "tenacity"];
  final _ageGroups = [
    "under_5",
    "cadet(5-7)",
    "sub-junior(7-9)",
    "sub-junior(9-11)",
    "junior(11-14)",
    "junior(14-17)",
    "senior(17_above)"
  ];

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _dob == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Full Name and Date of Birth are mandatory")),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(profileRepositoryProvider).addKid(
            firstName: name, // Entire name string to first_name
            lastName: "",    // Empty string to last_name
            dob: _dob!,
            gender: _gender,
            skateType: _skateType,
            ageGroup: _ageGroup,
          );
      
      ref.invalidate(kidsProvider);
      ref.invalidate(cachedProfileProvider);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Kid added successfully")),
      );
      context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Unable to add kid: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Another Kid")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "Full Name *",
                hintText: "Enter the kid's full name",
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime(now.year - 8, 1, 1),
                  firstDate: DateTime(2005, 1, 1),
                  lastDate: now,
                );
                if (picked != null) setState(() => _dob = picked);
              },
              icon: const Icon(Icons.calendar_today),
              label: Text(_dob == null 
                ? "Select Date of Birth *" 
                : "DOB: ${_dob!.toLocal().toIso8601String().split("T")[0]}"),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _gender,
              decoration: const InputDecoration(labelText: "Gender"),
              items: const [
                DropdownMenuItem(value: "male", child: Text("Male")),
                DropdownMenuItem(value: "female", child: Text("Female")),
                DropdownMenuItem(value: "other", child: Text("Other")),
                DropdownMenuItem(value: "unspecified", child: Text("Unspecified")),
              ],
              onChanged: (val) => setState(() => _gender = val ?? "unspecified"),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _skateType,
              decoration: const InputDecoration(labelText: "Skate Type"),
              items: _skateTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (val) => setState(() => _skateType = val),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _ageGroup,
              decoration: const InputDecoration(labelText: "Age Group"),
              items: _ageGroups.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
              onChanged: (val) => setState(() => _ageGroup = val),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _saving ? null : _submit,
                child: Text(_saving ? "Saving..." : "Add Kid"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
