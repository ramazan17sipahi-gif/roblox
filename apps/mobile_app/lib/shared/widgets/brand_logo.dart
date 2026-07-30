import 'package:flutter/material.dart';

import '../../config/app_config.dart';

/// App logo from brand assets.
class BrandLogo extends StatelessWidget {
  final double size;
  final double borderRadius;
  final BoxFit fit;

  const BrandLogo({
    super.key,
    required this.size,
    this.borderRadius = 16,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.asset(
        AppConfig.logoAsset,
        width: size,
        height: size,
        fit: fit,
        errorBuilder: (_, __, ___) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: const Color(0xFFFF793A),
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: Icon(Icons.checkroom, color: Colors.white, size: size * 0.5),
        ),
      ),
    );
  }
}
