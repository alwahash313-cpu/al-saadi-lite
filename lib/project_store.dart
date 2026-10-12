import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

class ProjectStore {
  static const _key = 'al_saadi_projects_v1';

  Future<List<EditorProject>> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList(_key) ?? [];
    return raw.map(EditorProject.decode).toList();
  }

  Future<List<EditorProject>> list() => load();

  Future<void> save(EditorProject project) async {
    final p = await SharedPreferences.getInstance();
    final all = await load();
    final i = all.indexWhere((x) => x.id == project.id);
    if (i >= 0) {
      all[i] = project;
    } else {
      all.insert(0, project);
    }
    await p.setStringList(_key, all.map((x) => x.encode()).toList());
  }

  Future<void> delete(String id) async {
    final p = await SharedPreferences.getInstance();
    final all = await load();
    all.removeWhere((x) => x.id == id);
    await p.setStringList(_key, all.map((x) => x.encode()).toList());
  }
}
