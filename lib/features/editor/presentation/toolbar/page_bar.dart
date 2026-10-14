import 'package:flutter/material.dart';

class PageBar extends StatelessWidget {
  const PageBar({
    super.key,
    required this.pageIndex,
    required this.pageCount,
    required this.onPrevious,
    required this.onNext,
    required this.onAdd,
    required this.onDuplicate,
    required this.onDelete,
    this.busy = false,
  });

  final int pageIndex;
  final int pageCount;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onAdd;
  final VoidCallback onDuplicate;

  /// Null disables the button (for example when only one page is left).
  final VoidCallback? onDelete;

  /// Disables every page action while a change is being saved.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: colors.surface,
      elevation: 1,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.zero,
          child: Center(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Previous page (Page Up)',
                    icon: const Icon(Icons.chevron_left),
                    onPressed: pageIndex > 0 ? onPrevious : null,
                  ),
                  Text(
                    'Page ${pageIndex + 1} of $pageCount',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Next page (Page Down)',
                    icon: const Icon(Icons.chevron_right),
                    onPressed: pageIndex < pageCount - 1 ? onNext : null,
                  ),
                  const SizedBox(
                    height: 24,
                    child: VerticalDivider(width: 24),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Add page…',
                    icon: const Icon(Icons.note_add_outlined),
                    onPressed: busy ? null : onAdd,
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Duplicate page',
                    icon: const Icon(Icons.file_copy_outlined),
                    onPressed: busy ? null : onDuplicate,
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Delete page',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: busy ? null : onDelete,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}