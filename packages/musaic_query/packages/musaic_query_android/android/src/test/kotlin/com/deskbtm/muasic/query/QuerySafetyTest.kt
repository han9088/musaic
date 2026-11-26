package com.deskbtm.muasic.query

import android.content.ContentProvider
import android.content.ContentValues
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import android.provider.MediaStore
import com.deskbtm.muasic.query.controllers.MethodController
import com.deskbtm.muasic.query.queries.helper.QueryHelper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowContentResolver

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [36])
class QuerySafetyTest {
    @Test
    fun bindsFolderAsDataAndClosesCursor() = runBlocking {
        val provider = MediaProvider()
        ShadowContentResolver.registerProviderInternal("media", provider)
        val result = Reply()
        MethodController(request(result)).find()
        assertEquals("_data LIKE ? ESCAPE '\\'", provider.selection)
        assertArrayEquals(arrayOf("/Music/John's 100\\%/%"), provider.arguments)
        assertTrue(provider.cursor.isClosed)
        assertEquals(1, (result.value as List<*>).size)
    }

    @Test
    fun closesCursorWhenReadingFails() = runBlocking {
        val provider = MediaProvider(failRead = true)
        ShadowContentResolver.registerProviderInternal("media", provider)
        try {
            MethodController(request(Reply())).find()
            fail("Expected a cursor failure")
        } catch (_: IllegalStateException) {
            assertTrue(provider.cursor.isClosed)
        }
    }

    @Test
    fun legacyFolderQueryUsesTheMediaIndexWithDefaultCaseHandling() = runBlocking {
        val provider = MediaProvider()
        ShadowContentResolver.registerProviderInternal("media", provider)
        val result = Reply()
        val request =
            QueryRequest(
                MethodCall(
                    "queryFromFolder",
                    mapOf("path" to "/Music", "sortType" to 0, "orderType" to 0, "uri" to 0),
                ),
                result,
                RuntimeEnvironment.getApplication(),
                false,
            )
        MethodController(request).find()
        assertArrayEquals(arrayOf("/Music/%"), provider.arguments)
        assertEquals(1, (result.value as List<*>).size)
        assertTrue(provider.cursor.isClosed)
    }

    @Test
    fun textFiltersTreatPercentAndUnderscoreAsLiteralCharacters() = runBlocking {
        val provider = MediaProvider()
        ShadowContentResolver.registerProviderInternal("media", provider)
        val result = Reply()
        MethodController(
                QueryRequest(
                    MethodCall(
                        "queryWithFilters",
                        mapOf("withType" to 0, "args" to 0, "argsVal" to "100%_live"),
                    ),
                    result,
                    RuntimeEnvironment.getApplication(),
                    false,
                )
            )
            .find()
        assertEquals("title like ? ESCAPE '\\'", provider.selection)
        assertArrayEquals(arrayOf("%100\\%\\_live%"), provider.arguments)
    }

    @Test
    fun albumNameLookupTreatsWildcardsAsLiteralCharacters() = runBlocking {
        val provider = MediaProvider()
        ShadowContentResolver.registerProviderInternal("media", provider)
        MethodController(audioFromRequest(0, "100%_Live")).find()
        assertEquals("album LIKE ? ESCAPE '\\'", provider.selection)
        assertArrayEquals(arrayOf("100\\%\\_Live"), provider.arguments)
    }

    @Test
    fun numericPlaylistIdDoesNotMatchAnotherPlaylistByName() = runBlocking {
        val provider = MediaProvider(numericPlaylistName = true)
        ShadowContentResolver.registerProviderInternal("media", provider)
        MethodController(audioFromRequest(6, 123L)).find()
        val expected = MediaStore.Audio.Playlists.Members.getContentUri("external", 123L)
        assertEquals(listOf(expected), provider.queriedUris)
    }

    @Test
    fun songMetadataPreservesLargeSizesAndUnknownFlags() {
        val columns = arrayOf("_size", "genre_id", "is_music", "is_alarm", "is_podcast")
        MatrixCursor(columns).use { cursor ->
            val size = 3L * 1024 * 1024 * 1024
            cursor.addRow(arrayOf<Any?>(size, 45L, null, 0, 1))
            assertTrue(cursor.moveToFirst())
            val helper = QueryHelper()
            assertEquals(size, helper.loadSongItem("_size", cursor))
            assertEquals(45L, helper.loadSongItem("genre_id", cursor))
            assertNull(helper.loadSongItem("is_music", cursor))
            assertEquals(false, helper.loadSongItem("is_alarm", cursor))
            assertEquals(true, helper.loadSongItem("is_podcast", cursor))
        }
    }

    private fun audioFromRequest(type: Int, source: Any) =
        QueryRequest(
            MethodCall(
                "queryAudiosFrom",
                mapOf("type" to type, "where" to source, "orderType" to 0, "ignoreCase" to true),
            ),
            Reply(),
            RuntimeEnvironment.getApplication(),
            false,
        )

    private fun request(result: Reply) =
        QueryRequest(
            MethodCall(
                "querySongs",
                mapOf(
                    "path" to "/Music/John's 100%",
                    "orderType" to 0,
                    "uri" to 0,
                    "ignoreCase" to true,
                ),
            ),
            result,
            RuntimeEnvironment.getApplication(),
            false,
        )

    private class Reply : MethodChannel.Result {
        var value: Any? = null

        override fun success(result: Any?) {
            value = result
        }

        override fun error(code: String, message: String?, details: Any?) {
            fail(code)
        }

        override fun notImplemented() {
            fail("not implemented")
        }
    }

    private class MediaProvider(
        failRead: Boolean = false,
        private val numericPlaylistName: Boolean = false,
    ) : ContentProvider() {
        val cursor =
            object : MatrixCursor(arrayOf("_id", "_data", "title")) {
                    override fun getString(column: Int): String? {
                        if (failRead) throw IllegalStateException("Broken cursor")
                        return super.getString(column)
                    }
                }
                .apply { addRow(arrayOf<Any>(1L, "/Music/test.mp3", "Test")) }
        var selection: String? = null
        var arguments: Array<out String>? = null
        val queriedUris = mutableListOf<Uri>()

        override fun query(
            uri: Uri,
            projection: Array<out String>?,
            selection: String?,
            selectionArgs: Array<out String>?,
            sortOrder: String?,
        ): Cursor {
            queriedUris.add(uri)
            if (numericPlaylistName && uri == MediaStore.Audio.Playlists.EXTERNAL_CONTENT_URI) {
                return MatrixCursor(arrayOf("name", "_id")).apply {
                    addRow(arrayOf<Any>("123", 456L))
                }
            }
            this.selection = selection
            arguments = selectionArgs
            return cursor
        }

        override fun onCreate() = true

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
