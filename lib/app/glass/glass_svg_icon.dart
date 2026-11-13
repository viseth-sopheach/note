import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// SVG that takes its size and color from the surrounding [IconTheme],
/// so it behaves like an [Icon] inside GlassIconButton.
class GlassSvgIcon extends StatelessWidget {
  const GlassSvgIcon(this.asset, {super.key});

  final String asset;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final size = theme.size ?? 22;
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      colorFilter: theme.color == null
          ? null
          : ColorFilter.mode(theme.color!, BlendMode.srcIn),
    );
  }
}
