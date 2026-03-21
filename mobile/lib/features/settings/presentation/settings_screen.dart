import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/storage.dart";

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notifications = true;
  bool _location = false;

  Future<void> _load() async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    setState(() {
      _notifications = prefs.getBool("pref_notifications") ?? true;
      _location = prefs.getBool("pref_location") ?? false;
    });
  }

  Future<void> _save(String key, bool value) async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setBool(key, value);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text("Notifications"),
            value: _notifications,
            onChanged: (value) {
              setState(() => _notifications = value);
              _save("pref_notifications", value);
            },
          ),
        ],
      ),
    );
  }
}
