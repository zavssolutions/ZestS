import "package:cached_network_image/cached_network_image.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../data/profile_providers.dart";
import "package:go_router/go_router.dart";
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
              if (profile.role == "parent") ...[
                const SizedBox(height: 24),
                const Text("My Kids", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Consumer(
                  builder: (context, ref, child) {
                    final kidsAsync = ref.watch(kidsProvider);
                    return kidsAsync.when(
                      data: (kids) {
                        if (kids.isEmpty) return const Text("No kids added yet.");
                        return Column(
                          children: kids.map((kid) => ListTile(
                            leading: const CircleAvatar(child: Icon(Icons.person)),
                            title: Text("${kid.firstName} ${kid.lastName ?? ''}"),
                            subtitle: Text("DOB: ${kid.dobDateTime?.toLocal().toIso8601String().split('T')[0] ?? 'N/A'}"),
                          )).toList(),
                        );
                      },
                      loading: () => const LinearProgressIndicator(),
                      error: (e, s) => Text("Error loading kids: $e"),
                    );
                  },
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                     // Navigate to ProfileCompletionScreen or a dedicated Add Kid screen
                     // Since ProfileCompletionScreen is already multi-kid aware, we could reuse it
                     // but it's better to have a dedicated "Add Kid" flow or a simplified one.
                     // For now, I'll redirect to a simplified "Add Kid" dialog or screen if it exists.
                     context.push("/profile/add-kid");
                  },
                  icon: const Icon(Icons.add),
                  label: const Text("Add Another Kid"),
                ),
              ],
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
