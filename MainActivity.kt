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
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.media.MediaMetadataRetriever
import androidx.media3.common.Effect
import androidx.media3.common.MediaItem
import androidx.media3.common.audio.AudioProcessor
import androidx.media3.common.audio.SonicAudioProcessor
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.Brightness
import androidx.media3.effect.Contrast
import androidx.media3.effect.RgbAdjustment
import androidx.media3.effect.RgbFilter
import androidx.media3.effect.SpeedChangeEffect
import androidx.media3.transformer.Composition
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.ProgressHolder
import androidx.media3.transformer.Transformer
import android.app.Activity
import android.content.Intent
import android.provider.OpenableColumns
import androidx.media3.common.MimeTypes
import androidx.media3.common.audio.ChannelMixingAudioProcessor
import androidx.media3.common.audio.ChannelMixingMatrix
import androidx.media3.transformer.EditedMediaItemSequence

@androidx.annotation.OptIn(UnstableApi::class)
class MainActivity : FlutterActivity() {
    private var pendingPick: MethodChannel.Result? = null

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
                    "speedVideo" -> {
                        val input = call.argument<String>("input")!!
                        val output = call.argument<String>("output")!!
                        val speed = call.argument<Number>("speed")!!.toFloat()
                        val sonic = SonicAudioProcessor()
                        sonic.setSpeed(speed)
                        export(input, output, listOf<AudioProcessor>(sonic), listOf<Effect>(SpeedChangeEffect(speed)), result)
                    }
                    "filterVideo" -> {
                        val input = call.argument<String>("input")!!
                        val output = call.argument<String>("output")!!
                        val filter = call.argument<String>("filter") ?: "none"
                        val effect: Effect? = when (filter) {
                            "bw" -> RgbFilter.createGrayscaleFilter()
                            "invert" -> RgbFilter.createInvertedFilter()
                            "warm" -> RgbAdjustment.Builder().setRedScale(1.15f).setGreenScale(1.0f).setBlueScale(0.88f).build()
                            "cool" -> RgbAdjustment.Builder().setRedScale(0.88f).setGreenScale(1.0f).setBlueScale(1.15f).build()
                            "bright" -> Brightness(0.2f)
                            "contrast" -> Contrast(0.35f)
                            else -> null
                        }
                        val list = if (effect == null) emptyList<Effect>() else listOf<Effect>(effect)
                        export(input, output, emptyList<AudioProcessor>(), list, result)
                    }
                    "saveImage" -> {
                        val path = call.argument<String>("path")!!
                        val name = call.argument<String>("name") ?: ("tayoub_" + System.currentTimeMillis() + ".png")
                        result.success(saveImageToGallery(path, name))
                    }
                    "pickAudio" -> {
                        if (pendingPick != null) {
                            result.error("BUSY", "اختيار الموسيقى قيد التنفيذ", null)
                        } else {
                            pendingPick = result
                            try {
                                val i = Intent(Intent.ACTION_GET_CONTENT)
                                i.type = "audio/*"
                                i.addCategory(Intent.CATEGORY_OPENABLE)
                                startActivityForResult(i, 7711)
                            } catch (e: Exception) {
                                pendingPick = null
                                result.error("PICK_ERROR", e.message, null)
                            }
                        }
                    }
                    "mixMusic" -> {
                        val input = call.argument<String>("input")!!
                        val audio = call.argument<String>("audio")!!
                        val output = call.argument<String>("output")!!
                        val isImage = call.argument<Boolean>("isImage") ?: false
                        val durationMs = (call.argument<Number>("durationMs") ?: 0).toLong()
                        val keepOriginal = call.argument<Boolean>("keepOriginal") ?: true
                        val volume = (call.argument<Number>("volume") ?: 1.0).toFloat()
                        mixMusic(input, isImage, durationMs, audio, output, keepOriginal, volume, result)
                    }
                    "saveVideo" -> {
                        val path = call.argument<String>("path")!!
                        val name = call.argument<String>("name") ?: ("tayoub_" + System.currentTimeMillis() + ".mp4")
                        result.success(saveVideoToGallery(path, name))
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) { result.error("MEDIA_ERROR", e.message, null) }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == 7711) {
            val r = pendingPick
            pendingPick = null
            if (r != null) {
                val uri = data?.data
                if (resultCode == Activity.RESULT_OK && uri != null) {
                    try {
                        r.success(copyUriToCache(uri))
                    } catch (e: Exception) {
                        r.error("PICK_ERROR", e.message, null)
                    }
                } else {
                    r.success(null)
                }
            }
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    private fun copyUriToCache(uri: Uri): Map<String, Any> {
        var name = "music_" + System.currentTimeMillis()
        contentResolver.query(uri, null, null, null, null)?.use { c ->
            val idx = c.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (idx >= 0 && c.moveToFirst()) {
                val n = c.getString(idx)
                if (n != null) name = n
            }
        }
        val ext0 = name.substringAfterLast('.', "m4a")
        val ext = if (ext0.length in 1..5) ext0 else "m4a"
        val out = File(cacheDir, "pick_audio_" + System.currentTimeMillis() + "." + ext)
        val input = contentResolver.openInputStream(uri) ?: throw IllegalStateException("تعذر قراءة الملف")
        input.use { src -> out.outputStream().use { dst -> src.copyTo(dst) } }
        return mapOf("path" to out.absolutePath, "name" to name)
    }

    private fun mixMusic(input: String, isImage: Boolean, imageDurationMs: Long, audioPath: String, output: String, keepOriginal: Boolean, volume: Float, result: MethodChannel.Result) {
        val totalMs = if (isImage) imageDurationMs else durationOf(input)
        val visualItem: EditedMediaItem = if (isImage) {
            val mime = if (input.lowercase().endsWith(".png")) MimeTypes.IMAGE_PNG else MimeTypes.IMAGE_JPEG
            val mediaItem = MediaItem.Builder()
                .setUri(Uri.fromFile(File(input)))
                .setMimeType(mime)
                .setImageDurationMs(totalMs)
                .build()
            EditedMediaItem.Builder(mediaItem)
                .setDurationUs(totalMs * 1000L)
                .setFrameRate(30)
                .build()
        } else {
            EditedMediaItem.Builder(MediaItem.fromUri(Uri.fromFile(File(input))))
                .setRemoveAudio(!keepOriginal)
                .build()
        }
        val clip = MediaItem.ClippingConfiguration.Builder()
            .setStartPositionMs(0)
            .setEndPositionMs(totalMs)
            .build()
        val audioMedia = MediaItem.Builder()
            .setUri(Uri.fromFile(File(audioPath)))
            .setClippingConfiguration(clip)
            .build()
        val processors = ArrayList<AudioProcessor>()
        if (volume < 0.99f || volume > 1.01f) {
            val mixer = ChannelMixingAudioProcessor()
            for (ch in 1..2) {
                mixer.putChannelMixingMatrix(ChannelMixingMatrix.create(ch, ch).scaleBy(volume))
            }
            processors.add(mixer)
        }
        val musicItem = EditedMediaItem.Builder(audioMedia)
            .setRemoveVideo(true)
            .setEffects(Effects(processors, emptyList<Effect>()))
            .build()
        val composition = Composition.Builder(
            listOf(EditedMediaItemSequence(listOf(visualItem)), EditedMediaItemSequence(listOf(musicItem)))
        ).build()
        exportComposition(composition, output, result)
    }

    private fun exportComposition(composition: Composition, output: String, result: MethodChannel.Result) {
        File(output).parentFile?.mkdirs()
        File(output).delete()
        val handler = Handler(Looper.getMainLooper())
        val holder = ProgressHolder()
        var finished = false
        lateinit var transformer: Transformer
        val poll = object : Runnable {
            override fun run() {
                if (finished) return
                if (transformer.getProgress(holder) == Transformer.PROGRESS_STATE_AVAILABLE) {
                    sink?.success(holder.progress / 100.0)
                }
                handler.postDelayed(this, 300)
            }
        }
        transformer = Transformer.Builder(this)
            .addListener(object : Transformer.Listener {
                override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                    finished = true
                    result.success(mapOf("path" to output, "durationMs" to durationOf(output)))
                }
                override fun onError(composition: Composition, exportResult: ExportResult, exportException: ExportException) {
                    finished = true
                    result.error("MEDIA_ERROR", exportException.message, null)
                }
            })
            .build()
        transformer.start(composition, output)
        handler.post(poll)
    }

    private fun saveVideoToGallery(path: String, name: String): String {
        val values = android.content.ContentValues().apply {
            put(android.provider.MediaStore.Video.Media.DISPLAY_NAME, name)
            put(android.provider.MediaStore.Video.Media.MIME_TYPE, "video/mp4")
            if (android.os.Build.VERSION.SDK_INT >= 29) {
                put(android.provider.MediaStore.Video.Media.RELATIVE_PATH, "Movies/Tayoub")
                put(android.provider.MediaStore.Video.Media.IS_PENDING, 1)
            }
        }
        val resolver = contentResolver
        val uri = resolver.insert(android.provider.MediaStore.Video.Media.EXTERNAL_CONTENT_URI, values)
            ?: throw IllegalStateException("تعذر إنشاء الملف في المعرض")
        val stream = resolver.openOutputStream(uri) ?: throw IllegalStateException("تعذر فتح ملف الحفظ")
        stream.use { out -> File(path).inputStream().use { input -> input.copyTo(out) } }
        if (android.os.Build.VERSION.SDK_INT >= 29) {
            val done = android.content.ContentValues()
            done.put(android.provider.MediaStore.Video.Media.IS_PENDING, 0)
            resolver.update(uri, done, null, null)
        }
        return uri.toString()
    }

    private fun saveImageToGallery(path: String, name: String): String {
        val values = android.content.ContentValues().apply {
            put(android.provider.MediaStore.Images.Media.DISPLAY_NAME, name)
            put(android.provider.MediaStore.Images.Media.MIME_TYPE, "image/png")
            if (android.os.Build.VERSION.SDK_INT >= 29) {
                put(android.provider.MediaStore.Images.Media.RELATIVE_PATH, "Pictures/Tayoub")
                put(android.provider.MediaStore.Images.Media.IS_PENDING, 1)
            }
        }
        val resolver = contentResolver
        val uri = resolver.insert(android.provider.MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
            ?: throw IllegalStateException("تعذر إنشاء الملف في المعرض")
        val stream = resolver.openOutputStream(uri) ?: throw IllegalStateException("تعذر فتح ملف الحفظ")
        stream.use { out -> File(path).inputStream().use { input -> input.copyTo(out) } }
        if (android.os.Build.VERSION.SDK_INT >= 29) {
            val done = android.content.ContentValues()
            done.put(android.provider.MediaStore.Images.Media.IS_PENDING, 0)
            resolver.update(uri, done, null, null)
        }
        return uri.toString()
    }

    private fun durationOf(path: String): Long {
        val r = MediaMetadataRetriever()
        return try {
            r.setDataSource(path)
            r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0L
        } finally { r.release() }
    }

    private fun export(input: String, output: String, audio: List<AudioProcessor>, video: List<Effect>, result: MethodChannel.Result) {
        File(output).parentFile?.mkdirs()
        File(output).delete()
        val item = EditedMediaItem.Builder(MediaItem.fromUri(Uri.fromFile(File(input))))
            .setEffects(Effects(audio, video))
            .build()
        val handler = Handler(Looper.getMainLooper())
        val holder = ProgressHolder()
        var finished = false
        lateinit var transformer: Transformer
        val poll = object : Runnable {
            override fun run() {
                if (finished) return
                if (transformer.getProgress(holder) == Transformer.PROGRESS_STATE_AVAILABLE) {
                    sink?.success(holder.progress / 100.0)
                }
                handler.postDelayed(this, 300)
            }
        }
        transformer = Transformer.Builder(this)
            .addListener(object : Transformer.Listener {
                override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                    finished = true
                    result.success(mapOf("path" to output, "durationMs" to durationOf(output)))
                }
                override fun onError(composition: Composition, exportResult: ExportResult, exportException: ExportException) {
                    finished = true
                    result.error("MEDIA_ERROR", exportException.message, null)
                }
            })
            .build()
        transformer.start(item, output)
        handler.post(poll)
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
