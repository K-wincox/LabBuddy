package com.kongweikang.labbuddy_android

import android.Manifest
import android.app.AlarmManager
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.app.Activity
import android.app.PendingIntent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.Rect
import android.graphics.RectF
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.ParcelFileDescriptor
import android.provider.MediaStore
import androidx.core.content.FileProvider
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val channelName = "labbuddy/data_card"
    private val timerChannelName = "labbuddy/timers"
    private val backupChannelName = "labbuddy/backup"
    private val profileChannelName = "labbuddy/profile"
    private val pickTextRequestCode = 4207
    private val pickAvatarRequestCode = 4208
    private val pickDataCardImageRequestCode = 4209
    private val pickOcrImageRequestCode = 4210
    private val captureOcrImageRequestCode = 4211
    private val pickOcrPdfRequestCode = 4212
    private var pendingPickTextResult: MethodChannel.Result? = null
    private var pendingPickAvatarResult: MethodChannel.Result? = null
    private var pendingPickDataCardImageResult: MethodChannel.Result? = null
    private var pendingOcrResult: MethodChannel.Result? = null
    private var pendingCaptureImageUri: Uri? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "shareDataCard" -> {
                    val args = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
                    val file = createDataCardPng(args)
                    shareImage(file)
                    result.success(file.absolutePath)
                }
                "saveDataCard" -> {
                    val args = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
                    val file = createDataCardPng(args)
                    val uri = saveImageToGallery(file)
                    result.success(uri.toString())
                }
                "pickDataCardImage" -> pickDataCardImage(result)
                "pickTextDocument" -> pickTextDocument(result)
                "recognizeImageText" -> pickOcrImage(result)
                "captureImageText" -> captureOcrImage(result)
                "recognizePdfText" -> pickOcrPdf(result)
                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, timerChannelName).setMethodCallHandler { call, result ->
            val args = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
            when (call.method) {
                "scheduleTimerNotification" -> {
                    scheduleTimerNotification(args)
                    result.success(null)
                }
                "cancelTimerNotification" -> {
                    val id = args["id"] as? String ?: ""
                    cancelTimerNotification(id)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, backupChannelName).setMethodCallHandler { call, result ->
            val args = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
            when (call.method) {
                "shareBackup" -> {
                    val fileName = args["fileName"] as? String ?: "labbuddy-backup.json"
                    val json = args["json"] as? String ?: "{}"
                    val file = createBackupFile(fileName, json)
                    shareBackupFile(file)
                    result.success(file.absolutePath)
                }
                "pickBackup" -> pickJsonDocument(result)
                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, profileChannelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickAvatarImage" -> pickAvatarImage(result)
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == pickAvatarRequestCode) {
            handleAvatarResult(resultCode, data)
            return
        }
        if (requestCode == pickDataCardImageRequestCode) {
            handleDataCardImageResult(resultCode, data)
            return
        }
        if (requestCode == pickOcrImageRequestCode) {
            handleOcrImageResult(resultCode, data?.data)
            return
        }
        if (requestCode == captureOcrImageRequestCode) {
            handleOcrImageResult(resultCode, pendingCaptureImageUri)
            pendingCaptureImageUri = null
            return
        }
        if (requestCode == pickOcrPdfRequestCode) {
            handleOcrPdfResult(resultCode, data?.data)
            return
        }
        if (requestCode != pickTextRequestCode) return
        val result = pendingPickTextResult ?: return
        pendingPickTextResult = null
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            result.success(null)
            return
        }
        try {
            val uri = data.data!!
            val text = contentResolver.openInputStream(uri)?.bufferedReader()?.use { it.readText() } ?: ""
            result.success(text)
        } catch (error: Exception) {
            result.error("TEXT_IMPORT_FAILED", error.message, null)
        }
    }

    private fun pickAvatarImage(result: MethodChannel.Result) {
        if (pendingPickAvatarResult != null) {
            result.error("PICK_IN_PROGRESS", "An avatar picker is already open.", null)
            return
        }
        pendingPickAvatarResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "image/*"
        }
        try {
            startActivityForResult(intent, pickAvatarRequestCode)
        } catch (error: Exception) {
            pendingPickAvatarResult = null
            result.error("AVATAR_PICK_FAILED", error.message, null)
        }
    }

    private fun pickDataCardImage(result: MethodChannel.Result) {
        if (pendingPickDataCardImageResult != null) {
            result.error("PICK_IN_PROGRESS", "A Data Card image picker is already open.", null)
            return
        }
        pendingPickDataCardImageResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "image/*"
        }
        try {
            startActivityForResult(intent, pickDataCardImageRequestCode)
        } catch (error: Exception) {
            pendingPickDataCardImageResult = null
            result.error("DATA_CARD_IMAGE_PICK_FAILED", error.message, null)
        }
    }

    private fun pickOcrImage(result: MethodChannel.Result) {
        if (pendingOcrResult != null) {
            result.error("OCR_IN_PROGRESS", "An OCR import is already running.", null)
            return
        }
        pendingOcrResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "image/*"
        }
        try {
            startActivityForResult(intent, pickOcrImageRequestCode)
        } catch (error: Exception) {
            pendingOcrResult = null
            result.error("OCR_IMAGE_PICK_FAILED", error.message, null)
        }
    }

    private fun captureOcrImage(result: MethodChannel.Result) {
        if (pendingOcrResult != null) {
            result.error("OCR_IN_PROGRESS", "An OCR import is already running.", null)
            return
        }
        pendingOcrResult = result
        val dir = File(cacheDir, "ocr").apply { mkdirs() }
        val file = File(dir, "ocr-${System.currentTimeMillis()}.jpg")
        val uri = FileProvider.getUriForFile(this, "${packageName}.fileprovider", file)
        pendingCaptureImageUri = uri
        val intent = Intent(MediaStore.ACTION_IMAGE_CAPTURE).apply {
            putExtra(MediaStore.EXTRA_OUTPUT, uri)
            addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION or Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        try {
            startActivityForResult(intent, captureOcrImageRequestCode)
        } catch (error: Exception) {
            pendingOcrResult = null
            pendingCaptureImageUri = null
            result.error("OCR_CAMERA_FAILED", error.message, null)
        }
    }

    private fun pickOcrPdf(result: MethodChannel.Result) {
        if (pendingOcrResult != null) {
            result.error("OCR_IN_PROGRESS", "An OCR import is already running.", null)
            return
        }
        pendingOcrResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "application/pdf"
        }
        try {
            startActivityForResult(intent, pickOcrPdfRequestCode)
        } catch (error: Exception) {
            pendingOcrResult = null
            result.error("OCR_PDF_PICK_FAILED", error.message, null)
        }
    }

    private fun handleOcrImageResult(resultCode: Int, uri: Uri?) {
        val result = pendingOcrResult ?: return
        pendingOcrResult = null
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return
        }
        recognizeImageUri(uri, result)
    }

    private fun handleOcrPdfResult(resultCode: Int, uri: Uri?) {
        val result = pendingOcrResult ?: return
        pendingOcrResult = null
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return
        }
        recognizePdfUri(uri, result)
    }

    private fun recognizeImageUri(uri: Uri, result: MethodChannel.Result) {
        try {
            val image = InputImage.fromFilePath(this, uri)
            val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
            recognizer.process(image)
                .addOnSuccessListener { visionText ->
                    result.success(visionText.text)
                }
                .addOnFailureListener { error ->
                    result.error("OCR_IMAGE_FAILED", error.message, null)
                }
        } catch (error: Exception) {
            result.error("OCR_IMAGE_FAILED", error.message, null)
        }
    }

    private fun recognizePdfUri(uri: Uri, result: MethodChannel.Result) {
        var descriptor: ParcelFileDescriptor? = null
        var renderer: android.graphics.pdf.PdfRenderer? = null
        try {
            descriptor = contentResolver.openFileDescriptor(uri, "r")
                ?: throw IllegalStateException("Unable to open selected PDF")
            renderer = android.graphics.pdf.PdfRenderer(descriptor)
            val pageCount = minOf(renderer.pageCount, 3)
            if (pageCount <= 0) {
                result.success("")
                renderer.close()
                descriptor.close()
                return
            }
            val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
            val pageTexts = MutableList(pageCount) { "" }
            var remaining = pageCount
            var completed = false

            fun closeRenderer() {
                try {
                    renderer?.close()
                } catch (_: Exception) {
                }
                try {
                    descriptor?.close()
                } catch (_: Exception) {
                }
            }

            for (index in 0 until pageCount) {
                val page = renderer.openPage(index)
                val scale = 2
                val maxWidth = 1600
                val width = minOf(page.width * scale, maxWidth)
                val height = (page.height * (width.toFloat() / page.width)).toInt().coerceAtLeast(1)
                val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                val canvas = Canvas(bitmap)
                canvas.drawColor(Color.WHITE)
                page.render(bitmap, null, null, android.graphics.pdf.PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                page.close()
                recognizer.process(InputImage.fromBitmap(bitmap, 0))
                    .addOnSuccessListener { visionText ->
                        if (completed) return@addOnSuccessListener
                        pageTexts[index] = visionText.text
                        remaining -= 1
                        if (remaining == 0) {
                            completed = true
                            closeRenderer()
                            result.success(pageTexts.filter { it.isNotBlank() }.joinToString("\n\n"))
                        }
                    }
                    .addOnFailureListener { error ->
                        if (completed) return@addOnFailureListener
                        completed = true
                        closeRenderer()
                        result.error("OCR_PDF_FAILED", error.message, null)
                    }
            }
        } catch (error: Exception) {
            try {
                renderer?.close()
            } catch (_: Exception) {
            }
            try {
                descriptor?.close()
            } catch (_: Exception) {
            }
            result.error("OCR_PDF_FAILED", error.message, null)
        }
    }

    private fun handleAvatarResult(resultCode: Int, data: Intent?) {
        val result = pendingPickAvatarResult ?: return
        pendingPickAvatarResult = null
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            result.success(null)
            return
        }
        try {
            val uri = data.data!!
            val dir = File(filesDir, "profile").apply { mkdirs() }
            val file = File(dir, "avatar-${System.currentTimeMillis()}.jpg")
            contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(file).use { out -> input.copyTo(out) }
            } ?: throw IllegalStateException("Unable to open selected image")
            result.success(file.absolutePath)
        } catch (error: Exception) {
            result.error("AVATAR_IMPORT_FAILED", error.message, null)
        }
    }

    private fun handleDataCardImageResult(resultCode: Int, data: Intent?) {
        val result = pendingPickDataCardImageResult ?: return
        pendingPickDataCardImageResult = null
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            result.success(null)
            return
        }
        try {
            val uri = data.data!!
            val dir = File(filesDir, "data-cards").apply { mkdirs() }
            val file = File(dir, "result-${System.currentTimeMillis()}.jpg")
            contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(file).use { out -> input.copyTo(out) }
            } ?: throw IllegalStateException("Unable to open selected image")
            result.success(file.absolutePath)
        } catch (error: Exception) {
            result.error("DATA_CARD_IMAGE_IMPORT_FAILED", error.message, null)
        }
    }

    private fun pickTextDocument(result: MethodChannel.Result) {
        pickReadableTextDocument(
            result,
            "text/*",
            arrayOf("text/plain", "text/markdown", "text/csv", "application/json")
        )
    }

    private fun pickJsonDocument(result: MethodChannel.Result) {
        pickReadableTextDocument(
            result,
            "application/json",
            arrayOf("application/json", "text/plain")
        )
    }

    private fun pickReadableTextDocument(result: MethodChannel.Result, type: String, mimeTypes: Array<String>) {
        if (pendingPickTextResult != null) {
            result.error("PICK_IN_PROGRESS", "A document picker is already open.", null)
            return
        }
        pendingPickTextResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            this.type = type
            putExtra(Intent.EXTRA_MIME_TYPES, mimeTypes)
        }
        try {
            startActivityForResult(intent, pickTextRequestCode)
        } catch (error: Exception) {
            pendingPickTextResult = null
            result.error("PICK_FAILED", error.message, null)
        }
    }

    private fun createBackupFile(fileName: String, json: String): File {
        val safeName = fileName.replace(Regex("[^A-Za-z0-9._-]"), "-")
        val file = File(cacheDir, safeName.ifBlank { "labbuddy-backup.json" })
        file.writeText(json)
        return file
    }

    private fun shareBackupFile(file: File) {
        val uri = FileProvider.getUriForFile(this, "${packageName}.fileprovider", file)
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "application/json"
            putExtra(Intent.EXTRA_STREAM, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(Intent.createChooser(intent, "Share LabBuddy Backup"))
    }

    private fun scheduleTimerNotification(args: Map<*, *>) {
        val id = args["id"] as? String ?: return
        val runTitle = args["runTitle"] as? String ?: "LabBuddy Timer"
        val stepTitle = args["stepTitle"] as? String ?: "实验步骤"
        val endsAtMs = (args["endsAtMs"] as? Number)?.toLong() ?: return
        if (endsAtMs <= System.currentTimeMillis()) return

        requestNotificationPermissionIfNeeded()

        val intent = Intent(this, TimerAlarmReceiver::class.java).apply {
            putExtra(TimerAlarmReceiver.extraTimerId, id)
            putExtra(TimerAlarmReceiver.extraRunTitle, runTitle)
            putExtra(TimerAlarmReceiver.extraStepTitle, stepTitle)
        }
        val pendingIntent = PendingIntent.getBroadcast(
            this,
            id.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, endsAtMs, pendingIntent)
        } else {
            alarmManager.set(AlarmManager.RTC_WAKEUP, endsAtMs, pendingIntent)
        }
    }

    private fun cancelTimerNotification(id: String) {
        if (id.isBlank()) return
        val intent = Intent(this, TimerAlarmReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            this,
            id.hashCode(),
            intent,
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
        )
        if (pendingIntent != null) {
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarmManager.cancel(pendingIntent)
            pendingIntent.cancel()
        }
    }

    private fun requestNotificationPermissionIfNeeded() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) return
        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 4308)
    }

    private fun createDataCardPng(args: Map<*, *>): File {
        val kind = args["kind"] as? String ?: "dataCard"
        if (kind == "protocol") return createProtocolSharePng(args)

        val title = args["title"] as? String ?: "LabBuddy Data Card"
        val subtitle = args["subtitle"] as? String ?: ""
        val lines = (args["lines"] as? List<*>)?.mapNotNull { it as? String } ?: emptyList()
        val imagePath = args["imagePath"] as? String
        val watermark = args["watermark"] as? Boolean ?: true

        val width = 1080
        val padding = 64
        val lineHeight = 44
        val imageHeight = 520
        val height = 330 + imageHeight + lines.size * lineHeight + if (watermark) 110 else 40
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        canvas.drawColor(Color.WHITE)

        val titlePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.rgb(21, 32, 31)
            textSize = 58f
            isFakeBoldText = true
        }
        val bodyPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.rgb(54, 67, 64)
            textSize = 34f
        }
        val mutedPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.rgb(102, 115, 111)
            textSize = 30f
        }
        val accentPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.rgb(15, 118, 110)
            textSize = 32f
            isFakeBoldText = true
        }
        val rulePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.rgb(224, 231, 228)
            strokeWidth = 2f
        }
        val imageStrokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.rgb(204, 230, 226)
            style = Paint.Style.STROKE
            strokeWidth = 3f
        }
        val placeholderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.rgb(226, 244, 242)
            style = Paint.Style.FILL
        }

        canvas.drawText("LabBuddy", padding.toFloat(), 82f, accentPaint)
        canvas.drawText(title, padding.toFloat(), 158f, titlePaint)
        if (subtitle.isNotBlank()) {
            canvas.drawText(subtitle, padding.toFloat(), 210f, mutedPaint)
        }
        canvas.drawLine(padding.toFloat(), 246f, (width - padding).toFloat(), 246f, rulePaint)

        val imageRect = RectF(
            padding.toFloat(),
            290f,
            (width - padding).toFloat(),
            290f + imageHeight,
        )
        drawDataCardImage(canvas, imageRect, imagePath, placeholderPaint, imageStrokePaint, accentPaint)

        var y = imageRect.bottom + 64f
        for (line in lines) {
            drawWrappedText(canvas, line, padding.toFloat(), y, width - padding * 2, bodyPaint)
            y += lineHeight
        }
        if (watermark) {
            canvas.drawLine(padding.toFloat(), y + 18f, (width - padding).toFloat(), y + 18f, rulePaint)
            canvas.drawText("Local-only preview · no cloud upload", padding.toFloat(), y + 72f, mutedPaint)
        }

        val file = File(cacheDir, "labbuddy-data-card-${System.currentTimeMillis()}.png")
        FileOutputStream(file).use { out ->
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
        }
        bitmap.recycle()
        return file
    }

    private fun createProtocolSharePng(args: Map<*, *>): File {
        val title = args["title"] as? String ?: "Protocol"
        val subtitle = args["subtitle"] as? String ?: ""
        val lines = (args["lines"] as? List<*>)?.mapNotNull { it as? String } ?: emptyList()

        val width = 1080
        val padding = 64
        val lineHeight = 48
        val height = 320 + lines.size * lineHeight + 130
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        canvas.drawColor(Color.WHITE)

        val titlePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.rgb(21, 32, 31)
            textSize = 58f
            isFakeBoldText = true
        }
        val bodyPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.rgb(54, 67, 64)
            textSize = 34f
        }
        val mutedPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.rgb(102, 115, 111)
            textSize = 30f
        }
        val accentPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.rgb(15, 118, 110)
            textSize = 32f
            isFakeBoldText = true
        }
        val rulePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.rgb(224, 231, 228)
            strokeWidth = 2f
        }

        canvas.drawText("LabBuddy Protocol", padding.toFloat(), 82f, accentPaint)
        drawWrappedText(canvas, title, padding.toFloat(), 158f, width - padding * 2, titlePaint)
        if (subtitle.isNotBlank()) {
            canvas.drawText(subtitle, padding.toFloat(), 230f, mutedPaint)
        }
        canvas.drawLine(padding.toFloat(), 266f, (width - padding).toFloat(), 266f, rulePaint)

        var y = 330f
        for (line in lines) {
            drawWrappedText(canvas, line, padding.toFloat(), y, width - padding * 2, bodyPaint)
            y += lineHeight
        }
        canvas.drawLine(padding.toFloat(), y + 18f, (width - padding).toFloat(), y + 18f, rulePaint)
        canvas.drawText("Local Protocol card · verify before bench use", padding.toFloat(), y + 72f, mutedPaint)

        val file = File(cacheDir, "labbuddy-protocol-card-${System.currentTimeMillis()}.png")
        FileOutputStream(file).use { out ->
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
        }
        bitmap.recycle()
        return file
    }

    private fun drawDataCardImage(
        canvas: Canvas,
        rect: RectF,
        imagePath: String?,
        placeholderPaint: Paint,
        strokePaint: Paint,
        accentPaint: Paint
    ) {
        val radius = 24f
        val bitmap = imagePath
            ?.takeIf { it.isNotBlank() }
            ?.let { BitmapFactory.decodeFile(it) }
        val path = Path().apply { addRoundRect(rect, radius, radius, Path.Direction.CW) }
        canvas.save()
        canvas.clipPath(path)
        if (bitmap != null) {
            val scale = maxOf(rect.width() / bitmap.width, rect.height() / bitmap.height)
            val scaledWidth = bitmap.width * scale
            val scaledHeight = bitmap.height * scale
            val left = rect.left + (rect.width() - scaledWidth) / 2f
            val top = rect.top + (rect.height() - scaledHeight) / 2f
            val src = Rect(0, 0, bitmap.width, bitmap.height)
            val dest = RectF(left, top, left + scaledWidth, top + scaledHeight)
            canvas.drawBitmap(bitmap, src, dest, null)
        } else {
            canvas.drawRect(rect, placeholderPaint)
            canvas.drawText("结果图", rect.centerX() - 48f, rect.centerY() + 10f, accentPaint)
        }
        canvas.restore()
        canvas.drawRoundRect(rect, radius, radius, strokePaint)
        bitmap?.recycle()
    }

    private fun drawWrappedText(canvas: Canvas, text: String, x: Float, y: Float, maxWidth: Int, paint: Paint) {
        val bounds = Rect()
        var current = text
        var currentY = y
        while (current.isNotEmpty()) {
            var end = current.length
            while (end > 1) {
                paint.getTextBounds(current, 0, end, bounds)
                if (bounds.width() <= maxWidth) break
                end--
            }
            canvas.drawText(current.substring(0, end), x, currentY, paint)
            current = current.substring(end).trimStart()
            currentY += 42f
        }
    }

    private fun shareImage(file: File) {
        val uri = FileProvider.getUriForFile(this, "${packageName}.fileprovider", file)
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "image/png"
            putExtra(Intent.EXTRA_STREAM, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(Intent.createChooser(intent, "Share LabBuddy Data Card"))
    }

    private fun saveImageToGallery(file: File): Uri {
        val resolver = contentResolver
        val fileName = file.name
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Images.Media.DISPLAY_NAME, fileName)
                put(MediaStore.Images.Media.MIME_TYPE, "image/png")
                put(MediaStore.Images.Media.RELATIVE_PATH, Environment.DIRECTORY_PICTURES + "/LabBuddy")
            }
            val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
                ?: throw IllegalStateException("Unable to create MediaStore entry")
            resolver.openOutputStream(uri)?.use { out ->
                file.inputStream().use { input -> input.copyTo(out) }
            }
            uri
        } else {
            val pictures = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES)
            val targetDir = File(pictures, "LabBuddy").apply { mkdirs() }
            val target = File(targetDir, fileName)
            file.copyTo(target, overwrite = true)
            Uri.fromFile(target)
        }
    }
}
