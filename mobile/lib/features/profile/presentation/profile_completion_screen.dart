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
  String? _skillLevel;
  final _yearsSkatingController = TextEditingController();
  String? _preferredTracks;
  String? _skateType;
  String? _ageGroup;
  
  // Parent Kid Details
  final List<_KidFormModel> _kids = [_KidFormModel()];

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
      if (_kids.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("At least one kid is required for Parent role")),
        );
        return;
      }
      for (var i = 0; i < _kids.length; i++) {
        final kid = _kids[i];
        if (kid.firstNameController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Kid ${i + 1}'s first name is required")),
          );
          return;
        }
        if (kid.dob == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Kid ${i + 1}'s Date of Birth is mandatory")),
          );
          return;
        }
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
            skillLevel: _role == "skater" ? _skillLevel : null,
            yearsSkating: _role == "skater" ? int.tryParse(_yearsSkatingController.text.trim()) : null,
            preferredTracks: _role == "skater" ? _preferredTracks : null,
            skateType: _role == "skater" ? _skateType : null,
            ageGroup: _role == "skater" ? _ageGroup : null,
          );
          
      if (_role == "parent") {
        for (final kid in _kids) {
          await ref.read(profileRepositoryProvider).addKid(
                firstName: kid.firstNameController.text.trim(),
                lastName: kid.lastNameController.text.trim(),
                dob: kid.dob!,
                gender: kid.gender,
                skateType: kid.skateType,
                ageGroup: kid.ageGroup,
              );
        }
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

  void _addKid() {
    if (_kids.length < 3) {
      setState(() => _kids.add(_KidFormModel()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Maximum 3 kids allowed")),
      );
    }
  }

  void _removeKid(int index) {
    if (_kids.length > 1) {
      setState(() => _kids.removeAt(index));
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
              const Text("Kid Details (Max 3)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Text("At least one kid is mandatory", style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
              ..._kids.asMap().entries.map((entry) {
                final index = entry.key;
                final kid = entry.value;
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Kid #${index + 1}", style: const TextStyle(fontWeight: FontWeight.bold)),
                            if (_kids.length > 1)
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _removeKid(index),
                              ),
                          ],
                        ),
                        TextField(
                          controller: kid.firstNameController,
                          decoration: const InputDecoration(labelText: "Kid's First name *"),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: kid.lastNameController,
                          decoration: const InputDecoration(labelText: "Kid's Last name (optional)"),
                        ),
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
                            if (picked != null) setState(() => kid.dob = picked);
                          },
                          child: Text(kid.dob == null ? "Kid's DOB * (Required)" : "Kid's DOB: ${kid.dob!.toLocal().toIso8601String().split("T")[0]}"),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: kid.gender,
                          decoration: const InputDecoration(labelText: "Kid's Gender"),
                          items: const [
                            DropdownMenuItem(value: "male", child: Text("Male")),
                            DropdownMenuItem(value: "female", child: Text("Female")),
                            DropdownMenuItem(value: "other", child: Text("Other")),
                            DropdownMenuItem(value: "unspecified", child: Text("Unspecified")),
                          ],
                          onChanged: (val) => setState(() => kid.gender = val ?? "unspecified"),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: kid.skateType,
                          decoration: const InputDecoration(labelText: "Kid's Skate Type"),
                          items: _skateTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                          onChanged: (val) => setState(() => kid.skateType = val),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: kid.ageGroup,
                          decoration: const InputDecoration(labelText: "Kid's Age Group"),
                          items: _ageGroups.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                          onChanged: (val) => setState(() => kid.ageGroup = val),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              if (_kids.length < 3)
                TextButton.icon(
                  onPressed: _addKid,
                  icon: const Icon(Icons.add),
                  label: const Text("Add Another Kid"),
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
              DropdownButtonFormField<String>(
                value: _skillLevel,
                decoration: const InputDecoration(labelText: "Skill Level (1-10)"),
                items: List.generate(10, (i) => (i + 1).toString()).map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (val) => setState(() => _skillLevel = val),
              ),
              const SizedBox(height: 12),
              TextField(controller: _yearsSkatingController, decoration: const InputDecoration(labelText: "Years Skating"), keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _preferredTracks,
                decoration: const InputDecoration(labelText: "Preferred Tracks"),
                items: ["Road", "Rink", "Ice", "Artistic"].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (val) => setState(() => _preferredTracks = val),
              ),
              const SizedBox(height: 12),
              TextField(controller: _schoolNameController, decoration: const InputDecoration(labelText: "School Name")),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _skateType,
                decoration: const InputDecoration(labelText: "Skate Type"),
                items: _skateTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (val) => setState(() => _skateType = val),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _ageGroup,
                decoration: const InputDecoration(labelText: "Age Group"),
                items: _ageGroups.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                onChanged: (val) => setState(() => _ageGroup = val),
              ),
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

class _KidFormModel {
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  DateTime? dob;
  String gender = "unspecified";
  String? skateType;
  String? ageGroup;
}
