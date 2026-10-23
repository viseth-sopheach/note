import 'package:flutter/material.dart';

import '../../../../app/glass/glass_icon_button.dart';
import '../../../../app/glass/glass_pill.dart';
import '../../../../app/glass/glass_theme.dart';

class PageBar extends StatelessWidget {
  const PageBar({
    super.key,
    required this.pageIndex,
    required this.pageCount,
    required this.visible,
    required this.showAdd,
    required this.onPrevious,
    required this.onNext,
    required this.onAdd,
    this.busy = false,
  });

  final int pageIndex;
  final int pageCount;
  final bool visible;
  final bool showAdd;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onAdd;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    final duration = still ? Duration.zero : const Duration(milliseconds: 420);
    final quick = still ? Duration.zero : const Duration(milliseconds: 300);
    final glass = context.glass;

    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: IgnorePointer(
            ignoring: !visible,
            child: AnimatedSlide(
              offset: visible ? Offset.zero : const Offset(0, 1.6),
              duration: duration,
              curve: visible ? Curves.easeOutBack : Curves.easeInCubic,
              child: AnimatedOpacity(
                opacity: visible ? 1 : 0,
                duration: duration,
                curve: Curves.easeOutCubic,
                child: GlassPill(
                  children: [
                    GlassIconButton(
                      tooltip: 'Previous page (Page Up)',
                      icon: const Icon(Icons.chevron_left),
                      onPressed: pageIndex > 0 ? onPrevious : null,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
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
                    AnimatedSize(
                      duration: quick,
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.centerLeft,
                      child: showAdd
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  height: 24,
                                  width: 9,
                                  child: Center(
                                    child: SizedBox(
                                      width: 1,
                                      height: 24,
                                      child: ColoredBox(color: glass.border),
                                    ),
                                  ),
                                ),
                                GlassIconButton(
                                  tooltip: 'Add page',
                                  icon: const Icon(Icons.add),
                                  onPressed: busy ? null : onAdd,
                                ),
                              ],
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
