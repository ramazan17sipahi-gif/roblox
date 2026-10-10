import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum DSButtonVariant { primary, secondary, outline, text }

class DSButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final DSButtonVariant variant;
  final bool isLoading;
  final bool isFullWidth;
  final IconData? icon;

  const DSButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = DSButtonVariant.primary,
    this.isLoading = false,
    this.isFullWidth = true,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    Widget buttonChild = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading)
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          )
        else if (icon != null)
          Icon(icon, size: 20),
        
        if (isLoading || icon != null) const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: variant == DSButtonVariant.primary ? Colors.white : null,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );

    if (variant == DSButtonVariant.primary) {
      return Container(
        width: isFullWidth ? double.infinity : null,
        height: 60,
        decoration: BoxDecoration(
          gradient: AppColors.actionGradient,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.12),
              blurRadius: 24,
              offset: const Offset(0, 12),
            )
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(30),
            onTap: isLoading ? null : onPressed,
            child: Center(child: buttonChild),
          ),
        ),
      );
    }

    // Other variants
    Widget btn;
    switch (variant) {
      case DSButtonVariant.secondary:
        btn = ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.surfaceContainerLow,
            foregroundColor: AppColors.onBackground,
            minimumSize: Size(isFullWidth ? double.infinity : 0, 60),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            elevation: 0,
          ),
          onPressed: isLoading ? null : onPressed,
          child: buttonChild,
        );
        break;
      case DSButtonVariant.outline:
        btn = OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: Size(isFullWidth ? double.infinity : 0, 60),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            side: BorderSide(color: AppColors.outlineVariant.withOpacity(0.2)),
          ),
          onPressed: isLoading ? null : onPressed,
          child: buttonChild,
        );
        break;
      case DSButtonVariant.text:
        btn = TextButton(
          style: TextButton.styleFrom(
            minimumSize: Size(isFullWidth ? double.infinity : 0, 60),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
          onPressed: isLoading ? null : onPressed,
          child: buttonChild,
        );
        break;
      default:
        btn = const SizedBox.shrink();
    }
    return btn;
  }
}
