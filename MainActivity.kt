package com.alsaadi.app

import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import android.media.MediaRecorder
import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.roundToInt
import kotlin.math.sin
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.media.MediaMetadataRetriever
import androidx.media3.common.Effect
import androidx.media3.common.MediaItem
import androidx.media3.common.audio.AudioProcessor
import androidx.media3.common.audio.SonicAudioProcessor
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.BitmapOverlay
import androidx.media3.effect.Brightness
import androidx.media3.effect.Contrast
import androidx.media3.effect.MatrixTransformation
import androidx.media3.effect.OverlayEffect
import androidx.media3.effect.Presentation
import androidx.media3.effect.RgbMatrix
import androidx.media3.effect.RgbAdjustment
import androidx.media3.effect.ScaleAndRotateTransformation
import androidx.media3.effect.RgbFilter
import androidx.media3.effect.SpeedChangeEffect
import androidx.media3.effect.TextureOverlay
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
    private var recorder: MediaRecorder? = null
    private var recordingPath: String? = null
    private var pendingRecordPath: String? = null
    private var pendingRecordResult: MethodChannel.Result? = null

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
                    "overlayImage" -> {
                        val input = call.argument<String>("input")!!
                        val overlay = call.argument<String>("overlay")!!
                        val output = call.argument<String>("output")!!
                        overlayImage(input, overlay, output, result)
                    }
                    "applyEffect" -> {
                        val input = call.argument<String>("input")!!
                        val output = call.argument<String>("output")!!
                        val kind = call.argument<String>("effect") ?: "zoom"
                        val durationMs = (call.argument<Number>("durationMs") ?: 0).toLong()
                        applyEffect(input, output, kind, durationMs, result)
                    }
                    "mergeFade" -> {
                        val inputs = call.argument<List<String>>("inputs") ?: emptyList()
                        val output = call.argument<String>("output")!!
                        mergeFade(inputs, output, result)
                    }
                    "makeSlideshow" -> {
                        val images = call.argument<List<String>>("images") ?: emptyList()
                        val output = call.argument<String>("output")!!
                        val slideMs = (call.argument<Number>("slideMs") ?: 3000).toLong()
                        val motion = call.argument<String>("motion") ?: "zoom"
                        val fade = call.argument<Boolean>("fade") ?: true
                        val extra = call.argument<String>("extra") ?: "none"
                        val audio = call.argument<String>("audio")
                        val volume = (call.argument<Number>("volume") ?: 1.0).toFloat()
                        makeSlideshow(images, slideMs, motion, fade, extra, audio, volume, output, result)
                    }
                    "exportVideo" -> {
                        val input = call.argument<String>("input")!!
                        val output = call.argument<String>("output")!!
                        val shortSide = (call.argument<Number>("shortSide") ?: 0).toInt()
                        val overlay = call.argument<String>("overlay")
                        val enhance = call.argument<Boolean>("enhance") ?: false
                        exportVideo(input, output, shortSide, overlay, enhance, result)
                    }
                    "transformVideo" -> {
                        val input = call.argument<String>("input")!!
                        val output = call.argument<String>("output")!!
                        val rotate = (call.argument<Number>("rotate") ?: 0).toInt()
                        val flip = call.argument<Boolean>("flip") ?: false
                        val aspect = (call.argument<Number>("aspect") ?: 0).toDouble()
                        val crop = call.argument<Boolean>("crop") ?: true
                        val volume = (call.argument<Number>("volume") ?: 1.0).toFloat()
                        transformVideo(input, output, rotate, flip, aspect, crop, volume, result)
                    }
                    "startRecording" -> {
                        val path = call.argument<String>("path")!!
                        startRecording(path, result)
                    }
                    "stopRecording" -> {
                        stopRecording(result)
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
            listOf(
                EditedMediaItemSequence.Builder().addItem(visualItem).build(),
                EditedMediaItemSequence.Builder().addItem(musicItem).build()
            )
        ).build()
        exportComposition(composition, output, result)
    }

    private fun buildFade(totalMs: Long, fadeMs: Long, fadeIn: Boolean = true, fadeOut: Boolean = true): RgbMatrix {
        return RgbMatrix { presentationTimeUs, _ ->
            val t = presentationTimeUs / 1000.0
            var f = 1.0
            if (fadeIn && t < fadeMs) f = t / fadeMs
            val remain = totalMs - t
            if (fadeOut && remain < fadeMs) f = minOf(f, remain / fadeMs)
            val k = f.coerceIn(0.0, 1.0).toFloat()
            floatArrayOf(
                k, 0f, 0f, 0f,
                0f, k, 0f, 0f,
                0f, 0f, k, 0f,
                0f, 0f, 0f, 1f
            )
        }
    }

    private fun buildLight(kind: String): RgbMatrix {
        return RgbMatrix { presentationTimeUs, _ ->
            val t = presentationTimeUs / 1000.0
            val f: Double = when (kind) {
                "flash" -> 1.0 + 0.7 * Math.exp(-((t % 1000.0) / 180.0))
                "strobe" -> if ((t % 400.0) < 60.0) 1.6 else 1.0
                else -> 1.0 + 0.2 * sin(2 * PI * t / 1500.0)
            }
            val k = f.coerceIn(0.0, 2.0).toFloat()
            floatArrayOf(
                k, 0f, 0f, 0f,
                0f, k, 0f, 0f,
                0f, 0f, k, 0f,
                0f, 0f, 0f, 1f
            )
        }
    }

    private fun buildMotion(kind: String, totalMs: Long): MatrixTransformation {
        return MatrixTransformation { presentationTimeUs ->
            val t = presentationTimeUs / 1000.0
            val p = if (totalMs > 0) (t / totalMs).coerceIn(0.0, 1.0) else 0.0
            val m = Matrix()
            when (kind) {
                "zoom" -> {
                    val s = (1.0 + 0.25 * p).toFloat()
                    m.setScale(s, s)
                }
                "zoomout" -> {
                    val s = (1.25 - 0.25 * p).toFloat()
                    m.setScale(s, s)
                }
                "pulse" -> {
                    val s = (1.0 + 0.06 * sin(2 * PI * t / 1000.0)).toFloat()
                    m.setScale(s, s)
                }
                "heartbeat" -> {
                    val ph = (t % 900.0) / 900.0
                    val b = if (ph < 0.15) sin(ph / 0.15 * PI) else if (ph >= 0.25 && ph < 0.4) sin((ph - 0.25) / 0.15 * PI) * 0.7 else 0.0
                    val s = (1.0 + 0.09 * b).toFloat()
                    m.setScale(s, s)
                }
                "shake" -> {
                    m.setScale(1.06f, 1.06f)
                    m.postTranslate((0.02 * sin(t / 40.0)).toFloat(), (0.02 * cos(t / 55.0)).toFloat())
                }
                "mirror" -> {
                    m.setScale(-1f, 1f)
                }
                "panLeft" -> {
                    m.setScale(1.2f, 1.2f)
                    m.postTranslate((0.18 * (1.0 - 2.0 * p)).toFloat(), 0f)
                }
                "panRight" -> {
                    m.setScale(1.2f, 1.2f)
                    m.postTranslate((-0.18 * (1.0 - 2.0 * p)).toFloat(), 0f)
                }
                "panUp" -> {
                    m.setScale(1.2f, 1.2f)
                    m.postTranslate(0f, (0.18 * (1.0 - 2.0 * p)).toFloat())
                }
                "panDown" -> {
                    m.setScale(1.2f, 1.2f)
                    m.postTranslate(0f, (-0.18 * (1.0 - 2.0 * p)).toFloat())
                }
                "pop" -> {
                    val e = (t / 450.0).coerceIn(0.0, 1.0)
                    val eased = 1.0 - (1.0 - e) * (1.0 - e)
                    val s = (0.8 + 0.2 * eased).toFloat()
                    m.setScale(s, s)
                }
                "sway" -> {
                    m.setScale(1.1f, 1.1f)
                    m.postTranslate((0.08 * sin(2 * PI * t / 2000.0)).toFloat(), (0.03 * sin(2 * PI * t / 1300.0)).toFloat())
                }
            }
            m
        }
    }

    private fun buildFx(kind: String, totalMs: Long): Effect {
        return when (kind) {
            "fade" -> buildFade(totalMs, 700)
            "fadeIn" -> buildFade(totalMs, 900, true, false)
            "fadeOut" -> buildFade(totalMs, 900, false, true)
            "flash", "strobe", "pulseLight" -> buildLight(kind)
            else -> buildMotion(kind, totalMs)
        }
    }

    private fun applyEffect(input: String, output: String, kind: String, durationMs: Long, result: MethodChannel.Result) {
        val fx: Effect = buildFx(kind, durationMs)
        val item = EditedMediaItem.Builder(MediaItem.fromUri(Uri.fromFile(File(input))))
            .setEffects(Effects(emptyList<AudioProcessor>(), listOf<Effect>(fx)))
            .build()
        val composition = Composition.Builder(
            listOf(EditedMediaItemSequence.Builder().addItem(item).build())
        ).build()
        exportComposition(composition, output, result)
    }

    private fun mergeFade(inputs: List<String>, output: String, result: MethodChannel.Result) {
        if (inputs.size < 2) {
            result.error("MEDIA_ERROR", "تحتاج مقطعين على الأقل", null)
            return
        }
        val seq = EditedMediaItemSequence.Builder()
        for (p in inputs) {
            val d = durationOf(p)
            val fade = buildFade(d, 500)
            val item = EditedMediaItem.Builder(MediaItem.fromUri(Uri.fromFile(File(p))))
                .setEffects(Effects(emptyList<AudioProcessor>(), listOf<Effect>(fade)))
                .build()
            seq.addItem(item)
        }
        exportComposition(Composition.Builder(listOf(seq.build())).build(), output, result)
    }

    private fun makeSlideshow(images: List<String>, slideMs: Long, motion: String, fade: Boolean, extra: String, audioPath: String?, volume: Float, output: String, result: MethodChannel.Result) {
        if (images.isEmpty()) {
            result.error("MEDIA_ERROR", "لا توجد صور", null)
            return
        }
        val totalMs = slideMs * images.size
        val seq = EditedMediaItemSequence.Builder()
        val motions = motion.split(",").map { it.trim() }.filter { it.isNotEmpty() }
        for ((idx, p) in images.withIndex()) {
            val mediaItem = MediaItem.Builder()
                .setUri(Uri.fromFile(File(p)))
                .setMimeType(MimeTypes.IMAGE_PNG)
                .setImageDurationMs(slideMs)
                .build()
            val fx = ArrayList<Effect>()
            val mk = if (motions.isEmpty()) "none" else motions[idx % motions.size]
            if (mk != "none") fx.add(buildMotion(mk, slideMs))
            if (fade) fx.add(buildFade(slideMs, 450))
            if (extra.isNotEmpty() && extra != "none") fx.add(buildLight(extra))
            val item = EditedMediaItem.Builder(mediaItem)
                .setDurationUs(slideMs * 1000L)
                .setFrameRate(30)
                .setEffects(Effects(emptyList<AudioProcessor>(), fx))
                .build()
            seq.addItem(item)
        }
        val sequences = ArrayList<EditedMediaItemSequence>()
        sequences.add(seq.build())
        if (audioPath != null && audioPath.isNotEmpty()) {
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
            sequences.add(EditedMediaItemSequence.Builder().addItem(musicItem).build())
        }
        exportComposition(Composition.Builder(sequences).build(), output, result)
    }

    private fun exportVideo(input: String, output: String, shortSide: Int, overlay: String?, enhance: Boolean, result: MethodChannel.Result) {
        val fx = ArrayList<Effect>()
        if (enhance) {
            fx.add(Contrast(0.12f))
            fx.add(Brightness(0.02f))
        }
        if (shortSide > 0) {
            val r = MediaMetadataRetriever()
            try {
                r.setDataSource(input)
                val w0 = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull() ?: 0
                val h0 = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull() ?: 0
                val rot = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toIntOrNull() ?: 0
                val swap = rot == 90 || rot == 270
                val w = if (swap) h0 else w0
                val h = if (swap) w0 else h0
                if (w > 0 && h > 0) {
                    val targetH = if (h >= w) ((shortSide.toDouble() * h / w) / 2.0).roundToInt() * 2 else shortSide
                    fx.add(Presentation.createForHeight(targetH))
                }
            } catch (e: Exception) {
            } finally {
                r.release()
            }
        }
        if (overlay != null && overlay.isNotEmpty()) {
            val bmp = BitmapFactory.decodeFile(overlay)
            if (bmp != null) {
                fx.add(OverlayEffect(listOf<TextureOverlay>(BitmapOverlay.createStaticBitmapOverlay(bmp))))
            }
        }
        val item = EditedMediaItem.Builder(MediaItem.fromUri(Uri.fromFile(File(input))))
            .setEffects(Effects(emptyList<AudioProcessor>(), fx))
            .build()
        val composition = Composition.Builder(
            listOf(EditedMediaItemSequence.Builder().addItem(item).build())
        ).build()
        exportComposition(composition, output, result)
    }

    private fun transformVideo(input: String, output: String, rotate: Int, flip: Boolean, aspect: Double, crop: Boolean, volume: Float, result: MethodChannel.Result) {
        val fx = ArrayList<Effect>()
        if (rotate != 0 || flip) {
            val b = ScaleAndRotateTransformation.Builder()
            if (rotate != 0) b.setRotationDegrees(((360 - rotate) % 360).toFloat())
            if (flip) b.setScale(-1f, 1f)
            fx.add(b.build())
        }
        if (aspect > 0.0) {
            val layout = if (crop) Presentation.LAYOUT_SCALE_TO_FIT_WITH_CROP else Presentation.LAYOUT_SCALE_TO_FIT
            fx.add(Presentation.createForAspectRatio(aspect.toFloat(), layout))
        }
        val processors = ArrayList<AudioProcessor>()
        if (volume < 0.99f || volume > 1.01f) {
            val mixer = ChannelMixingAudioProcessor()
            for (ch in 1..2) {
                mixer.putChannelMixingMatrix(ChannelMixingMatrix.create(ch, ch).scaleBy(volume))
            }
            processors.add(mixer)
        }
        val item = EditedMediaItem.Builder(MediaItem.fromUri(Uri.fromFile(File(input))))
            .setEffects(Effects(processors, fx))
            .build()
        val composition = Composition.Builder(
            listOf(EditedMediaItemSequence.Builder().addItem(item).build())
        ).build()
        exportComposition(composition, output, result)
    }

    @Suppress("DEPRECATION")
    private fun createLegacyRecorder(): MediaRecorder = MediaRecorder()

    private fun startRecording(path: String, result: MethodChannel.Result) {
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            pendingRecordPath = path
            pendingRecordResult = result
            requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), 7712)
            return
        }
        doStartRecording(path, result)
    }

    private fun doStartRecording(path: String, result: MethodChannel.Result) {
        try {
            recorder?.release()
            val r: MediaRecorder = if (Build.VERSION.SDK_INT >= 31) MediaRecorder(this) else createLegacyRecorder()
            r.setAudioSource(MediaRecorder.AudioSource.MIC)
            r.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            r.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            r.setAudioEncodingBitRate(128000)
            r.setAudioSamplingRate(44100)
            r.setOutputFile(path)
            r.prepare()
            r.start()
            recorder = r
            recordingPath = path
            result.success(true)
        } catch (e: Exception) {
            recorder = null
            recordingPath = null
            result.error("RECORD", e.message ?: "تعذر بدء التسجيل", null)
        }
    }

    private fun stopRecording(result: MethodChannel.Result) {
        val r = recorder
        val p = recordingPath
        recorder = null
        recordingPath = null
        if (r == null || p == null) {
            result.success(null)
            return
        }
        try {
            r.stop()
            r.release()
            result.success(p)
        } catch (e: Exception) {
            try {
                r.release()
            } catch (_: Exception) {
            }
            result.error("RECORD", e.message ?: "تعذر إيقاف التسجيل", null)
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 7712) {
            val res = pendingRecordResult
            val path = pendingRecordPath
            pendingRecordResult = null
            pendingRecordPath = null
            if (res != null && path != null) {
                if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                    doStartRecording(path, res)
                } else {
                    res.error("PERMISSION", "لم تسمح للتطبيق باستخدام الميكروفون", null)
                }
            }
        }
    }

    private fun overlayImage(input: String, overlay: String, output: String, result: MethodChannel.Result) {
        val bmp = BitmapFactory.decodeFile(overlay)
        if (bmp == null) {
            result.error("MEDIA_ERROR", "تعذر قراءة صورة النص", null)
            return
        }
        val ov = BitmapOverlay.createStaticBitmapOverlay(bmp)
        val effect = OverlayEffect(listOf<TextureOverlay>(ov))
        val item = EditedMediaItem.Builder(MediaItem.fromUri(Uri.fromFile(File(input))))
            .setEffects(Effects(emptyList<AudioProcessor>(), listOf<Effect>(effect)))
            .build()
        val composition = Composition.Builder(
            listOf(EditedMediaItemSequence.Builder().addItem(item).build())
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
