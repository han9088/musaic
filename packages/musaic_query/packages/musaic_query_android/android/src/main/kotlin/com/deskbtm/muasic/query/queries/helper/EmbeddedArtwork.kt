package com.deskbtm.muasic.query.queries.helper

import android.content.Context
import android.media.MediaMetadataRetriever
import android.net.Uri
import java.io.BufferedInputStream
import java.io.DataInputStream
import java.io.EOFException
import java.io.InputStream
import java.nio.ByteBuffer

internal object EmbeddedArtwork {
    private const val ANDROID_TAG_LIMIT = 3 * 1024 * 1024
    private const val MAX_TAG_SIZE = 16 * 1024 * 1024
    private val largeTagLock = Any()

    fun <T> load(context: Context, uri: Uri, decode: (ByteArray) -> T?): T? {
        val picture = try {
            val retriever = MediaMetadataRetriever()
            try {
                retriever.setDataSource(context, uri)
                retriever.embeddedPicture
            } finally {
                retriever.release()
            }
        } catch (_: Exception) {
            null
        }
        picture?.let(decode)?.let { return it }

        // Limit concurrent large allocations across the library and directory entry points.
        return synchronized(largeTagLock) {
            val fallback = try {
                context.contentResolver.openInputStream(uri)?.use(::readLargeId3Picture)
            } catch (_: Exception) {
                null
            }
            fallback?.let(decode)
        }
    }

    // shortcut: plain ID3v2.3/v2.4 tags up to 16 MiB; use a full tag reader if more variants are needed.
    internal fun readLargeId3Picture(stream: InputStream): ByteArray? {
        val input = DataInputStream(BufferedInputStream(stream))
        return try {
            val header = ByteArray(10)
            input.readFully(header)
            if (String(header, 0, 3, Charsets.US_ASCII) != "ID3") return null
            val version = header[3].toInt()
            if (version !in 3..4 || (header[5].toInt() and 0xc0) != 0) return null
            var remaining = syncSafeSize(header, 6)
            if (remaining !in (ANDROID_TAG_LIMIT + 1)..MAX_TAG_SIZE) return null

            var firstPicture: ByteArray? = null
            while (remaining >= header.size) {
                input.readFully(header)
                val frameId = String(header, 0, 4, Charsets.US_ASCII)
                val frameSize = if (version == 4) syncSafeSize(header, 4) else ByteBuffer.wrap(header, 4, 4).int
                remaining -= header.size
                if (frameSize <= 0 || frameSize > remaining) break
                remaining -= frameSize
                if (frameId != "APIC" || header[9] != 0.toByte()) {
                    if (input.skipBytes(frameSize) != frameSize) return firstPicture
                    continue
                }

                val frame = ByteArray(frameSize)
                input.readFully(frame)
                val start = pictureStart(frame) ?: continue
                if (frame[start.typeOffset] == 3.toByte()) {
                    return frame.copyOfRange(start.dataOffset, frame.size)
                }
                if (firstPicture == null) firstPicture = frame.copyOfRange(start.dataOffset, frame.size)
            }
            firstPicture
        } catch (_: EOFException) {
            null
        }
    }

    private fun syncSafeSize(bytes: ByteArray, offset: Int): Int {
        var size = 0
        for (index in offset until offset + 4) {
            val byte = bytes[index].toInt()
            if (byte < 0) return -1
            size = (size shl 7) or byte
        }
        return size
    }

    private data class PictureStart(val typeOffset: Int, val dataOffset: Int)

    private fun pictureStart(frame: ByteArray): PictureStart? {
        val width = when (frame[0].toInt()) {
            0, 3 -> 1
            1, 2 -> 2
            else -> return null
        }
        var mimeEnd = 1
        while (mimeEnd < frame.size && frame[mimeEnd] != 0.toByte()) mimeEnd++
        if (mimeEnd + 2 >= frame.size) return null
        if (String(frame, 1, mimeEnd - 1, Charsets.US_ASCII) == "-->") return null
        var offset = mimeEnd + 2
        while (offset + width < frame.size) {
            if (frame[offset] == 0.toByte() && (width == 1 || frame[offset + 1] == 0.toByte())) {
                return PictureStart(mimeEnd + 1, offset + width)
            }
            offset += width
        }
        return null
    }
}
