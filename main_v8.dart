import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'models.dart';
import 'project_store.dart';
import 'native_media_engine.dart';
import 'cache_manager.dart';
import 'splash_assets.dart';

void main() => runApp(const AlSaadiLite());

const kGold = Color(0xFFD4AF6A);
const kBlack = Color(0xFF080705);
const kCardColor = Color(0xFF14100A);
final Uint8List _logoBytes = base64Decode(kSplashLogoBase64);

ThemeData _tayoubTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: kGold, brightness: Brightness.dark).copyWith(
    primary: kGold,
    onPrimary: Colors.black,
    secondary: const Color(0xFFB8924A),
    surface: kCardColor,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: kBlack,
    iconTheme: const IconThemeData(color: kGold),
    appBarTheme: const AppBarTheme(backgroundColor: kBlack, foregroundColor: kGold, centerTitle: true, elevation: 0, scrolledUnderElevation: 0),
    cardTheme: CardThemeData(
      color: kCardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Color(0x33D4AF6A))),
    ),
    navigationBarTheme: const NavigationBarThemeData(backgroundColor: Color(0xFF0D0B07), indicatorColor: Color(0x33D4AF6A)),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(backgroundColor: kGold, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(foregroundColor: kGold, side: const BorderSide(color: Color(0x66D4AF6A)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))),
    chipTheme: ChipThemeData(selectedColor: const Color(0x33D4AF6A), checkmarkColor: kGold, side: const BorderSide(color: Color(0x44D4AF6A))),
  );
}

class AlSaadiLite extends StatelessWidget {
  const AlSaadiLite({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    onGenerateTitle: (c) => Localizations.localeOf(c).languageCode == 'ar' ? 'طيوب' : 'Tayoub',
    theme: _tayoubTheme(),
    home: const SplashScreen(),
  );
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..forward();
  final _logo = base64Decode(kSplashLogoBase64);
  Timer? _timer;
  bool _went = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 2800), _go);
  }

  void _go() {
    if (_went || !mounted) return;
    _went = true;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 600),
      pageBuilder: (_, __, ___) => const LiteHome(),
      transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
    ));
  }

  @override
  void dispose() { _timer?.cancel(); _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    return Scaffold(
      backgroundColor: const Color(0xFF080705),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _go,
        child: Center(
          child: FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
              child: Image.memory(_logo, width: MediaQuery.of(context).size.width * 0.72, fit: BoxFit.contain, filterQuality: FilterQuality.high, gaplessPlayback: true),
            ),
          ),
        ),
      ),
    );
  }
}

class MusicPick {
  final String path;
  final String name;
  const MusicPick(this.path, this.name);
}

class MediaApi {
  static const _ch = MethodChannel('com.alsaadi/media');

  static Future<MusicPick?> pickAudio() async {
    final r = await _ch.invokeMethod<Map>('pickAudio');
    if (r == null) return null;
    return MusicPick(r['path'] as String, (r['name'] as String?) ?? 'موسيقى');
  }

  static Future<NativeExportResult> mixMusic({
    required String input,
    required String audio,
    required String output,
    required bool isImage,
    int durationMs = 0,
    bool keepOriginal = true,
    double volume = 1.0,
  }) async {
    final r = await _ch.invokeMethod<Map>('mixMusic', {
      'input': input, 'audio': audio, 'output': output, 'isImage': isImage,
      'durationMs': durationMs, 'keepOriginal': keepOriginal, 'volume': volume,
    });
    if (r == null) throw StateError('فشل إضافة الموسيقى');
    return NativeExportResult(r['path'] as String, (r['durationMs'] as num).toInt());
  }

  static Future<void> saveVideo(String path, String name) async {
    await _ch.invokeMethod('saveVideo', {'path': path, 'name': name});
  }
}

Widget editorFor(EditorProject p, ProjectStore s) =>
    (p.clips.isNotEmpty && p.clips.every((c) => c.kind == ClipKind.image))
        ? ImageEditor(project: p, store: s)
        : LiteEditor(project: p, store: s);

class ImageEditor extends StatefulWidget {
  const ImageEditor({super.key, required this.project, required this.store});
  final EditorProject project;
  final ProjectStore store;
  @override State<ImageEditor> createState() => _ImageEditorState();
}

class _ImageEditorState extends State<ImageEditor> {
  static const _channel = MethodChannel('com.alsaadi/media');
  static const List<double> _identity = [1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0];
  static const Map<String, String> _filters = {
    'none': 'بدون', 'bw': 'أبيض وأسود', 'warm': 'دافئ', 'cool': 'بارد',
    'bright': 'سطوع', 'contrast': 'تباين', 'invert': 'معكوس',
  };

  String filter = 'none';
  double brightness = 0;
  double contrast = 1;
  double saturation = 1;
  bool saving = false;
  MusicPick? music;
  double musicVolume = 0.8;
  double videoSeconds = 10;
  VideoPlayerController? _musicPlayer;
  bool _musicPlaying = false;

  Future<void> _startMusicPreview(String path) async {
    final old = _musicPlayer;
    _musicPlayer = null;
    await old?.dispose();
    final c = VideoPlayerController.file(File(path));
    try {
      await c.initialize();
      await c.setLooping(true);
      await c.setVolume(musicVolume);
      await c.play();
      if (!mounted) { await c.dispose(); return; }
      c.addListener(() {
        if (mounted && _musicPlayer == c && c.value.isPlaying != _musicPlaying) setState(() => _musicPlaying = c.value.isPlaying);
      });
      setState(() { _musicPlayer = c; _musicPlaying = true; });
    } catch (e) {
      await c.dispose();
      _msg('تعذر تشغيل الأغنية للمعاينة: $e');
    }
  }

  Future<void> _toggleMusicPreview() async {
    final c = _musicPlayer;
    if (c == null) return;
    try {
      if (c.value.isPlaying) { await c.pause(); } else { await c.play(); }
      if (mounted) setState(() => _musicPlaying = c.value.isPlaying);
    } catch (_) {}
  }

  Future<void> _stopMusicPreview() async {
    final c = _musicPlayer;
    if (c == null) return;
    try { await c.pause(); } catch (_) {}
    if (mounted) setState(() => _musicPlaying = false);
  }

  @override
  void dispose() { _musicPlayer?.dispose(); super.dispose(); }

  EditorClip get clip => widget.project.clips.first;

  List<double> _filterMatrix() {
    switch (filter) {
      case 'bw':
        return [0.2126, 0.7152, 0.0722, 0, 0, 0.2126, 0.7152, 0.0722, 0, 0, 0.2126, 0.7152, 0.0722, 0, 0, 0, 0, 0, 1, 0];
      case 'warm':
        return [1.15, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0.88, 0, 0, 0, 0, 0, 1, 0];
      case 'cool':
        return [0.88, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1.15, 0, 0, 0, 0, 0, 1, 0];
      case 'invert':
        return [-1, 0, 0, 0, 255, 0, -1, 0, 0, 255, 0, 0, -1, 0, 255, 0, 0, 0, 1, 0];
      case 'bright':
        return [1, 0, 0, 0, 51, 0, 1, 0, 0, 51, 0, 0, 1, 0, 51, 0, 0, 0, 1, 0];
      case 'contrast':
        return [1.35, 0, 0, 0, -44.6, 0, 1.35, 0, 0, -44.6, 0, 0, 1.35, 0, -44.6, 0, 0, 0, 1, 0];
      default:
        return _identity;
    }
  }

  List<double> _mul(List<double> a, List<double> b) {
    final r = List<double>.filled(20, 0);
    for (var i = 0; i < 4; i++) {
      for (var j = 0; j < 5; j++) {
        var s = 0.0;
        for (var k = 0; k < 4; k++) { s += a[i * 5 + k] * b[k * 5 + j]; }
        if (j == 4) s += a[i * 5 + 4];
        r[i * 5 + j] = s;
      }
    }
    return r;
  }

  List<double> _adjustMatrix() {
    final c = contrast;
    final o = 127.5 * (1 - c) + brightness * 127.5;
    final s = saturation;
    const lr = 0.2126;
    const lg = 0.7152;
    const lb = 0.0722;
    final sat = <double>[
      lr * (1 - s) + s, lg * (1 - s), lb * (1 - s), 0, 0,
      lr * (1 - s), lg * (1 - s) + s, lb * (1 - s), 0, 0,
      lr * (1 - s), lg * (1 - s), lb * (1 - s) + s, 0, 0,
      0, 0, 0, 1, 0,
    ];
    final bc = <double>[c, 0, 0, 0, o, 0, c, 0, 0, o, 0, 0, c, 0, o, 0, 0, 0, 1, 0];
    return _mul(bc, _mul(sat, _filterMatrix()));
  }

  Future<Uint8List> _render({bool even = false}) async {
    final bytes = await File(clip.path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final img = frame.image;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImage(img, Offset.zero, Paint()..colorFilter = ColorFilter.matrix(_adjustMatrix()));
    final picture = recorder.endRecording();
    final w = even ? (img.width ~/ 2) * 2 : img.width;
    final h = even ? (img.height ~/ 2) * 2 : img.height;
    final out = await picture.toImage(w, h);
    final data = await out.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw StateError('تعذر إنشاء الصورة');
    return data.buffer.asUint8List();
  }

  Future<void> _save() async {
    if (saving) return;
    setState(() => saving = true);
    try {
      final bytes = await _render();
      final dir = await getTemporaryDirectory();
      final name = 'tayoub_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${dir.path}/$name');
      await file.writeAsBytes(bytes, flush: true);
      await _channel.invokeMethod('saveImage', {'path': file.path, 'name': name});
      _msg('تم حفظ الصورة في المعرض (مجلد Pictures/Tayoub)');
    } catch (e) {
      _msg('تعذر حفظ الصورة: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _pickMusic() async {
    if (saving) return;
    try {
      final p = await MediaApi.pickAudio();
      if (p != null && mounted) { setState(() => music = p); await _startMusicPreview(p.path); }
    } catch (e) { _msg('تعذر اختيار الموسيقى: $e'); }
  }

  Future<void> _makeVideo() async {
    final m = music;
    if (m == null || saving) return;
    await _stopMusicPreview();
    setState(() => saving = true);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final png = File('${dir.path}/img_$stamp.png');
      await png.writeAsBytes(await _render(even: true), flush: true);
      final out = '${dir.path}/photo_music_$stamp.mp4';
      final r = await MediaApi.mixMusic(input: png.path, audio: m.path, output: out, isImage: true, durationMs: (videoSeconds * 1000).round(), keepOriginal: false, volume: musicVolume);
      await MediaApi.saveVideo(r.path, 'tayoub_$stamp.mp4');
      _msg('تم إنشاء الفيديو وحفظه في المعرض (مجلد Movies/Tayoub)');
    } catch (e) { _msg('تعذر إنشاء الفيديو: $e'); }
    finally { if (mounted) setState(() => saving = false); }
  }

  void _msg(String text) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text))); }

  Widget _slider(String label, double value, double min, double max, ValueChanged<double> onChanged) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
    child: Row(children: [
      SizedBox(width: 84, child: Text(label)),
      Expanded(child: Slider(value: value, min: min, max: max, onChanged: saving ? null : onChanged)),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    final m = _adjustMatrix();
    return Scaffold(
      appBar: AppBar(title: const Text('تعديل الصورة'), actions: [
        IconButton(onPressed: saving ? null : _save, icon: const Icon(Icons.check)),
      ]),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ColoredBox(
            color: Colors.black,
            child: SizedBox(
              height: 380,
              width: double.infinity,
              child: ColorFiltered(colorFilter: ColorFilter.matrix(m), child: Image.file(File(clip.path), fit: BoxFit.contain)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(child: Column(children: [
          const ListTile(title: Text('الفلاتر', textAlign: TextAlign.right)),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Wrap(spacing: 8, runSpacing: 8, children: _filters.entries.map((e) => ChoiceChip(label: Text(e.value), selected: filter == e.key, onSelected: saving ? null : (_) => setState(() => filter = e.key))).toList()),
          ),
        ])),
        const SizedBox(height: 10),
        Card(child: Column(children: [
          _slider('السطوع', brightness, -1, 1, (v) => setState(() => brightness = v)),
          _slider('التباين', contrast, 0.5, 1.5, (v) => setState(() => contrast = v)),
          _slider('التشبع', saturation, 0, 2, (v) => setState(() => saturation = v)),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextButton(onPressed: saving ? null : () => setState(() { filter = 'none'; brightness = 0; contrast = 1; saturation = 1; }), child: const Text('إعادة الضبط')),
          ),
        ])),
        const SizedBox(height: 10),
        Card(child: Column(children: [
          const ListTile(title: Text('موسيقى للصورة (يتحول لفيديو)', textAlign: TextAlign.right)),
          ListTile(dense: true, leading: const Icon(Icons.library_music_outlined), title: Text(music?.name ?? 'لم يتم اختيار موسيقى', textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis), trailing: Row(mainAxisSize: MainAxisSize.min, children: [if (music != null) IconButton(onPressed: _toggleMusicPreview, icon: Icon(_musicPlaying ? Icons.pause_circle_outline : Icons.play_circle_outline)), TextButton(onPressed: saving ? null : _pickMusic, child: const Text('اختيار'))])),
          _slider('المدة ${videoSeconds.round()} ث', videoSeconds, 3, 60, (v) => setState(() => videoSeconds = v)),
          _slider('الصوت', musicVolume, 0.1, 1, (v) { setState(() => musicVolume = v); _musicPlayer?.setVolume(v); }),
          Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 16), child: OutlinedButton.icon(onPressed: (saving || music == null) ? null : _makeVideo, icon: const Icon(Icons.movie_creation_outlined), label: const Text('إنشاء فيديو بالموسيقى'))),
        ])),
        const SizedBox(height: 10),
        FilledButton.icon(onPressed: saving ? null : _save, icon: const Icon(Icons.save_alt), label: const Text('حفظ في المعرض')),
        if (saving) const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator()),
      ]),
    );
  }
}

class LiteHome extends StatefulWidget {
  const LiteHome({super.key});
  @override State<LiteHome> createState() => _LiteHomeState();
}

class _LiteHomeState extends State<LiteHome> {
  final picker = ImagePicker();
  final store = ProjectStore();
  int tab = 0;

  Future<void> pick(bool video) async {
    final f = video
        ? await picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(minutes: 15))
        : await picker.pickImage(source: ImageSource.gallery, maxWidth: 1920, imageQuality: 82);
    if (!mounted || f == null) return;
    final now = DateTime.now().microsecondsSinceEpoch.toString();
    final p = EditorProject(
      id: now,
      name: video ? 'فيديو جديد' : 'صورة جديدة',
      clips: [EditorClip(id: now, kind: video ? ClipKind.video : ClipKind.image, path: f.path, durationMs: video ? 10000 : 5000)],
    );
    await store.save(p);
    if (!mounted) return;
    _open(p);
  }

  void _open(EditorProject p) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => editorFor(p, store))).then((_) {
      if (mounted) setState(() {});
    });
  }

  void _soon(String what) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$what - قريبًا')));
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _home(),
      _projects(),
      _settings(),
    ];
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(child: pages[tab]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (v) => setState(() => tab = v),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'الرئيسية'),
            NavigationDestination(icon: Icon(Icons.folder_outlined), selectedIcon: Icon(Icons.folder), label: 'مشاريعي'),
            NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'الإعدادات'),
          ],
        ),
      ),
    );
  }

  Widget _hero() => Container(
    height: 150,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0x33D4AF6A)),
      gradient: const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [Color(0xFF0D0B07), Color(0xFF3A2A12)],
      ),
    ),
    child: Row(children: [
      const Expanded(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('صورك وفيديوهاتك\nبأسلوب احترافي', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold, height: 1.4)),
          SizedBox(height: 6),
          Text('ابدأ الإبداع بلا حدود', style: TextStyle(color: Colors.white54)),
        ],
      )),
      const Icon(Icons.auto_awesome, size: 54),
    ]),
  );

  Widget _bigCard(IconData icon, String title, String sub, VoidCallback onTap) => Expanded(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: kCardColor,
          border: Border.all(color: const Color(0x66D4AF6A)),
        ),
        child: Column(children: [
          Icon(icon, size: 34),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(sub, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Colors.white54)),
        ]),
      ),
    ),
  );

  Widget _tool(IconData icon, String label, VoidCallback onTap) => Expanded(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: kCardColor,
          border: Border.all(color: const Color(0x33D4AF6A)),
        ),
        child: Column(children: [
          Icon(icon, size: 26),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 12)),
        ]),
      ),
    ),
  );

  Widget _thumb(EditorProject p, double size) {
    final c = p.clips.isNotEmpty ? p.clips.first : null;
    final Widget inner = (c != null && c.kind == ClipKind.image)
        ? Image.file(File(c.path), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image_outlined))
        : const Icon(Icons.movie_outlined, size: 30);
    return InkWell(
      onTap: () => _open(p),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: kCardColor,
          border: Border.all(color: const Color(0x44D4AF6A)),
        ),
        child: inner,
      ),
    );
  }

  Widget _recent() => FutureBuilder<List<EditorProject>>(
    future: store.list(),
    builder: (context, snap) {
      final items = snap.data ?? const <EditorProject>[];
      if (items.isEmpty) {
        return const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('ماكو مشاريع محفوظة بعد.', style: TextStyle(color: Colors.white54))),
        );
      }
      final recent = items.take(8).toList();
      return SizedBox(
        height: 92,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: recent.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, i) => _thumb(recent[i], 92),
        ),
      );
    },
  );

  Widget _home() => ListView(padding: const EdgeInsets.all(16), children: [
    Row(children: [
      Image.memory(_logoBytes, height: 42, fit: BoxFit.contain, filterQuality: FilterQuality.high, gaplessPlayback: true),
      const Spacer(),
      IconButton(onPressed: () => setState(() => tab = 2), icon: const Icon(Icons.settings_outlined)),
    ]),
    const SizedBox(height: 12),
    _hero(),
    const SizedBox(height: 14),
    Row(children: [
      _bigCard(Icons.photo_library_outlined, 'تحرير الصور', 'فلاتر - تعديل - موسيقى', () => pick(false)),
      const SizedBox(width: 12),
      _bigCard(Icons.video_library_outlined, 'تحرير الفيديو', 'قص - دمج - موسيقى', () => pick(true)),
    ]),
    const SizedBox(height: 18),
    const Text('أدوات سريعة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    const SizedBox(height: 10),
    Row(children: [
      _tool(Icons.grid_view_outlined, 'الكولاج', () => _soon('الكولاج')),
      const SizedBox(width: 8),
      _tool(Icons.text_fields, 'النصوص', () => _soon('النصوص')),
      const SizedBox(width: 8),
      _tool(Icons.emoji_emotions_outlined, 'الملصقات', () => _soon('الملصقات')),
      const SizedBox(width: 8),
      _tool(Icons.filter_vintage_outlined, 'المرشحات', () => pick(false)),
    ]),
    const SizedBox(height: 18),
    Row(children: [
      const Text('مشاريعي الأخيرة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      const Spacer(),
      TextButton(onPressed: () => setState(() => tab = 1), child: const Text('عرض الكل')),
    ]),
    const SizedBox(height: 6),
    _recent(),
  ]);

  Widget _projects() => FutureBuilder<List<EditorProject>>(
    future: store.list(),
    builder: (context, snap) {
      final items = snap.data ?? const <EditorProject>[];
      return ListView(padding: const EdgeInsets.all(16), children: [
        const Text('مشاريعي', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 14),
        if (items.isEmpty) const Padding(
          padding: EdgeInsets.all(30),
          child: Text('ماكو مشاريع محفوظة بعد.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)),
        ),
        ...items.map((p) => Card(child: ListTile(
          leading: _thumb(p, 52),
          title: Text(p.name),
          subtitle: Text('${p.clips.length} مقطع'),
          onTap: () => _open(p),
        ))),
      ]);
    },
  );

  Widget _settings() => ListView(padding: const EdgeInsets.all(16), children: [
    const Text('الإعدادات', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
    const SizedBox(height: 16),
    const Text('الخصوصية والأمان', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    const SizedBox(height: 8),
    const Card(child: ListTile(
      leading: Icon(Icons.lock_outline),
      title: Text('ملفاتك تبقى على جهازك'),
      subtitle: Text('المعالجة تتم محليًا على هاتفك.'),
    )),
    const SizedBox(height: 10),
    Card(child: ListTile(
      leading: const Icon(Icons.cleaning_services_outlined),
      title: const Text('تنظيف الملفات المؤقتة'),
      subtitle: const Text('يحرر مساحة بدون حذف مشاريعك.'),
      onTap: () async {
        final before = await LiteCacheManager.bytes();
        await LiteCacheManager.clear();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم تحرير ${LiteCacheManager.humanBytes(before)} من الملفات المؤقتة.')));
      },
    )),
    const SizedBox(height: 18),
    const Text('عن التطبيق', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    const SizedBox(height: 8),
    const Card(child: ListTile(
      leading: Icon(Icons.info_outline),
      title: Text('طيوب'),
      subtitle: Text('Tayoub'),
    )),
  ]);
}

class LiteEditor extends StatefulWidget {
  final EditorProject project;
  final ProjectStore store;
  const LiteEditor({super.key, required this.project, required this.store});
  @override State<LiteEditor> createState() => _LiteEditorState();
}

class _LiteEditorState extends State<LiteEditor> {
  VideoPlayerController? controller;
  final engine = NativeMediaEngine();
  bool busy = false;
  double speed = 1;
  double trimStart = 0;
  double trimEnd = 1;
  StreamSubscription<double>? progressSub;
  double progress = 0;
  bool loading = false;
  String? loadError;
  String filter = 'none';
  static const Map<String, String> _filters = {
    'none': 'بدون', 'bw': 'أبيض وأسود', 'warm': 'دافئ', 'cool': 'بارد',
    'bright': 'سطوع', 'contrast': 'تباين', 'invert': 'معكوس',
  };

  MusicPick? music;
  double musicVolume = 0.8;
  bool muteOriginal = false;

  List<EditorClip> get videos => widget.project.clips.where((c) => c.kind == ClipKind.video).toList();

  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final clip = videos.firstOrNull;
    if (clip == null) return;
    if (mounted) setState(() { loading = true; loadError = null; });
    final file = File(clip.path);
    if (!await file.exists()) {
      if (mounted) setState(() { loading = false; loadError = 'الملف غير موجود: ${clip.path}'; });
      return;
    }
    final c = VideoPlayerController.file(file);
    try {
      await c.initialize().timeout(const Duration(seconds: 20));
      c.addListener(_onTick);
      final duration = c.value.duration.inMilliseconds;
      if (duration > 0) { trimStart = 0; trimEnd = 1; }
      if (mounted) {
        setState(() { controller = c; loading = false; });
      } else {
        await c.dispose();
      }
    } catch (e) {
      await c.dispose();
      if (mounted) setState(() { loading = false; loadError = '$e'; });
    }
  }
  @override
  void dispose() { controller?.dispose(); progressSub?.cancel(); super.dispose(); }

  void _onTick() {
    final c = controller;
    if (c == null || !mounted) return;
    if (c.value.hasError && loadError == null) {
      setState(() => loadError = 'خطأ أثناء التشغيل: ${c.value.errorDescription}');
    } else {
      setState(() {});
    }
  }

  Future<void> _togglePlay() async {
    final c = controller;
    if (c == null) { _msg('المشغل غير جاهز'); return; }
    try {
      if (c.value.isPlaying) {
        await c.pause();
      } else {
        _msg('جاري التشغيل...');
        unawaited(c.play().timeout(const Duration(seconds: 6)).catchError((Object e) { _msg('خطأ في التشغيل: $e'); }));
        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) _msg('بعد 1.5 ث: ${c.value.isPlaying ? "يعمل" : "متوقف"} | ${c.value.position.inMilliseconds} ms');
      }
    } catch (e) { _msg('تعذر التشغيل: $e'); }
  }

  Future<String> _output(String name) async {
    final dir = await getApplicationDocumentsDirectory();
    final outDir = Directory('${dir.path}/exports');
    await outDir.create(recursive: true);
    return '${outDir.path}/$name-${DateTime.now().millisecondsSinceEpoch}.mp4';
  }

  Future<void> _trim() async {
    final clip = videos.firstOrNull; final c = controller;
    if (clip == null || c == null || !c.value.isInitialized || busy) return;
    final total = c.value.duration.inMilliseconds;
    final start = (trimStart * total).round();
    final end = (trimEnd * total).round();
    if (end - start < 500) return _msg('اختَر مدة لا تقل عن نصف ثانية');
    setState(() { busy = true; progress = 0; });
    progressSub = engine.progress.listen((v) { if (mounted) setState(() => progress = v); });
    try {
      final out = await _output('trim');
      final r = await engine.trimVideo(input: clip.path, output: out, startMs: start, endMs: end);
      await _addResult(r.path, r.durationMs, 'مقطع مقصوص');
      _msg('تم قص الفيديو وحفظه محليًا.');
    } catch (e) { _msg('تعذر القص: $e'); }
    finally { await progressSub?.cancel(); progressSub = null; if (mounted) setState(() => busy = false); }
  }

  Future<void> _merge() async {
    if (videos.length < 2 || busy) return _msg('أضف مقطعين أو أكثر للدمج');
    setState(() { busy = true; progress = 0; });
    progressSub = engine.progress.listen((v) { if (mounted) setState(() => progress = v); });
    try {
      final out = await _output('merge');
      final r = await engine.mergeVideos(inputs: videos.map((e) => e.path).toList(), output: out);
      await _addResult(r.path, r.durationMs, 'فيديو مدموج');
      _msg('تم دمج ${videos.length} مقاطع بنجاح.');
    } catch (e) { _msg('تعذر الدمج: $e'); }
    finally { await progressSub?.cancel(); progressSub = null; if (mounted) setState(() => busy = false); }
  }

  Future<void> _deleteClip(int index) async {
    if (busy || index < 0 || index >= widget.project.clips.length) return;
    if (widget.project.clips.length <= 1) return _msg('لا يمكن حذف آخر مقطع من المشروع');
    widget.project.clips.removeAt(index);
    await widget.store.save(widget.project);
    await controller?.dispose();
    controller = null;
    await _load();
    if (mounted) setState(() {});
  }

  Future<void> _moveClip(int index, int delta) async {
    if (busy) return;
    final to = index + delta;
    if (index < 0 || index >= widget.project.clips.length || to < 0 || to >= widget.project.clips.length) return;
    final item = widget.project.clips.removeAt(index);
    widget.project.clips.insert(to, item);
    await widget.store.save(widget.project);
    if (mounted) setState(() {});
  }

  Future<void> _addVideo() async {
    if (busy) return;
    final f = await ImagePicker().pickVideo(source: ImageSource.gallery, maxDuration: const Duration(minutes: 15));
    if (f == null) return;
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    widget.project.clips.add(EditorClip(id: id, kind: ClipKind.video, path: f.path, durationMs: 10000));
    await widget.store.save(widget.project);
    await controller?.dispose(); controller = null;
    await _load();
    if (mounted) setState(() {});
  }

  Future<void> _speedExport() async {
    final clip = videos.firstOrNull;
    if (clip == null || busy) return;
    setState(() { busy = true; progress = 0; });
    progressSub = engine.progress.listen((v) { if (mounted) setState(() => progress = v); });
    try {
      final out = await _output('speed');
      final r = await engine.speedVideo(input: clip.path, output: out, speed: speed);
      await _addResult(r.path, r.durationMs, 'فيديو بسرعة ${speed.toStringAsFixed(1)}x');
      _msg('تم تصدير الفيديو بالسرعة الجديدة.');
    } catch (e) { _msg('تغيير السرعة غير متاح على هذا الجهاز حاليًا: $e'); }
    finally { await progressSub?.cancel(); progressSub = null; if (mounted) setState(() => busy = false); }
  }

  Future<void> _filterExport() async {
    final clip = videos.firstOrNull;
    if (clip == null || busy || filter == 'none') return;
    setState(() { busy = true; progress = 0; });
    progressSub = engine.progress.listen((v) { if (mounted) setState(() => progress = v); });
    try {
      final out = await _output('filter');
      final r = await engine.filterVideo(input: clip.path, output: out, filter: filter);
      await _addResult(r.path, r.durationMs, 'فيديو بفلتر ${_filters[filter]}');
      _msg('تم تطبيق الفلتر.');
    } catch (e) { _msg('تعذر تطبيق الفلتر: $e'); }
    finally { await progressSub?.cancel(); progressSub = null; if (mounted) setState(() => busy = false); }
  }

  Future<void> _pickMusic() async {
    if (busy) return;
    try {
      final p = await MediaApi.pickAudio();
      if (p != null && mounted) setState(() => music = p);
    } catch (e) { _msg('تعذر اختيار الموسيقى: $e'); }
  }

  Future<void> _addMusic() async {
    final clip = videos.firstOrNull;
    final m = music;
    if (clip == null || m == null || busy) return;
    setState(() { busy = true; progress = 0; });
    progressSub = engine.progress.listen((v) { if (mounted) setState(() => progress = v); });
    try {
      final out = await _output('music');
      final r = await MediaApi.mixMusic(input: clip.path, audio: m.path, output: out, isImage: false, keepOriginal: !muteOriginal, volume: musicVolume);
      await _addResult(r.path, r.durationMs, 'فيديو مع موسيقى');
      _msg('تمت إضافة الموسيقى.');
    } catch (e) { _msg('تعذر إضافة الموسيقى: $e'); }
    finally { await progressSub?.cancel(); progressSub = null; if (mounted) setState(() => busy = false); }
  }

  Future<void> _saveVideo() async {
    final clip = videos.firstOrNull;
    if (clip == null || busy) return;
    if (videos.length > 1) { _msg('ادمج المقاطع أولاً ثم احفظ الفيديو.'); return; }
    try {
      await MediaApi.saveVideo(clip.path, 'tayoub_${DateTime.now().millisecondsSinceEpoch}.mp4');
      _msg('تم حفظ الفيديو في المعرض (مجلد Movies/Tayoub)');
    } catch (e) { _msg('تعذر حفظ الفيديو: $e'); }
  }

  Future<void> _addResult(String path, int durationMs, String name) async {
    widget.project.clips = [EditorClip(id: DateTime.now().microsecondsSinceEpoch.toString(), kind: ClipKind.video, path: path, durationMs: durationMs)];
    widget.project.name = name;
    await widget.store.save(widget.project);
    if (mounted) { await controller?.dispose(); controller = null; await _load(); setState(() {}); }
  }

  void _msg(String text) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text))); }

  @override
  Widget build(BuildContext context) {
    final duration = controller?.value.isInitialized == true ? controller!.value.duration : Duration.zero;
    return Scaffold(
      appBar: AppBar(title: const Text('محرر الفيديو'), actions: [
        IconButton(onPressed: busy ? null : () async { await widget.store.save(widget.project); _msg('تم حفظ المشروع'); }, icon: const Icon(Icons.save_outlined)),
      ]),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        AspectRatio(aspectRatio: controller?.value.aspectRatio ?? 16/9, child: controller == null ? const ColoredBox(color: Colors.black, child: Center(child: Icon(Icons.movie_outlined, size: 50))) : VideoPlayer(controller!)),
        if (loading) const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator()),
        if (loadError != null) Padding(padding: const EdgeInsets.all(8), child: SelectableText('تعذر تشغيل المعاينة:\n$loadError', textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent, fontSize: 12))),
        if (controller != null) IconButton(icon: Icon(controller!.value.isPlaying ? Icons.pause : Icons.play_arrow), onPressed: _togglePlay),
        if (controller != null) Text('المشغل: ${controller!.value.isPlaying ? "يعمل" : "متوقف"} | ${controller!.value.position.inSeconds}/${controller!.value.duration.inSeconds} ث | تخزين مؤقت: ${controller!.value.isBuffering ? "نعم" : "لا"} | ${controller!.value.hasError ? "خطأ: ${controller!.value.errorDescription}" : "بدون خطأ"} | ${controller!.value.size.width.toInt()}x${controller!.value.size.height.toInt()}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Colors.white54)),
        const SizedBox(height: 8),
        _timeline(),
        const SizedBox(height: 10),
        Card(child: Column(children: [
          ListTile(title: Text('المقاطع (${videos.length})', textAlign: TextAlign.right), leading: IconButton(onPressed: busy ? null : _addVideo, icon: const Icon(Icons.add))),
          ...videos.asMap().entries.map((e) => ListTile(
            dense: true,
            leading: CircleAvatar(radius: 14, child: Text('${e.key + 1}')),
            title: Text(e.value.path.split('/').last, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right),
            trailing: PopupMenuButton<String>(
              enabled: !busy,
              onSelected: (action) {
                if (action == 'up') _moveClip(e.key, -1);
                if (action == 'down') _moveClip(e.key, 1);
                if (action == 'delete') _deleteClip(widget.project.clips.indexOf(e.value));
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'up', child: Text('تحريك للأعلى')),
                PopupMenuItem(value: 'down', child: Text('تحريك للأسفل')),
                PopupMenuItem(value: 'delete', child: Text('حذف المقطع')),
              ],
            ),
          )),
        ])),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: FilledButton.icon(onPressed: busy ? null : _trim, icon: const Icon(Icons.content_cut), label: const Text('قص'))),
          const SizedBox(width: 8),
          Expanded(child: FilledButton.tonalIcon(onPressed: busy ? null : _merge, icon: const Icon(Icons.merge_type), label: const Text('دمج'))),
        ]),
        const SizedBox(height: 10),
        Card(child: Column(children: [
          const ListTile(title: Text('السرعة', textAlign: TextAlign.right)),
          Slider(value: speed, min: .5, max: 2, divisions: 6, label: '${speed.toStringAsFixed(1)}x', onChanged: busy ? null : (v) => setState(() => speed = v)),
          Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: OutlinedButton.icon(onPressed: busy ? null : _speedExport, icon: const Icon(Icons.speed), label: const Text('تطبيق السرعة'))),
        ])),
        const SizedBox(height: 10),
        Card(child: Column(children: [
          const ListTile(title: Text('الفلاتر', textAlign: TextAlign.right)),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Wrap(spacing: 8, runSpacing: 8, children: _filters.entries.map((e) => ChoiceChip(label: Text(e.value), selected: filter == e.key, onSelected: busy ? null : (_) => setState(() => filter = e.key))).toList())),
          Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 16), child: OutlinedButton.icon(onPressed: (busy || filter == 'none') ? null : _filterExport, icon: const Icon(Icons.auto_fix_high), label: const Text('تطبيق الفلتر'))),
        ])),
        const SizedBox(height: 10),
        Card(child: Column(children: [
          const ListTile(title: Text('الموسيقى', textAlign: TextAlign.right)),
          ListTile(dense: true, leading: const Icon(Icons.library_music_outlined), title: Text(music?.name ?? 'لم يتم اختيار موسيقى', textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis), trailing: TextButton(onPressed: busy ? null : _pickMusic, child: const Text('اختيار'))),
          SwitchListTile(dense: true, title: const Text('كتم صوت الفيديو الأصلي', textAlign: TextAlign.right), value: muteOriginal, onChanged: busy ? null : (v) => setState(() => muteOriginal = v)),
          Row(children: [
            const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('الصوت')),
            Expanded(child: Slider(value: musicVolume, min: 0.1, max: 1, onChanged: busy ? null : (v) => setState(() => musicVolume = v))),
          ]),
          Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: OutlinedButton.icon(onPressed: (busy || music == null) ? null : _addMusic, icon: const Icon(Icons.music_note), label: const Text('إضافة الموسيقى'))),
        ])),
        const SizedBox(height: 10),
        FilledButton.icon(onPressed: busy ? null : _saveVideo, icon: const Icon(Icons.save_alt), label: const Text('حفظ الفيديو في المعرض')),
        if (busy) Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Column(children: [LinearProgressIndicator(value: progress > 0 ? progress : null), const SizedBox(height: 8), Text('جاري المعالجة ${progress > 0 ? '${(progress * 100).round()}%' : ''}') ])),
        const SizedBox(height: 10),
        Text('المدة الحالية: ${duration.inSeconds} ثانية • ${videos.length} مقطع', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54)),
      ],),
    );
  }

  Widget _timeline() {
    if (controller?.value.isInitialized != true) return const SizedBox.shrink();
    final total = controller!.value.duration.inMilliseconds;
    return Card(child: Padding(padding: const EdgeInsets.fromLTRB(10, 10, 10, 4), child: Column(children: [
      const Text('نطاق القص', textAlign: TextAlign.right),
      RangeSlider(values: RangeValues(trimStart, trimEnd), min: 0, max: 1, onChanged: busy ? null : (v) { if (v.end - v.start > .01) setState(() { trimStart = v.start; trimEnd = v.end; }); }),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(_fmt(total * trimStart)), Text(_fmt(total * trimEnd))]),
    ])));
  }

  String _fmt(double ms) { final s = (ms / 1000).round(); return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}'; }
}
