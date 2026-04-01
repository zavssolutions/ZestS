import "package:flutter_riverpod/flutter_riverpod.dart";
import "profile_providers.dart";

// State notifier to manage selected kid ID
class SelectedKidNotifier extends StateNotifier<String?> {
  SelectedKidNotifier() : super(null);

  void selectKid(String? kidId) {
    state = kidId;
  }

  void clearSelection() {
    state = null;
  }
}

final selectedKidProvider = StateNotifierProvider<SelectedKidNotifier, String?>((ref) {
  return SelectedKidNotifier();
});

// Provider to get the currently selected kid's profile
final selectedKidProfileProvider = Provider((ref) {
  final selectedId = ref.watch(selectedKidProvider);
  if (selectedId == null) return null;
  
  final kidsAsync = ref.watch(kidsProvider);
  return kidsAsync.whenOrNull(
    data: (kids) => kids.firstWhere((k) => k.id == selectedId),
  );
});
