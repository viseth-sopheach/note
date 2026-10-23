import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
const Color kEditorSurface = Color(0xFF222224);
const Color _kOnSurface = Color(0xFFF2F2F7);
const Color _kOnSurfaceMuted = Color(0xFF9A9AA0);
const Color _kTile = Color(0xFF2E2E31);

/// Duration shared by every fade/slide in this file. Zero when the user
/// asked the OS to reduce motion.
Duration _motion(BuildContext context, [int ms = 300]) =>
    MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : Duration(milliseconds: ms);

// ---------------------------------------------------------------------------
// PageBar: floating "< Page 2 of 2 >" pill
// ---------------------------------------------------------------------------

class PageBar extends StatelessWidget {
  const PageBar({
    super.key,
    required this.pageIndex,
    required this.pageCount,
    required this.visible,
    required this.onPrevious,
    required this.onNext,
  });

  /// Zero-based index of the page in view.
  final int pageIndex;
  final int pageCount;

  /// Fades the pill out when false and stops it from receiving touches.
  final bool visible;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final duration = _motion(context, 420);

    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: duration,
        curve: Curves.easeOutCubic,
        child: Material(
          color: kEditorSurface,
          elevation: 4,
          shadowColor: Colors.black54,
          shape: const StadiumBorder(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Previous page',
                  color: _kOnSurface,
                  disabledColor: _kOnSurfaceMuted.withValues(alpha: 0.4),
                  icon: const Icon(Icons.chevron_left),
                  onPressed: pageIndex > 0 ? onPrevious : null,
                ),
                Text(
                  'Page ${pageIndex + 1} of $pageCount',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: _kOnSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  tooltip: 'Next page',
                  color: _kOnSurface,
                  disabledColor: _kOnSurfaceMuted.withValues(alpha: 0.4),
                  icon: const Icon(Icons.chevron_right),
                  onPressed: pageIndex < pageCount - 1 ? onNext : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// NewPageCard: large card + 4 quick actions
// ---------------------------------------------------------------------------

class NewPageCard extends StatelessWidget {
  const NewPageCard({
    super.key,
    required this.visible,
    required this.onAdd,
    required this.onAddTemplate,
    required this.onAddImage,
    required this.onImport,
    required this.onMore,
    this.enabled = true,
  });

  /// Total height, used by [EditorStack] to avoid overlapping the page pill.
  static const double height = 232;
  static const double maxWidth = 360;

  final bool visible;
  final bool enabled;
  final VoidCallback onAdd;
  final VoidCallback onAddTemplate;
  final VoidCallback onAddImage;
  final VoidCallback onImport;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final duration = _motion(context);

    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, 0.4),
        duration: duration,
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: duration,
          curve: Curves.easeOutCubic,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: maxWidth),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MainCard(onTap: enabled ? onAdd : null),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _QuickAction(
                      icon: Icons.article_outlined,
                      label: 'Template',
                      onTap: enabled ? onAddTemplate : null,
                    ),
                    _QuickAction(
                      icon: Icons.image_outlined,
                      label: 'Image',
                      onTap: enabled ? onAddImage : null,
                    ),
                    _QuickAction(
                      icon: Icons.file_download_outlined,
                      label: 'Import',
                      onTap: enabled ? onImport : null,
                    ),
                    _QuickAction(
                      icon: Icons.more_horiz,
                      label: 'More',
                      onTap: onMore,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MainCard extends StatelessWidget {
  const _MainCard({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'New Page',
      excludeSemantics: true,
      child: Material(
        color: kEditorSurface,
        elevation: 3,
        shadowColor: Colors.black54,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 132,
            width: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.note_add_outlined,
                  size: 40,
                  color: _kOnSurface,
                ),
                const SizedBox(height: 10),
                Text(
                  'New Page',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: _kOnSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Semantics(
          button: true,
          enabled: enabled,
          label: label,
          excludeSemantics: true,
          child: Material(
            color: kEditorSurface,
            elevation: 2,
            shadowColor: Colors.black54,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: SizedBox(
                height: 60,
                child: Center(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      color: _kTile,
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Icon(
                        icon,
                        size: 22,
                        color: enabled
                            ? _kOnSurface
                            : _kOnSurfaceMuted.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// EditorStack: canvas + toolbar + page pill + bottom card
// ---------------------------------------------------------------------------

class EditorStack extends StatelessWidget {
  const EditorStack({
    super.key,
    required this.canvas,
    required this.toolbar,
    required this.transform,
    required this.scrolling,
    required this.atBottom,
    required this.pageIndex,
    required this.pageCount,
    required this.onPrevious,
    required this.onNext,
    required this.onAdd,
    required this.onAddTemplate,
    required this.onAddImage,
    required this.onImport,
    required this.onMore,
    this.busy = false,
  });

  /// Zoomable page area. Fills the whole stack.
  final Widget canvas;

  /// Floating toolbar pinned to the top.
  final Widget toolbar;

  /// Listened to so the visible page index is re-read on every pan/zoom.
  final Listenable transform;

  /// True while the user is scrolling, false once idle.
  final ValueListenable<bool> scrolling;

  /// True when the last page is fully scrolled into view.
  final ValueListenable<bool> atBottom;

  /// Reads the zero-based index of the page currently in view.
  final int Function() pageIndex;
  final int pageCount;
  final bool busy;

  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onAdd;
  final VoidCallback onAddTemplate;
  final VoidCallback onAddImage;
  final VoidCallback onImport;
  final VoidCallback onMore;

  static const double _edge = 16;
  static const double _narrow = 640;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: canvas),
        Positioned(top: 0, left: 0, right: 0, child: toolbar),
        Positioned.fill(
          child: ListenableBuilder(
            listenable: Listenable.merge([transform, scrolling, atBottom]),
            builder: (context, _) => _bottomLayer(context),
          ),
        ),
      ],
    );
  }

  Widget _bottomLayer(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final cardShown = atBottom.value;

    // On narrow screens the pill would sit on top of the card, so it rides
    // above it while the card is showing.
    final pillLift = cardShown && width < _narrow
        ? NewPageCard.height + _edge
        : 0.0;

    return SafeArea(
      top: false,
      child: Stack(
        children: [
          // Depends only on atBottom: never hidden by the idle fade.
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(_edge, 0, _edge, _edge),
              child: NewPageCard(
                visible: cardShown,
                enabled: !busy,
                onAdd: onAdd,
                onAddTemplate: onAddTemplate,
                onAddImage: onAddImage,
                onImport: onImport,
                onMore: onMore,
              ),
            ),
          ),
          // Depends only on scrolling.
          Align(
            alignment: Alignment.bottomLeft,
            child: AnimatedPadding(
              duration: _motion(context),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.fromLTRB(_edge, 0, _edge, _edge + pillLift),
              child: PageBar(
                pageIndex: pageIndex().clamp(0, pageCount - 1),
                pageCount: pageCount,
                visible: scrolling.value,
                onPrevious: onPrevious,
                onNext: onNext,
              ),
            ),
          ),
        ],
      ),
    );
  }
}