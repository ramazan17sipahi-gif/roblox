import 'dart:ui';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';
import '../l10n/generated/app_localizations.dart';
import '../features/editor/presentation/widgets/classic_clothing_selector.dart';
import 'shell_tab_provider.dart';

class ScaffoldShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const ScaffoldShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.read(shellBranchIndexProvider.notifier).state = navigationShell.currentIndex;

    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: _GlassBottomBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) {
          if (index == 2) {
            ClassicClothingSelector.show(context);
            return;
          }

          final branchIndex = index > 2 ? index - 1 : index;
          ref.read(shellBranchIndexProvider.notifier).state = branchIndex;
          navigationShell.goBranch(
            branchIndex,
            initialLocation: branchIndex == navigationShell.currentIndex,
          );
        },
      ),
    );
  }
}

class _GlassBottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _GlassBottomBar({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _NavBarItem(
                icon: Icons.home_filled,
                label: AppLocalizations.of(context).navHome,
                isSelected: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              _NavBarItem(
                icon: Icons.explore,
                label: AppLocalizations.of(context).navExplore,
                isSelected: currentIndex == 1,
                onTap: () => onTap(1),
              ),
              _NavBarItem(
                icon: Icons.add_circle,
                label: AppLocalizations.of(context).navCreate,
                isSelected: false,
                onTap: () => onTap(2),
              ),
              _NavBarItem(
                icon: Icons.inventory_2,
                label: AppLocalizations.of(context).navLibrary,
                isSelected: currentIndex == 2,
                onTap: () => onTap(3),
              ),
              _NavBarItem(
                icon: Icons.dashboard_customize_rounded,
                label: AppLocalizations.of(context).navTemplates,
                isSelected: currentIndex == 3,
                onTap: () => onTap(4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected ? AppColors.primary : AppColors.outlineVariant,
            ),
            SizedBox(height: 4),
            Text(
              label.toUpperCase(),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: isSelected ? AppColors.primary : AppColors.outlineVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
