package com.deskbtm.muasic.query.queries

import android.content.ContentResolver
import android.net.Uri
import com.deskbtm.muasic.query.QueryRequest
import com.deskbtm.muasic.query.queries.helper.QueryHelper
import com.deskbtm.muasic.query.types.checkAudiosUriType
import com.deskbtm.muasic.query.types.sorttypes.checkSongSortType
import com.deskbtm.muasic.query.utils.songProjection
import io.flutter.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

internal class AudioQuery(private val request: QueryRequest) {

    companion object {
        private const val TAG = "AudioQuery"
    }

    // Main parameters
    private val helper = QueryHelper()
    private var selection: String? = null
    private var selectionArgs: Array<String>? = null

    private lateinit var uri: Uri
    private lateinit var sortType: String
    private lateinit var resolver: ContentResolver

    /** Method to "query" all songs. */
    suspend fun querySongs() {
        val call = request.call
        val result = request.result
        val context = request.context
        this.resolver = context.contentResolver

        // Sort: Type and Order.
        sortType =
            checkSongSortType(
                call.argument<Int>("sortType"),
                call.argument<Int>("orderType")!!,
                call.argument<Boolean>("ignoreCase") ?: true,
            )

        // Check uri:
        //   * 0 -> External.
        //   * 1 -> Internal.
        uri = checkAudiosUriType(call.argument<Int>("uri")!!)

        call.argument<String>("path")?.let { path ->
            selection = "${songProjection()[0]} LIKE ? ESCAPE '\\'"
            selectionArgs = arrayOf(folderPattern(path))
        }

        Log.d(TAG, "Query config: ")
        Log.d(TAG, "\tsortType: $sortType")
        Log.d(TAG, "\tselection: $selection")
        Log.d(TAG, "\turi: $uri")

        // Query everything in background for a better performance.
        val queryResult = loadSongs()
        result.success(queryResult)
    }

    // Loading in Background
    private suspend fun loadSongs(): ArrayList<MutableMap<String, Any?>> =
        withContext(Dispatchers.IO) {
            // Setup the cursor with 'uri', 'projection' and 'sortType'.
            val cursor = resolver.query(uri, songProjection(), selection, selectionArgs, sortType)
            cursor.use {
                val songList: ArrayList<MutableMap<String, Any?>> = ArrayList()

                Log.d(TAG, "Cursor count: ${cursor?.count}")

                // For each item(song) inside this "cursor", take one and "format"
                // into a 'Map<String, dynamic>'.
                while (cursor != null && cursor.moveToNext()) {
                    val tempData: MutableMap<String, Any?> = HashMap()

                    for (audioMedia in cursor.columnNames) {
                        tempData[audioMedia] = helper.loadSongItem(audioMedia, cursor)
                    }

                    // Get a extra information from audio, e.g: extension, uri, etc..
                    val tempExtraData = helper.loadSongExtraInfo(uri, tempData)
                    tempData.putAll(tempExtraData)

                    songList.add(tempData)
                }

                return@withContext songList
            }
        }
}

internal fun escapeLike(value: String): String =
    value.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")

internal fun folderPattern(path: String): String = "${escapeLike(path.trimEnd('/'))}/%"
