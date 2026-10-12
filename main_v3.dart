import 'dart:async';
import 'dart:convert';
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

class AlSaadiLite extends StatelessWidget {
  const AlSaadiLite({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'الساعدي Lite',
    theme: ThemeData.dark(useMaterial3: true).copyWith(
      scaffoldBackgroundColor: const Color(0xFF08090B),
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFC5A66A), brightness: Brightness.dark),
    ),
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
    Navigator.push(context, MaterialPageRoute(builder: (_) => LiteEditor(project: p, store: store)));
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _home(),
      _projects(),
    ];
    return Scaffold(
      body: SafeArea(child: pages[tab]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (v) => setState(() => tab = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.folder_outlined), selectedIcon: Icon(Icons.folder), label: 'المشاريع'),
        ],
      ),
    );
  }

  Widget _home() => ListView(padding: const EdgeInsets.all(18), children: [
    const SizedBox(height: 12),
    const Text('الساعدي Lite', textAlign: TextAlign.right, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
    const SizedBox(height: 5),
    const Text('مونتاج سريع، بدون تعقيد.', textAlign: TextAlign.right, style: TextStyle(color: Colors.white60)),
    const SizedBox(height: 22),
    _action(Icons.video_library_outlined, 'فيديو', 'قص وتغيير السرعة', () => pick(true)),
    const SizedBox(height: 12),
    _action(Icons.photo_library_outlined, 'صورة', 'تحرير وحفظ محلي', () => pick(false)),
    const SizedBox(height: 20),
    Card(child: Padding(padding: const EdgeInsets.all(16), child: Row(children: const [
      Icon(Icons.lock_outline, size: 22), SizedBox(width: 10),
      Expanded(child: Text('خصوصيتك أولًا\nملفاتك تبقى على جهازك افتراضيًا.')),
    ]))),
    const SizedBox(height: 12),
    Card(child: Padding(padding: const EdgeInsets.all(16), child: Row(children: const [
      Icon(Icons.speed_outlined, size: 22), SizedBox(width: 10),
      Expanded(child: Text('نسخة خفيفة\nاعتماديات أقل وواجهة أسرع.')),
    ]))),
    const SizedBox(height: 12),
    Card(child: ListTile(leading: const Icon(Icons.cleaning_services_outlined), title: const Text('تنظيف الملفات المؤقتة', textAlign: TextAlign.right), subtitle: const Text('يحرر مساحة بدون حذف مشاريعك.', textAlign: TextAlign.right), onTap: () async {
      final before = await LiteCacheManager.bytes();
      await LiteCacheManager.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم تحرير ${LiteCacheManager.humanBytes(before)} من الملفات المؤقتة.')));
    })),
  ]);

  Widget _action(IconData icon, String title, String sub, VoidCallback onTap) => Card(
    child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16), child: Padding(
      padding: const EdgeInsets.all(18), child: Row(children: [
        Container(width: 50, height: 50, decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: const Color(0x22C5A66A)), child: Icon(icon)),
        const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(sub, style: const TextStyle(color: Colors.white54)),
        ])), const Icon(Icons.chevron_left),
      ]),
    )),
  );

  Widget _projects() => FutureBuilder<List<EditorProject>>(
    future: store.list(),
    builder: (context, snap) {
      final items = snap.data ?? const <EditorProject>[];
      return ListView(padding: const EdgeInsets.all(18), children: [
        const Text('مشاريعي', textAlign: TextAlign.right, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        if (items.isEmpty) const Padding(padding: EdgeInsets.all(30), child: Text('ماكو مشاريع محفوظة بعد.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54))),
        ...items.map((p) => Card(child: ListTile(title: Text(p.name, textAlign: TextAlign.right), subtitle: Text('${p.clips.length} مقطع', textAlign: TextAlign.right), trailing: const Icon(Icons.movie_outlined), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LiteEditor(project: p, store: store)))))),
      ]);
    },
  );
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
      appBar: AppBar(title: const Text('المحرر Lite'), actions: [
        IconButton(onPressed: busy ? null : () async { await widget.store.save(widget.project); _msg('تم حفظ المشروع'); }, icon: const Icon(Icons.save_outlined)),
      ]),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        AspectRatio(aspectRatio: controller?.value.aspectRatio ?? 16/9, child: controller == null ? const ColoredBox(color: Colors.black, child: Center(child: Icon(Icons.movie_outlined, size: 50))) : VideoPlayer(controller!)),
        if (loading) const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator()),
        if (loadError != null) Padding(padding: const EdgeInsets.all(8), child: SelectableText('تعذر تشغيل المعاينة:\n$loadError', textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent, fontSize: 12))),
        if (controller != null) IconButton(icon: Icon(controller!.value.isPlaying ? Icons.pause : Icons.play_arrow), onPressed: () { setState(() { controller!.value.isPlaying ? controller!.pause() : controller!.play(); }); }),
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
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(_fmt(total * trimEnd)), Text(_fmt(total * trimStart))]),
    ])));
  }

  String _fmt(double ms) { final s = (ms / 1000).round(); return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}'; }
}
