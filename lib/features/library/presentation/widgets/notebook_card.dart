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

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _edited(DateTime date) {
    final now = DateTime.now();
    final days = DateTime(now.year, now.month, now.day)
        .difference(DateTime(date.year, date.month, date.day))
        .inDays;
    if (days <= 0) return 'Today';
    if (days == 1) return 'Yesterday';
    if (days < 7) return '${days}d ago';
    final label = '${_months[date.month - 1]} ${date.day}';
    return date.year == now.year ? label : '$label, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final cover = Color(notebook.coverColorValue);
    final background = showCover ? cover : colors.surfaceContainerHighest;
    final foreground = showCover
        ? CoverPalette.onColor(cover)
        : colors.onSurfaceVariant;
    final isPdf = notebook.pdfPath != null;

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
                borderRadius: BorderRadius.circular(12),
                side: showCover
                    ? BorderSide.none
                    : BorderSide(color: colors.outlineVariant),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                child: Stack(
                  children: [
                    if (showCover)
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: 10,
                        child: ColoredBox(
                          color: Colors.black.withValues(alpha: 0.14),
                        ),
                      ),
                    Center(
                      child: Icon(
                        isPdf
                            ? Icons.picture_as_pdf_outlined
                            : Icons.menu_book_outlined,
                        size: 36,
                        color: foreground.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          notebook.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(
          '${isPdf ? 'PDF' : notebook.template.label} · ${_edited(notebook.updatedAt)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodySmall?.copyWith(color: colors.outline),
        ),
      ],
    );
  }
}