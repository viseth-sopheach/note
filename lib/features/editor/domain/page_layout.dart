enum PageLayout {
  single('Single page', 'One page per row', 1, 0),
  doublePage('Double page', 'Book spread, page 1 alone on the right', 2, 1),
  dualPages('Dual pages', 'Pages side by side: 1|2, 3|4', 2, 0);

  const PageLayout(this.label, this.hint, this.columns, this.leading);

  final String label;
  final String hint;
  final int columns;

  /// Empty slots before page 1.
  final int leading;

  static PageLayout fromName(String? name) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return PageLayout.single;
  }
}