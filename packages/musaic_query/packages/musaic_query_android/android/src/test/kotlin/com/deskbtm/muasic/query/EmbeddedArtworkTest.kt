package com.deskbtm.muasic.query

import com.deskbtm.muasic.query.queries.helper.EmbeddedArtwork
import java.nio.ByteBuffer
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertNull
import org.junit.Test

class EmbeddedArtworkTest {
    private val cover = ByteArray(5 * 1024 * 1024) { (it % 256).toByte() }

    @Test
    fun readsLargeFrontCoverFromId3v23AndV24() {
        for (version in 3..4) {
            val tag = tag(version)
            assertArrayEquals(cover, EmbeddedArtwork.readLargeId3Picture(tag.inputStream()))
        }
    }

    @Test
    fun ignoresTruncatedAndOverLimitTags() {
        val tag = tag(3)
        assertNull(EmbeddedArtwork.readLargeId3Picture(tag.inputStream(0, tag.size - 1)))
        syncSafe(17 * 1024 * 1024).copyInto(tag, destinationOffset = 6)
        assertNull(EmbeddedArtwork.readLargeId3Picture(tag.inputStream()))
    }

    private fun tag(version: Int): ByteArray {
        val picture = byteArrayOf(0) + "image/png".toByteArray() + byteArrayOf(0, 3, 0) + cover
        val length = if (version == 3) ByteBuffer.allocate(4).putInt(picture.size).array() else
            syncSafe(picture.size)
        val frame = "APIC".toByteArray() + length + byteArrayOf(0, 0) + picture
        return "ID3".toByteArray() + byteArrayOf(version.toByte(), 0, 0) + syncSafe(frame.size) + frame
    }

    private fun syncSafe(size: Int) = ByteArray(4) { index ->
        ((size ushr (21 - index * 7)) and 0x7f).toByte()
    }
}
