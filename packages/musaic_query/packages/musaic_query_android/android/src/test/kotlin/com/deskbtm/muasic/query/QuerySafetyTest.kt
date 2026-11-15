package com.deskbtm.muasic.query

import android.content.ContentProvider
import android.content.ContentValues
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import com.deskbtm.muasic.query.controllers.MethodController
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

    private class MediaProvider(failRead: Boolean = false) : ContentProvider() {
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

        override fun query(
            uri: Uri,
            projection: Array<out String>?,
            selection: String?,
            selectionArgs: Array<out String>?,
            sortOrder: String?,
        ): Cursor {
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
