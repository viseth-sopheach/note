enum LayoutDensity {
  comfortable('Comfortable'),
  compact('Compact');

  const LayoutDensity(this.label);

  final String label;

  static LayoutDensity fromName(String? name) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return LayoutDensity.comfortable;
  }
}
