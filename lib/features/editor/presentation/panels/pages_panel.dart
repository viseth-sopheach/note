import 'package:flutter/foundation.dart' show ValueListenable;import 'package:flutter/material.dart';

import '../../../../app/glass/glass_icon_button.dart';
import '../../../../app/glass/glass_surface.dart';
import '../../../../app/glass/glass_tokens.dart';

/// Left-side panel with one thumbnail per page.
class PagesPanel extends StatefulWidget {
  const PagesPanel({
    super.key,
    required this.count,
    required this.current,
    required this.thumbBuilder,
    required this.onSelect,
    required this.onClose,
  });

  final int count;
  final ValueListenable<int> current;
  final Widget Function(int index, double width) thumbBuilder;
  final ValueChanged<int> onSelect;
  final VoidCallback onClose;

  @override
  State<PagesPanel> createState() => _PagesPanelState();
}

class _PagesPanelState extends State<PagesPanel> {
  static const double _extent = 176;
  static const double _thumbWidth = 96;

  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.current.addListener(_follow);
    WidgetsBinding.instance.addPostFrameCallback((_) => _follow(jump: true));
  }

  @override
  void dispose() {
    widget.current.removeListener(_follow);
    _scroll.dispose();
    super.dispose();
  }

  void _follow({bool jump = false}) {
    if (!mounted || !_scroll.hasClients) return;
    final pos = _scroll.position;
    final target = (widget.current.value * _extent -
            (pos.viewportDimension - _extent) / 2)
        .clamp(0.0, pos.maxScrollExtent)
        .toDouble();
    if (jump || MediaQuery.disableAnimationsOf(context)) {
      _scroll.jumpTo(target);
    } else {
      _scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  Widget _tile(BuildContext context, int i) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return ValueListenableBuilder<int>(
      valueListenable: widget.current,
      child: widget.thumbBuilder(i, _thumbWidth),
      builder: (context, cur, thumb) {
        final sel = cur == i;
        return Semantics(
          button: true,
          selected: sel,
          label: 'Page ${i + 1}',
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => widget.onSelect(i),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: sel ? scheme.primary : scheme.outlineVariant,
                        width: sel ? 2 : 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: thumb,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${i + 1}',
                    style: text.labelMedium?.copyWith(
                      color: sel ? scheme.primary : null,
                      fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: still ? 1 : 0, end: 1),
      duration: still ? Duration.zero : GlassTokens.menu,
      curve: GlassTokens.curve,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(-24 * (1 - t), 0), child: child),
      ),
      child: GlassSurface(
        intensity: GlassIntensity.thick,
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 4, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Pages',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    GlassIconButton(
                      size: 36,
                      tooltip: 'Close pages',
                      icon: const Icon(Icons.close),
                      onPressed: widget.onClose,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: _scroll,
                  itemExtent: _extent,
                  itemCount: widget.count,
                  itemBuilder: _tile,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}