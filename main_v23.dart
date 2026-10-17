import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
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

  static Future<NativeExportResult> overlayImage({
    required String input,
    required String overlay,
    required String output,
  }) async {
    final r = await _ch.invokeMethod<Map>('overlayImage', {'input': input, 'overlay': overlay, 'output': output});
    if (r == null) throw StateError('فشل إضافة النص');
    return NativeExportResult(r['path'] as String, (r['durationMs'] as num).toInt());
  }

  static Future<NativeExportResult> applyEffect({
    required String input,
    required String output,
    required String effect,
    required int durationMs,
  }) async {
    final r = await _ch.invokeMethod<Map>('applyEffect', {'input': input, 'output': output, 'effect': effect, 'durationMs': durationMs});
    if (r == null) throw StateError('فشل تطبيق التأثير');
    return NativeExportResult(r['path'] as String, (r['durationMs'] as num).toInt());
  }

  static Future<NativeExportResult> mergeFade({required List<String> inputs, required String output}) async {
    final r = await _ch.invokeMethod<Map>('mergeFade', {'inputs': inputs, 'output': output});
    if (r == null) throw StateError('فشل الدمج مع التلاشي');
    return NativeExportResult(r['path'] as String, (r['durationMs'] as num).toInt());
  }

  static Future<NativeExportResult> makeSlideshow({
    required List<String> images,
    required String output,
    required int slideMs,
    required String motion,
    required bool fade,
    String extra = 'none',
    String? audio,
    double volume = 1.0,
  }) async {
    final r = await _ch.invokeMethod<Map>('makeSlideshow', {
      'images': images, 'output': output, 'slideMs': slideMs, 'motion': motion,
      'fade': fade, 'extra': extra, 'audio': audio, 'volume': volume,
    });
    if (r == null) throw StateError('فشل إنشاء الفيديو');
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

class _Tpl {
  const _Tpl({
    required this.name,
    required this.desc,
    required this.icon,
    required this.c1,
    required this.c2,
    required this.slideMs,
    required this.motion,
    required this.fade,
    required this.titleStyle,
    required this.cat,
    this.extra = 'none',
    this.tint = 'none',
  });
  final String name;
  final String desc;
  final IconData icon;
  final Color c1;
  final Color c2;
  final int slideMs;
  final String motion;
  final bool fade;
  final _TextStyleTpl titleStyle;
  final String cat;
  final String extra;
  final String tint;
}

const List<String> _kStickers = [
  '😀', '😍', '🥰', '😎', '🤩', '😂', '😭', '😡', '👍', '👏', '🙏', '💪',
  '❤️', '💛', '💙', '💚', '💜', '🔥', '✨', '⭐', '🌟', '💫', '🎉', '🎊',
  '🎁', '🎶', '🎵', '👑', '💎', '🌹', '🌸', '🌙', '☀️', '⚡', '🌈', '🕌',
  '☪️', '🤲', '📿', '🏆',
];

Widget _stickerRow(void Function(String) onPick, bool enabled) {
  return SizedBox(
    height: 52,
    child: ListView(
      scrollDirection: Axis.horizontal,
      children: _kStickers.map((e) => InkWell(
        onTap: enabled ? () => onPick(e) : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          child: Text(e, style: const TextStyle(fontSize: 28)),
        ),
      )).toList(),
    ),
  );
}

class _CollageOpts {
  _CollageOpts(this.layout, this.square, this.bg, this.gap);
  final String layout;
  final bool square;
  final int bg;
  final double gap;
  Color get bgColor => bg == 1 ? Colors.white : (bg == 2 ? kGold : Colors.black);
}

List<Rect> _collageRects(int n, String layout, double w, double h, double gap) {
  final out = <Rect>[];
  if (layout == 'v') {
    final ch = (h - gap * (n + 1)) / n;
    for (var i = 0; i < n; i++) {
      out.add(Rect.fromLTWH(gap, gap + i * (ch + gap), w - gap * 2, ch));
    }
  } else if (layout == 'h') {
    final cw = (w - gap * (n + 1)) / n;
    for (var i = 0; i < n; i++) {
      out.add(Rect.fromLTWH(gap + i * (cw + gap), gap, cw, h - gap * 2));
    }
  } else if (layout == 'hero' && n >= 3) {
    final rest = n - 1;
    if (w >= h) {
      final heroW = w * 0.6;
      out.add(Rect.fromLTWH(gap, gap, heroW - gap * 1.5, h - gap * 2));
      final ch = (h - gap * (rest + 1)) / rest;
      final x = heroW + gap * 0.5;
      for (var i = 0; i < rest; i++) {
        out.add(Rect.fromLTWH(x, gap + i * (ch + gap), w - x - gap, ch));
      }
    } else {
      final heroH = h * 0.55;
      out.add(Rect.fromLTWH(gap, gap, w - gap * 2, heroH - gap * 1.5));
      final cw = (w - gap * (rest + 1)) / rest;
      final y = heroH + gap * 0.5;
      for (var i = 0; i < rest; i++) {
        out.add(Rect.fromLTWH(gap + i * (cw + gap), y, cw, h - y - gap));
      }
    }
  } else {
    final cols = n == 2 ? (w >= h ? 2 : 1) : (n <= 4 ? 2 : 3);
    final rows = (n + cols - 1) ~/ cols;
    final ch = (h - gap * (rows + 1)) / rows;
    var idx = 0;
    for (var r = 0; r < rows; r++) {
      final left = n - idx;
      final k = left < cols ? left : cols;
      final cw = (w - gap * (k + 1)) / k;
      for (var c = 0; c < k; c++) {
        out.add(Rect.fromLTWH(gap + c * (cw + gap), gap + r * (ch + gap), cw, ch));
        idx++;
      }
    }
  }
  return out;
}

class _AiStyle {
  const _AiStyle(this.name, this.suffix);
  final String name;
  final String suffix;
}

const List<_AiStyle> _kAiStyles = [
  _AiStyle('واقعي', 'photorealistic, ultra detailed, sharp focus, natural light'),
  _AiStyle('سينمائي', 'cinematic still, dramatic lighting, film grain, shallow depth of field'),
  _AiStyle('إسلامي ذهبي', 'islamic geometric ornament, black and gold, elegant, luxurious, ornate'),
  _AiStyle('أنمي', 'anime style, vibrant colors, detailed illustration'),
  _AiStyle('رسم زيتي', 'oil painting, classic art, rich brush strokes'),
  _AiStyle('ثلاثي الأبعاد', '3d render, soft lighting, pixar style'),
  _AiStyle('بدون نمط', ''),
];

class _AiStudioPage extends StatefulWidget {
  const _AiStudioPage({required this.onEdit, required this.onVideo});
  final Future<void> Function(String path) onEdit;
  final Future<void> Function(List<String> paths) onVideo;
  @override
  State<_AiStudioPage> createState() => _AiStudioPageState();
}

class _AiStudioPageState extends State<_AiStudioPage> {
  final ctrl = TextEditingController();
  int style = 0;
  int aspect = 0;
  int count = 2;
  bool busy = false;
  int done = 0;
  String? error;
  String? usedPrompt;
  final List<String> results = [];

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  int get _w => aspect == 0 ? 768 : (aspect == 1 ? 1024 : 1344);
  int get _h => aspect == 0 ? 1344 : (aspect == 1 ? 1024 : 768);

  Future<String> _translate(String text) async {
    if (!RegExp(r'[\u0600-\u06FF]').hasMatch(text)) return text;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final q = 'Translate to a short English image prompt, output only the translation: $text';
      final req = await client.getUrl(Uri.parse('https://text.pollinations.ai/${Uri.encodeComponent(q)}'));
      final res = await req.close().timeout(const Duration(seconds: 40));
      if (res.statusCode != 200) return text;
      final body = (await res.transform(utf8.decoder).join()).trim();
      if (body.isEmpty || body.length > 500) return text;
      return body;
    } catch (_) {
      return text;
    } finally {
      client.close();
    }
  }

  Future<String> _fetchOnce(String prompt, int seed, int attempt) async {
    final enc = Uri.encodeComponent(prompt);
    String url;
    if (attempt == 0) {
      url = 'https://image.pollinations.ai/prompt/$enc?width=$_w&height=$_h&seed=$seed&model=flux&nologo=true';
    } else if (attempt == 1) {
      url = 'https://image.pollinations.ai/prompt/$enc?width=$_w&height=$_h&seed=$seed';
    } else {
      url = 'https://image.pollinations.ai/prompt/$enc?seed=$seed';
    }
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 25);
    try {
      final req = await client.getUrl(Uri.parse(url));
      final res = await req.close().timeout(const Duration(seconds: 150));
      if (res.statusCode != 200) throw HttpException('الخدمة ردّت برمز ${res.statusCode}');
      final data = <int>[];
      await for (final chunk in res) {
        data.addAll(chunk);
      }
      final bytes = Uint8List.fromList(data);
      final codec = await ui.instantiateImageCodec(bytes);
      codec.dispose();
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}/ai');
      await dir.create(recursive: true);
      final f = File('${dir.path}/ai_${DateTime.now().millisecondsSinceEpoch}_$seed.jpg');
      await f.writeAsBytes(bytes, flush: true);
      return f.path;
    } finally {
      client.close();
    }
  }

  Future<String> _fetch(String prompt, int seed) async {
    Object? lastErr;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        return await _fetchOnce(prompt, seed + attempt * 101, attempt);
      } catch (e) {
        lastErr = e;
        await Future.delayed(Duration(seconds: 4 + attempt * 4));
      }
    }
    throw lastErr ?? StateError('فشل إنشاء الصورة');
  }

  Future<void> _generate() async {
    var text = ctrl.text.trim();
    if (text.isEmpty || busy) return;
    if (text.length > 400) text = text.substring(0, 400);
    FocusScope.of(context).unfocus();
    setState(() { busy = true; done = 0; error = null; });
    final suffix = _kAiStyles[style].suffix;
    text = text.replaceAll(RegExp(r'[\r\n]+'), ' ');
    final eng = await _translate(text);
    final prompt = suffix.isEmpty ? eng : '$eng, $suffix';
    if (mounted) setState(() => usedPrompt = eng);
    final base = DateTime.now().millisecondsSinceEpoch % 100000;
    final found = <String>[];
    String? err;
    for (var i = 0; i < count; i++) {
      if (i > 0) await Future.delayed(const Duration(seconds: 3));
      try {
        found.add(await _fetch(prompt, base + i * 7919));
      } catch (e) {
        err = '$e';
      }
      if (!mounted) return;
      setState(() => done = i + 1);
    }
    if (!mounted) return;
    setState(() {
      busy = false;
      if (found.isNotEmpty) {
        results
          ..clear()
          ..addAll(found);
      }
      error = found.isEmpty ? 'الخدمة المجانية مشغولة أو متوقفة مؤقتًا، أو لا يوجد إنترنت. انتظر دقيقة وحاول مرة ثانية.\n(${err ?? ''})' : null;
    });
  }

  void _actions(String path) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('فتح في محرر الصور'),
            onTap: () { Navigator.pop(ctx); widget.onEdit(path); },
          ),
          ListTile(
            leading: const Icon(Icons.movie_creation_outlined),
            title: const Text('تحويل إلى فيديو بقالب'),
            onTap: () { Navigator.pop(ctx); widget.onVideo([path]); },
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('تصميم بالذكاء الاصطناعي')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          TextField(
            controller: ctrl,
            maxLines: 3,
            minLines: 2,
            decoration: const InputDecoration(
              hintText: 'صف الصورة التي تريدها... (الوصف بالإنجليزية يعطي نتائج أفضل)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          const Text('النمط', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 4, children: List.generate(_kAiStyles.length, (i) => ChoiceChip(
            label: Text(_kAiStyles[i].name),
            selected: style == i,
            onSelected: busy ? null : (_) => setState(() => style = i),
          ))),
          const SizedBox(height: 10),
          const Text('الأبعاد', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, children: [
            ChoiceChip(label: const Text('عمودي 9:16'), selected: aspect == 0, onSelected: busy ? null : (_) => setState(() => aspect = 0)),
            ChoiceChip(label: const Text('مربع 1:1'), selected: aspect == 1, onSelected: busy ? null : (_) => setState(() => aspect = 1)),
            ChoiceChip(label: const Text('أفقي 16:9'), selected: aspect == 2, onSelected: busy ? null : (_) => setState(() => aspect = 2)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            const Text('عدد الصور', style: TextStyle(fontWeight: FontWeight.bold)),
            Expanded(child: Slider(value: count.toDouble(), min: 1, max: 4, divisions: 3, label: '$count', onChanged: busy ? null : (v) => setState(() => count = v.round()))),
            Text('$count'),
          ]),
          FilledButton.icon(
            onPressed: busy ? null : _generate,
            icon: const Icon(Icons.auto_awesome),
            label: Text(busy ? 'جاري الإنشاء ($done / $count)...' : 'إنشاء'),
          ),
          const SizedBox(height: 6),
          const Text(
            'يحتاج إنترنت. يُرسل نص الوصف فقط إلى خدمة خارجية (Pollinations)، ويستغرق كل تصميم من 10 إلى 60 ثانية.',
            style: TextStyle(color: Colors.white54, fontSize: 11),
          ),
          if (usedPrompt != null) Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('الوصف المُرسل: $usedPrompt', textDirection: TextDirection.ltr, style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ),
          if (busy) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
          if (error != null) Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(error!, style: const TextStyle(color: Colors.redAccent)),
          ),
          if (results.isNotEmpty) ...[
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: aspect == 0 ? 0.6 : (aspect == 1 ? 1.0 : 1.6),
              children: results.map((p) => InkWell(
                onTap: () => _actions(p),
                borderRadius: BorderRadius.circular(14),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.file(File(p), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined)),
                ),
              )).toList(),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: busy ? null : () => widget.onVideo(List<String>.from(results)),
              icon: const Icon(Icons.movie_creation_outlined),
              label: const Text('تحويل كل الصور إلى فيديو بقالب'),
            ),
          ],
        ]),
      ),
    );
  }
}

class _TplOpts {
  _TplOpts(this.title, this.music);
  final String title;
  final MusicPick? music;
}

const _TextStyleTpl _tsGold = _TextStyleTpl('عنوان', Color(0xFFD4AF6A), 0.09, true, 0);
const _TextStyleTpl _tsWhite = _TextStyleTpl('عنوان', Colors.white, 0.08, true, 0);
const _TextStyleTpl _tsQuote = _TextStyleTpl('عنوان', Colors.white, 0.06, false, 1);
const _TextStyleTpl _tsBanner = _TextStyleTpl('عنوان', Colors.black, 0.07, true, 2);
const _TextStyleTpl _tsSoft = _TextStyleTpl('عنوان', Colors.white, 0.06, false, 0);

const List<String> _kTplCats = ['الكل', 'هادئ', 'سريع', 'فاخر', 'رومانسي'];

const List<_Tpl> _kTemplates = [
  _Tpl(name: 'ذكريات', desc: 'تكبير بطيء بألوان دافئة', icon: Icons.favorite_border, c1: Color(0xFF5A3E1B), c2: Color(0xFF14100A), slideMs: 3000, motion: 'zoom', fade: true, titleStyle: _tsGold, cat: 'هادئ', tint: 'warm'),
  _Tpl(name: 'سينمائي', desc: 'لقطات بطيئة بلمسة باردة', icon: Icons.movie_filter_outlined, c1: Color(0xFF1B2A3A), c2: Color(0xFF0A0E14), slideMs: 4000, motion: 'zoom', fade: true, titleStyle: _tsQuote, cat: 'فاخر', tint: 'cool'),
  _Tpl(name: 'نبض', desc: 'إيقاع سريع مع وميض', icon: Icons.bolt, c1: Color(0xFF5A1B2B), c2: Color(0xFF140A0E), slideMs: 1800, motion: 'pulse', fade: false, titleStyle: _tsWhite, cat: 'سريع', extra: 'flash'),
  _Tpl(name: 'ذهبي فاخر', desc: 'تكبير مع لافتة ذهبية', icon: Icons.auto_awesome, c1: Color(0xFF6B4E16), c2: Color(0xFF1A1206), slideMs: 3500, motion: 'zoom', fade: true, titleStyle: _tsBanner, cat: 'فاخر', tint: 'warm'),
  _Tpl(name: 'اهتزاز', desc: 'حركة حيوية قصيرة', icon: Icons.vibration, c1: Color(0xFF1B4A3A), c2: Color(0xFF0A1410), slideMs: 2000, motion: 'shake', fade: false, titleStyle: _tsWhite, cat: 'سريع'),
  _Tpl(name: 'هادئ', desc: 'صور ثابتة بألوان باهتة', icon: Icons.spa_outlined, c1: Color(0xFF2A2A3A), c2: Color(0xFF0E0E14), slideMs: 3500, motion: 'none', fade: true, titleStyle: _tsSoft, cat: 'هادئ', tint: 'fade'),
  _Tpl(name: 'رحلة', desc: 'تحريك يمين ويسار وتكبير', icon: Icons.flight_takeoff, c1: Color(0xFF1B3F5A), c2: Color(0xFF0A1218), slideMs: 3000, motion: 'panLeft,panRight,zoom', fade: true, titleStyle: _tsWhite, cat: 'هادئ', tint: 'vivid'),
  _Tpl(name: 'عرض سريع', desc: 'ظهور مفاجئ مع وميض', icon: Icons.flash_on, c1: Color(0xFF5A4A1B), c2: Color(0xFF14110A), slideMs: 1200, motion: 'pop,zoom,pulse', fade: false, titleStyle: _tsWhite, cat: 'سريع', extra: 'flash'),
  _Tpl(name: 'نبض القلب', desc: 'خفقان رومانسي دافئ', icon: Icons.favorite, c1: Color(0xFF5A1B3A), c2: Color(0xFF140A10), slideMs: 2800, motion: 'heartbeat', fade: true, titleStyle: _tsGold, cat: 'رومانسي', tint: 'warm'),
  _Tpl(name: 'أنيق', desc: 'تصغير هادئ بالأبيض والأسود', icon: Icons.diamond_outlined, c1: Color(0xFF333333), c2: Color(0xFF0A0A0A), slideMs: 4000, motion: 'zoomout', fade: true, titleStyle: _tsQuote, cat: 'فاخر', tint: 'bw'),
  _Tpl(name: 'إيقاع', desc: 'نبض واهتزاز متبادل', icon: Icons.music_note, c1: Color(0xFF3A1B5A), c2: Color(0xFF0E0A14), slideMs: 1500, motion: 'pulse,shake', fade: false, titleStyle: _tsWhite, cat: 'سريع', extra: 'flash', tint: 'vivid'),
  _Tpl(name: 'ضوء', desc: 'تكبير مع إضاءة نابضة', icon: Icons.wb_sunny_outlined, c1: Color(0xFF5A4A2A), c2: Color(0xFF14100A), slideMs: 3200, motion: 'zoom', fade: true, titleStyle: _tsGold, cat: 'رومانسي', extra: 'pulseLight', tint: 'warm'),
  _Tpl(name: 'تصفح', desc: 'تحريك لأعلى ولأسفل', icon: Icons.swap_vert, c1: Color(0xFF1B5A5A), c2: Color(0xFF0A1414), slideMs: 3000, motion: 'panUp,panDown', fade: true, titleStyle: _tsSoft, cat: 'هادئ', tint: 'vivid'),
  _Tpl(name: 'رياضي', desc: 'حركة عنيفة مع ومضات', icon: Icons.sports_score, c1: Color(0xFF5A1B1B), c2: Color(0xFF140A0A), slideMs: 1400, motion: 'shake,pop,pulse', fade: false, titleStyle: _tsWhite, cat: 'سريع', extra: 'strobe', tint: 'vivid'),
  _Tpl(name: 'دراما', desc: 'تكبير بطيء أبيض وأسود', icon: Icons.theater_comedy_outlined, c1: Color(0xFF2A2A2A), c2: Color(0xFF050505), slideMs: 5000, motion: 'zoom', fade: true, titleStyle: _tsQuote, cat: 'فاخر', tint: 'bw'),
  _Tpl(name: 'تمايل', desc: 'حركة موجية ناعمة', icon: Icons.waves, c1: Color(0xFF1B3A5A), c2: Color(0xFF0A0E14), slideMs: 2500, motion: 'sway', fade: true, titleStyle: _tsSoft, cat: 'رومانسي'),
  _Tpl(name: 'أحلام', desc: 'حركة حالمة وإضاءة هادئة', icon: Icons.bedtime_outlined, c1: Color(0xFF3A2A5A), c2: Color(0xFF0E0A14), slideMs: 4000, motion: 'panLeft,zoomout', fade: true, titleStyle: _tsSoft, cat: 'رومانسي', extra: 'pulseLight', tint: 'fade'),
  _Tpl(name: 'عتيق', desc: 'بني قديم مثل الصور القديمة', icon: Icons.camera_alt_outlined, c1: Color(0xFF5A4A2A), c2: Color(0xFF120E08), slideMs: 3500, motion: 'zoom', fade: true, titleStyle: _tsGold, cat: 'فاخر', tint: 'sepia'),
];

const List<_TextStyleTpl> _kTextStyles = [
  _TextStyleTpl('عنوان ذهبي', Color(0xFFD4AF6A), 0.09, true, 0),
  _TextStyleTpl('اقتباس', Colors.white, 0.06, false, 1),
  _TextStyleTpl('لافتة', Colors.black, 0.07, true, 2),
  _TextStyleTpl('أبيض بسيط', Colors.white, 0.07, true, 0),
];

const List<Color> _kPalette = [
  Colors.white, Color(0xFFD4AF6A), Colors.black, Color(0xFFE53935), Color(0xFF1E88E5), Color(0xFF43A047),
];

Future<File> _settingsFile() async {
  final dir = await getApplicationDocumentsDirectory();
  return File('${dir.path}/settings.json');
}

Future<bool> _readWatermark() async {
  try {
    final f = await _settingsFile();
    if (await f.exists()) {
      final m = jsonDecode(await f.readAsString()) as Map;
      return m['watermark'] != false;
    }
  } catch (_) {}
  return true;
}

Future<void> _writeWatermark(bool v) async {
  try {
    final f = await _settingsFile();
    await f.writeAsString(jsonEncode({'watermark': v}));
  } catch (_) {}
}

List<double>? _tintMatrix(String t) {
  switch (t) {
    case 'warm':
      return const [1.1, 0, 0, 0, 12, 0, 1.0, 0, 0, 0, 0, 0, 0.88, 0, -12, 0, 0, 0, 1, 0];
    case 'cool':
      return const [0.9, 0, 0, 0, -8, 0, 1.0, 0, 0, 0, 0, 0, 1.15, 0, 12, 0, 0, 0, 1, 0];
    case 'bw':
      return const [0.33, 0.59, 0.11, 0, 0, 0.33, 0.59, 0.11, 0, 0, 0.33, 0.59, 0.11, 0, 0, 0, 0, 0, 1, 0];
    case 'sepia':
      return const [0.393, 0.769, 0.189, 0, 0, 0.349, 0.686, 0.168, 0, 0, 0.272, 0.534, 0.131, 0, 0, 0, 0, 0, 1, 0];
    case 'fade':
      return const [0.9, 0, 0, 0, 25, 0, 0.9, 0, 0, 25, 0, 0, 0.9, 0, 25, 0, 0, 0, 1, 0];
    case 'vivid':
      return const [1.35, -0.2, -0.15, 0, 0, -0.1, 1.25, -0.15, 0, 0, -0.1, -0.2, 1.3, 0, 0, 0, 0, 0, 1, 0];
    default:
      return null;
  }
}

bool _layerRtl(String t) => RegExp(r'[\u0600-\u06FF]').hasMatch(t);

Color? _layerBg(int b) => b == 1 ? const Color(0xB3000000) : (b == 2 ? kGold : null);

Widget _layerBox(_TextLayer t, double refWidth, {bool selected = false}) {
  final fs = t.size * refWidth;
  return Container(
    constraints: BoxConstraints(maxWidth: refWidth * 0.9),
    padding: EdgeInsets.symmetric(horizontal: fs * 0.35, vertical: fs * 0.15),
    decoration: BoxDecoration(
      color: _layerBg(t.bg),
      borderRadius: BorderRadius.circular(fs * 0.25),
      border: selected ? Border.all(color: kGold, width: 1.5) : null,
    ),
    child: Text(
      t.text,
      textAlign: TextAlign.center,
      textDirection: _layerRtl(t.text) ? TextDirection.rtl : TextDirection.ltr,
      style: TextStyle(fontSize: fs, color: t.color, fontWeight: t.bold ? FontWeight.bold : FontWeight.normal, height: 1.2),
    ),
  );
}

void _paintLayer(Canvas canvas, _TextLayer t, double w, double h) {
  final fs = t.size * w;
  final tp = TextPainter(
    text: TextSpan(text: t.text, style: TextStyle(fontSize: fs, color: t.color, fontWeight: t.bold ? FontWeight.bold : FontWeight.normal, height: 1.2)),
    textAlign: TextAlign.center,
    textDirection: _layerRtl(t.text) ? TextDirection.rtl : TextDirection.ltr,
  )..layout(maxWidth: w * 0.9);
  final padX = fs * 0.35;
  final padY = fs * 0.15;
  final cx = t.dx * w;
  final cy = t.dy * h;
  final rect = Rect.fromCenter(center: Offset(cx, cy), width: tp.width + padX * 2, height: tp.height + padY * 2);
  final bg = _layerBg(t.bg);
  if (bg != null) {
    canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(fs * 0.25)), Paint()..color = bg);
  }
  tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
}

class _TextLayer {
  _TextLayer({required this.text, this.dx = 0.5, this.dy = 0.5, this.size = 0.07, this.color = Colors.white, this.bold = true, this.bg = 0});
  String text;
  double dx;
  double dy;
  double size;
  Color color;
  bool bold;
  int bg;
}

class _LookTemplate {
  const _LookTemplate(this.name, this.filter, this.brightness, this.contrast, this.saturation);
  final String name;
  final String filter;
  final double brightness;
  final double contrast;
  final double saturation;
}

class _TextStyleTpl {
  const _TextStyleTpl(this.name, this.color, this.size, this.bold, this.bg);
  final String name;
  final Color color;
  final double size;
  final bool bold;
  final int bg;
}

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
  final List<_TextLayer> texts = [];
  int? selectedText;
  bool dragging = false;
  double imgW = 0;
  double imgH = 0;

  static const List<_LookTemplate> _look = [
    _LookTemplate('طبيعي', 'none', 0, 1, 1),
    _LookTemplate('ذهبي فاخر', 'warm', 0.05, 1.1, 1.15),
    _LookTemplate('سينمائي', 'cool', -0.05, 1.25, 0.9),
    _LookTemplate('كلاسيك', 'bw', 0, 1.15, 1),
    _LookTemplate('مشرق', 'bright', 0, 1.05, 1.2),
    _LookTemplate('دراما', 'contrast', -0.1, 1.1, 1.1),
  ];

  static const List<_TextStyleTpl> _textStyles = [
    _TextStyleTpl('عنوان ذهبي', Color(0xFFD4AF6A), 0.09, true, 0),
    _TextStyleTpl('اقتباس', Colors.white, 0.06, false, 1),
    _TextStyleTpl('لافتة', Colors.black, 0.07, true, 2),
    _TextStyleTpl('أبيض بسيط', Colors.white, 0.07, true, 0),
  ];

  static const List<Color> _palette = [
    Colors.white, Color(0xFFD4AF6A), Colors.black, Color(0xFFE53935), Color(0xFF1E88E5), Color(0xFF43A047),
  ];

  @override
  void initState() {
    super.initState();
    _loadDims();
  }

  Future<void> _loadDims() async {
    try {
      final bytes = await File(clip.path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (mounted) setState(() { imgW = frame.image.width.toDouble(); imgH = frame.image.height.toDouble(); });
    } catch (_) {}
  }

  bool _isRtl(String t) => RegExp(r'[\u0600-\u06FF]').hasMatch(t);

  Color? _bgColor(int b) => b == 1 ? const Color(0xB3000000) : (b == 2 ? kGold : null);

  Future<String?> _askText(String initial) {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('اكتب النص'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          minLines: 1,
          textDirection: TextDirection.rtl,
          decoration: const InputDecoration(hintText: 'النص هنا'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('تم')),
        ],
      ),
    );
  }

  void _addSticker(String e) {
    setState(() {
      texts.add(_TextLayer(text: e, size: 0.16, bold: false));
      selectedText = texts.length - 1;
    });
  }

  Future<void> _addText(_TextStyleTpl? st) async {
    final v = await _askText('');
    if (v == null || v.trim().isEmpty || !mounted) return;
    setState(() {
      texts.add(_TextLayer(text: v.trim(), color: st?.color ?? Colors.white, size: st?.size ?? 0.07, bold: st?.bold ?? true, bg: st?.bg ?? 0));
      selectedText = texts.length - 1;
    });
  }

  Future<void> _editText(_TextLayer t) async {
    final v = await _askText(t.text);
    if (v == null || v.trim().isEmpty || !mounted) return;
    setState(() => t.text = v.trim());
  }

  Widget _textBox(_TextLayer t, double refWidth, {bool selected = false}) {
    final fs = t.size * refWidth;
    return Container(
      constraints: BoxConstraints(maxWidth: refWidth * 0.9),
      padding: EdgeInsets.symmetric(horizontal: fs * 0.35, vertical: fs * 0.15),
      decoration: BoxDecoration(
        color: _bgColor(t.bg),
        borderRadius: BorderRadius.circular(fs * 0.25),
        border: selected ? Border.all(color: kGold, width: 1.5) : null,
      ),
      child: Text(
        t.text,
        textAlign: TextAlign.center,
        textDirection: _isRtl(t.text) ? TextDirection.rtl : TextDirection.ltr,
        style: TextStyle(fontSize: fs, color: t.color, fontWeight: t.bold ? FontWeight.bold : FontWeight.normal, height: 1.2),
      ),
    );
  }

  Widget _preview(double bw, double bh, List<double> m) {
    final base = ColorFiltered(colorFilter: ColorFilter.matrix(m), child: Image.file(File(clip.path), fit: BoxFit.contain));
    if (imgW <= 0 || imgH <= 0) return base;
    final scale = (bw / imgW) < (bh / imgH) ? bw / imgW : bh / imgH;
    final dw = imgW * scale;
    final dh = imgH * scale;
    final left = (bw - dw) / 2;
    final top = (bh - dh) / 2;
    return Stack(children: [
      Positioned.fill(child: base),
      for (var i = 0; i < texts.length; i++)
        Positioned(
          left: left + texts[i].dx * dw,
          top: top + texts[i].dy * dh,
          child: FractionalTranslation(
            translation: const Offset(-0.5, -0.5),
            child: Listener(
              onPointerDown: (_) => setState(() => dragging = true),
              onPointerUp: (_) => setState(() => dragging = false),
              onPointerCancel: (_) => setState(() => dragging = false),
              child: GestureDetector(
                onTap: () => setState(() => selectedText = i),
                onPanUpdate: (d) => setState(() {
                  selectedText = i;
                  texts[i].dx = (texts[i].dx + d.delta.dx / dw).clamp(0.0, 1.0).toDouble();
                  texts[i].dy = (texts[i].dy + d.delta.dy / dh).clamp(0.0, 1.0).toDouble();
                }),
                child: _textBox(texts[i], dw, selected: selectedText == i),
              ),
            ),
          ),
        ),
    ]);
  }

  void _drawText(Canvas canvas, _TextLayer t, double w, double h) {
    final fs = t.size * w;
    final tp = TextPainter(
      text: TextSpan(text: t.text, style: TextStyle(fontSize: fs, color: t.color, fontWeight: t.bold ? FontWeight.bold : FontWeight.normal, height: 1.2)),
      textAlign: TextAlign.center,
      textDirection: _isRtl(t.text) ? TextDirection.rtl : TextDirection.ltr,
    )..layout(maxWidth: w * 0.9);
    final padX = fs * 0.35;
    final padY = fs * 0.15;
    final cx = t.dx * w;
    final cy = t.dy * h;
    final rect = Rect.fromCenter(center: Offset(cx, cy), width: tp.width + padX * 2, height: tp.height + padY * 2);
    final bg = _bgColor(t.bg);
    if (bg != null) {
      canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(fs * 0.25)), Paint()..color = bg);
    }
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }

  Widget _lookCard() => Card(child: Column(children: [
    const ListTile(title: Text('القوالب', textAlign: TextAlign.right), subtitle: Text('أنماط جاهزة للألوان', textAlign: TextAlign.right)),
    SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: _look.map((t) => Padding(
          padding: const EdgeInsets.only(left: 8),
          child: ActionChip(
            label: Text(t.name),
            onPressed: saving ? null : () => setState(() {
              filter = t.filter;
              brightness = t.brightness;
              contrast = t.contrast;
              saturation = t.saturation;
            }),
          ),
        )).toList(),
      ),
    ),
    const SizedBox(height: 12),
  ]));

  Widget _textCard() {
    final sel = (selectedText != null && selectedText! < texts.length) ? texts[selectedText!] : null;
    return Card(child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('النصوص والملصقات', textAlign: TextAlign.right, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _stickerRow(_addSticker, !saving),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.icon(onPressed: saving ? null : () => _addText(null), icon: const Icon(Icons.add), label: const Text('إضافة نص')),
          ..._textStyles.map((st) => ActionChip(label: Text(st.name), onPressed: saving ? null : () => _addText(st))),
        ]),
        if (sel != null) ...[
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: _palette.map((c) => GestureDetector(
            onTap: () => setState(() => sel.color = c),
            child: Container(
              width: 30,
              height: 30,
              margin: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                border: Border.all(color: sel.color == c ? kGold : Colors.white24, width: sel.color == c ? 3 : 1),
              ),
            ),
          )).toList()),
          _slider('الحجم', sel.size, 0.03, 0.2, (v) => setState(() => sel.size = v)),
          Wrap(spacing: 8, runSpacing: 4, alignment: WrapAlignment.center, children: [
            ChoiceChip(label: const Text('بلا خلفية'), selected: sel.bg == 0, onSelected: (_) => setState(() => sel.bg = 0)),
            ChoiceChip(label: const Text('خلفية داكنة'), selected: sel.bg == 1, onSelected: (_) => setState(() => sel.bg = 1)),
            ChoiceChip(label: const Text('خلفية ذهبية'), selected: sel.bg == 2, onSelected: (_) => setState(() => sel.bg = 2)),
            FilterChip(label: const Text('عريض'), selected: sel.bold, onSelected: (v) => setState(() => sel.bold = v)),
          ]),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            TextButton.icon(onPressed: () => _editText(sel), icon: const Icon(Icons.edit_outlined), label: const Text('تعديل')),
            TextButton.icon(onPressed: () => setState(() { texts.remove(sel); selectedText = null; }), icon: const Icon(Icons.delete_outline), label: const Text('حذف')),
          ]),
        ] else
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('اضغط "إضافة نص" ثم اسحب النص على الصورة لتحريكه.', textAlign: TextAlign.right, style: TextStyle(color: Colors.white54, fontSize: 12)),
          ),
      ]),
    ));
  }
  VideoPlayerController? _musicPlayer;
  bool _musicPlaying = false;

  Future<void> _startMusicPreview(String path) async {
    final old = _musicPlayer;
    _musicPlayer = null;
    await old?.dispose();
    final c = VideoPlayerController.file(File(path), videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));
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
    for (final t in texts) { _drawText(canvas, t, img.width.toDouble(), img.height.toDouble()); }
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
      final now = DateTime.now().microsecondsSinceEpoch.toString();
      final vp = EditorProject(
        id: now,
        name: 'فيديو من صورة',
        clips: [EditorClip(id: now, kind: ClipKind.video, path: r.path, durationMs: r.durationMs)],
      );
      await widget.store.save(vp);
      if (!mounted) return;
      _msg('تم إنشاء الفيديو. اضغط "حفظ الفيديو في المعرض" لحفظه.');
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => editorFor(vp, widget.store)));
      return;
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
      body: ListView(physics: dragging ? const NeverScrollableScrollPhysics() : null, padding: const EdgeInsets.all(14), children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ColoredBox(
            color: Colors.black,
            child: SizedBox(
              height: 380,
              width: double.infinity,
              child: LayoutBuilder(builder: (context, box) => _preview(box.maxWidth, 380, m)),
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
        _lookCard(),
        const SizedBox(height: 10),
        _textCard(),
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
  Set<String> _hidden = {};
  String _cat = 'الكل';
  bool _wm = true;

  void _snack(String t) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  }

  Future<void> _openAi() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _AiStudioPage(onEdit: _editImagePath, onVideo: _videoFromPaths)),
    );
  }

  Future<void> _editImagePath(String path) async {
    final now = DateTime.now().microsecondsSinceEpoch.toString();
    final p = EditorProject(
      id: now,
      name: 'تصميم ذكاء اصطناعي',
      clips: [EditorClip(id: now, kind: ClipKind.image, path: path, durationMs: 5000)],
    );
    await store.save(p);
    if (!mounted) return;
    _open(p);
  }

  Future<void> _videoFromPaths(List<String> paths) async {
    if (paths.isEmpty || !mounted) return;
    final t = await showDialog<_Tpl>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('اختر قالبًا'),
        children: _kTemplates.map((x) => SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, x),
          child: Text('${x.name} - ${x.desc}'),
        )).toList(),
      ),
    );
    if (t == null || !mounted) return;
    await _runTemplate(t, paths);
  }

  Future<_CollageOpts?> _askCollage() {
    var layout = 'grid';
    var square = false;
    var bg = 0;
    var gap = 14.0;
    return showDialog<_CollageOpts>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('إعدادات الكولاج'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('النمط'),
              Wrap(spacing: 8, children: [
                ChoiceChip(label: const Text('شبكة'), selected: layout == 'grid', onSelected: (_) => setD(() => layout = 'grid')),
                ChoiceChip(label: const Text('رأسي'), selected: layout == 'v', onSelected: (_) => setD(() => layout = 'v')),
                ChoiceChip(label: const Text('أفقي'), selected: layout == 'h', onSelected: (_) => setD(() => layout = 'h')),
                ChoiceChip(label: const Text('صورة كبيرة'), selected: layout == 'hero', onSelected: (_) => setD(() => layout = 'hero')),
              ]),
              const SizedBox(height: 10),
              const Text('الحجم'),
              Wrap(spacing: 8, children: [
                ChoiceChip(label: const Text('عمودي 9:16'), selected: !square, onSelected: (_) => setD(() => square = false)),
                ChoiceChip(label: const Text('مربع 1:1'), selected: square, onSelected: (_) => setD(() => square = true)),
              ]),
              const SizedBox(height: 10),
              const Text('الخلفية'),
              Wrap(spacing: 8, children: [
                ChoiceChip(label: const Text('أسود'), selected: bg == 0, onSelected: (_) => setD(() => bg = 0)),
                ChoiceChip(label: const Text('أبيض'), selected: bg == 1, onSelected: (_) => setD(() => bg = 1)),
                ChoiceChip(label: const Text('ذهبي'), selected: bg == 2, onSelected: (_) => setD(() => bg = 2)),
              ]),
              const SizedBox(height: 10),
              const Text('المسافة بين الصور'),
              Slider(value: gap, min: 0, max: 40, onChanged: (v) => setD(() => gap = v)),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(ctx, _CollageOpts(layout, square, bg, gap)), child: const Text('إنشاء')),
          ],
        ),
      ),
    );
  }

  Future<String> _renderCollage(List<String> paths, _CollageOpts o) async {
    const w = 1080.0;
    final h = o.square ? 1080.0 : 1920.0;
    final rects = _collageRects(paths.length, o.layout, w, h, o.gap);
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec, Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = o.bgColor);
    for (var i = 0; i < paths.length; i++) {
      final bytes = await File(paths[i]).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final img = (await codec.getNextFrame()).image;
      final r = rects[i];
      final scale = (r.width / img.width) > (r.height / img.height) ? r.width / img.width : r.height / img.height;
      final dw = img.width * scale;
      final dh = img.height * scale;
      canvas.save();
      canvas.clipRRect(RRect.fromRectAndRadius(r, const Radius.circular(18)));
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        Rect.fromLTWH(r.left + (r.width - dw) / 2, r.top + (r.height - dh) / 2, dw, dh),
        Paint()..filterQuality = FilterQuality.high,
      );
      canvas.restore();
    }
    final out = await rec.endRecording().toImage(w.toInt(), h.toInt());
    final data = await out.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw StateError('تعذر إنشاء الكولاج');
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/exports');
    await dir.create(recursive: true);
    final f = File('${dir.path}/collage_${DateTime.now().millisecondsSinceEpoch}.png');
    await f.writeAsBytes(data.buffer.asUint8List(), flush: true);
    return f.path;
  }

  Future<void> _collage() async {
    List<XFile> files;
    try {
      files = await picker.pickMultiImage(maxWidth: 1600, imageQuality: 85);
    } catch (e) {
      _snack('تعذر فتح المعرض: $e');
      return;
    }
    if (!mounted || files.isEmpty) return;
    if (files.length < 2) { _snack('اختر صورتين على الأقل.'); return; }
    if (files.length > 9) { _snack('اختر 9 صور كحد أقصى.'); return; }
    final opts = await _askCollage();
    if (opts == null || !mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: AlertDialog(content: Row(children: [
          CircularProgressIndicator(),
          SizedBox(width: 16),
          Expanded(child: Text('جاري إنشاء الكولاج...')),
        ])),
      ),
    );
    EditorProject? made;
    String? err;
    try {
      final path = await _renderCollage(files.map((f) => f.path).toList(), opts);
      final now = DateTime.now().microsecondsSinceEpoch.toString();
      final p = EditorProject(
        id: now,
        name: 'كولاج',
        clips: [EditorClip(id: now, kind: ClipKind.image, path: path, durationMs: 5000)],
      );
      await store.save(p);
      made = p;
    } catch (e) {
      err = '$e';
    }
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    if (made != null) {
      _open(made);
    } else {
      _snack('تعذر إنشاء الكولاج: $err');
    }
  }

  Future<_TplOpts?> _askOptions() {
    final ctrl = TextEditingController();
    MusicPick? music;
    return showDialog<_TplOpts>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('تفاصيل الفيديو'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: ctrl,
              textDirection: TextDirection.rtl,
              decoration: const InputDecoration(hintText: 'عنوان على الفيديو (اختياري)'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                try {
                  final m = await MediaApi.pickAudio();
                  if (m != null) setD(() => music = m);
                } catch (_) {}
              },
              icon: const Icon(Icons.library_music_outlined),
              label: Text(music?.name ?? 'اختيار موسيقى (اختياري)', maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(ctx, _TplOpts(ctrl.text.trim(), music)), child: const Text('إنشاء')),
          ],
        ),
      ),
    );
  }

  Future<String> _renderSlide(String path, _TextLayer? title, String tint) async {
    const w = 1080.0;
    const h = 1920.0;
    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final img = (await codec.getNextFrame()).image;
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec, const Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(const Rect.fromLTWH(0, 0, w, h), Paint()..color = Colors.black);
    final scale = (w / img.width) > (h / img.height) ? w / img.width : h / img.height;
    final dw = img.width * scale;
    final dh = img.height * scale;
    final imgPaint = Paint()..filterQuality = FilterQuality.high;
    final tm = _tintMatrix(tint);
    if (tm != null) imgPaint.colorFilter = ColorFilter.matrix(tm);
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      Rect.fromLTWH((w - dw) / 2, (h - dh) / 2, dw, dh),
      imgPaint,
    );
    if (title != null) _paintLayer(canvas, title, w, h);
    final out = await rec.endRecording().toImage(w.toInt(), h.toInt());
    final data = await out.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw StateError('تعذر تجهيز الصورة');
    final tmp = await getTemporaryDirectory();
    final f = File('${tmp.path}/slide_${DateTime.now().microsecondsSinceEpoch}.png');
    await f.writeAsBytes(data.buffer.asUint8List(), flush: true);
    return f.path;
  }

  Future<void> _useTemplate(_Tpl t) async {
    List<XFile> files;
    try {
      files = await picker.pickMultiImage(maxWidth: 1920, imageQuality: 85);
    } catch (e) {
      _snack('تعذر فتح المعرض: $e');
      return;
    }
    if (!mounted || files.isEmpty) return;
    if (files.length > 12) { _snack('اختر 12 صورة كحد أقصى.'); return; }
    await _runTemplate(t, files.map((f) => f.path).toList());
  }

  Future<void> _runTemplate(_Tpl t, List<String> paths) async {
    final opts = await _askOptions();
    if (opts == null || !mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: AlertDialog(content: Row(children: [
          CircularProgressIndicator(),
          SizedBox(width: 16),
          Expanded(child: Text('جاري إنشاء الفيديو...')),
        ])),
      ),
    );
    EditorProject? made;
    String? err;
    try {
      final n = paths.length;
      final want = (15000 / t.slideMs).round();
      final count = want > n ? want : n;
      final slideMs = (15000 / count).round();
      final photoSlides = <String>[];
      for (var i = 0; i < n; i++) {
        _TextLayer? tl;
        if (i == 0 && opts.title.isNotEmpty) {
          tl = _TextLayer(text: opts.title, color: t.titleStyle.color, size: t.titleStyle.size, bold: t.titleStyle.bold, bg: t.titleStyle.bg);
        }
        photoSlides.add(await _renderSlide(paths[i], tl, t.tint));
      }
      String? plainFirst;
      if (opts.title.isNotEmpty && count > n) {
        plainFirst = await _renderSlide(paths[0], null, t.tint);
      }
      final slides = <String>[];
      for (var i = 0; i < count; i++) {
        final j = i % n;
        if (i < n) {
          slides.add(photoSlides[i]);
        } else if (j == 0 && plainFirst != null) {
          slides.add(plainFirst);
        } else {
          slides.add(photoSlides[j]);
        }
      }
      final docs = await getApplicationDocumentsDirectory();
      final outDir = Directory('${docs.path}/exports');
      await outDir.create(recursive: true);
      final out = '${outDir.path}/template-${DateTime.now().millisecondsSinceEpoch}.mp4';
      final r = await MediaApi.makeSlideshow(
        images: slides,
        output: out,
        slideMs: slideMs,
        motion: t.motion,
        fade: t.fade,
        extra: t.extra,
        audio: opts.music?.path,
        volume: 0.9,
      );
      final now = DateTime.now().microsecondsSinceEpoch.toString();
      final vp = EditorProject(
        id: now,
        name: 'فيديو من قالب ${t.name}',
        clips: [EditorClip(id: now, kind: ClipKind.video, path: r.path, durationMs: r.durationMs)],
      );
      await store.save(vp);
      made = vp;
    } catch (e) {
      err = '$e';
    }
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    if (made != null) {
      _open(made);
    } else {
      _snack('تعذر إنشاء الفيديو: $err');
    }
  }

  Widget _tplCard(_Tpl t) => InkWell(
    onTap: () => _useTemplate(t),
    borderRadius: BorderRadius.circular(18),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x55D4AF6A)),
        gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [t.c1, t.c2]),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(t.icon, size: 34, color: kGold),
        const Spacer(),
        Text(t.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(t.desc, style: const TextStyle(fontSize: 11, color: Colors.white60)),
        const SizedBox(height: 8),
        const Text('مدة الفيديو 15 ثانية', style: TextStyle(fontSize: 11, color: kGold)),
      ]),
    ),
  );

  Widget _templates() {
    final list = _kTemplates.where((t) => _cat == 'الكل' || t.cat == _cat).toList();
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('القوالب', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      const Text('اختر قالبًا، ثم اختر صورك، ويتحول إلى فيديو تلقائيًا.', style: TextStyle(color: Colors.white54)),
      const SizedBox(height: 12),
      SizedBox(
        height: 42,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: _kTplCats.map((c) => Padding(
            padding: const EdgeInsets.only(left: 8),
            child: ChoiceChip(label: Text(c), selected: _cat == c, onSelected: (_) => setState(() => _cat = c)),
          )).toList(),
        ),
      ),
      const SizedBox(height: 12),
      GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
        children: list.map(_tplCard).toList(),
      ),
    ]);
  }

  @override
  void initState() {
    super.initState();
    _loadHidden();
  }

  Future<File> _hiddenFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/hidden_projects.json');
  }

  Future<void> _loadHidden() async {
    try {
      final f = await _hiddenFile();
      if (await f.exists()) {
        final list = jsonDecode(await f.readAsString()) as List;
        _hidden = list.map((e) => e.toString()).toSet();
      }
    } catch (_) {}
    _wm = await _readWatermark();
    if (mounted) setState(() {});
  }

  Future<List<EditorProject>> _list() async {
    final all = await store.list();
    return all.where((p) => !_hidden.contains(p.id)).toList();
  }

  Future<void> _deleteProject(EditorProject p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف المشروع'),
        content: Text('هل تريد حذف "${p.name}"؟ لا يمكن التراجع.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try { await (store as dynamic).delete(p.id); } catch (_) {}
    _hidden.add(p.id);
    try {
      final f = await _hiddenFile();
      await f.writeAsString(jsonEncode(_hidden.toList()));
    } catch (_) {}
    try {
      final dir = await getApplicationDocumentsDirectory();
      final exportsPath = '${dir.path}/exports/';
      final all = await store.list();
      final others = all.where((q) => q.id != p.id && !_hidden.contains(q.id)).expand((q) => q.clips.map((c) => c.path)).toSet();
      for (final c in p.clips) {
        if (c.path.startsWith(exportsPath) && !others.contains(c.path)) {
          final file = File(c.path);
          if (await file.exists()) await file.delete();
        }
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف المشروع')));
  }

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
      _templates(),
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
            NavigationDestination(icon: Icon(Icons.dashboard_customize_outlined), selectedIcon: Icon(Icons.dashboard_customize), label: 'القوالب'),
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
      onLongPress: () => _deleteProject(p),
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
    future: _list(),
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
      IconButton(onPressed: () => setState(() => tab = 3), icon: const Icon(Icons.settings_outlined)),
    ]),
    const SizedBox(height: 12),
    _hero(),
    const SizedBox(height: 12),
    InkWell(
      onTap: _openAi,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kGold),
          gradient: const LinearGradient(colors: [Color(0xFF3A2A12), Color(0xFF14100A)]),
        ),
        child: Row(children: const [
          Icon(Icons.auto_awesome, color: kGold, size: 30),
          SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('تصميم بالذكاء الاصطناعي', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 2),
            Text('اكتب وصفًا واحصل على صور، ثم حوّلها إلى فيديو', style: TextStyle(fontSize: 12, color: Colors.white60)),
          ])),
          Icon(Icons.chevron_left),
        ]),
      ),
    ),
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
      _tool(Icons.grid_view_outlined, 'الكولاج', _collage),
      const SizedBox(width: 8),
      _tool(Icons.text_fields, 'النصوص', () => pick(false)),
      const SizedBox(width: 8),
      _tool(Icons.emoji_emotions_outlined, 'الملصقات', () => pick(false)),
      const SizedBox(width: 8),
      _tool(Icons.filter_vintage_outlined, 'المرشحات', () => pick(false)),
    ]),
    const SizedBox(height: 18),
    Row(children: [
      const Text('مشاريعي الأخيرة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      const Spacer(),
      TextButton(onPressed: () => setState(() => tab = 2), child: const Text('عرض الكل')),
    ]),
    const Text('اضغط مطولًا على أي مشروع لحذفه.', style: TextStyle(color: Colors.white38, fontSize: 11)),
    const SizedBox(height: 6),
    _recent(),
  ]);

  Widget _projects() => FutureBuilder<List<EditorProject>>(
    future: _list(),
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
          trailing: IconButton(tooltip: 'حذف', icon: const Icon(Icons.delete_outline), onPressed: () => _deleteProject(p)),
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
      subtitle: Text('المعالجة تتم محليًا على هاتفك. ميزة الذكاء الاصطناعي ترسل نص الوصف فقط إلى خدمة خارجية.'),
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
    const Text('الفيديو', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    const SizedBox(height: 8),
    Card(child: SwitchListTile(
      secondary: const Icon(Icons.branding_watermark_outlined),
      title: const Text('شعار طيوب على الفيديو'),
      subtitle: const Text('يُضاف في زاوية الفيديو عند الحفظ والمشاركة.'),
      value: _wm,
      onChanged: (v) async {
        setState(() => _wm = v);
        await _writeWatermark(v);
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
    final c = VideoPlayerController.file(file, videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));
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
    if (c == null) return;
    try {
      if (c.value.isPlaying) {
        await c.pause();
      } else {
        await c.play();
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
      final paths = videos.map((e) => e.path).toList();
      final r = fadeMerge ? await MediaApi.mergeFade(inputs: paths, output: out) : await engine.mergeVideos(inputs: paths, output: out);
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

  Future<String> _renderWatermarkPng() async {
    final vs = controller?.value.size ?? const Size(1080, 1920);
    final ratio = (vs.width > 0 && vs.height > 0) ? vs.height / vs.width : 16 / 9;
    const outW = 1080.0;
    final outH = (outW * ratio).roundToDouble();
    final codec = await ui.instantiateImageCodec(_logoBytes);
    final logo = (await codec.getNextFrame()).image;
    final logoW = outW * 0.24;
    final logoH = logoW * logo.height / logo.width;
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec, Rect.fromLTWH(0, 0, outW, outH));
    canvas.drawImageRect(
      logo,
      Rect.fromLTWH(0, 0, logo.width.toDouble(), logo.height.toDouble()),
      Rect.fromLTWH(outW - logoW - outW * 0.04, outH - logoH - outH * 0.05, logoW, logoH),
      Paint()
        ..filterQuality = FilterQuality.high
        ..color = const Color.fromRGBO(255, 255, 255, 0.9),
    );
    final img = await rec.endRecording().toImage(outW.toInt(), outH.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw StateError('تعذر إنشاء الشعار');
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/watermark_${DateTime.now().millisecondsSinceEpoch}.png');
    await f.writeAsBytes(data.buffer.asUint8List(), flush: true);
    return f.path;
  }

  Future<String> _withWatermark(String inputPath) async {
    final png = await _renderWatermarkPng();
    final out = await _output('wm');
    final r = await MediaApi.overlayImage(input: inputPath, overlay: png, output: out);
    return r.path;
  }

  Future<void> _shareVideo() async {
    final clip = videos.firstOrNull;
    if (clip == null || busy) return;
    if (videos.length > 1) { _msg('ادمج المقاطع أولاً ثم شارك الفيديو.'); return; }
    setState(() { busy = true; progress = 0; });
    progressSub = engine.progress.listen((v) { if (mounted) setState(() => progress = v); });
    String? wm;
    try {
      var path = clip.path;
      if (await _readWatermark()) {
        wm = await _withWatermark(clip.path);
        path = wm;
      }
      if (mounted) setState(() => busy = false);
      await Share.shareXFiles([XFile(path)], text: 'طيوب');
    } catch (e) { _msg('تعذرت المشاركة: $e'); }
    finally {
      await progressSub?.cancel();
      progressSub = null;
      if (wm != null) { try { await File(wm).delete(); } catch (_) {} }
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _saveVideo() async {
    final clip = videos.firstOrNull;
    if (clip == null || busy) return;
    if (videos.length > 1) { _msg('ادمج المقاطع أولاً ثم احفظ الفيديو.'); return; }
    setState(() { busy = true; progress = 0; });
    progressSub = engine.progress.listen((v) { if (mounted) setState(() => progress = v); });
    String? wm;
    try {
      var path = clip.path;
      if (await _readWatermark()) {
        wm = await _withWatermark(clip.path);
        path = wm;
      }
      await MediaApi.saveVideo(path, 'tayoub_${DateTime.now().millisecondsSinceEpoch}.mp4');
      _msg('تم حفظ الفيديو في المعرض (مجلد Movies/Tayoub)');
    } catch (e) { _msg('تعذر حفظ الفيديو: $e'); }
    finally {
      await progressSub?.cancel();
      progressSub = null;
      if (wm != null) { try { await File(wm).delete(); } catch (_) {} }
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _addResult(String path, int durationMs, String name) async {
    widget.project.clips = [EditorClip(id: DateTime.now().microsecondsSinceEpoch.toString(), kind: ClipKind.video, path: path, durationMs: durationMs)];
    widget.project.name = name;
    await widget.store.save(widget.project);
    if (mounted) { await controller?.dispose(); controller = null; await _load(); setState(() {}); }
  }

  void _msg(String text) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text))); }

  int tool = -1;
  String fx = 'none';
  bool fadeMerge = false;
  static const Map<String, String> _fxList = {
    'zoom': 'تكبير بطيء',
    'zoomout': 'تصغير بطيء',
    'pulse': 'نبض',
    'heartbeat': 'نبض القلب',
    'shake': 'اهتزاز',
    'sway': 'تمايل',
    'panLeft': 'تحريك لليسار',
    'panRight': 'تحريك لليمين',
    'panUp': 'تحريك لأعلى',
    'panDown': 'تحريك لأسفل',
    'pop': 'ظهور مفاجئ',
    'flash': 'وميض',
    'pulseLight': 'إضاءة نابضة',
    'strobe': 'ومضات سريعة',
    'fade': 'تلاشي البداية والنهاية',
    'fadeIn': 'تلاشي دخول',
    'fadeOut': 'تلاشي خروج',
    'mirror': 'مرآة',
  };

  Future<void> _fxExport() async {
    final clip = videos.firstOrNull;
    if (clip == null || busy || fx == 'none') return;
    if (videos.length > 1) { _msg('ادمج المقاطع أولاً ثم طبّق التأثير.'); return; }
    setState(() { busy = true; progress = 0; });
    progressSub = engine.progress.listen((v) { if (mounted) setState(() => progress = v); });
    try {
      final total = controller?.value.duration.inMilliseconds ?? clip.durationMs;
      final out = await _output('fx');
      final r = await MediaApi.applyEffect(input: clip.path, output: out, effect: fx, durationMs: total);
      await _addResult(r.path, r.durationMs, 'فيديو مع تأثير');
      _msg('تم تطبيق التأثير.');
    } catch (e) { _msg('تعذر تطبيق التأثير: $e'); }
    finally { await progressSub?.cancel(); progressSub = null; if (mounted) setState(() => busy = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تحرير الفيديو'),
        actions: [
          IconButton(tooltip: 'مشاركة (تيك توك وغيره)', onPressed: busy ? null : _shareVideo, icon: const Icon(Icons.ios_share)),
          IconButton(tooltip: 'حفظ المشروع', onPressed: busy ? null : () async { await widget.store.save(widget.project); _msg('تم حفظ المشروع'); }, icon: const Icon(Icons.save_outlined)),
          TextButton.icon(onPressed: busy ? null : _saveVideo, icon: const Icon(Icons.check), label: const Text('حفظ')),
        ],
      ),
      body: Column(children: [
        Expanded(child: Container(
          width: double.infinity,
          color: Colors.black,
          child: Center(child: AspectRatio(
            aspectRatio: controller?.value.aspectRatio ?? 16 / 9,
            child: controller == null
                ? const ColoredBox(color: Colors.black, child: Center(child: Icon(Icons.movie_outlined, size: 50)))
                : LayoutBuilder(builder: (context, box) => _videoStack(box.maxWidth, box.maxHeight)),
          )),
        )),
        if (loading) const LinearProgressIndicator(),
        if (loadError != null) Padding(padding: const EdgeInsets.all(6), child: SelectableText('تعذر تشغيل المعاينة:\n$loadError', textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent, fontSize: 12))),
        _playBar(),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: _timeline()),
        if (busy) Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: Column(children: [
            LinearProgressIndicator(value: progress > 0 ? progress : null),
            const SizedBox(height: 4),
            Text('جاري المعالجة ${progress > 0 ? '${(progress * 100).round()}%' : ''}', style: const TextStyle(fontSize: 12)),
          ]),
        ),
        _toolPanel(),
        _toolBar(),
      ]),
    );
  }

  Widget _playBar() {
    final c = controller;
    if (c == null || !c.value.isInitialized) return const SizedBox(height: 8);
    final total = c.value.duration.inMilliseconds.toDouble();
    final maxV = total <= 0 ? 1.0 : total;
    final pos = c.value.position.inMilliseconds.toDouble().clamp(0.0, maxV).toDouble();
    return Row(children: [
      const SizedBox(width: 12),
      Text(_fmt(pos), style: const TextStyle(fontSize: 12, color: Colors.white70)),
      IconButton(icon: Icon(c.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill, size: 34, color: kGold), onPressed: _togglePlay),
      Expanded(child: Slider(value: pos, min: 0, max: maxV, onChanged: (v) => c.seekTo(Duration(milliseconds: v.round())))),
      Text(_fmt(total), style: const TextStyle(fontSize: 12, color: Colors.white70)),
      const SizedBox(width: 12),
    ]);
  }

  Widget _toolBar() {
    const labels = ['قص', 'دمج', 'السرعة', 'تأثيرات', 'نص+ملصق', 'موسيقى'];
    const icons = [Icons.content_cut, Icons.merge_type, Icons.speed, Icons.auto_fix_high, Icons.text_fields, Icons.music_note];
    return Container(
      decoration: BoxDecoration(color: kCardColor, border: const Border(top: BorderSide(color: Color(0x33D4AF6A)))),
      child: SafeArea(
        top: false,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: SizedBox(
            height: 62,
            child: Row(children: List.generate(labels.length, (i) => Expanded(
              child: InkWell(
                onTap: () => setState(() => tool = (tool == i) ? -1 : i),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(icons[i], color: tool == i ? kGold : Colors.white70),
                  const SizedBox(height: 4),
                  Text(labels[i], style: TextStyle(fontSize: 11, color: tool == i ? kGold : Colors.white70)),
                ]),
              ),
            ))),
          ),
        ),
      ),
    );
  }

  Widget _toolPanel() {
    if (tool < 0) return const SizedBox.shrink();
    Widget content;
    switch (tool) {
      case 0:
        content = _trimPanel();
        break;
      case 1:
        content = _mergePanel();
        break;
      case 2:
        content = _speedPanel();
        break;
      case 3:
        content = _filterPanel();
        break;
      case 4:
        content = _textCard();
        break;
      default:
        content = _musicPanel();
    }
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 290),
      decoration: BoxDecoration(color: kCardColor, border: const Border(top: BorderSide(color: Color(0x33D4AF6A)))),
      child: SingleChildScrollView(padding: const EdgeInsets.all(12), child: content),
    );
  }

  Widget _trimPanel() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const Text('حرّك مقبضي "نطاق القص" في الخط الزمني لتحديد الجزء المطلوب، ثم اضغط قص.', textAlign: TextAlign.right, style: TextStyle(color: Colors.white70)),
    const SizedBox(height: 10),
    FilledButton.icon(onPressed: busy ? null : _trim, icon: const Icon(Icons.content_cut), label: const Text('قص')),
  ]);

  Widget _mergePanel() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    ListTile(
      dense: true,
      title: Text('المقاطع (${videos.length})', textAlign: TextAlign.right),
      leading: IconButton(onPressed: busy ? null : _addVideo, icon: const Icon(Icons.add)),
    ),
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
    SwitchListTile(dense: true, title: const Text('انتقال تلاشي بين المقاطع', textAlign: TextAlign.right), subtitle: const Text('يعيد ترميز الفيديو فيستغرق وقتًا أطول', textAlign: TextAlign.right), value: fadeMerge, onChanged: busy ? null : (v) => setState(() => fadeMerge = v)),
    const SizedBox(height: 8),
    FilledButton.tonalIcon(onPressed: busy ? null : _merge, icon: const Icon(Icons.merge_type), label: const Text('دمج المقاطع')),
  ]);

  Widget _speedPanel() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const Text('سرعة الفيديو', textAlign: TextAlign.right, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    Slider(value: speed, min: .5, max: 2, divisions: 6, label: '${speed.toStringAsFixed(1)}x', onChanged: busy ? null : (v) => setState(() => speed = v)),
    OutlinedButton.icon(onPressed: busy ? null : _speedExport, icon: const Icon(Icons.speed), label: const Text('تطبيق السرعة')),
  ]);

  Widget _filterPanel() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const Text('الفلاتر', textAlign: TextAlign.right, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    const SizedBox(height: 8),
    Wrap(spacing: 8, runSpacing: 8, children: _filters.entries.map((e) => ChoiceChip(label: Text(e.value), selected: filter == e.key, onSelected: busy ? null : (_) => setState(() => filter = e.key))).toList()),
    const SizedBox(height: 10),
    OutlinedButton.icon(onPressed: (busy || filter == 'none') ? null : _filterExport, icon: const Icon(Icons.auto_fix_high), label: const Text('تطبيق الفلتر')),
    const Divider(height: 28),
    const Text('تأثيرات الحركة', textAlign: TextAlign.right, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    const SizedBox(height: 8),
    Wrap(spacing: 8, runSpacing: 8, children: _fxList.entries.map((e) => ChoiceChip(label: Text(e.value), selected: fx == e.key, onSelected: busy ? null : (_) => setState(() => fx = (fx == e.key) ? 'none' : e.key))).toList()),
    const SizedBox(height: 10),
    OutlinedButton.icon(onPressed: (busy || fx == 'none') ? null : _fxExport, icon: const Icon(Icons.motion_photos_on_outlined), label: const Text('تطبيق التأثير')),
  ]);

  Widget _musicPanel() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const Text('الموسيقى', textAlign: TextAlign.right, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    ListTile(dense: true, leading: const Icon(Icons.library_music_outlined), title: Text(music?.name ?? 'لم يتم اختيار موسيقى', textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis), trailing: TextButton(onPressed: busy ? null : _pickMusic, child: const Text('اختيار'))),
    SwitchListTile(dense: true, title: const Text('كتم صوت الفيديو الأصلي', textAlign: TextAlign.right), value: muteOriginal, onChanged: busy ? null : (v) => setState(() => muteOriginal = v)),
    Row(children: [
      const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('الصوت')),
      Expanded(child: Slider(value: musicVolume, min: 0.1, max: 1, onChanged: busy ? null : (v) => setState(() => musicVolume = v))),
    ]),
    OutlinedButton.icon(onPressed: (busy || music == null) ? null : _addMusic, icon: const Icon(Icons.music_note), label: const Text('إضافة الموسيقى')),
  ]);

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

  final List<_TextLayer> texts = [];
  int? selectedText;
  bool dragging = false;

  Future<String?> _askText(String initial) {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('اكتب النص'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          minLines: 1,
          textDirection: TextDirection.rtl,
          decoration: const InputDecoration(hintText: 'النص هنا'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('تم')),
        ],
      ),
    );
  }

  void _addSticker(String e) {
    setState(() {
      texts.add(_TextLayer(text: e, size: 0.16, bold: false));
      selectedText = texts.length - 1;
    });
  }

  Future<void> _addText(_TextStyleTpl? st) async {
    final v = await _askText('');
    if (v == null || v.trim().isEmpty || !mounted) return;
    setState(() {
      texts.add(_TextLayer(text: v.trim(), color: st?.color ?? Colors.white, size: st?.size ?? 0.07, bold: st?.bold ?? true, bg: st?.bg ?? 0));
      selectedText = texts.length - 1;
    });
  }

  Future<void> _editText(_TextLayer t) async {
    final v = await _askText(t.text);
    if (v == null || v.trim().isEmpty || !mounted) return;
    setState(() => t.text = v.trim());
  }

  Widget _videoStack(double dw, double dh) {
    return Stack(children: [
      Positioned.fill(child: VideoPlayer(controller!)),
      for (var i = 0; i < texts.length; i++)
        Positioned(
          left: texts[i].dx * dw,
          top: texts[i].dy * dh,
          child: FractionalTranslation(
            translation: const Offset(-0.5, -0.5),
            child: Listener(
              onPointerDown: (_) => setState(() => dragging = true),
              onPointerUp: (_) => setState(() => dragging = false),
              onPointerCancel: (_) => setState(() => dragging = false),
              child: GestureDetector(
                onTap: () => setState(() => selectedText = i),
                onPanUpdate: (d) => setState(() {
                  selectedText = i;
                  texts[i].dx = (texts[i].dx + d.delta.dx / dw).clamp(0.0, 1.0).toDouble();
                  texts[i].dy = (texts[i].dy + d.delta.dy / dh).clamp(0.0, 1.0).toDouble();
                }),
                child: _layerBox(texts[i], dw, selected: selectedText == i),
              ),
            ),
          ),
        ),
    ]);
  }

  Future<String> _renderOverlayPng() async {
    final vs = controller?.value.size ?? const Size(1080, 1920);
    final ratio = (vs.width > 0 && vs.height > 0) ? vs.height / vs.width : 16 / 9;
    const outW = 1080.0;
    final outH = (outW * ratio).roundToDouble();
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec, Rect.fromLTWH(0, 0, outW, outH));
    for (final t in texts) { _paintLayer(canvas, t, outW, outH); }
    final img = await rec.endRecording().toImage(outW.toInt(), outH.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw StateError('تعذر إنشاء صورة النص');
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/text_overlay_${DateTime.now().millisecondsSinceEpoch}.png');
    await f.writeAsBytes(data.buffer.asUint8List(), flush: true);
    return f.path;
  }

  Future<void> _applyText() async {
    final clip = videos.firstOrNull;
    if (clip == null || texts.isEmpty || busy) return;
    setState(() { busy = true; progress = 0; });
    progressSub = engine.progress.listen((v) { if (mounted) setState(() => progress = v); });
    try {
      final png = await _renderOverlayPng();
      final out = await _output('text');
      final r = await MediaApi.overlayImage(input: clip.path, overlay: png, output: out);
      texts.clear();
      selectedText = null;
      await _addResult(r.path, r.durationMs, 'فيديو مع نص');
      _msg('تمت إضافة النص على الفيديو.');
    } catch (e) { _msg('تعذر إضافة النص: $e'); }
    finally { await progressSub?.cancel(); progressSub = null; if (mounted) setState(() => busy = false); }
  }

  Widget _textCard() {
    final sel = (selectedText != null && selectedText! < texts.length) ? texts[selectedText!] : null;
    return Card(child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('النص والملصقات على الفيديو', textAlign: TextAlign.right, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _stickerRow(_addSticker, !busy),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.icon(onPressed: busy ? null : () => _addText(null), icon: const Icon(Icons.add), label: const Text('إضافة نص')),
          ..._kTextStyles.map((st) => ActionChip(label: Text(st.name), onPressed: busy ? null : () => _addText(st))),
        ]),
        if (sel != null) ...[
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: _kPalette.map((c) => GestureDetector(
            onTap: () => setState(() => sel.color = c),
            child: Container(
              width: 30,
              height: 30,
              margin: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                border: Border.all(color: sel.color == c ? kGold : Colors.white24, width: sel.color == c ? 3 : 1),
              ),
            ),
          )).toList()),
          Row(children: [
            const SizedBox(width: 60, child: Text('الحجم')),
            Expanded(child: Slider(value: sel.size.clamp(0.03, 0.2).toDouble(), min: 0.03, max: 0.2, onChanged: busy ? null : (v) => setState(() => sel.size = v))),
          ]),
          Wrap(spacing: 8, runSpacing: 4, alignment: WrapAlignment.center, children: [
            ChoiceChip(label: const Text('بلا خلفية'), selected: sel.bg == 0, onSelected: (_) => setState(() => sel.bg = 0)),
            ChoiceChip(label: const Text('خلفية داكنة'), selected: sel.bg == 1, onSelected: (_) => setState(() => sel.bg = 1)),
            ChoiceChip(label: const Text('خلفية ذهبية'), selected: sel.bg == 2, onSelected: (_) => setState(() => sel.bg = 2)),
            FilterChip(label: const Text('عريض'), selected: sel.bold, onSelected: (v) => setState(() => sel.bold = v)),
          ]),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            TextButton.icon(onPressed: () => _editText(sel), icon: const Icon(Icons.edit_outlined), label: const Text('تعديل')),
            TextButton.icon(onPressed: () => setState(() { texts.remove(sel); selectedText = null; }), icon: const Icon(Icons.delete_outline), label: const Text('حذف')),
          ]),
        ] else
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('اضغط "إضافة نص" ثم اسحب النص على الفيديو لتحريكه.', textAlign: TextAlign.right, style: TextStyle(color: Colors.white54, fontSize: 12)),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: (busy || texts.isEmpty) ? null : _applyText,
          icon: const Icon(Icons.text_fields),
          label: const Text('تطبيق النص والملصقات على الفيديو'),
        ),
      ]),
    ));
  }
}
