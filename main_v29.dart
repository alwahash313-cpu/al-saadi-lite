import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
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

  static Future<NativeExportResult> exportVideo({
    required String input,
    required String output,
    required int shortSide,
    String? overlay,
    bool enhance = false,
  }) async {
    final r = await _ch.invokeMethod<Map>('exportVideo', {
      'input': input, 'output': output, 'shortSide': shortSide, 'overlay': overlay, 'enhance': enhance,
    });
    if (r == null) throw StateError('فشل تصدير الفيديو');
    return NativeExportResult(r['path'] as String, (r['durationMs'] as num).toInt());
  }

  static Future<NativeExportResult> transformVideo({
    required String input,
    required String output,
    int rotate = 0,
    bool flip = false,
    double aspect = 0,
    bool crop = true,
    double volume = 1.0,
  }) async {
    final r = await _ch.invokeMethod<Map>('transformVideo', {
      'input': input, 'output': output, 'rotate': rotate, 'flip': flip,
      'aspect': aspect, 'crop': crop, 'volume': volume,
    });
    if (r == null) throw StateError('فشل تعديل الفيديو');
    return NativeExportResult(r['path'] as String, (r['durationMs'] as num).toInt());
  }

  static Future<bool> startRecording(String path) async {
    final ok = await _ch.invokeMethod<bool>('startRecording', {'path': path});
    return ok ?? false;
  }

  static Future<String?> stopRecording() async {
    return _ch.invokeMethod<String>('stopRecording');
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

class _ImgSaveOpts {
  _ImgSaveOpts(this.scale, this.sharpen);
  final double scale;
  final bool sharpen;
}

class _SaveOpts {
  _SaveOpts(this.shortSide, this.enhance);
  final int shortSide;
  final bool enhance;
}

Uint8List _unsharp(Uint8List src, int w, int h, double amount) {
  final out = Uint8List.fromList(src);
  final tmp = Uint16List(w * h * 3);
  for (var y = 0; y < h; y++) {
    final row = y * w;
    for (var x = 0; x < w; x++) {
      final xl = x > 0 ? x - 1 : 0;
      final xr = x < w - 1 ? x + 1 : w - 1;
      final i0 = (row + xl) * 4;
      final i1 = (row + x) * 4;
      final i2 = (row + xr) * 4;
      final t = (row + x) * 3;
      tmp[t] = src[i0] + src[i1] + src[i2];
      tmp[t + 1] = src[i0 + 1] + src[i1 + 1] + src[i2 + 1];
      tmp[t + 2] = src[i0 + 2] + src[i1 + 2] + src[i2 + 2];
    }
  }
  for (var y = 0; y < h; y++) {
    final yu = y > 0 ? y - 1 : 0;
    final yd = y < h - 1 ? y + 1 : h - 1;
    for (var x = 0; x < w; x++) {
      final a = (yu * w + x) * 3;
      final b = (y * w + x) * 3;
      final c = (yd * w + x) * 3;
      final o = (y * w + x) * 4;
      for (var k = 0; k < 3; k++) {
        final blur = (tmp[a + k] + tmp[b + k] + tmp[c + k]) / 9.0;
        final v = src[o + k] + amount * (src[o + k] - blur);
        out[o + k] = v < 0 ? 0 : (v > 255 ? 255 : v.round());
      }
    }
  }
  return out;
}

class _MagicTool {
  const _MagicTool(this.id, this.name, this.icon);
  final String id;
  final String name;
  final IconData icon;
}

const List<_MagicTool> _kMagic = [
  _MagicTool('anime', 'أنمي', Icons.face_retouching_natural),
  _MagicTool('cartoon', 'كرتون', Icons.emoji_emotions_outlined),
  _MagicTool('oil', 'رسم زيتي', Icons.brush),
  _MagicTool('watercolor', 'ألوان مائية', Icons.water_drop_outlined),
  _MagicTool('pencil', 'قلم رصاص', Icons.edit),
  _MagicTool('colorpencil', 'قلم ملوّن', Icons.palette_outlined),
  _MagicTool('ink', 'رسم بالحبر', Icons.draw_outlined),
  _MagicTool('pop', 'بوب آرت', Icons.auto_awesome_mosaic_outlined),
  _MagicTool('neon', 'نيون', Icons.flare),
  _MagicTool('mosaic', 'فسيفساء', Icons.grid_on),
];

int _c8(double v) => v < 0 ? 0 : (v > 255 ? 255 : v.round());

double _cl(double v) => v < 0 ? 0.0 : (v > 255 ? 255.0 : v);

Float32List _gray(Uint8List p, int w, int h) {
  final n = w * h;
  final g = Float32List(n);
  for (var i = 0, j = 0; i < n; i++, j += 4) {
    g[i] = 0.299 * p[j] + 0.587 * p[j + 1] + 0.114 * p[j + 2];
  }
  return g;
}

Float32List _boxBlur(Float32List a, int w, int h, int r) {
  if (r < 1) return Float32List.fromList(a);
  final tmp = Float32List(w * h);
  final out = Float32List(w * h);
  final d = (2 * r + 1).toDouble();
  for (var y = 0; y < h; y++) {
    final row = y * w;
    double sum = 0;
    for (var x = -r; x <= r; x++) {
      final xi = x < 0 ? 0 : (x >= w ? w - 1 : x);
      sum += a[row + xi];
    }
    for (var x = 0; x < w; x++) {
      tmp[row + x] = sum / d;
      final addX = x + r + 1;
      final subX = x - r;
      final ai = addX >= w ? w - 1 : addX;
      final si = subX < 0 ? 0 : subX;
      sum += a[row + ai] - a[row + si];
    }
  }
  for (var x = 0; x < w; x++) {
    double sum = 0;
    for (var y = -r; y <= r; y++) {
      final yi = y < 0 ? 0 : (y >= h ? h - 1 : y);
      sum += tmp[yi * w + x];
    }
    for (var y = 0; y < h; y++) {
      out[y * w + x] = sum / d;
      final addY = y + r + 1;
      final subY = y - r;
      final ai = addY >= h ? h - 1 : addY;
      final si = subY < 0 ? 0 : subY;
      sum += tmp[ai * w + x] - tmp[si * w + x];
    }
  }
  return out;
}

Float32List _sobel(Float32List g, int w, int h) {
  final e = Float32List(w * h);
  for (var y = 1; y < h - 1; y++) {
    for (var x = 1; x < w - 1; x++) {
      final i = y * w + x;
      final gx = -g[i - w - 1] - 2 * g[i - 1] - g[i + w - 1] + g[i - w + 1] + 2 * g[i + 1] + g[i + w + 1];
      final gy = -g[i - w - 1] - 2 * g[i - w] - g[i - w + 1] + g[i + w - 1] + 2 * g[i + w] + g[i + w + 1];
      e[i] = math.sqrt(gx * gx + gy * gy);
    }
  }
  return e;
}

Uint8List _kuwahara(Uint8List src, int w, int h, int r) {
  final bw = w + 1;
  final size = bw * (h + 1);
  final iR = Float64List(size);
  final iG = Float64List(size);
  final iB = Float64List(size);
  final iL = Float64List(size);
  final iQ = Float64List(size);
  for (var y = 0; y < h; y++) {
    double sr = 0, sg = 0, sb = 0, sl = 0, sq = 0;
    for (var x = 0; x < w; x++) {
      final p = (y * w + x) * 4;
      final rr = src[p].toDouble();
      final gg = src[p + 1].toDouble();
      final bb = src[p + 2].toDouble();
      final l = 0.299 * rr + 0.587 * gg + 0.114 * bb;
      sr += rr;
      sg += gg;
      sb += bb;
      sl += l;
      sq += l * l;
      final k = (y + 1) * bw + (x + 1);
      final up = y * bw + (x + 1);
      iR[k] = iR[up] + sr;
      iG[k] = iG[up] + sg;
      iB[k] = iB[up] + sb;
      iL[k] = iL[up] + sl;
      iQ[k] = iQ[up] + sq;
    }
  }
  double rect(Float64List a, int x0, int y0, int x1, int y1) =>
      a[y1 * bw + x1] - a[y0 * bw + x1] - a[y1 * bw + x0] + a[y0 * bw + x0];
  final out = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      double best = double.infinity;
      double mr = 0, mg = 0, mb = 0;
      for (var q = 0; q < 4; q++) {
        final left = (q & 1) == 0;
        final top = (q & 2) == 0;
        var x0 = left ? x - r : x;
        var x1 = left ? x : x + r;
        var y0 = top ? y - r : y;
        var y1 = top ? y : y + r;
        if (x0 < 0) x0 = 0;
        if (y0 < 0) y0 = 0;
        if (x1 > w - 1) x1 = w - 1;
        if (y1 > h - 1) y1 = h - 1;
        final cnt = ((x1 - x0 + 1) * (y1 - y0 + 1)).toDouble();
        final mean = rect(iL, x0, y0, x1 + 1, y1 + 1) / cnt;
        final v = rect(iQ, x0, y0, x1 + 1, y1 + 1) / cnt - mean * mean;
        if (v < best) {
          best = v;
          mr = rect(iR, x0, y0, x1 + 1, y1 + 1) / cnt;
          mg = rect(iG, x0, y0, x1 + 1, y1 + 1) / cnt;
          mb = rect(iB, x0, y0, x1 + 1, y1 + 1) / cnt;
        }
      }
      final o = (y * w + x) * 4;
      out[o] = _c8(mr);
      out[o + 1] = _c8(mg);
      out[o + 2] = _c8(mb);
      out[o + 3] = 255;
    }
  }
  return out;
}

Uint8List _fxPencil(Uint8List src, int w, int h, bool color) {
  final n = w * h;
  final g = _gray(src, w, h);
  final inv = Float32List(n);
  for (var i = 0; i < n; i++) {
    inv[i] = 255 - g[i];
  }
  final r = math.max(3, (math.max(w, h) / 120).round());
  final blur = _boxBlur(inv, w, h, r);
  final out = Uint8List(n * 4);
  for (var i = 0, j = 0; i < n; i++, j += 4) {
    double s = g[i] * 255.0 / (256.0 - blur[i]);
    if (s > 255) s = 255;
    s = 255 - (255 - s) * 0.95;
    if (color) {
      final f = s / 255.0;
      out[j] = _c8((src[j] * 0.65 + 255 * 0.35) * f);
      out[j + 1] = _c8((src[j + 1] * 0.65 + 255 * 0.35) * f);
      out[j + 2] = _c8((src[j + 2] * 0.65 + 255 * 0.35) * f);
    } else {
      final v = _c8(s);
      out[j] = v;
      out[j + 1] = v;
      out[j + 2] = v;
    }
    out[j + 3] = 255;
  }
  return out;
}

Uint8List _fxInk(Uint8List src, int w, int h) {
  final p = _fxPencil(src, w, h, false);
  final out = Uint8List(w * h * 4);
  for (var j = 0; j < out.length; j += 4) {
    final t = ((p[j] - 115) / 45.0).clamp(0.0, 1.0).toDouble();
    final v = _c8(15 + 240 * t);
    out[j] = v;
    out[j + 1] = v;
    out[j + 2] = v;
    out[j + 3] = 255;
  }
  return out;
}

Uint8List _fxCartoon(Uint8List src, int w, int h, bool anime) {
  final n = w * h;
  final long = math.max(w, h);
  final sm = _kuwahara(src, w, h, math.max(2, (long / (anime ? 450 : 330)).round()));
  final gray = _boxBlur(_gray(sm, w, h), w, h, 1);
  final e = _sobel(gray, w, h);
  final thr = anime ? 55.0 : 38.0;
  final line = Float32List(n);
  for (var i = 0; i < n; i++) {
    final t = (e[i] - thr) / thr;
    line[i] = t < 0 ? 0.0 : (t > 1 ? 1.0 : t);
  }
  final lineS = anime ? line : _boxBlur(line, w, h, 1);
  final levels = anime ? 7 : 5;
  final step = 255.0 / (levels - 1);
  final sat = anime ? 1.3 : 1.2;
  final out = Uint8List(n * 4);
  for (var i = 0, j = 0; i < n; i++, j += 4) {
    double r = sm[j].toDouble();
    double g = sm[j + 1].toDouble();
    double b = sm[j + 2].toDouble();
    final l = 0.299 * r + 0.587 * g + 0.114 * b;
    r = l + (r - l) * sat;
    g = l + (g - l) * sat;
    b = l + (b - l) * sat;
    r = (_cl(r) / step).round() * step;
    g = (_cl(g) / step).round() * step;
    b = (_cl(b) / step).round() * step;
    if (anime) {
      r = r * 0.92 + 22;
      g = g * 0.92 + 22;
      b = b * 0.92 + 22;
    }
    final k = lineS[i] * (anime ? 0.85 : 0.95);
    out[j] = _c8(r * (1 - k) + 25 * k);
    out[j + 1] = _c8(g * (1 - k) + 20 * k);
    out[j + 2] = _c8(b * (1 - k) + 30 * k);
    out[j + 3] = 255;
  }
  return out;
}

Uint8List _fxPaint(Uint8List src, int w, int h, bool oil) {
  final long = math.max(w, h);
  final k = _kuwahara(src, w, h, oil ? math.max(3, (long / 220).round()) : math.max(2, (long / 420).round()));
  final out = Uint8List(w * h * 4);
  final sat = oil ? 1.18 : 0.95;
  for (var j = 0; j < out.length; j += 4) {
    double r = k[j].toDouble();
    double g = k[j + 1].toDouble();
    double b = k[j + 2].toDouble();
    final l = 0.299 * r + 0.587 * g + 0.114 * b;
    r = l + (r - l) * sat;
    g = l + (g - l) * sat;
    b = l + (b - l) * sat;
    if (oil) {
      r = (r - 128) * 1.08 + 128;
      g = (g - 128) * 1.08 + 128;
      b = (b - 128) * 1.08 + 128;
    } else {
      r = 255.0 * math.pow(_cl(r) / 255.0, 0.82).toDouble() * 0.92 + 255 * 0.08;
      g = 255.0 * math.pow(_cl(g) / 255.0, 0.82).toDouble() * 0.92 + 255 * 0.08;
      b = 255.0 * math.pow(_cl(b) / 255.0, 0.82).toDouble() * 0.92 + 255 * 0.08;
    }
    out[j] = _c8(r);
    out[j + 1] = _c8(g);
    out[j + 2] = _c8(b);
    out[j + 3] = 255;
  }
  return out;
}

Uint8List _fxPop(Uint8List src, int w, int h) {
  final n = w * h;
  final e = _sobel(_boxBlur(_gray(src, w, h), w, h, 1), w, h);
  final out = Uint8List(n * 4);
  const step = 255.0 / 3;
  for (var i = 0, j = 0; i < n; i++, j += 4) {
    double r = src[j].toDouble();
    double g = src[j + 1].toDouble();
    double b = src[j + 2].toDouble();
    final l = 0.299 * r + 0.587 * g + 0.114 * b;
    r = l + (r - l) * 1.7;
    g = l + (g - l) * 1.7;
    b = l + (b - l) * 1.7;
    r = (r - 128) * 1.2 + 128;
    g = (g - 128) * 1.2 + 128;
    b = (b - 128) * 1.2 + 128;
    r = (_cl(r) / step).round() * step;
    g = (_cl(g) / step).round() * step;
    b = (_cl(b) / step).round() * step;
    final dark = e[i] > 70;
    out[j] = dark ? 10 : _c8(r);
    out[j + 1] = dark ? 10 : _c8(g);
    out[j + 2] = dark ? 10 : _c8(b);
    out[j + 3] = 255;
  }
  return out;
}

Uint8List _fxNeon(Uint8List src, int w, int h) {
  final n = w * h;
  final e = _sobel(_boxBlur(_gray(src, w, h), w, h, 1), w, h);
  final ee = Float32List(n);
  for (var i = 0; i < n; i++) {
    final t = e[i] / 110.0;
    ee[i] = t > 1 ? 1.0 : t;
  }
  final glow = _boxBlur(ee, w, h, math.max(2, (math.max(w, h) / 300).round()));
  final out = Uint8List(n * 4);
  for (var i = 0, j = 0; i < n; i++, j += 4) {
    double it = ee[i] + glow[i] * 1.4;
    if (it > 1) it = 1;
    final r = src[j];
    final g = src[j + 1];
    final b = src[j + 2];
    final mx = math.max(r, math.max(g, b));
    final k = mx == 0 ? 0.0 : 255.0 / mx;
    out[j] = _c8(r * k * it);
    out[j + 1] = _c8(g * k * it);
    out[j + 2] = _c8(b * k * it);
    out[j + 3] = 255;
  }
  return out;
}

Uint8List _fxMosaic(Uint8List src, int w, int h) {
  final bs = math.max(10, (math.max(w, h) / 48).round());
  final out = Uint8List(w * h * 4);
  for (var by = 0; by < h; by += bs) {
    for (var bx = 0; bx < w; bx += bs) {
      final x1 = math.min(bx + bs, w);
      final y1 = math.min(by + bs, h);
      double sr = 0, sg = 0, sb = 0;
      var cnt = 0;
      for (var y = by; y < y1; y++) {
        for (var x = bx; x < x1; x++) {
          final p = (y * w + x) * 4;
          sr += src[p];
          sg += src[p + 1];
          sb += src[p + 2];
          cnt++;
        }
      }
      final r = sr / cnt;
      final g = sg / cnt;
      final b = sb / cnt;
      for (var y = by; y < y1; y++) {
        for (var x = bx; x < x1; x++) {
          final p = (y * w + x) * 4;
          final f = (x - bx < 2 || y - by < 2) ? 0.55 : 1.0;
          out[p] = _c8(r * f);
          out[p + 1] = _c8(g * f);
          out[p + 2] = _c8(b * f);
          out[p + 3] = 255;
        }
      }
    }
  }
  return out;
}

Future<Uint8List> _runMagic(Uint8List rgba, int w, int h, String kind) {
  return Isolate.run(() => _magicProcess(rgba, w, h, kind));
}

Uint8List _magicProcess(Uint8List src, int w, int h, String kind) {
  switch (kind) {
    case 'pencil':
      return _fxPencil(src, w, h, false);
    case 'colorpencil':
      return _fxPencil(src, w, h, true);
    case 'ink':
      return _fxInk(src, w, h);
    case 'cartoon':
      return _fxCartoon(src, w, h, false);
    case 'anime':
      return _fxCartoon(src, w, h, true);
    case 'oil':
      return _fxPaint(src, w, h, true);
    case 'watercolor':
      return _fxPaint(src, w, h, false);
    case 'pop':
      return _fxPop(src, w, h);
    case 'neon':
      return _fxNeon(src, w, h);
    case 'mosaic':
      return _fxMosaic(src, w, h);
    default:
      return src;
  }
}

class _Stroke {
  _Stroke(this.color, this.width);
  final Color color;
  final double width;
  final List<Offset> pts = [];
}

void _paintStrokes(Canvas c, double w, double h, List<_Stroke> strokes) {
  for (final s in strokes) {
    if (s.pts.isEmpty) continue;
    if (s.pts.length == 1) {
      c.drawCircle(Offset(s.pts[0].dx * w, s.pts[0].dy * h), s.width * w / 2, Paint()..color = s.color);
      continue;
    }
    final paint = Paint()
      ..color = s.color
      ..strokeWidth = s.width * w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(s.pts[0].dx * w, s.pts[0].dy * h);
    for (var i = 1; i < s.pts.length; i++) {
      path.lineTo(s.pts[i].dx * w, s.pts[i].dy * h);
    }
    c.drawPath(path, paint);
  }
}

class _StrokesPainter extends CustomPainter {
  _StrokesPainter(this.strokes);
  final List<_Stroke> strokes;
  @override
  void paint(Canvas canvas, Size size) => _paintStrokes(canvas, size.width, size.height, strokes);
  @override
  bool shouldRepaint(covariant _StrokesPainter oldDelegate) => true;
}

const List<String> _kFrameNames = ['بدون', 'أبيض', 'ذهبي', 'بولارويد', 'سينمائي', 'مزدوج', 'زوايا مدورة'];

void _paintFrame(Canvas c, double w, double h, int frame) {
  if (frame <= 0) return;
  final white = Paint()..color = Colors.white;
  final gold = Paint()..color = kGold;
  final black = Paint()..color = Colors.black;
  if (frame == 1) {
    final t = w * 0.045;
    c.drawRect(Rect.fromLTWH(0, 0, w, t), white);
    c.drawRect(Rect.fromLTWH(0, h - t, w, t), white);
    c.drawRect(Rect.fromLTWH(0, 0, t, h), white);
    c.drawRect(Rect.fromLTWH(w - t, 0, t, h), white);
  } else if (frame == 2) {
    final t = w * 0.03;
    c.drawRect(Rect.fromLTWH(0, 0, w, t), gold);
    c.drawRect(Rect.fromLTWH(0, h - t, w, t), gold);
    c.drawRect(Rect.fromLTWH(0, 0, t, h), gold);
    c.drawRect(Rect.fromLTWH(w - t, 0, t, h), gold);
    c.drawRect(
      Rect.fromLTWH(t, t, w - t * 2, h - t * 2),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.004,
    );
  } else if (frame == 3) {
    final side = w * 0.05;
    final bottom = w * 0.16;
    c.drawRect(Rect.fromLTWH(0, 0, w, side), white);
    c.drawRect(Rect.fromLTWH(0, h - bottom, w, bottom), white);
    c.drawRect(Rect.fromLTWH(0, 0, side, h), white);
    c.drawRect(Rect.fromLTWH(w - side, 0, side, h), white);
  } else if (frame == 4) {
    final bar = h * 0.1;
    c.drawRect(Rect.fromLTWH(0, 0, w, bar), black);
    c.drawRect(Rect.fromLTWH(0, h - bar, w, bar), black);
  } else if (frame == 5) {
    c.drawRect(
      Rect.fromLTWH(w * 0.03, w * 0.03, w - w * 0.06, h - w * 0.06),
      Paint()
        ..color = kGold
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.012,
    );
    c.drawRect(
      Rect.fromLTWH(w * 0.055, w * 0.055, w - w * 0.11, h - w * 0.11),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.004,
    );
  } else if (frame == 6) {
    final full = Path()..addRect(Rect.fromLTWH(0, 0, w, h));
    final hole = Path()..addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.03, w * 0.03, w - w * 0.06, h - w * 0.06),
      Radius.circular(w * 0.08),
    ));
    c.drawPath(Path.combine(PathOperation.difference, full, hole), black);
    c.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.03, w * 0.03, w - w * 0.06, h - w * 0.06), Radius.circular(w * 0.08)),
      Paint()
        ..color = kGold
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.006,
    );
  }
}

class _FramePainter extends CustomPainter {
  _FramePainter(this.frame);
  final int frame;
  @override
  void paint(Canvas canvas, Size size) => _paintFrame(canvas, size.width, size.height, frame);
  @override
  bool shouldRepaint(covariant _FramePainter oldDelegate) => oldDelegate.frame != frame;
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

Future<Map<String, dynamic>> _readSettings() async {
  try {
    final f = await _settingsFile();
    if (await f.exists()) {
      final m = jsonDecode(await f.readAsString());
      if (m is Map) return Map<String, dynamic>.from(m);
    }
  } catch (_) {}
  return <String, dynamic>{};
}

Future<void> _updateSettings(Map<String, dynamic> patch) async {
  try {
    final cur = await _readSettings();
    cur.addAll(patch);
    final f = await _settingsFile();
    await f.writeAsString(jsonEncode(cur));
  } catch (_) {}
}

Future<bool> _readWatermark() async {
  final m = await _readSettings();
  return m['watermark'] != false;
}

Future<void> _writeWatermark(bool v) async {
  await _updateSettings({'watermark': v});
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
  String? _originalPath;
  bool magicBusy = false;
  String? magicKind;
  int frame = 0;
  bool drawMode = false;
  Color penColor = Colors.white;
  double penWidth = 0.012;
  final List<_Stroke> strokes = [];

  Future<void> _transformImage({int rotate = 0, bool flip = false, double aspect = 0}) async {
    if (saving || magicBusy) return;
    setState(() => magicBusy = true);
    try {
      final bytes = await File(clip.path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final img = (await codec.getNextFrame()).image;
      final w = img.width.toDouble();
      final h = img.height.toDouble();
      final swap = rotate % 180 != 0;
      final tw = swap ? h : w;
      final th = swap ? w : h;
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec);
      canvas.translate(tw / 2, th / 2);
      canvas.rotate(rotate * math.pi / 180);
      if (flip) canvas.scale(-1.0, 1.0);
      canvas.drawImage(img, Offset(-w / 2, -h / 2), Paint()..filterQuality = FilterQuality.high);
      ui.Image cur = await rec.endRecording().toImage(tw.round(), th.round());
      if (aspect > 0) {
        final cw = cur.width.toDouble();
        final ch = cur.height.toDouble();
        var nw = cw;
        var nh = ch;
        if (cw / ch > aspect) {
          nw = ch * aspect;
        } else {
          nh = cw / aspect;
        }
        final rec2 = ui.PictureRecorder();
        final c2 = Canvas(rec2);
        c2.drawImageRect(
          cur,
          Rect.fromLTWH((cw - nw) / 2, (ch - nh) / 2, nw, nh),
          Rect.fromLTWH(0, 0, nw, nh),
          Paint()..filterQuality = FilterQuality.high,
        );
        cur = await rec2.endRecording().toImage(nw.round(), nh.round());
      }
      final png = await cur.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) throw StateError('تعذر حفظ النتيجة');
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}/exports');
      await dir.create(recursive: true);
      final f = File('${dir.path}/edit_${DateTime.now().millisecondsSinceEpoch}.png');
      await f.writeAsBytes(png.buffer.asUint8List(), flush: true);
      final dur = clip.durationMs;
      widget.project.clips = [
        EditorClip(id: DateTime.now().microsecondsSinceEpoch.toString(), kind: ClipKind.image, path: f.path, durationMs: dur),
      ];
      _originalPath = null;
      texts.clear();
      strokes.clear();
      selectedText = null;
      await widget.store.save(widget.project);
      await _loadDims();
      _msg('تم التعديل.');
    } catch (e) {
      _msg('تعذر التعديل: $e');
    } finally {
      if (mounted) setState(() => magicBusy = false);
    }
  }

  Widget _transformCard() => Card(child: Padding(
    padding: const EdgeInsets.all(12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('تدوير وقص', textAlign: TextAlign.right, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        ActionChip(avatar: const Icon(Icons.rotate_right, size: 18), label: const Text('تدوير يمين'), onPressed: (saving || magicBusy) ? null : () => _transformImage(rotate: 90)),
        ActionChip(avatar: const Icon(Icons.rotate_left, size: 18), label: const Text('تدوير يسار'), onPressed: (saving || magicBusy) ? null : () => _transformImage(rotate: 270)),
        ActionChip(avatar: const Icon(Icons.flip, size: 18), label: const Text('قلب'), onPressed: (saving || magicBusy) ? null : () => _transformImage(flip: true)),
      ]),
      const SizedBox(height: 10),
      const Text('قص بنسبة (من الوسط)', style: TextStyle(color: Colors.white70, fontSize: 12)),
      const SizedBox(height: 6),
      Wrap(spacing: 8, runSpacing: 4, children: [
        ActionChip(label: const Text('1:1'), onPressed: (saving || magicBusy) ? null : () => _transformImage(aspect: 1.0)),
        ActionChip(label: const Text('4:5'), onPressed: (saving || magicBusy) ? null : () => _transformImage(aspect: 0.8)),
        ActionChip(label: const Text('3:4'), onPressed: (saving || magicBusy) ? null : () => _transformImage(aspect: 0.75)),
        ActionChip(label: const Text('9:16'), onPressed: (saving || magicBusy) ? null : () => _transformImage(aspect: 0.5625)),
        ActionChip(label: const Text('16:9'), onPressed: (saving || magicBusy) ? null : () => _transformImage(aspect: 1.7778)),
      ]),
      const SizedBox(height: 6),
      const Text('أي تدوير أو قص يحذف النصوص والرسم الحالي حتى لا تتغير أماكنها.', style: TextStyle(color: Colors.white38, fontSize: 11)),
    ]),
  ));

  Widget _framesCard() => Card(child: Padding(
    padding: const EdgeInsets.all(12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('الإطارات', textAlign: TextAlign.right, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 4, children: List.generate(_kFrameNames.length, (i) => ChoiceChip(
        label: Text(_kFrameNames[i]),
        selected: frame == i,
        onSelected: (_) => setState(() => frame = i),
      ))),
    ]),
  ));

  Widget _drawCard() => Card(child: Padding(
    padding: const EdgeInsets.all(12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('الرسم الحر', textAlign: TextAlign.right, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('وضع الرسم'),
        subtitle: const Text('ارسم بإصبعك فوق الصورة'),
        value: drawMode,
        onChanged: (v) => setState(() => drawMode = v),
      ),
      if (drawMode) ...[
        Row(mainAxisAlignment: MainAxisAlignment.center, children: _palette.map((c) => GestureDetector(
          onTap: () => setState(() => penColor = c),
          child: Container(
            width: 30,
            height: 30,
            margin: const EdgeInsets.symmetric(horizontal: 5),
            decoration: BoxDecoration(
              color: c,
              shape: BoxShape.circle,
              border: Border.all(color: penColor == c ? kGold : Colors.white24, width: penColor == c ? 3 : 1),
            ),
          ),
        )).toList()),
        _slider('السماكة', penWidth, 0.004, 0.04, (v) => setState(() => penWidth = v)),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          TextButton.icon(onPressed: strokes.isEmpty ? null : () => setState(() => strokes.removeLast()), icon: const Icon(Icons.undo), label: const Text('تراجع')),
          TextButton.icon(onPressed: strokes.isEmpty ? null : () => setState(() => strokes.clear()), icon: const Icon(Icons.delete_outline), label: const Text('مسح الكل')),
        ]),
      ],
    ]),
  ));

  Future<void> _applyMagic(String kind) async {
    if (saving || magicBusy) return;
    setState(() { magicBusy = true; magicKind = kind; });
    try {
      _originalPath ??= clip.path;
      final bytes = await File(_originalPath!).readAsBytes();
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      final desc = await ui.ImageDescriptor.encoded(buffer);
      final wide = desc.width >= desc.height;
      final longSide = wide ? desc.width : desc.height;
      const maxSide = 1280;
      final ui.Codec codec;
      if (longSide > maxSide) {
        codec = await desc.instantiateCodec(targetWidth: wide ? maxSide : null, targetHeight: wide ? null : maxSide);
      } else {
        codec = await desc.instantiateCodec();
      }
      final img = (await codec.getNextFrame()).image;
      final w = img.width;
      final h = img.height;
      final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) throw StateError('تعذر قراءة الصورة');
      final rgba = Uint8List.fromList(data.buffer.asUint8List());
      final res = await _runMagic(rgba, w, h, kind);
      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(res, w, h, ui.PixelFormat.rgba8888, completer.complete);
      final outImg = await completer.future;
      final png = await outImg.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) throw StateError('تعذر حفظ النتيجة');
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}/exports');
      await dir.create(recursive: true);
      final f = File('${dir.path}/magic_${DateTime.now().millisecondsSinceEpoch}.png');
      await f.writeAsBytes(png.buffer.asUint8List(), flush: true);
      widget.project.clips = [
        EditorClip(id: DateTime.now().microsecondsSinceEpoch.toString(), kind: ClipKind.image, path: f.path, durationMs: clip.durationMs),
      ];
      await widget.store.save(widget.project);
      await _loadDims();
      _msg('تم تطبيق التأثير السحري.');
    } catch (e) {
      _msg('تعذر تطبيق التأثير: $e');
    } finally {
      if (mounted) setState(() => magicBusy = false);
    }
  }

  Future<void> _revertMagic() async {
    final o = _originalPath;
    if (o == null || magicBusy) return;
    widget.project.clips = [
      EditorClip(id: DateTime.now().microsecondsSinceEpoch.toString(), kind: ClipKind.image, path: o, durationMs: clip.durationMs),
    ];
    _originalPath = null;
    await widget.store.save(widget.project);
    await _loadDims();
    if (mounted) setState(() {});
  }

  Widget _magicCard() => Card(child: Padding(
    padding: const EdgeInsets.all(12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('الأدوات السحرية', textAlign: TextAlign.right, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      const Text('حوّل صورتك إلى رسم بلمسة واحدة. تعمل على جهازك بدون إنترنت، وتأخذ بضع ثوانٍ.', textAlign: TextAlign.right, style: TextStyle(color: Colors.white60, fontSize: 12)),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: _kMagic.map((t) => ActionChip(
        avatar: Icon(t.icon, size: 18, color: (magicBusy && magicKind == t.id) ? kGold : null),
        label: Text(t.name),
        onPressed: (saving || magicBusy) ? null : () => _applyMagic(t.id),
      )).toList()),
      if (magicBusy) const Padding(padding: EdgeInsets.only(top: 10), child: LinearProgressIndicator()),
      if (_originalPath != null && !magicBusy) TextButton.icon(onPressed: _revertMagic, icon: const Icon(Icons.undo), label: const Text('الرجوع للصورة الأصلية')),
      const SizedBox(height: 4),
      const Text('هذه تأثيرات ذكية تعالج الصورة على جهازك، وليست نموذج ذكاء اصطناعي. النتيجة تُعالج بدقة تصل إلى 1280 بكسل، ويمكنك رفع الدقة عند الحفظ.', textAlign: TextAlign.right, style: TextStyle(color: Colors.white38, fontSize: 11)),
    ]),
  ));

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
      if (frame != 0)
        Positioned(left: left, top: top, width: dw, height: dh, child: IgnorePointer(child: CustomPaint(painter: _FramePainter(frame)))),
      if (strokes.isNotEmpty)
        Positioned(left: left, top: top, width: dw, height: dh, child: IgnorePointer(child: CustomPaint(painter: _StrokesPainter(strokes)))),
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
      if (drawMode)
        Positioned(
          left: left,
          top: top,
          width: dw,
          height: dh,
          child: Listener(
            onPointerDown: (_) => setState(() => dragging = true),
            onPointerUp: (_) => setState(() => dragging = false),
            onPointerCancel: (_) => setState(() => dragging = false),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (d) => setState(() {
                final st = _Stroke(penColor, penWidth);
                st.pts.add(Offset(d.localPosition.dx / dw, d.localPosition.dy / dh));
                strokes.add(st);
              }),
              onPanUpdate: (d) => setState(() {
                if (strokes.isNotEmpty) {
                  strokes.last.pts.add(Offset(
                    (d.localPosition.dx / dw).clamp(0.0, 1.0).toDouble(),
                    (d.localPosition.dy / dh).clamp(0.0, 1.0).toDouble(),
                  ));
                }
              }),
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

  Future<Uint8List> _render({bool even = false, double scale = 1.0, bool sharp = false}) async {
    final bytes = await File(clip.path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final img = frame.image;
    final maxSide = img.width > img.height ? img.width : img.height;
    var sc = scale;
    if (maxSide * sc > 4096) sc = 4096 / maxSide;
    if (sc < 1) sc = 1;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(sc, sc);
    canvas.drawImage(img, Offset.zero, Paint()
      ..filterQuality = FilterQuality.high
      ..colorFilter = ColorFilter.matrix(_adjustMatrix()));
    _paintStrokes(canvas, img.width.toDouble(), img.height.toDouble(), strokes);
    _paintFrame(canvas, img.width.toDouble(), img.height.toDouble(), frame);
    for (final t in texts) { _drawText(canvas, t, img.width.toDouble(), img.height.toDouble()); }
    final picture = recorder.endRecording();
    var w = (img.width * sc).round();
    var h = (img.height * sc).round();
    if (even) { w = (w ~/ 2) * 2; h = (h ~/ 2) * 2; }
    final out = await picture.toImage(w, h);
    ByteData? data;
    if (sharp) {
      final raw = await out.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (raw != null) {
        final px = _unsharp(raw.buffer.asUint8List(), w, h, 0.6);
        final completer = Completer<ui.Image>();
        ui.decodeImageFromPixels(px, w, h, ui.PixelFormat.rgba8888, completer.complete);
        final sharpImg = await completer.future;
        data = await sharpImg.toByteData(format: ui.ImageByteFormat.png);
      }
    }
    data ??= await out.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw StateError('تعذر إنشاء الصورة');
    return data.buffer.asUint8List();
  }

  Future<_ImgSaveOpts?> _askImageSave() {
    var scale = 1.0;
    var sharpen = false;
    final src = imgW > 0 ? '${imgW.round()}×${imgH.round()}' : '';
    return showDialog<_ImgSaveOpts>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('جودة الحفظ'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('الدقة'),
              Wrap(spacing: 8, children: [
                ChoiceChip(label: Text(src.isEmpty ? 'الأصلية' : 'الأصلية ($src)'), selected: scale == 1.0, onSelected: (_) => setD(() => scale = 1.0)),
                ChoiceChip(label: const Text('رفع الدقة ×1.5'), selected: scale == 1.5, onSelected: (_) => setD(() => scale = 1.5)),
                ChoiceChip(label: const Text('رفع الدقة ×2'), selected: scale == 2.0, onSelected: (_) => setD(() => scale = 2.0)),
              ]),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: sharpen,
                onChanged: (v) => setD(() => sharpen = v ?? false),
                title: const Text('تحسين الحدة والوضوح'),
              ),
              const Text(
                'رفع الدقة يكبّر الصورة بجودة عالية ولا يضيف تفاصيل جديدة، والحد الأقصى 4096 بكسل. والتحسين يستغرق بضع ثوانٍ.',
                style: TextStyle(fontSize: 11, color: Colors.white54),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(ctx, _ImgSaveOpts(scale, sharpen)), child: const Text('حفظ')),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (saving) return;
    final opts = await _askImageSave();
    if (opts == null || !mounted) return;
    setState(() => saving = true);
    try {
      final bytes = await _render(scale: opts.scale, sharp: opts.sharpen);
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

  Future<void> _autoEnhance() async {
    if (saving) return;
    try {
      final bytes = await File(clip.path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 256);
      final img = (await codec.getNextFrame()).image;
      final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) return;
      final px = data.buffer.asUint8List();
      final hist = List<int>.filled(256, 0);
      var n = 0;
      double sumLum = 0;
      double sumSat = 0;
      for (var i = 0; i + 3 < px.length; i += 4) {
        final r = px[i];
        final g = px[i + 1];
        final b = px[i + 2];
        final lum = (0.2126 * r + 0.7152 * g + 0.0722 * b).round();
        final li = lum < 0 ? 0 : (lum > 255 ? 255 : lum);
        hist[li]++;
        sumLum += li;
        final mx = r > g ? (r > b ? r : b) : (g > b ? g : b);
        final mn = r < g ? (r < b ? r : b) : (g < b ? g : b);
        sumSat += mx == 0 ? 0.0 : (mx - mn) / mx;
        n++;
      }
      if (n == 0) return;
      var acc = 0;
      var p1 = 0;
      var p99 = 255;
      var got1 = false;
      for (var v = 0; v < 256; v++) {
        acc += hist[v];
        if (!got1 && acc >= n * 0.01) { p1 = v; got1 = true; }
        if (acc >= n * 0.99) { p99 = v; break; }
      }
      final mean = sumLum / n;
      final range = (p99 - p1).toDouble();
      var c = range > 20 ? 255.0 / range : 1.0;
      c = c.clamp(1.0, 1.35).toDouble();
      var bright = ((118 - mean) / 255.0) * 0.8;
      bright = bright.clamp(-0.12, 0.12).toDouble();
      final ms = sumSat / n;
      var sat = ms < 0.38 ? 1.0 + (0.38 - ms) * 1.3 : 1.0;
      sat = sat.clamp(1.0, 1.3).toDouble();
      if (!mounted) return;
      setState(() {
        brightness = bright;
        contrast = c;
        saturation = sat;
      });
      _msg('تم التحسين التلقائي. عدّل بالأشرطة إن أردت.');
    } catch (e) {
      _msg('تعذر التحسين التلقائي: $e');
    }
  }

  Widget _enhanceCard() => Card(child: Padding(
    padding: const EdgeInsets.all(12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('التحسين الذكي', textAlign: TextAlign.right, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      const Text(
        'يحلّل الصورة ويضبط السطوع والتباين والألوان تلقائيًا، ثم تعدّل عليها كما تشاء. وعند الحفظ تقدر ترفع الدقة وتحسّن الحدة.',
        textAlign: TextAlign.right,
        style: TextStyle(color: Colors.white60, fontSize: 12),
      ),
      const SizedBox(height: 8),
      FilledButton.icon(onPressed: saving ? null : _autoEnhance, icon: const Icon(Icons.auto_fix_high), label: const Text('تحسين تلقائي')),
    ]),
  ));

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
        _magicCard(),
        const SizedBox(height: 10),
        _transformCard(),
        const SizedBox(height: 10),
        _framesCard(),
        const SizedBox(height: 10),
        _drawCard(),
        const SizedBox(height: 10),
        _enhanceCard(),
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
  void dispose() { recTimer?.cancel(); controller?.dispose(); progressSub?.cancel(); super.dispose(); }

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

  Future<_SaveOpts?> _askSave() {
    var q = 0;
    var enhance = false;
    final vs = controller?.value.size;
    final src = (vs != null && vs.width > 0) ? '${vs.width.round()}×${vs.height.round()}' : '';
    return showDialog<_SaveOpts>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('جودة الحفظ'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('الدقة'),
              Wrap(spacing: 8, children: [
                ChoiceChip(label: Text(src.isEmpty ? 'الأصلية' : 'الأصلية ($src)'), selected: q == 0, onSelected: (_) => setD(() => q = 0)),
                ChoiceChip(label: const Text('480p'), selected: q == 480, onSelected: (_) => setD(() => q = 480)),
                ChoiceChip(label: const Text('720p HD'), selected: q == 720, onSelected: (_) => setD(() => q = 720)),
                ChoiceChip(label: const Text('1080p Full HD'), selected: q == 1080, onSelected: (_) => setD(() => q = 1080)),
                ChoiceChip(label: const Text('1440p 2K'), selected: q == 1440, onSelected: (_) => setD(() => q = 1440)),
              ]),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: enhance,
                onChanged: (v) => setD(() => enhance = v ?? false),
                title: const Text('تحسين تلقائي للتباين والألوان'),
              ),
              const Text(
                'اختيار دقة أعلى من الأصلية يكبّر الفيديو ولا يضيف تفاصيل جديدة. وأي خيار غير "الأصلية" أو التحسين يعيد ترميز الفيديو فيأخذ وقتًا أطول.',
                style: TextStyle(fontSize: 11, color: Colors.white54),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(ctx, _SaveOpts(q, enhance)), child: const Text('حفظ')),
          ],
        ),
      ),
    );
  }

  Future<void> _saveVideo() async {
    final clip = videos.firstOrNull;
    if (clip == null || busy) return;
    if (videos.length > 1) { _msg('ادمج المقاطع أولاً ثم احفظ الفيديو.'); return; }
    final opts = await _askSave();
    if (opts == null || !mounted) return;
    setState(() { busy = true; progress = 0; });
    progressSub = engine.progress.listen((v) { if (mounted) setState(() => progress = v); });
    String? tmpOut;
    try {
      final useWm = await _readWatermark();
      final name = 'tayoub_${DateTime.now().millisecondsSinceEpoch}.mp4';
      if (opts.shortSide == 0 && !opts.enhance && !useWm) {
        await MediaApi.saveVideo(clip.path, name);
      } else {
        String? png;
        if (useWm) png = await _renderWatermarkPng();
        final out = await _output('save');
        final r = await MediaApi.exportVideo(input: clip.path, output: out, shortSide: opts.shortSide, overlay: png, enhance: opts.enhance);
        tmpOut = r.path;
        await MediaApi.saveVideo(r.path, name);
      }
      _msg('تم حفظ الفيديو في المعرض (مجلد Movies/Tayoub)');
    } catch (e) { _msg('تعذر حفظ الفيديو: $e'); }
    finally {
      await progressSub?.cancel();
      progressSub = null;
      if (tmpOut != null) { try { await File(tmpOut).delete(); } catch (_) {} }
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _enhanceExport() async {
    final clip = videos.firstOrNull;
    if (clip == null || busy) return;
    if (videos.length > 1) { _msg('ادمج المقاطع أولاً ثم طبّق التحسين.'); return; }
    setState(() { busy = true; progress = 0; });
    progressSub = engine.progress.listen((v) { if (mounted) setState(() => progress = v); });
    try {
      final out = await _output('enh');
      final r = await MediaApi.exportVideo(input: clip.path, output: out, shortSide: 0, enhance: true);
      await _addResult(r.path, r.durationMs, 'فيديو محسّن');
      _msg('تم تحسين التباين والألوان.');
    } catch (e) { _msg('تعذر التحسين: $e'); }
    finally { await progressSub?.cancel(); progressSub = null; if (mounted) setState(() => busy = false); }
  }

  Future<void> _addResult(String path, int durationMs, String name) async {
    widget.project.clips = [EditorClip(id: DateTime.now().microsecondsSinceEpoch.toString(), kind: ClipKind.video, path: path, durationMs: durationMs)];
    widget.project.name = name;
    await widget.store.save(widget.project);
    if (mounted) { await controller?.dispose(); controller = null; await _load(); setState(() {}); }
  }

  void _msg(String text) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text))); }

  int tool = -1;
  int rot = 0;
  bool flipH = false;
  double aspect = 0;
  bool cropFill = true;
  double origVolume = 1.0;
  bool recording = false;
  int recSeconds = 0;
  Timer? recTimer;

  Future<void> _cutAt(bool keepAfter) async {
    final clip = videos.firstOrNull;
    final c = controller;
    if (clip == null || c == null || !c.value.isInitialized || busy) return;
    if (videos.length > 1) { _msg('ادمج المقاطع أولاً.'); return; }
    final total = c.value.duration.inMilliseconds;
    final pos = c.value.position.inMilliseconds;
    if (pos < 500 || pos > total - 500) {
      _msg('حرّك مؤشر التشغيل إلى مكان يبعد نصف ثانية على الأقل عن البداية والنهاية.');
      return;
    }
    setState(() { busy = true; progress = 0; });
    progressSub = engine.progress.listen((v) { if (mounted) setState(() => progress = v); });
    try {
      final out = await _output(keepAfter ? 'after' : 'before');
      final r = await engine.trimVideo(input: clip.path, output: out, startMs: keepAfter ? pos : 0, endMs: keepAfter ? total : pos);
      await _addResult(r.path, r.durationMs, keepAfter ? 'بعد المؤشر' : 'قبل المؤشر');
      _msg(keepAfter ? 'تم حذف ما قبل المؤشر.' : 'تم حذف ما بعد المؤشر.');
    } catch (e) { _msg('تعذر القص: $e'); }
    finally { await progressSub?.cancel(); progressSub = null; if (mounted) setState(() => busy = false); }
  }

  Future<void> _splitHere() async {
    final clip = videos.firstOrNull;
    final c = controller;
    if (clip == null || c == null || !c.value.isInitialized || busy) return;
    if (videos.length > 1) { _msg('ادمج المقاطع أولاً.'); return; }
    final total = c.value.duration.inMilliseconds;
    final pos = c.value.position.inMilliseconds;
    if (pos < 500 || pos > total - 500) {
      _msg('حرّك مؤشر التشغيل إلى مكان يبعد نصف ثانية على الأقل عن البداية والنهاية.');
      return;
    }
    setState(() { busy = true; progress = 0; });
    progressSub = engine.progress.listen((v) { if (mounted) setState(() => progress = v); });
    try {
      final out1 = await _output('part1');
      final r1 = await engine.trimVideo(input: clip.path, output: out1, startMs: 0, endMs: pos);
      final out2 = await _output('part2');
      final r2 = await engine.trimVideo(input: clip.path, output: out2, startMs: pos, endMs: total);
      final t = DateTime.now().microsecondsSinceEpoch;
      widget.project.clips = [
        EditorClip(id: '${t}a', kind: ClipKind.video, path: r1.path, durationMs: r1.durationMs),
        EditorClip(id: '${t}b', kind: ClipKind.video, path: r2.path, durationMs: r2.durationMs),
      ];
      await widget.store.save(widget.project);
      await controller?.dispose();
      controller = null;
      await _load();
      if (mounted) setState(() => tool = 2);
      _msg('تم التقسيم إلى مقطعين. من أداة "دمج" تقدر تحذف أحدهما أو تعيد ترتيبهما.');
    } catch (e) { _msg('تعذر التقسيم: $e'); }
    finally { await progressSub?.cancel(); progressSub = null; if (mounted) setState(() => busy = false); }
  }

  Future<void> _applyTransform() async {
    final clip = videos.firstOrNull;
    if (clip == null || busy) return;
    if (videos.length > 1) { _msg('ادمج المقاطع أولاً.'); return; }
    if (rot == 0 && !flipH && aspect == 0) { _msg('اختر تدويرًا أو قلبًا أو نسبة عرض أولًا.'); return; }
    setState(() { busy = true; progress = 0; });
    progressSub = engine.progress.listen((v) { if (mounted) setState(() => progress = v); });
    try {
      final out = await _output('tf');
      final r = await MediaApi.transformVideo(input: clip.path, output: out, rotate: rot, flip: flipH, aspect: aspect, crop: cropFill);
      rot = 0;
      flipH = false;
      aspect = 0;
      await _addResult(r.path, r.durationMs, 'فيديو معدّل');
      _msg('تم تطبيق التعديل.');
    } catch (e) { _msg('تعذر التعديل: $e'); }
    finally { await progressSub?.cancel(); progressSub = null; if (mounted) setState(() => busy = false); }
  }

  Future<void> _applyVolume() async {
    final clip = videos.firstOrNull;
    if (clip == null || busy) return;
    if (videos.length > 1) { _msg('ادمج المقاطع أولاً.'); return; }
    setState(() { busy = true; progress = 0; });
    progressSub = engine.progress.listen((v) { if (mounted) setState(() => progress = v); });
    try {
      final out = await _output('vol');
      final r = await MediaApi.transformVideo(input: clip.path, output: out, volume: origVolume);
      await _addResult(r.path, r.durationMs, 'فيديو بمستوى صوت جديد');
      _msg('تم تغيير مستوى الصوت.');
    } catch (e) { _msg('تعذر تغيير الصوت: $e'); }
    finally { await progressSub?.cancel(); progressSub = null; if (mounted) setState(() => busy = false); }
  }

  Future<void> _toggleRecord() async {
    if (busy) return;
    if (!recording) {
      final clip = videos.firstOrNull;
      if (clip == null) return;
      if (videos.length > 1) { _msg('ادمج المقاطع أولاً.'); return; }
      try {
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        final ok = await MediaApi.startRecording(path);
        if (!ok) { _msg('تعذر بدء التسجيل.'); return; }
        await controller?.seekTo(Duration.zero);
        await controller?.play();
        recTimer?.cancel();
        recTimer = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted) setState(() => recSeconds++); });
        if (mounted) setState(() { recording = true; recSeconds = 0; });
      } catch (e) { _msg('تعذر بدء التسجيل: $e'); }
    } else {
      recTimer?.cancel();
      await controller?.pause();
      String? p;
      try {
        p = await MediaApi.stopRecording();
      } catch (e) {
        _msg('تعذر إنهاء التسجيل: $e');
      }
      if (mounted) setState(() => recording = false);
      if (p != null) await _mixVoice(p);
    }
  }

  Future<void> _mixVoice(String voicePath) async {
    final clip = videos.firstOrNull;
    if (clip == null || busy) return;
    setState(() { busy = true; progress = 0; });
    progressSub = engine.progress.listen((v) { if (mounted) setState(() => progress = v); });
    try {
      final out = await _output('voice');
      final r = await MediaApi.mixMusic(input: clip.path, audio: voicePath, output: out, isImage: false, keepOriginal: !muteOriginal, volume: 1.0);
      await _addResult(r.path, r.durationMs, 'فيديو مع تعليق صوتي');
      _msg('تمت إضافة التعليق الصوتي.');
    } catch (e) { _msg('تعذر إضافة التعليق الصوتي: $e'); }
    finally { await progressSub?.cancel(); progressSub = null; if (mounted) setState(() => busy = false); }
  }

  Widget _transformPanel() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const Text('تدوير وقلب', textAlign: TextAlign.right, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    const SizedBox(height: 8),
    Wrap(spacing: 8, runSpacing: 8, children: [
      ActionChip(avatar: const Icon(Icons.rotate_right, size: 18), label: const Text('تدوير يمين'), onPressed: busy ? null : () => setState(() => rot = (rot + 90) % 360)),
      ActionChip(avatar: const Icon(Icons.rotate_left, size: 18), label: const Text('تدوير يسار'), onPressed: busy ? null : () => setState(() => rot = (rot + 270) % 360)),
      FilterChip(label: const Text('قلب أفقي'), selected: flipH, onSelected: busy ? null : (v) => setState(() => flipH = v)),
    ]),
    const SizedBox(height: 4),
    Text('التدوير الحالي: $rot°', style: const TextStyle(color: Colors.white54, fontSize: 12)),
    const Divider(height: 24),
    const Text('نسبة العرض', textAlign: TextAlign.right, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    const SizedBox(height: 8),
    Wrap(spacing: 8, runSpacing: 4, children: [
      ChoiceChip(label: const Text('الأصلية'), selected: aspect == 0, onSelected: busy ? null : (_) => setState(() => aspect = 0)),
      ChoiceChip(label: const Text('9:16'), selected: aspect == 0.5625, onSelected: busy ? null : (_) => setState(() => aspect = 0.5625)),
      ChoiceChip(label: const Text('1:1'), selected: aspect == 1.0, onSelected: busy ? null : (_) => setState(() => aspect = 1.0)),
      ChoiceChip(label: const Text('16:9'), selected: aspect == 1.7778, onSelected: busy ? null : (_) => setState(() => aspect = 1.7778)),
      ChoiceChip(label: const Text('4:5'), selected: aspect == 0.8, onSelected: busy ? null : (_) => setState(() => aspect = 0.8)),
    ]),
    if (aspect > 0) Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(spacing: 8, children: [
        ChoiceChip(label: const Text('ملء بالاقتصاص'), selected: cropFill, onSelected: busy ? null : (_) => setState(() => cropFill = true)),
        ChoiceChip(label: const Text('احتواء بحواف سوداء'), selected: !cropFill, onSelected: busy ? null : (_) => setState(() => cropFill = false)),
      ]),
    ),
    const SizedBox(height: 12),
    FilledButton.icon(onPressed: busy ? null : _applyTransform, icon: const Icon(Icons.aspect_ratio), label: const Text('تطبيق')),
    const SizedBox(height: 6),
    const Text('التطبيق يعيد ترميز الفيديو فيأخذ وقتًا.', style: TextStyle(color: Colors.white38, fontSize: 11)),
  ]);

  Widget _audioPanel() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const Text('صوت الفيديو الأصلي', textAlign: TextAlign.right, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    Row(children: [
      const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('المستوى')),
      Expanded(child: Slider(value: origVolume, min: 0, max: 2, divisions: 20, label: '${(origVolume * 100).round()}%', onChanged: busy ? null : (v) => setState(() => origVolume = v))),
      Text('${(origVolume * 100).round()}%'),
    ]),
    Row(children: [
      Expanded(child: OutlinedButton.icon(onPressed: busy ? null : _applyVolume, icon: const Icon(Icons.volume_up), label: const Text('تطبيق'))),
      const SizedBox(width: 8),
      Expanded(child: OutlinedButton.icon(onPressed: busy ? null : () { setState(() => origVolume = 0); _applyVolume(); }, icon: const Icon(Icons.volume_off), label: const Text('كتم'))),
    ]),
    const Divider(height: 28),
    const Text('تسجيل تعليق صوتي', textAlign: TextAlign.right, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    const SizedBox(height: 4),
    const Text('يبدأ التسجيل والفيديو يتشغل من البداية، ويُدمج صوتك مع الفيديو عند الإيقاف.', textAlign: TextAlign.right, style: TextStyle(color: Colors.white60, fontSize: 12)),
    const SizedBox(height: 8),
    FilledButton.icon(
      onPressed: busy ? null : _toggleRecord,
      icon: Icon(recording ? Icons.stop : Icons.mic),
      label: Text(recording ? 'إيقاف وحفظ ($recSeconds ث)' : 'بدء التسجيل'),
    ),
    const Divider(height: 28),
    _musicPanel(),
  ]);
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
    const labels = ['قص', 'تحويل', 'دمج', 'السرعة', 'تأثيرات', 'نص+ملصق', 'صوت'];
    const icons = [Icons.content_cut, Icons.crop_rotate, Icons.merge_type, Icons.speed, Icons.auto_fix_high, Icons.text_fields, Icons.graphic_eq];
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
        content = _transformPanel();
        break;
      case 2:
        content = _mergePanel();
        break;
      case 3:
        content = _speedPanel();
        break;
      case 4:
        content = _filterPanel();
        break;
      case 5:
        content = _textCard();
        break;
      default:
        content = _audioPanel();
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
    const Divider(height: 28),
    const Text('القص والتقسيم عند مؤشر التشغيل', textAlign: TextAlign.right, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    const SizedBox(height: 4),
    const Text('حرّك شريط التشغيل إلى المكان المطلوب أولًا.', textAlign: TextAlign.right, style: TextStyle(color: Colors.white60, fontSize: 12)),
    const SizedBox(height: 8),
    Wrap(spacing: 8, runSpacing: 8, children: [
      OutlinedButton.icon(onPressed: busy ? null : _splitHere, icon: const Icon(Icons.call_split), label: const Text('تقسيم هنا')),
      OutlinedButton.icon(onPressed: busy ? null : () => _cutAt(true), icon: const Icon(Icons.last_page), label: const Text('حذف ما قبله')),
      OutlinedButton.icon(onPressed: busy ? null : () => _cutAt(false), icon: const Icon(Icons.first_page), label: const Text('حذف ما بعده')),
    ]),
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
    const Divider(height: 28),
    const Text('التحسين الذكي', textAlign: TextAlign.right, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    const SizedBox(height: 6),
    const Text('يرفع التباين والألوان تلقائيًا. ورفع الدقة تختاره عند الحفظ.', textAlign: TextAlign.right, style: TextStyle(color: Colors.white60, fontSize: 12)),
    const SizedBox(height: 8),
    FilledButton.icon(onPressed: busy ? null : _enhanceExport, icon: const Icon(Icons.auto_fix_high), label: const Text('تحسين الفيديو تلقائيًا')),
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
