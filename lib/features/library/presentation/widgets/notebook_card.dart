import 'package:flutter/material.dart';

import '../../domain/notebook.dart';
import '../cover_palette.dart';

class NotebookCard extends StatelessWidget {
  const NotebookCard({
    super.key,
    required this.notebook,
    required this.onTap,
    this.showCover = true,
  });

  final Notebook notebook;
  final VoidCallback onTap;

  /// When false the card is a plain tile that ignores the cover color.
  final bool showCover;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final cover = Color(notebook.coverColorValue);
    final background = showCover ? cover : colors.surfaceContainerHighest;
    final foreground = showCover
        ? CoverPalette.onColor(cover)
        : colors.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Semantics(
            button: true,
            label: 'Open notebook ${notebook.title}',
            child: Material(
              color: background,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: showCover
                    ? BorderSide.none
                    : BorderSide(color: colors.outlineVariant),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                child: Center(
                  child: Icon(
                    Icons.menu_book_outlined,
                    size: 40,
                    color: foreground,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          notebook.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.titleSmall,
        ),
        Text(
          notebook.template.label,
          style: textTheme.bodySmall?.copyWith(color: colors.outline),
        ),
      ],
    );
  }
}
