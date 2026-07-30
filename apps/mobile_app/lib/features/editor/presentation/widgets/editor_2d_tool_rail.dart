import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

/// Vertical 2D drawing tool rail (hand, brush, fill, eraser, …).
class Editor2DToolRail extends StatelessWidget {
  final List<(IconData, String)> tools;
  final int activeIndex;
  final ValueChanged<int> onSelect;

  const Editor2DToolRail({
    super.key,
    required this.tools,
    required this.activeIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 44,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: tools.length,
          separatorBuilder: (_, __) => const SizedBox(height: 4),
          itemBuilder: (_, index) {
            final isActive = index == activeIndex;
            final (icon, label) = tools[index];
            return Semantics(
              button: true,
              label: label,
              selected: isActive,
              child: GestureDetector(
                onTap: () => onSelect(index),
                child: Tooltip(
                  message: label,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    height: 40,
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.primary.withValues(alpha: 0.14)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: isActive
                          ? Border.all(color: AppColors.primary.withValues(alpha: 0.35))
                          : null,
                    ),
                    child: Icon(
                      icon,
                      size: 20,
                      color: isActive ? AppColors.primary : AppColors.outlineVariant,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
