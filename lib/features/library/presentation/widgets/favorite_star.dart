import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/favorites.dart';

class FavoriteStar extends ConsumerWidget {
  const FavoriteStar({
    super.key,
    required this.id,
    required this.name,
    this.onCover = false,
  });

  final String id;
  final String name;

  /// True when drawn over a notebook cover (adds a dark backing circle).
  final bool onCover;

  static const Color gold = Color(0xFFFFC107);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fav = ref.watch(favoritesProvider.select((s) => s.contains(id)));
    final scheme = Theme.of(context).colorScheme;
    final idle = onCover ? Colors.white : scheme.onSurfaceVariant;
    final tip = fav ? 'Remove from favorites' : 'Add to favorites';

    return Tooltip(
      message: tip,
      child: Semantics(
        button: true,
        toggled: fav,
        label: '$tip: $name',
        excludeSemantics: true,
        child: InkResponse(
          radius: 20,
          onTap: () {
            HapticFeedback.selectionClick();
            ref.read(favoritesProvider.notifier).toggle(id);
          },
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: onCover ? Colors.black.withValues(alpha: 0.35) : null,
            ),
            child: Icon(
              fav ? Icons.star_rounded : Icons.star_border_rounded,
              size: 20,
              color: fav ? gold : idle,
            ),
          ),
        ),
      ),
    );
  }
}