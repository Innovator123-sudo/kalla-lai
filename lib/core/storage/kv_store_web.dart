import 'package:web/web.dart' as web;

import 'kv_store.dart';

class _WebKvStore implements KvStore {
  @override
  String? read(String key) {
    try {
      return web.window.localStorage.getItem(key);
    } catch (_) {
      // Private mode / storage disabled: behave as if nothing was saved.
      return null;
    }
  }

  @override
  void write(String key, String value) {
    try {
      web.window.localStorage.setItem(key, value);
    } catch (_) {
      // Ignore quota / disabled-storage errors; the app still works in memory.
    }
  }

  @override
  void remove(String key) {
    try {
      web.window.localStorage.removeItem(key);
    } catch (_) {
      // Ignore.
    }
  }
}

KvStore createKvStore() => _WebKvStore();
