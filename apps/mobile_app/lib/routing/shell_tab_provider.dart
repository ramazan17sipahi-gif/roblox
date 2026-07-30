import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

/// Active branch index inside [StatefulShellRoute.indexedStack].
/// Updated by [ScaffoldShell] so tab pages can defer heavy fetches until first visit.
final shellBranchIndexProvider = StateProvider<int>((ref) => 0);

/// Mixin for shell tab pages: loads data only when the tab becomes active (once).
mixin LazyShellTabLoader<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  int get shellBranchIndex;

  bool _lazyLoaded = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(shellBranchIndexProvider, (prev, next) {
      if (next == shellBranchIndex && !_lazyLoaded) {
        _lazyLoaded = true;
        onLazyTabLoad();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(shellBranchIndexProvider) == shellBranchIndex && !_lazyLoaded) {
        _lazyLoaded = true;
        onLazyTabLoad();
      }
    });
  }

  void onLazyTabLoad();
}
