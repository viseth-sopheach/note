import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Overridden in main.dart. Null in tests (pins stay in memory).
final sharedPrefsProvider = Provider<SharedPreferences?>((_) => null);

class PinnedNotes extends Notifier<Set<String>> {
  static const _key = 'pinned_notebooks';

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

final pinnedNotesProvider =
    NotifierProvider<PinnedNotes, Set<String>>(PinnedNotes.new);