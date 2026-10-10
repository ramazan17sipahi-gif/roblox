import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum DSToastType { success, error, info, warning }

/// Reusable toast/snackbar notifications optimized for the Creator Platform
class DSToast {
  DSToast._();

  static void show(
    BuildContext context, {
    required String message,
    DSToastType type = DSToastType.info,
    Duration duration = const Duration(seconds: 4),
  }) {
    IconData icon;
    Color backgroundColor;
    Color iconColor = Colors.white;

    switch (type) {
      case DSToastType.success:
        icon = Icons.check_circle;
        backgroundColor = AppColors.success;
        break;
      case DSToastType.error:
        icon = Icons.error;
        backgroundColor = AppColors.error;
        break;
      case DSToastType.warning:
        icon = Icons.warning;
        backgroundColor = AppColors.warning;
        break;
      case DSToastType.info:
        icon = Icons.info;
        backgroundColor = AppColors.textHighEmphasis;
        break;
    }

    final snackBar = SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      backgroundColor: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 6,
      duration: duration,
      content: Row(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);
  }

  static void showSuccess(BuildContext context, String message) => 
      show(context, message: message, type: DSToastType.success);

  static void showError(BuildContext context, String message) => 
      show(context, message: message, type: DSToastType.error);
      
  static void showInfo(BuildContext context, String message) => 
      show(context, message: message, type: DSToastType.info);
}
