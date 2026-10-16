/// Where a notebook was last being viewed.
final class EditorPosition {
  const EditorPosition({required this.pageIndex, required this.offset});

  final int pageIndex;

  /// Distance in document units from the top of [pageIndex] to the top of
  /// the viewport. Negative when the viewport starts above the page.
  final double offset;

  String encode() => '$pageIndex;$offset';

  static EditorPosition? tryParse(String? raw) {
    if (raw == null) return null;
    final parts = raw.split(';');
    if (parts.length != 2) return null;
    final page = int.tryParse(parts[0]);
    final offset = double.tryParse(parts[1]);
    if (page == null || page < 0 || offset == null || !offset.isFinite) {
      return null;
    }
    return EditorPosition(pageIndex: page, offset: offset);
  }

  @override
  bool operator ==(Object other) =>
      other is EditorPosition &&
      other.pageIndex == pageIndex &&
      other.offset == offset;

  @override
  int get hashCode => Object.hash(pageIndex, offset);
}
