import "package:cached_network_image/cached_network_image.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../data/profile_providers.dart";
import "../../../core/constants.dart";

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
                 backgroundImage: profile.profilePictureUrl != null && profile.profilePictureUrl!.isNotEmpty
                    ? CachedNetworkImageProvider(imageUrl(profile.profilePictureUrl))
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
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text("We couldn't load your profile details."),
                SizedBox(height: 8),
                Text("Please try again later."),
              ],
            ),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
