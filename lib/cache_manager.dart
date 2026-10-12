import 'dart:io';
import 'package:path_provider/path_provider.dart';

class LiteCacheManager {
  static Future<Directory> directory() async {
    final base = await getTemporaryDirectory();
    final dir = Directory('${base.path}/al_saadi_lite');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<int> clear() async {
    final dir = await directory();
    var count = 0;
    if (await dir.exists()) {
      await for (final e in dir.list()) {
        try { await e.delete(recursive: true); count++; } catch (_) {}
      }
    }
    return count;
  }

  static Future<int> bytes() async {
    final dir = await directory();
    var total = 0;
    if (!await dir.exists()) return 0;
    await for (final e in dir.list(recursive: true)) {
      if (e is File) { try { total += await e.length(); } catch (_) {} }
    }
    return total;
  }

  static String humanBytes(int n) {
    if (n < 1024) return '$n B';
    if (n < 1024 * 1024) return '${(n / 1024).toStringAsFixed(1)} KB';
    return '${(n / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
