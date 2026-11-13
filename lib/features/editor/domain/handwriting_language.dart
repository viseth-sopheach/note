enum HandwritingLanguage {
  auto('Auto detect'),
  english('English'),
  khmer('Khmer · ខ្មែរ');

  const HandwritingLanguage(this.label);

  final String label;

  static HandwritingLanguage fromName(String? name) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return HandwritingLanguage.auto;
  }
}
