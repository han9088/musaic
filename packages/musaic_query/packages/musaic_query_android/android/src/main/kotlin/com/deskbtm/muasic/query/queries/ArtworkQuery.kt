package com.deskbtm.muasic.query.queries

import android.content.ContentResolver
import android.content.ContentUris
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.util.Size
import com.deskbtm.muasic.query.QueryRequest
import com.deskbtm.muasic.query.queries.helper.EmbeddedArtwork
import com.deskbtm.muasic.query.queries.helper.QueryHelper
import com.deskbtm.muasic.query.types.checkArtworkFormat
import com.deskbtm.muasic.query.types.checkArtworkType
import io.flutter.Log
import java.io.ByteArrayOutputStream
import java.io.FileInputStream
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

internal class ArtworkQuery(private val request: QueryRequest) {

    companion object {
        private const val TAG = "OnArtworksQuery"
    }

    private val helper = QueryHelper()
    private var type: Int = -1
    private var id: Number = 0
    private var quality: Int = 100
    private var size: Int = 200
    private var showDetailedLog: Boolean = false

    private lateinit var uri: Uri
    private lateinit var resolver: ContentResolver
    private lateinit var format: Bitmap.CompressFormat

    /** Method to "query" artwork. */
    suspend fun queryArtwork() {
        val call = request.call
        val result = request.result
        val context = request.context
        this.resolver = context.contentResolver
        this.showDetailedLog = request.showDetailedLog

        id = call.argument<Number>("id")!!

        // If the 'size' is null, will be '200'.
        size = call.argument<Int>("size")!!

        // The 'quality' value cannot be greater than 100 so, we check and if is, set to '50'.
        quality = call.argument<Int>("quality")!!
        require(quality in 0..100) { "quality must be between 0 and 100" }
        require(size in 1..4096) { "size must be between 1 and 4096" }

        // Check format:
        //   * 0 -> JPEG
        //   * 1 -> PNG
        format = checkArtworkFormat(call.argument<Int>("format")!!)

        // Check uri:
        //   * 0 -> Song.
        //   * 1 -> Album.
        //   * 2 -> Playlist.
        //   * 3 -> Artist.
        //   * 4 -> Genre.
        uri = checkArtworkType(call.argument<Int>("type")!!)

        // This query is 'universal' will work for multiple types (audio, album, artist, etc...).
        type = call.argument<Int>("type")!!

        Log.d(TAG, "Query config: ")
        Log.d(TAG, "\tid: $id")
        Log.d(TAG, "\tquality: $quality")
        Log.d(TAG, "\tformat: $format")
        Log.d(TAG, "\turi: $uri")
        Log.d(TAG, "\ttype: $type")

        // Query everything in background for a better performance.
        var resultArtList = loadArt()

        // Sometimes android will extract a 'wrong' or 'empty' artwork. Just set as null.
        if (resultArtList != null && resultArtList.isEmpty()) {
            Log.i(TAG, "Artwork for '$id' is empty. Returning null")
            resultArtList = null
        }

        result.success(resultArtList)
    }

    // Loading in Background
    private suspend fun loadArt(): ByteArray? =
        withContext(Dispatchers.IO) {
            var artData: ByteArray? = null

            if (type == 0) {
                val trackUri = ContentUris.withAppendedId(uri, id.toLong())
                val embedded = EmbeddedArtwork.load(request.context, trackUri) {
                    convertOrResize(byteArray = it)
                }
                if (embedded != null) return@withContext embedded
            }
            if (Build.VERSION.SDK_INT >= 29) {
                try {
                    // If 'type' is 2, 3 or 4, Get the first item from playlist or artist.
                    // Use the first artist song to 'simulate' the artwork.
                    //
                    // Type:
                    //   * 2 -> Playlist.
                    //   * 3 -> Artist.
                    //   * 4 -> Genre.
                    //
                    // OBS: The 'id' is defined as 'Number'. Convert to 'Long'
                    val query =
                        if (type == 2 || type == 3 || type == 4) {
                            val item =
                                helper.loadFirstItem(type, id, resolver) ?: return@withContext null
                            ContentUris.withAppendedId(uri, item.toLong())
                        } else {
                            ContentUris.withAppendedId(uri, id.toLong())
                        }

                    val bitmap = resolver.loadThumbnail(query, Size(size, size), null)
                    artData = convertOrResize(bitmap = bitmap)
                } catch (e: Exception) {
                    // This may produce a lot of logging on console so, will required a explicit
                    // request
                    // to show the errors.
                    if (showDetailedLog) Log.w(TAG, "($id) Message: $e")
                }
            } else {
                // If 'uri == Audio':
                //   * Load the first 'item' from cursor using the 'id' as filter.
                // else:
                //   * Load the first 'item' from 'album' using the 'id' as filter.
                //
                // If 'item' return null, no song/album has found, return null.
                val item = helper.loadFirstItem(type, id, resolver) ?: return@withContext null

                try {
                    FileInputStream(item).use { file ->
                        val metadata = MediaMetadataRetriever()
                        try {
                            metadata.setDataSource(file.fd)
                            artData =
                                metadata.embeddedPicture?.let { convertOrResize(byteArray = it) }
                        } finally {
                            metadata.release()
                        }
                    }
                } catch (e: Exception) {
                    if (showDetailedLog) Log.w(TAG, "($id) Message: $e")
                }
            }

            return@withContext artData
        }

    //
    private fun convertOrResize(bitmap: Bitmap? = null, byteArray: ByteArray? = null): ByteArray? {
        val source =
            bitmap
                ?: byteArray?.let { bytes ->
                    val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                    BitmapFactory.decodeByteArray(bytes, 0, bytes.size, options)
                    options.inSampleSize = 1
                    while (
                        options.outWidth / options.inSampleSize > size * 2 ||
                            options.outHeight / options.inSampleSize > size * 2
                    ) {
                        options.inSampleSize *= 2
                    }
                    options.inJustDecodeBounds = false
                    BitmapFactory.decodeByteArray(bytes, 0, bytes.size, options)
                }
                ?: return null
        var scaled = source
        try {
            val ratio = minOf(1.0, size.toDouble() / maxOf(source.width, source.height))
            if (ratio < 1) {
                scaled =
                    Bitmap.createScaledBitmap(
                        source,
                        maxOf(1, (source.width * ratio).toInt()),
                        maxOf(1, (source.height * ratio).toInt()),
                        true,
                    )
            }
            return ByteArrayOutputStream().use { output ->
                if (scaled.compress(format, quality, output)) output.toByteArray() else null
            }
        } finally {
            if (scaled !== source) scaled.recycle()
            source.recycle()
        }
    }
}
