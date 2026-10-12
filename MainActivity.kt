package com.alsaadi.app

import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val channel = "com.alsaadi/media"
    private val events = "com.alsaadi/media_events"
    private var sink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        EventChannel(engine.dartExecutor.binaryMessenger, events).setStreamHandler(object: EventChannel.StreamHandler {
            override fun onListen(args: Any?, es: EventChannel.EventSink?) { sink = es }
            override fun onCancel(args: Any?) { sink = null }
        })
        MethodChannel(engine.dartExecutor.binaryMessenger, channel).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "trimVideo" -> {
                        val input = call.argument<String>("input")!!
                        val output = call.argument<String>("output")!!
                        val start = call.argument<Number>("startMs")!!.toLong()
                        val end = call.argument<Number>("endMs")!!.toLong()
                        val duration = trim(input, output, start, end)
                        result.success(mapOf("path" to output, "durationMs" to duration))
                    }
                    "mergeVideos" -> {
                        val inputs = call.argument<List<String>>("inputs") ?: emptyList()
                        val output = call.argument<String>("output")!!
                        val duration = merge(inputs, output)
                        result.success(mapOf("path" to output, "durationMs" to duration))
                    }
                    "copyVideo" -> {
                        val input = call.argument<String>("input")!!
                        val output = call.argument<String>("output")!!
                        val duration = copy(input, output)
                        result.success(mapOf("path" to output, "durationMs" to duration))
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) { result.error("MEDIA_ERROR", e.message, null) }
        }
    }

    private fun copy(input: String, output: String): Long {
        File(output).parentFile?.mkdirs()
        File(input).copyTo(File(output), overwrite = true)
        val ex = MediaExtractor(); ex.setDataSource(input)
        var max = 0L
        for (i in 0 until ex.trackCount) max = maxOf(max, ex.getTrackFormat(i).getLong(MediaFormat.KEY_DURATION))
        ex.release(); return max / 1000
    }

    private fun merge(inputs: List<String>, output: String): Long {
        require(inputs.isNotEmpty()) { "لا توجد مقاطع للدمج" }
        File(output).parentFile?.mkdirs()
        val first = MediaExtractor()
        first.setDataSource(inputs[0])
        val muxer = MediaMuxer(output, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        val maps = HashMap<Int, Int>()
        for (i in 0 until first.trackCount) maps[i] = muxer.addTrack(first.getTrackFormat(i))
        first.release()
        muxer.start()
        val buffer = java.nio.ByteBuffer.allocate(4 * 1024 * 1024)
        val info = android.media.MediaCodec.BufferInfo()
        var offsetUs = 0L
        var totalDurationUs = 0L
        try {
            for ((index, input) in inputs.withIndex()) {
                val ex = MediaExtractor(); ex.setDataSource(input)
                require(ex.trackCount == maps.size) { "المقاطع لا تحتوي على مسارات متوافقة" }
                var localMax = 0L
                for (track in 0 until ex.trackCount) {
                    ex.selectTrack(track)
                    ex.seekTo(0L, MediaExtractor.SEEK_TO_CLOSEST_SYNC)
                    while (true) {
                        val t = ex.sampleTime
                        if (t < 0) break
                        buffer.clear()
                        val size = ex.readSampleData(buffer, 0)
                        if (size < 0) break
                        info.offset = 0; info.size = size
                        info.presentationTimeUs = t + offsetUs
                        info.flags = ex.sampleFlags
                        muxer.writeSampleData(maps[track]!!, buffer, info)
                        localMax = maxOf(localMax, t)
                        ex.advance()
                    }
                    ex.unselectTrack(track)
                }
                ex.release()
                offsetUs += localMax + 1_000_000L / 30L
                totalDurationUs = offsetUs
                sink?.success((index + 1).toDouble() / inputs.size.toDouble())
            }
        } finally {
            muxer.stop(); muxer.release()
        }
        return totalDurationUs / 1000L
    }

    private fun trim(input: String, output: String, startMs: Long, endMs: Long): Long {
        require(endMs > startMs) { "نهاية المقطع يجب أن تكون بعد البداية" }
        File(output).parentFile?.mkdirs()
        val extractor = MediaExtractor(); extractor.setDataSource(input)
        val muxer = MediaMuxer(output, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        val map = HashMap<Int, Int>()
        for (i in 0 until extractor.trackCount) {
            val f = extractor.getTrackFormat(i)
            if (f.containsKey(MediaFormat.KEY_MIME)) map[i] = muxer.addTrack(f)
        }
        muxer.start()
        val buffer = java.nio.ByteBuffer.allocate(4 * 1024 * 1024)
        val info = android.media.MediaCodec.BufferInfo()
        val startUs = startMs * 1000L; val endUs = endMs * 1000L
        for ((track, outTrack) in map) {
            extractor.selectTrack(track); extractor.seekTo(startUs, MediaExtractor.SEEK_TO_CLOSEST_SYNC)
            while (true) {
                val t = extractor.sampleTime
                if (t < 0 || t > endUs) break
                buffer.clear(); val size = extractor.readSampleData(buffer, 0)
                if (size < 0) break
                info.offset = 0; info.size = size; info.presentationTimeUs = t - startUs
                info.flags = extractor.sampleFlags
                muxer.writeSampleData(outTrack, buffer, info)
                sink?.success(((t - startUs).toDouble() / (endUs - startUs).coerceAtLeast(1L)).coerceIn(0.0, 1.0))
                extractor.advance()
            }
            extractor.unselectTrack(track)
        }
        muxer.stop(); muxer.release(); extractor.release()
        return endMs - startMs
    }
}
