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
  
  // Trainer
  final _schoolNameController = TextEditingController();
  final _clubNameController = TextEditingController();
  final _specializationController = TextEditingController();
  final _experienceYearsController = TextEditingController();
  
  // Organizer
  final _orgNameController = TextEditingController();
  final _websiteUrlController = TextEditingController();
  
  // Skater
  final _skillLevelController = TextEditingController();
  final _yearsSkatingController = TextEditingController();
  final _preferredTracksController = TextEditingController();

  // Parent Kid Details
  final _kidFirstNameController = TextEditingController();
  final _kidLastNameController = TextEditingController();
  DateTime? _kidDob;
  String _kidGender = "unspecified";

  DateTime? _dob;
  String? _role;
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
    
    if (_role == "organizer" && _orgNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Organization name is required")),
      );
      return;
    }
    
    if (_role == "skater" && _dob == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Date of Birth is mandatory for Skater")),
      );
      return;
    }
    
    if (_role == "parent") {
      if (_kidFirstNameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Kid's first name is required")),
        );
        return;
      }
      if (_kidDob == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Kid's Date of Birth is mandatory")),
        );
        return;
      }
    }

    setState(() => _saving = true);
    try {
      await ref.read(profileRepositoryProvider).updateProfile(
            firstName: first,
            lastName: last,
            dob: _dob,
            role: _role,
            schoolName: _role == "trainer" || _role == "skater" ? _schoolNameController.text.trim() : null,
            clubName: _role == "trainer" ? _clubNameController.text.trim() : null,
            specialization: _role == "trainer" ? _specializationController.text.trim() : null,
            experienceYears: _role == "trainer" ? int.tryParse(_experienceYearsController.text.trim()) : null,
            orgName: _role == "organizer" ? _orgNameController.text.trim() : null,
            websiteUrl: _role == "organizer" ? _websiteUrlController.text.trim() : null,
            skillLevel: _role == "skater" ? _skillLevelController.text.trim() : null,
            yearsSkating: _role == "skater" ? int.tryParse(_yearsSkatingController.text.trim()) : null,
            preferredTracks: _role == "skater" ? _preferredTracksController.text.trim() : null,
          );
          
      if (_role == "parent") {
        await ref.read(profileRepositoryProvider).addKid(
              firstName: _kidFirstNameController.text.trim(),
              lastName: _kidLastNameController.text.trim(),
              dob: _kidDob!,
              gender: _kidGender,
            );
      }
          
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
        child: ListView(
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
              child: Text(_dob == null ? "Select Date of Birth" : "DOB: ${_dob!.toLocal().toIso8601String().split("T")[0]}"),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _role,
              decoration: const InputDecoration(labelText: "Role"),
              items: const [
                DropdownMenuItem(value: "parent", child: Text("Parent")),
                DropdownMenuItem(value: "trainer", child: Text("Trainer")),
                DropdownMenuItem(value: "organizer", child: Text("Organizer")),
                DropdownMenuItem(value: "admin", child: Text("Admin")),
                DropdownMenuItem(value: "skater", child: Text("Skater")),
                DropdownMenuItem(value: "sponsor", child: Text("Sponsor")),
              ],
              onChanged: (val) => setState(() => _role = val),
            ),
            
            if (_role == "parent") ...[
              const SizedBox(height: 16),
              const Text("Kid Details", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(controller: _kidFirstNameController, decoration: const InputDecoration(labelText: "Kid's First name *")),
              const SizedBox(height: 12),
              TextField(controller: _kidLastNameController, decoration: const InputDecoration(labelText: "Kid's Last name (optional)")),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime(now.year - 8, 1, 1),
                    firstDate: DateTime(2005, 1, 1),
                    lastDate: now,
                  );
                  if (picked != null) setState(() => _kidDob = picked);
                },
                child: Text(_kidDob == null ? "Kid's DOB * (Required)" : "Kid's DOB: ${_kidDob!.toLocal().toIso8601String().split("T")[0]}"),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _kidGender,
                decoration: const InputDecoration(labelText: "Kid's Gender"),
                items: const [
                  DropdownMenuItem(value: "male", child: Text("Male")),
                  DropdownMenuItem(value: "female", child: Text("Female")),
                  DropdownMenuItem(value: "other", child: Text("Other")),
                  DropdownMenuItem(value: "unspecified", child: Text("Unspecified")),
                ],
                onChanged: (val) => setState(() => _kidGender = val ?? "unspecified"),
              ),
            ],
            
            if (_role == "trainer") ...[
              const SizedBox(height: 12),
              TextField(controller: _schoolNameController, decoration: const InputDecoration(labelText: "School name")),
              const SizedBox(height: 12),
              TextField(controller: _clubNameController, decoration: const InputDecoration(labelText: "Club name")),
              const SizedBox(height: 12),
              TextField(controller: _specializationController, decoration: const InputDecoration(labelText: "Specialization")),
              const SizedBox(height: 12),
              TextField(controller: _experienceYearsController, decoration: const InputDecoration(labelText: "Experience (years)"), keyboardType: TextInputType.number),
            ],
            
            if (_role == "organizer") ...[
              const SizedBox(height: 12),
              TextField(controller: _orgNameController, decoration: const InputDecoration(labelText: "Organization Name *")),
              const SizedBox(height: 12),
              TextField(controller: _websiteUrlController, decoration: const InputDecoration(labelText: "Website URL")),
            ],
            
            if (_role == "skater") ...[
              const SizedBox(height: 12),
              TextField(controller: _skillLevelController, decoration: const InputDecoration(labelText: "Skill Level")),
              const SizedBox(height: 12),
              TextField(controller: _yearsSkatingController, decoration: const InputDecoration(labelText: "Years Skating"), keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              TextField(controller: _preferredTracksController, decoration: const InputDecoration(labelText: "Preferred Tracks")),
              const SizedBox(height: 12),
              TextField(controller: _schoolNameController, decoration: const InputDecoration(labelText: "School Name")),
            ],

            const SizedBox(height: 12),
            const Text("Favorite sport: Skating"),
            const SizedBox(height: 24),
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
