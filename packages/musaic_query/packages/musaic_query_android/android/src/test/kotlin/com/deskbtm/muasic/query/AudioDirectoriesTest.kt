package com.deskbtm.muasic.query

import android.content.ContentProvider
import android.content.ContentValues
import android.database.Cursor
import android.database.MatrixCursor
import android.graphics.Bitmap
import android.graphics.Color
import android.net.Uri
import android.os.Bundle
import android.provider.DocumentsContract
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import java.nio.ByteBuffer
import java.nio.file.Files
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowContentResolver

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [36])
class AudioDirectoriesTest {
    private class Messenger : BinaryMessenger {
        override fun send(channel: String, message: ByteBuffer?) {}

        override fun send(
            channel: String,
            message: ByteBuffer?,
            callback: BinaryMessenger.BinaryReply?,
        ) {}

        override fun setMessageHandler(
            channel: String,
            handler: BinaryMessenger.BinaryMessageHandler?,
        ) {}
    }

    private fun invoke(
        plugin: AudioDirectories,
        method: String,
        args: Map<String, Any?> = emptyMap(),
    ): Any? {
        val function =
            AudioDirectories::class.java.getDeclaredMethod("handle", MethodCall::class.java)
        function.isAccessible = true
        return function.invoke(plugin, MethodCall(method, args))
    }

    @Test
    fun pagesFilesSkipsSymlinksAndClosesSessions() {
        val directory = Files.createTempDirectory("musaic-audio-test").toFile()
        val plugin = AudioDirectories(RuntimeEnvironment.getApplication(), Messenger())
        try {
            repeat(300) { directory.resolve("track$it.mp3").writeText("audio") }
            Files.createSymbolicLink(directory.resolve("loop").toPath(), directory.toPath())
            val source = invoke(plugin, "openPath", mapOf("path" to directory.path)) as Map<*, *>
            val session =
                invoke(plugin, "open", mapOf("source" to source, "directory" to source["id"]))
            var count = 0
            do {
                val page = invoke(plugin, "next", mapOf("session" to session)) as Map<*, *>
                val entries = page["entries"] as List<*>
                assertTrue(entries.size <= 128)
                count += entries.size
            } while (page["done"] != true)
            assertEquals(300, count)
            invoke(plugin, "close", mapOf("session" to session))
            try {
                invoke(plugin, "next", mapOf("session" to session))
                fail("closed cursor accepted")
            } catch (e: java.lang.reflect.InvocationTargetException) {
                assertTrue(e.cause is IllegalStateException)
            }
        } finally {
            plugin.dispose()
            directory.deleteRecursively()
        }
    }

    @Test
    fun rejectsEscapingSourceAndCacheClearPreservesUserFiles() {
        val directory = Files.createTempDirectory("musaic-audio-test").toFile()
        val file = directory.resolve("cover.jpg").apply { writeText("user artwork") }
        val plugin = AudioDirectories(RuntimeEnvironment.getApplication(), Messenger())
        try {
            val source = invoke(plugin, "openPath", mapOf("path" to directory.path)) as Map<*, *>
            try {
                invoke(
                    plugin,
                    "open",
                    mapOf(
                        "source" to source,
                        "directory" to directory.parentFile.toURI().toString(),
                    ),
                )
                fail("outside source accepted")
            } catch (e: java.lang.reflect.InvocationTargetException) {
                assertTrue(e.cause is IllegalArgumentException)
            }
            val cached =
                java.io.File(
                    RuntimeEnvironment.getApplication().cacheDir,
                    "musaic_query_artwork/test.jpg",
                )
            cached.parentFile!!.mkdirs()
            cached.writeText("cache")
            invoke(plugin, "clearCache")
            assertFalse(cached.exists())
            assertEquals("user artwork", file.readText())
        } finally {
            plugin.dispose()
            directory.deleteRecursively()
        }
    }

    @Test
    fun safUsesDocumentIdentityAndClosesProviderCursor() {
        val provider = Provider()
        ShadowContentResolver.registerProviderInternal("test.documents", provider)
        val plugin = AudioDirectories(RuntimeEnvironment.getApplication(), Messenger())
        try {
            val source =
                mapOf(
                    "id" to "document:test.documents:root",
                    "token" to "content://test.documents/tree/root",
                    "name" to "Root",
                )
            val session =
                invoke(plugin, "open", mapOf("source" to source, "directory" to source["id"]))
            val page = invoke(plugin, "next", mapOf("session" to session)) as Map<*, *>
            val row = (page["entries"] as List<*>).single() as Map<*, *>
            assertEquals("document:test.documents:opaque-id", row["id"])
            assertEquals(false, row["reliable"])
            assertNull(row["modified"])
            assertTrue((row["uri"] as String).startsWith("content://"))
            invoke(plugin, "close", mapOf("session" to session))
            assertTrue(provider.cursor!!.isClosed)
        } finally {
            plugin.dispose()
        }
    }

    @Test
    fun providerErrorsAreNotSuccessfulEmptyDirectories() {
        val provider =
            Provider().apply {
                replyExtras.putString(DocumentsContract.EXTRA_ERROR, "Storage offline")
            }
        ShadowContentResolver.registerProviderInternal("test.documents", provider)
        val plugin = AudioDirectories(RuntimeEnvironment.getApplication(), Messenger())
        val source =
            mapOf(
                "id" to "document:test.documents:root",
                "token" to "content://test.documents/tree/root",
                "name" to "Root",
            )
        try {
            try {
                invoke(plugin, "open", mapOf("source" to source, "directory" to source["id"]))
                fail("provider error accepted as complete directory")
            } catch (e: java.lang.reflect.InvocationTargetException) {
                assertTrue(e.cause?.message?.contains("Storage offline") == true)
            }
            assertTrue(provider.cursor!!.isClosed)
        } finally {
            plugin.dispose()
        }
    }

    @Test
    fun oneMalformedEntryDoesNotDiscardHealthySiblings() {
        val provider = Provider().apply { malformedFirst = true }
        ShadowContentResolver.registerProviderInternal("test.documents", provider)
        val plugin = AudioDirectories(RuntimeEnvironment.getApplication(), Messenger())
        val source =
            mapOf(
                "id" to "document:test.documents:root",
                "token" to "content://test.documents/tree/root",
                "name" to "Root",
            )
        try {
            val session =
                invoke(plugin, "open", mapOf("source" to source, "directory" to source["id"]))
            val page = invoke(plugin, "next", mapOf("session" to session)) as Map<*, *>
            assertEquals(1, (page["entries"] as List<*>).size)
            assertEquals(1, (page["errors"] as List<*>).size)
            assertEquals(true, page["done"])
            invoke(plugin, "close", mapOf("session" to session))
        } finally {
            plugin.dispose()
        }
    }

    @Test
    fun artworkRevalidatesStaleEntriesAndChangesPathAfterClearing() {
        val directory = Files.createTempDirectory("musaic-cover-test").toFile()
        val plugin = AudioDirectories(RuntimeEnvironment.getApplication(), Messenger())
        try {
            val audio = directory.resolve("song.wav").apply { writeText("audio") }
            val cover = directory.resolve("cover.png")
            val bitmap = Bitmap.createBitmap(8, 8, Bitmap.Config.ARGB_8888)
            bitmap.eraseColor(Color.RED)
            cover.outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
            bitmap.recycle()
            val source = invoke(plugin, "openPath", mapOf("path" to directory.path)) as Map<*, *>
            fun entry(file: java.io.File) =
                mapOf(
                    "id" to file.toURI().toString(),
                    "size" to file.length(),
                    "modified" to file.lastModified(),
                    "reliable" to true,
                )
            val args =
                mapOf(
                    "source" to source,
                    "file" to entry(audio),
                    "cover" to entry(cover),
                    "size" to 64,
                )
            val first = invoke(plugin, "artwork", args) as String
            assertEquals(first, invoke(plugin, "artwork", args))
            assertTrue(cover.setLastModified(cover.lastModified() + 5000))
            val changed = invoke(plugin, "artwork", args) as String
            assertNotEquals(first, changed)
            invoke(plugin, "clearCache")
            val cleared = invoke(plugin, "artwork", args) as String
            assertNotEquals(changed, cleared)
            assertTrue(cover.delete())
            assertNull(invoke(plugin, "artwork", args))
        } finally {
            plugin.dispose()
            directory.deleteRecursively()
        }
    }

    @Test
    fun pagesRemainBoundedWhenEveryEntryIsASymlink() {
        val directory = Files.createTempDirectory("musaic-symlink-test").toFile()
        val plugin = AudioDirectories(RuntimeEnvironment.getApplication(), Messenger())
        try {
            repeat(300) {
                Files.createSymbolicLink(directory.resolve("link$it").toPath(), directory.toPath())
            }
            val source = invoke(plugin, "openPath", mapOf("path" to directory.path)) as Map<*, *>
            val session =
                invoke(plugin, "open", mapOf("source" to source, "directory" to source["id"]))
            val page = invoke(plugin, "next", mapOf("session" to session)) as Map<*, *>
            assertTrue((page["entries"] as List<*>).isEmpty())
            assertEquals(false, page["done"])
            invoke(plugin, "close", mapOf("session" to session))
        } finally {
            plugin.dispose()
            directory.deleteRecursively()
        }
    }

    private class Provider : ContentProvider() {
        var cursor: MatrixCursor? = null
        val replyExtras = Bundle()
        var malformedFirst = false

        override fun onCreate() = true

        override fun query(
            uri: Uri,
            projection: Array<out String>?,
            selection: String?,
            selectionArgs: Array<out String>?,
            sortOrder: String?,
        ): Cursor {
            return object : MatrixCursor(projection) {
                    override fun getExtras() = replyExtras
                }
                .also {
                    if (malformedFirst)
                        it.addRow(arrayOf<Any?>("bad", null, "audio/mpeg", 100L, null))
                    it.addRow(arrayOf<Any?>("opaque-id", "Song.mp3", "audio/mpeg", 100L, null))
                    cursor = it
                }
        }

        override fun getType(uri: Uri): String? = null

        override fun insert(uri: Uri, values: ContentValues?): Uri? = null

        override fun delete(uri: Uri, selection: String?, args: Array<out String>?) = 0

        override fun update(
            uri: Uri,
            values: ContentValues?,
            selection: String?,
            args: Array<out String>?,
        ) = 0
    }
}
