import 'package:flutter/material.dart';

import '../../data/catalog_likes_repository.dart';

/// Circular heart control for the top corner of a product card.
class CatalogLikeButton extends StatelessWidget {
  const CatalogLikeButton({
    super.key,
    required this.liked,
    required this.onTap,
  });

  final bool liked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      elevation: 2,
      shadowColor: Colors.black26,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(
            liked ? Icons.favorite : Icons.favorite_border,
            size: 17,
            color: liked ? const Color(0xFFE11D48) : const Color(0xFF3F3F46),
          ),
        ),
      ),
    );
  }
}

/// Heart + count, used on the right of a skin title.
class CatalogLikeCount extends StatelessWidget {
  const CatalogLikeCount({
    super.key,
    required this.count,
    required this.liked,
    this.onTap,
    this.light = false,
  });

  final int count;
  final bool liked;
  final VoidCallback? onTap;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final color = liked
        ? const Color(0xFFE11D48)
        : (light ? Colors.white : const Color(0xFF71717A));
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          liked ? Icons.favorite : Icons.favorite_border,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
    if (onTap == null) return child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: child,
    );
  }
}

Future<void> handleCatalogLikeTap({
  required BuildContext context,
  required String templateId,
  int? knownCount,
}) async {
  if (templateId.isEmpty) return;
  final likes = CatalogLikesController.instance;
  if (!likes.isSignedIn()) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Beğenmek için giriş yapın.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }
  final next = await likes.toggle(templateId, knownCount: knownCount);
  if (next == null && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Beğeni kaydedilemedi. Tekrar deneyin.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
