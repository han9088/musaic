package com.deskbtm.musaic

import android.content.ContentResolver
import android.content.ContentUris
import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec
import java.io.File
import java.util.UUID

private val isScopedStorage = Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q

private val images
    get() = if (isScopedStorage) {
        MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
    } else {
        MediaStore.Images.Media.EXTERNAL_CONTENT_URI
    }

internal fun registerCoverFlowPhotos(messenger: BinaryMessenger, resolver: ContentResolver) {
    MethodChannel(
        messenger,
        "com.deskbtm.musaic/coverflow_photos",
        StandardMethodCodec.INSTANCE,
        messenger.makeBackgroundTaskQueue(),
    ).setMethodCallHandler { call, result ->
        try {
            when (call.method) {
                "save" -> result.success(savePhoto(resolver, call.arguments as ByteArray))
                "delete" -> {
                    val id = (call.arguments as String).toLong()
                    val uri = ContentUris.withAppendedId(images, id)
                    check(resolver.delete(uri, null, null) == 1)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        } catch (error: Exception) {
            result.error("photoLibrary", error.message, null)
        }
    }
}

private fun savePhoto(resolver: ContentResolver, png: ByteArray): String {
    val filename = "Musaic_${UUID.randomUUID()}.png"
    val values = ContentValues().apply {
        put(MediaStore.Images.Media.DISPLAY_NAME, filename)
        put(MediaStore.Images.Media.MIME_TYPE, "image/png")
        if (isScopedStorage) {
            put(MediaStore.Images.Media.RELATIVE_PATH, Environment.DIRECTORY_PICTURES)
            put(MediaStore.Images.Media.IS_PENDING, 1)
        } else {
            @Suppress("DEPRECATION")
            val directory = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES)
            check(directory.isDirectory || directory.mkdirs())
            put(MediaStore.Images.Media.DATA, File(directory, filename).path)
        }
    }
    val uri = checkNotNull(resolver.insert(images, values))
    try {
        checkNotNull(resolver.openOutputStream(uri)).use { it.write(png) }
        if (isScopedStorage) {
            values.clear()
            values.put(MediaStore.Images.Media.IS_PENDING, 0)
            check(resolver.update(uri, values, null, null) == 1)
        }
        return ContentUris.parseId(uri).toString()
    } catch (error: Exception) {
        runCatching { resolver.delete(uri, null, null) }
        throw error
    }
}
