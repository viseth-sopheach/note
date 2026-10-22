import 'package:flutter/material.dart';

import '../../../../app/glass/glass_icon_button.dart';
import '../../../../app/glass/glass_pill.dart';

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
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        child: Center(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: GlassPill(
              children: [
                GlassIconButton(
                  tooltip: 'Previous page (Page Up)',
                  icon: const Icon(Icons.chevron_left),
                  onPressed: pageIndex > 0 ? onPrevious : null,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'Page ${pageIndex + 1} of $pageCount',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                GlassIconButton(
                  tooltip: 'Next page (Page Down)',
                  icon: const Icon(Icons.chevron_right),
                  onPressed: pageIndex < pageCount - 1 ? onNext : null,
                ),
                const SizedBox(height: 24, child: VerticalDivider(width: 16)),
                GlassIconButton(
                  tooltip: 'Add page…',
                  icon: const Icon(Icons.note_add_outlined),
                  onPressed: busy ? null : onAdd,
                ),
                GlassIconButton(
                  tooltip: 'Duplicate page',
                  icon: const Icon(Icons.file_copy_outlined),
                  onPressed: busy ? null : onDuplicate,
                ),
                GlassIconButton(
                  tooltip: 'Delete page',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: busy ? null : onDelete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
