package com.deskbtm.muasic.query.queries

import android.content.ContentResolver
import android.net.Uri
import com.deskbtm.muasic.query.QueryRequest
import com.deskbtm.muasic.query.queries.helper.QueryHelper
import com.deskbtm.muasic.query.types.checkPlaylistsUriType
import com.deskbtm.muasic.query.types.sorttypes.checkPlaylistSortType
import com.deskbtm.muasic.query.utils.playlistProjection
import io.flutter.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/** OnPlaylistQuery */
internal class PlaylistQuery(private val request: QueryRequest) {

    companion object {
        private const val TAG = "OnPlaylistQuery"
    }

    // Main parameters
    private val helper = QueryHelper()

    private lateinit var uri: Uri
    private lateinit var resolver: ContentResolver
    private lateinit var sortType: String

    /** Method to "query" all playlists. */
    suspend fun queryPlaylists() {
        val call = request.call
        val result = request.result
        val context = request.context
        this.resolver = context.contentResolver

        // Sort: Type and Order.
        sortType =
            checkPlaylistSortType(
                call.argument<Int>("sortType"),
                call.argument<Int>("orderType")!!,
                call.argument<Boolean>("ignoreCase")!!,
            )
        // Check uri:
        //   * 0 -> External.
        //   * 1 -> Internal.
        uri = checkPlaylistsUriType(call.argument<Int>("uri")!!)

        Log.d(TAG, "Query config: ")
        Log.d(TAG, "\tsortType: $sortType")
        Log.d(TAG, "\turi: $uri")

        // Query everything in background for a better performance.
        val queryResult = loadPlaylists()
        result.success(queryResult)
    }

    // Loading in Background
    private suspend fun loadPlaylists(): ArrayList<MutableMap<String, Any?>> =
        withContext(Dispatchers.IO) {
            // Setup the cursor with 'uri' and 'projection'.
            val cursor = resolver.query(uri, playlistProjection, null, null, sortType)
            cursor.use {
                val playlistList: ArrayList<MutableMap<String, Any?>> = ArrayList()

                Log.d(TAG, "Cursor count: ${cursor?.count}")

                if (cursor == null) {
                    Log.e(TAG, "ERROR: Cursor is null when querying playlists")
                    return@withContext playlistList
                }

                // For each item(playlist) inside this "cursor", take one and "format"
                // into a 'Map<String, dynamic>'.
                while (cursor != null && cursor.moveToNext()) {
                    val playlistData: MutableMap<String, Any?> = HashMap()

                    for (playlistMedia in cursor.columnNames) {
                        playlistData[playlistMedia] = helper.loadPlaylistItem(playlistMedia, cursor)
                    }

                    Log.d(TAG, "Loaded playlist data: $playlistData")

                    // Validate that _id exists and is not null
                    val playlistId = playlistData["_id"]
                    if (playlistId == null) {
                        Log.e(TAG, "ERROR: Playlist ID is null! Playlist data: $playlistData")
                        Log.e(TAG, "Available columns: ${cursor.columnNames.joinToString(", ")}")
                        continue
                    }

                    Log.d(
                        TAG,
                        "Playlist ID = $playlistId, type = ${playlistId.javaClass.simpleName}",
                    )

                    // Count and add the number of songs for every playlist.
                    val mediaCount = helper.getMediaCount(1, playlistId.toString(), resolver)
                    playlistData["num_of_songs"] = mediaCount

                    Log.d(TAG, "Playlist ${playlistData["_id"]} has $mediaCount songs")

                    playlistList.add(playlistData)
                }

                return@withContext playlistList
            }
        }
}
