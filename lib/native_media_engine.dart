import 'dart:async';
import 'package:flutter/services.dart';

class NativeExportResult {
  final String path;
  final int durationMs;
  const NativeExportResult(this.path, this.durationMs);
}

class NativeMediaEngine {
  static const _channel = MethodChannel('com.alsaadi/media');
  static const _events = EventChannel('com.alsaadi/media_events');

  Stream<double> get progress => _events.receiveBroadcastStream().map((e) => (e as num).toDouble());

  Future<NativeExportResult> trimVideo({required String input, required String output, required int startMs, required int endMs}) async {
    final r = await _channel.invokeMethod<Map>('trimVideo', {
      'input': input, 'output': output, 'startMs': startMs, 'endMs': endMs,
    });
    if (r == null) throw StateError('لم يرجع محرك الوسائط نتيجة');
    return NativeExportResult(r['path'] as String, (r['durationMs'] as num).toInt());
  }

  Future<NativeExportResult> mergeVideos({required List<String> inputs, required String output}) async {
    if (inputs.length < 2) throw ArgumentError('تحتاج مقطعين على الأقل');
    final r = await _channel.invokeMethod<Map>('mergeVideos', {'inputs': inputs, 'output': output});
    if (r == null) throw StateError('فشل دمج المقاطع');
    return NativeExportResult(r['path'] as String, (r['durationMs'] as num).toInt());
  }

  Future<NativeExportResult> speedVideo({required String input, required String output, required double speed}) async {
    final r = await _channel.invokeMethod<Map>('speedVideo', {'input': input, 'output': output, 'speed': speed});
    if (r == null) throw StateError('فشل تغيير السرعة');
    return NativeExportResult(r['path'] as String, (r['durationMs'] as num).toInt());
  }

  Future<NativeExportResult> copyVideo({required String input, required String output}) async {
    final r = await _channel.invokeMethod<Map>('copyVideo', {'input': input, 'output': output});
    if (r == null) throw StateError('فشل تصدير الفيديو');
    return NativeExportResult(r['path'] as String, (r['durationMs'] as num).toInt());
  }
}
