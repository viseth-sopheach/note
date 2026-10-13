const int kMaxNameLength = 80;

/// Returns an error message, or null when [value] is an acceptable name.
String? validateName(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) return 'Enter a name';
  if (trimmed.length > kMaxNameLength) {
    return 'Use $kMaxNameLength characters or fewer';
  }
  return null;
}