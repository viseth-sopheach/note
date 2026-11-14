import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'pinned_notes.dart' show sharedPrefsProvider;

/// Ids of favorite folders and notebooks. Ids are UUIDs, so one set is enough.
class Favorites extends Notifier<Set<String>> {
  static const _key = 'favorite_ids';

  @override
  Set<String> build() =>
      (ref.read(sharedPrefsProvider)?.getStringList(_key) ?? const <String>[])
          .toSet();

  Future<void> toggle(String id) async {
    final next = {...state};
    next.contains(id) ? next.remove(id) : next.add(id);
    state = next;
    await ref.read(sharedPrefsProvider)?.setStringList(_key, next.toList());
  }
}

final favoritesProvider =
    NotifierProvider<Favorites, Set<String>>(Favorites.new);