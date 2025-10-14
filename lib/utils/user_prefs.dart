import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class UserPrefs {
  static Map<String, dynamic>? _cache;
  static File? _file;

  static Future<File> _prefsFile() async {
    if (_file != null) return _file!;
    final dir = await getApplicationSupportDirectory();
    final f = File(p.join(dir.path, 'user_prefs.json'));
    _file = f;
    return f;
  }

  static Future<void> _ensureLoaded() async {
    if (_cache != null) return;
    final f = await _prefsFile();
    if (await f.exists()) {
      try {
        final s = await f.readAsString();
        _cache = jsonDecode(s) as Map<String, dynamic>;
      } catch (_) {
        _cache = <String, dynamic>{};
      }
    } else {
      _cache = <String, dynamic>{};
    }
  }

  static Future<void> _flush() async {
    final f = await _prefsFile();
    final s = jsonEncode(_cache ?? <String, dynamic>{});
    await f.create(recursive: true);
    await f.writeAsString(s);
  }

  static Future<String?> getString(String key) async {
    await _ensureLoaded();
    final v = _cache![key];
    return v is String ? v : null;
  }

  static Future<void> setString(String key, String? value) async {
    await _ensureLoaded();
    if (value == null) {
      _cache!.remove(key);
    } else {
      _cache![key] = value;
    }
    await _flush();
  }

  static Future<String?> getLastProjectPath() => getString('lastProjectPath');

  static Future<void> setLastProjectPath(String path) =>
      setString('lastProjectPath', path);
}
