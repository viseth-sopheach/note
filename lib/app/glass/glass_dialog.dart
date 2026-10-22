import 'package:flutter/material.dart';

import 'glass_surface.dart';
import 'glass_tokens.dart';

Future<T?> showGlassDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  final still = MediaQuery.disableAnimationsOf(context);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.25),
    transitionDuration: still ? Duration.zero : GlassTokens.menu,
    pageBuilder: (context, _, _) => SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Center(child: builder(context)),
      ),
    ),
    transitionBuilder: (context, animation, _, child) {
      final curved = animation.drive(CurveTween(curve: GlassTokens.curve));
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: curved.drive(Tween(begin: 0.96, end: 1.0)),
          child: child,
        ),
      );
    },
  );
}

Future<T?> showGlassSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: Colors.black.withValues(alpha: 0.25),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(GlassTokens.space2),
        child: GlassSurface(
          intensity: GlassIntensity.thick,
          radius: GlassTokens.radiusLarge,
          child: builder(context),
        ),
      ),
    ),
  );
}

class GlassDialog extends StatelessWidget {
  const GlassDialog({
    super.key,
    this.title,
    this.content,
    this.actions = const [],
    this.maxWidth = 420,
  });

  final Widget? title;
  final Widget? content;
  final List<Widget> actions;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(GlassTokens.space4),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Material(
          type: MaterialType.transparency,
          child: GlassSurface(
            intensity: GlassIntensity.thick,
            radius: GlassTokens.radiusLarge,
            padding: const EdgeInsets.all(GlassTokens.space6),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null)
                    DefaultTextStyle(
                      style: text.titleLarge!.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      child: title!,
                    ),
                  if (title != null && content != null)
                    const SizedBox(height: GlassTokens.space3),
                  if (content != null) content!,
                  if (actions.isNotEmpty) ...[
                    const SizedBox(height: GlassTokens.space6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        for (var i = 0; i < actions.length; i++) ...[
                          if (i > 0) const SizedBox(width: GlassTokens.space2),
                          actions[i],
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
