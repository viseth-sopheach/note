import 'package:flutter/material.dart';

@immutable
class GlassTheme extends ThemeExtension<GlassTheme> {
  const GlassTheme({
    required this.fill,
    required this.highlight,
    required this.border,
    required this.shadow,
    required this.solid,
    required this.hover,
    required this.canvas,
  });

  final Color fill;
  final Color highlight;
  final Color border;
  final Color shadow;
  final Color solid;
  final Color hover;
  final Color canvas;

  static const GlassTheme light = GlassTheme(
    fill: Color(0xB8FFFFFF),
    highlight: Color(0x66FFFFFF),
    border: Color(0x1F000000),
    shadow: Color(0x1A000000),
    solid: Color(0xFFF7F7F9),
    hover: Color(0x14000000),
    canvas: Color(0xFFE4E5E9),
  );

  static const GlassTheme dark = GlassTheme(
    fill: Color(0x24FFFFFF),
    highlight: Color(0x33FFFFFF),
    border: Color(0x2EFFFFFF),
    shadow: Color(0x59000000),
    solid: Color(0xFF2C2C2E),
    hover: Color(0x1FFFFFFF),
    canvas: Color(0xFF1C1C1E),
  );

  @override
  GlassTheme copyWith({
    Color? fill,
    Color? highlight,
    Color? border,
    Color? shadow,
    Color? solid,
    Color? hover,
    Color? canvas,
  }) => GlassTheme(
    fill: fill ?? this.fill,
    highlight: highlight ?? this.highlight,
    border: border ?? this.border,
    shadow: shadow ?? this.shadow,
    solid: solid ?? this.solid,
    hover: hover ?? this.hover,
    canvas: canvas ?? this.canvas,
  );

  @override
  GlassTheme lerp(ThemeExtension<GlassTheme>? other, double t) {
    if (other is! GlassTheme) return this;
    return GlassTheme(
      fill: Color.lerp(fill, other.fill, t)!,
      highlight: Color.lerp(highlight, other.highlight, t)!,
      border: Color.lerp(border, other.border, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      solid: Color.lerp(solid, other.solid, t)!,
      hover: Color.lerp(hover, other.hover, t)!,
      canvas: Color.lerp(canvas, other.canvas, t)!,
    );
  }
}

extension GlassThemeContext on BuildContext {
  GlassTheme get glass {
    final theme = Theme.of(this);
    return theme.extension<GlassTheme>() ??
        (theme.brightness == Brightness.dark
            ? GlassTheme.dark
            : GlassTheme.light);
  }
}
