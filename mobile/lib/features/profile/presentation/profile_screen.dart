import "package:cached_network_image/cached_network_image.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../data/profile_providers.dart";

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(cachedProfileProvider);
    return Scaffold(
      appBar: AppBar(title: const Text("My Profile")),
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text("Profile not available"));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              CircleAvatar(
                radius: 36,
                backgroundImage: profile.profilePictureUrl != null
                    ? CachedNetworkImageProvider(profile.profilePictureUrl!)
                    : null,
                child: profile.profilePictureUrl == null ? const Icon(Icons.person) : null,
              ),
              const SizedBox(height: 16),
              Text(profile.displayName, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text("Role: ${profile.role}"),
              Text("Favorite sport: ${profile.favoriteSport ?? "skating"}"),
            ],
          );
        },
        error: (error, stackTrace) => const Center(child: Text("Unable to load profile")),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
