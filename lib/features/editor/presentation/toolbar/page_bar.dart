import 'package:flutter/material.dart';

class PageBar extends StatelessWidget {
  const PageBar({
    super.key,
    required this.pageIndex,
    required this.pageCount,
    required this.onPrevious,
    required this.onNext,
    required this.onAdd,
  });

  final int pageIndex;
  final int pageCount;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: colors.surface,
      elevation: 1,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Previous page (Page Up)',
                icon: const Icon(Icons.chevron_left),
                onPressed: pageIndex > 0 ? onPrevious : null,
              ),
              Text(
                'Page ${pageIndex + 1} of $pageCount',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              IconButton(
                tooltip: 'Next page (Page Down)',
                icon: const Icon(Icons.chevron_right),
                onPressed: pageIndex < pageCount - 1 ? onNext : null,
              ),
              const SizedBox(width: 16),
              IconButton(
                tooltip: 'Add page',
                icon: const Icon(Icons.add_box_outlined),
                onPressed: onAdd,
              ),
            ],
          ),
        ),
      ),
    );
  }
}