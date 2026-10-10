import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'ds_button.dart';

class DSUpgradeBanner extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onUpgrade;

  const DSUpgradeBanner({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.1),
            AppColors.primaryLight.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.workspace_premium, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textMediumEmphasis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          DSButton(
            label: 'Upgrade',
            variant: DSButtonVariant.primary,
            isFullWidth: false,
            onPressed: onUpgrade,
          )
        ],
      ),
    );
  }
}
