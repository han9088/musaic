package com.deskbtm.muasic.query

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract as Documents
import android.provider.MediaStore
import com.deskbtm.muasic.query.queries.helper.EmbeddedArtwork
import io.flutter.plugin.common.*
import java.io.File
import java.security.MessageDigest
import java.util.UUID
import java.util.concurrent.Executors

/** Separate from MediaStore permissions: a tree grant grants only that tree. */
internal class AudioDirectories(private val context: Context, messenger: BinaryMessenger) :
    PluginRegistry.ActivityResultListener {
    private val channel = MethodChannel(messenger, "com.deskbtm.muasic.query/directories")
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val sessions = mutableMapOf<String, Pair<Iterator<Map<String, Any?>>, AutoCloseable?>>()
    private var cacheGeneration = 0L
    private val cache = File(context.cacheDir, "musaic_query_artwork")
    var activity: Activity? = null
    private var picker: MethodChannel.Result? = null
    @Volatile private var detached = false
    private val pending = mutableSetOf<MethodChannel.Result>()

    init {
        channel.setMethodCallHandler { call, callback ->
            val result =
                object : MethodChannel.Result {
                    private val delivered = java.util.concurrent.atomic.AtomicBoolean()

                    private fun finish(reply: () -> Unit) {
                        if (!delivered.compareAndSet(false, true)) return
                        pending.remove(this)
                        reply()
                    }

                    override fun success(value: Any?) = finish { callback.success(value) }

                    override fun error(code: String, message: String?, details: Any?) = finish {
                        callback.error(code, message, details)
                    }

                    override fun notImplemented() = finish { callback.notImplemented() }
                }
            pending.add(result)
            if (call.method == "supported") result.success(true)
            else if (call.method == "pick") pick(result)
            else
                worker.execute {
                    try {
                        val value = handle(call)
                        main.post { result.success(value) }
                    } catch (e: Exception) {
                        main.post {
                            result.error(
                                when (e) {
                                    is SecurityException -> "permissionDenied"
                                    is java.io.FileNotFoundException -> "notFound"
                                    is IllegalArgumentException -> "invalidArgument"
                                    else -> "directoryError"
                                },
                                e.message,
                                null,
                            )
                        }
                    }
                }
        }
    }

    private fun pick(result: MethodChannel.Result) {
        val host = activity
        if (picker != null) {
            result.error("busy", "Directory picker already open", null)
            return
        }
        if (host == null) {
            result.error("unavailable", "No foreground activity", null)
            return
        }
        picker = result
        try {
            host.startActivityForResult(
                Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
                    .addFlags(
                        Intent.FLAG_GRANT_READ_URI_PERMISSION or
                            Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or
                            Intent.FLAG_GRANT_PREFIX_URI_PERMISSION
                    ),
                47261,
            )
        } catch (e: Exception) {
            picker = null
            result.error("pickerFailed", e.message, null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != 47261) return false
        val reply = picker ?: return true
        picker = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            reply.success(null)
            return true
        }
        try {
            context.contentResolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION,
            )
            reply.success(
                mapOf(
                    "id" to documentKey(uri.authority!!, Documents.getTreeDocumentId(uri)),
                    "name" to Documents.getTreeDocumentId(uri).substringAfterLast('/'),
                    "token" to uri.toString(),
                )
            )
        } catch (e: Exception) {
            reply.error("permissionDenied", e.message, null)
        }
        return true
    }

    fun detachActivity(cancelPicker: Boolean = true) {
        activity = null
        if (!cancelPicker) return
        picker?.error("cancelled", "Activity detached", null)
        picker = null
    }

    fun dispose() {
        detached = true
        channel.setMethodCallHandler(null)
        detachActivity()
        pending.toList().forEach { it.error("detached", "Plugin detached", null) }
        worker.execute {
            sessions.values.forEach { (_, resource) -> runCatching { resource?.close() } }
            sessions.clear()
        }
        worker.shutdown()
    }

    private fun documentKey(authority: String, id: String) = "document:$authority:$id"

    private fun source(call: MethodCall) =
        call.argument<Map<String, Any?>>("source") ?: error("Missing source")

    private fun uriFor(source: Map<String, Any?>, id: String): Uri {
        val root = Uri.parse(source["token"] as String)
        if (root.scheme == "file") {
            val base = File(root.path!!).canonicalFile
            val child = File(Uri.parse(id).path ?: error("Invalid file URI")).canonicalFile
            require(
                child == base ||
                    child.path.startsWith(base.path.trimEnd(File.separatorChar) + File.separator)
            ) {
                "Resource outside source"
            }
            return Uri.fromFile(child)
        }
        val prefix = "document:${root.authority}:"
        require(id.startsWith(prefix)) { "Invalid document identity" }
        return Documents.buildDocumentUriUsingTree(root, id.removePrefix(prefix))
    }

    private fun handle(call: MethodCall): Any? {
        check(!detached) { "Plugin detached" }
        when (call.method) {
            "mediaPaths" -> return mediaPaths(call.argument<List<String>>("uris").orEmpty())
            "openPath" -> {
                val file =
                    File(call.argument<String>("path") ?: error("Missing path")).canonicalFile
                if (!file.exists()) throw java.io.FileNotFoundException(file.path)
                require(file.isDirectory) { "Not a directory" }
                if (!file.canRead()) throw SecurityException("Directory is not readable")
                return mapOf(
                    "id" to file.toURI().toString(),
                    "name" to file.name,
                    "token" to file.toURI().toString(),
                )
            }
            "restore" -> {
                val source = source(call)
                val session = open(source, source["id"] as String)
                session.second?.close()
                return source
            }
            "release" -> {
                val root = Uri.parse(source(call)["token"] as String)
                if (root.scheme == "content")
                    context.contentResolver.releasePersistableUriPermission(
                        root,
                        Intent.FLAG_GRANT_READ_URI_PERMISSION,
                    )
                return null
            }
            "open" -> {
                require(sessions.size < 16) { "Too many open enumerators" }
                val id = UUID.randomUUID().toString()
                sessions[id] =
                    open(
                        source(call),
                        call.argument<String>("directory") ?: error("Missing directory"),
                    )
                return id
            }
            "next" -> {
                val session =
                    sessions[call.argument<String>("session")] ?: error("Enumerator closed")
                val rows = mutableListOf<Map<String, Any?>>()
                val errors = mutableListOf<String>()
                var visited = 0
                while (visited++ < 128 && session.first.hasNext()) {
                    try {
                        val row = session.first.next()
                        if (row.isNotEmpty()) rows.add(row)
                    } catch (e: Exception) {
                        errors.add(e.message ?: "Cannot read entry")
                    }
                }
                return mapOf(
                    "entries" to rows,
                    "done" to !session.first.hasNext(),
                    "errors" to errors,
                )
            }
            "close" -> {
                sessions.remove(call.argument<String>("session"))?.second?.close()
                return null
            }
            "openPlayback" -> {
                val file = call.argument<Map<String, Any?>>("file") ?: error("Missing file")
                val uri = uriFor(source(call), file["id"] as String)
                // The player opens the content descriptor using the persisted tree grant.
                return mapOf("uri" to uri.toString())
            }
            "metadata",
            "artwork" -> {
                val source = source(call)
                val entry = call.argument<Map<String, Any?>>("file") ?: error("Missing file")
                val uri = uriFor(source, entry["id"] as String)
                if (call.method == "metadata") return metadata(uri)
                return artwork(
                    source,
                    entry,
                    call.argument<Map<String, Any?>>("cover"),
                    call.argument<Int>("size") ?: 512,
                )
            }
            "clearCache" -> {
                cacheGeneration++
                cache.listFiles()?.forEach { check(it.delete()) { "Cannot remove cache file" } }
                return null
            }
            else -> error("Unsupported directory operation")
        }
    }

    private fun mediaPaths(uris: List<String>): Map<String, String> {
        val sdk = android.os.Build.VERSION.SDK_INT
        if (sdk < 29) return emptyMap()
        val resolver = context.contentResolver
        return buildMap {
            for (value in uris) {
                val uri = Uri.parse(value)
                when (uri.authority) {
                    "com.android.externalstorage.documents" -> Unit
                    "com.android.providers.media.documents" -> if (sdk < 31) continue
                    else -> continue
                }
                try {
                    val media = MediaStore.getMediaUri(context, uri) ?: continue
                    resolver.query(media, arrayOf(MediaStore.MediaColumns.DATA), null, null, null)
                        ?.use { cursor ->
                            if (cursor.moveToFirst() && !cursor.isNull(0)) {
                                put(value, cursor.getString(0))
                            }
                        }
                } catch (_: Exception) {
                    // Keep both entries if the provider cannot confirm the identity.
                }
            }
        }
    }

    private fun open(
        source: Map<String, Any?>,
        id: String,
    ): Pair<Iterator<Map<String, Any?>>, AutoCloseable?> {
        val uri = uriFor(source, id)
        if (uri.scheme == "file") {
            val folder = File(uri.path!!)
            if (!folder.exists()) throw java.io.FileNotFoundException(folder.path)
            require(folder.isDirectory) { "Not a directory" }
            if (!folder.canRead()) throw SecurityException("Directory is not readable")
            if (android.os.Build.VERSION.SDK_INT < 26) {
                // shortcut: pre-26 File API materializes one directory; API 26+ uses
                // DirectoryStream.
                val children = folder.listFiles() ?: error("Directory unavailable")
                val iterator =
                    children
                        .asSequence()
                        .map { f ->
                            if (f.canonicalFile != f.absoluteFile)
                                return@map emptyMap<String, Any?>()
                            mapOf<String, Any?>(
                                "id" to f.toURI().toString(),
                                "uri" to f.toURI().toString(),
                                "parent" to id,
                                "reliable" to true,
                                "name" to f.name,
                                "directory" to f.isDirectory,
                                "size" to if (f.isDirectory) null else f.length(),
                                "modified" to f.lastModified().takeIf { it > 0 },
                            )
                        }
                        .iterator()
                return iterator to null
            }
            // DirectoryStream avoids allocating all children for a large folder.
            val stream = java.nio.file.Files.newDirectoryStream(folder.toPath())
            val iterator =
                stream
                    .iterator()
                    .asSequence()
                    .map { path ->
                        if (java.nio.file.Files.isSymbolicLink(path))
                            return@map emptyMap<String, Any?>()
                        val f = path.toFile()
                        val attr =
                            java.nio.file.Files.readAttributes(
                                path,
                                java.nio.file.attribute.BasicFileAttributes::class.java,
                            )
                        mapOf<String, Any?>(
                            "id" to f.toURI().toString(),
                            "uri" to f.toURI().toString(),
                            "parent" to id,
                            "reliable" to true,
                            "name" to f.name,
                            "directory" to attr.isDirectory,
                            "size" to if (attr.isDirectory) null else attr.size(),
                            "modified" to attr.lastModifiedTime().toMillis().takeIf { it > 0 },
                        )
                    }
                    .iterator()
            return iterator to stream
        }
        val root = Uri.parse(source["token"] as String)
        val docId = Documents.getDocumentId(uri)
        val children = Documents.buildChildDocumentsUriUsingTree(root, docId)
        val projection =
            arrayOf(
                Documents.Document.COLUMN_DOCUMENT_ID,
                Documents.Document.COLUMN_DISPLAY_NAME,
                Documents.Document.COLUMN_MIME_TYPE,
                Documents.Document.COLUMN_SIZE,
                Documents.Document.COLUMN_LAST_MODIFIED,
            )
        val cursor =
            context.contentResolver.query(children, projection, null, null, null)
                ?: error("Provider returned no cursor")
        fun checkProvider() {
            val extras = cursor.extras
            check(!extras.getBoolean(Documents.EXTRA_LOADING, false)) {
                "Provider is still loading; retry scan"
            }
            val error = extras.getString(Documents.EXTRA_ERROR)
            check(error.isNullOrBlank()) { error ?: "Provider failed" }
        }
        try {
            checkProvider()
        } catch (e: Exception) {
            cursor.close()
            throw e
        }
        val iterator =
            object : Iterator<Map<String, Any?>> {
                var ready = false
                var available = false

                override fun hasNext(): Boolean {
                    if (!ready) {
                        available = cursor.moveToNext()
                        if (!available) checkProvider()
                        ready = true
                    }
                    return available
                }

                override fun next(): Map<String, Any?> {
                    check(hasNext())
                    ready = false
                    val key = requireNotNull(cursor.getString(0)) { "Missing document ID" }
                    val name = requireNotNull(cursor.getString(1)) { "Missing document name" }
                    return mapOf(
                        "id" to documentKey(root.authority!!, key),
                        "uri" to Documents.buildDocumentUriUsingTree(root, key).toString(),
                        "parent" to id,
                        "reliable" to (root.authority == "com.android.externalstorage.documents"),
                        "name" to name,
                        "directory" to (cursor.getString(2) == Documents.Document.MIME_TYPE_DIR),
                        "size" to
                            if (cursor.isNull(3)) null else cursor.getLong(3).takeIf { it >= 0 },
                        "modified" to
                            if (cursor.isNull(4)) null else cursor.getLong(4).takeIf { it > 0 },
                    )
                }
            }
        return iterator to AutoCloseable { cursor.close() }
    }

    private fun fingerprint(uri: Uri): List<Long?> {
        if (uri.scheme == "file") {
            val file = File(uri.path!!)
            if (!file.isFile) throw java.io.FileNotFoundException(file.path)
            return listOf(file.length(), file.lastModified())
        }
        val columns =
            arrayOf(Documents.Document.COLUMN_SIZE, Documents.Document.COLUMN_LAST_MODIFIED)
        return context.contentResolver.query(uri, columns, null, null, null)?.use { cursor ->
            if (!cursor.moveToFirst()) throw java.io.FileNotFoundException(uri.toString())
            columns.indices.map { if (cursor.isNull(it)) null else cursor.getLong(it) }
        } ?: error("File unavailable")
    }

    private fun metadata(uri: Uri): Map<String, Any?> {
        val stamp = fingerprint(uri)
        val reader = MediaMetadataRetriever()
        try {
            reader.setDataSource(context, uri)
            fun tag(key: Int) = reader.extractMetadata(key)?.takeIf { it.isNotBlank() }
            val result =
                mapOf(
                    "title" to tag(7),
                    "artist" to tag(2),
                    "album" to tag(1),
                    "albumArtist" to tag(13),
                    "track" to tag(0),
                    "disc" to tag(14),
                    "genre" to tag(6),
                    "durationMs" to tag(9)?.toLongOrNull(),
                    "mimeType" to tag(12),
                )
            check(stamp == fingerprint(uri)) { "File changed while reading metadata" }
            return result
        } finally {
            reader.release()
        }
    }

    private fun imageBounds(bytes: ByteArray): BitmapFactory.Options? {
        if (bytes.size > 32 * 1024 * 1024) return null
        val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, options)
        return options.takeIf { it.outWidth > 0 && it.outHeight > 0 }
    }

    private fun artwork(
        source: Map<String, Any?>,
        entry: Map<String, Any?>,
        cover: Map<String, Any?>?,
        size: Int,
    ): String? {
        require(size in 1..4096)
        val uri = uriFor(source, entry["id"] as String)
        // Check authorization even on cache hits.
        context.contentResolver.openAssetFileDescriptor(uri, "r")?.use {}
            ?: error("File unavailable")
        val stamp = fingerprint(uri)
        val coverStamp =
            cover?.let {
                try {
                    fingerprint(uriFor(source, it["id"] as String))
                } catch (_: Exception) {
                    null
                }
            }
        val availableCover = cover?.takeIf { coverStamp != null }
        cache.mkdirs()
        val key =
            listOf(
                    "id3-artwork-v1",
                    cacheGeneration,
                    entry["id"],
                    stamp[0],
                    stamp[1],
                    availableCover?.get("id"),
                    coverStamp?.get(0),
                    coverStamp?.get(1),
                    size,
                )
                .joinToString("\u0000")
        val digest =
            MessageDigest.getInstance("SHA-256").digest(key.toByteArray()).joinToString("") {
                "%02x".format(it)
            }
        val reliable =
            entry["reliable"] == true &&
                stamp.all { it != null && it >= 0 } &&
                stamp[1] != 0L &&
                (availableCover == null ||
                    availableCover["reliable"] == true &&
                        coverStamp?.all { it != null && it >= 0 } == true &&
                        coverStamp?.get(1) != 0L)
        val target =
            File(cache, if (reliable) "$digest.jpg" else "$digest-${UUID.randomUUID()}.jpg")
        if (reliable && target.isFile) {
            target.setLastModified(System.currentTimeMillis())
            return target.toURI().toString()
        }
        fun decode(bytes: ByteArray): Bitmap? {
            val options = imageBounds(bytes) ?: return null
            options.inSampleSize = 1
            while (maxOf(options.outWidth, options.outHeight) / options.inSampleSize > size) options
                .inSampleSize *= 2
            options.inJustDecodeBounds = false
            return BitmapFactory.decodeByteArray(bytes, 0, bytes.size, options)
        }
        val bitmap =
            EmbeddedArtwork.load(context, uri, ::decode)
                ?: availableCover
                    ?.let {
                        val coverUri = uriFor(source, it["id"] as String)
                        context.contentResolver.openInputStream(coverUri)?.use { input ->
                            val output = java.io.ByteArrayOutputStream()
                            val block = ByteArray(8192)
                            while (true) {
                                val n = input.read(block)
                                if (n < 0) break
                                require(output.size() + n <= 32 * 1024 * 1024) { "Cover too large" }
                                output.write(block, 0, n)
                            }
                            output.toByteArray()
                        }
                    }
                    ?.let { decode(it) }
                ?: return null
        val scale = minOf(1.0, size.toDouble() / maxOf(bitmap.width, bitmap.height))
        val resized =
            if (scale < 1)
                Bitmap.createScaledBitmap(
                    bitmap,
                    maxOf(1, (bitmap.width * scale).toInt()),
                    maxOf(1, (bitmap.height * scale).toInt()),
                    true,
                )
            else bitmap
        val temp = File(cache, "$digest.tmp")
        try {
            check(stamp == fingerprint(uri)) { "Audio changed while reading artwork" }
            if (availableCover != null) {
                check(coverStamp == fingerprint(uriFor(source, availableCover["id"] as String))) {
                    "Cover changed while reading artwork"
                }
            }
            temp.outputStream().use { check(resized.compress(Bitmap.CompressFormat.JPEG, 85, it)) }
            check(temp.renameTo(target)) { "Cache write failed" }
        } finally {
            temp.delete()
            if (resized !== bitmap) resized.recycle()
            bitmap.recycle()
        }
        val files =
            cache
                .listFiles()
                ?.sortedWith(
                    compareByDescending<File> { it == target }
                        .thenByDescending { it.lastModified() }
                ) ?: emptyList()
        var total = 0L
        files.forEachIndexed { index, file ->
            total += file.length()
            if (index >= 512 || total > 64L * 1024 * 1024) {
                check(file.delete()) { "Cannot evict artwork cache file" }
            }
        }
        return target.toURI().toString()
    }
}
