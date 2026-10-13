import 'package:flutter/material.dart';

import '../../domain/notebook.dart';
import '../cover_palette.dart';

class NotebookCard extends StatelessWidget {
  const NotebookCard({super.key, required this.notebook, required this.onTap});

  final Notebook notebook;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final cover = Color(notebook.coverColorValue);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Semantics(
            button: true,
            label: 'Open notebook ${notebook.title}',
            child: Material(
              color: cover,
              borderRadius: BorderRadius.circular(8),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                child: Center(
                  child: Icon(
                    Icons.menu_book_outlined,
                    size: 40,
                    color: CoverPalette.onColor(cover),
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
          style: textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ],
    );
  }
}