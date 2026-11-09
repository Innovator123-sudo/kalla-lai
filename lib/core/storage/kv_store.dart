import 'kv_store_io.dart'
    if (dart.library.js_interop) 'kv_store_web.dart';

/// Small key/value store used for session and preferences.
///
/// On web this is backed by localStorage, so a session survives a reload and
/// a browser restart. Native builds fall back to an in-memory store.
abstract interface class KvStore {
  String? read(String key);
  void write(String key, String value);
  void remove(String key);
}

class MemoryKvStore implements KvStore {
  final Map<String, String> _values = <String, String>{};

  @override
  String? read(String key) => _values[key];

  @override
  void write(String key, String value) => _values[key] = value;

  @override
  void remove(String key) => _values.remove(key);
}

final KvStore kvStore = createKvStore();
