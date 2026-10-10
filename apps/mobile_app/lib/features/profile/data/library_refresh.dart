import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bumped after editor save/exit so Library reloads.
final libraryRefreshProvider = StateProvider<int>((ref) => 0);

void notifyLibraryChanged(WidgetRef ref) {
  ref.read(libraryRefreshProvider.notifier).state++;
}

void notifyLibraryChangedFromContext(ProviderContainer container) {
  container.read(libraryRefreshProvider.notifier).state++;
}
