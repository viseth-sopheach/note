class InkColor {
  const InkColor(this.name, this.value);

  final String name;
  final int value;
}

const List<InkColor> kInkColors = [
  InkColor('Black', 0xFF1B1B1F),
  InkColor('Blue', 0xFF1E5AA8),
  InkColor('Red', 0xFFC62828),
  InkColor('Green', 0xFF2E7D32),
  InkColor('Orange', 0xFFEF6C00),
  InkColor('Yellow', 0xFFFFEB3B),
];
