package com.deskbtm.muasic.query.queries

import android.content.ContentResolver
import android.net.Uri
import com.deskbtm.muasic.query.QueryRequest
import com.deskbtm.muasic.query.queries.helper.QueryHelper
import com.deskbtm.muasic.query.types.checkArtistsUriType
import com.deskbtm.muasic.query.types.sorttypes.checkArtistSortType
import com.deskbtm.muasic.query.utils.artistProjection
import io.flutter.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/** OnArtistsQuery */
internal class ArtistQuery(private val request: QueryRequest) {

    companion object {
        private const val TAG = "OnArtistsQuery"
    }

    // Main parameters
    private val helper = QueryHelper()

    // None of this methods can be null.
    private lateinit var uri: Uri
    private lateinit var resolver: ContentResolver
    private lateinit var sortType: String

    /** Method to "query" all artists. */
    suspend fun queryArtists() {
        val call = request.call
        val result = request.result
        val context = request.context
        this.resolver = context.contentResolver

        // Sort: Type and Order
        sortType =
            checkArtistSortType(
                call.argument<Int>("sortType"),
                call.argument<Int>("orderType")!!,
                call.argument<Boolean>("ignoreCase")!!,
            )

        // Check uri:
        //   * 0 -> External.
        //   * 1 -> Internal.
        uri = checkArtistsUriType(call.argument<Int>("uri")!!)

        Log.d(TAG, "Query config: ")
        Log.d(TAG, "\tsortType: $sortType")
        Log.d(TAG, "\turi: $uri")

        // Query everything in background for a better performance.
        val queryResult = loadArtists()
        result.success(queryResult)
    }

    // Loading in Background
    private suspend fun loadArtists(): ArrayList<MutableMap<String, Any?>> =
        withContext(Dispatchers.IO) {
            // Setup the cursor with 'uri', 'projection' and 'sortType'.
            val cursor = resolver.query(uri, artistProjection, null, null, sortType)
            cursor.use {
                val artistList: ArrayList<MutableMap<String, Any?>> = ArrayList()

                Log.d(TAG, "Cursor count: ${cursor?.count}")

                // For each item(artist) inside this "cursor", take one and "format"
                // into a 'Map<String, dynamic>'.
                while (cursor != null && cursor.moveToNext()) {
                    val tempData: MutableMap<String, Any?> = HashMap()

                    for (artistMedia in cursor.columnNames) {
                        tempData[artistMedia] = helper.loadArtistItem(artistMedia, cursor)
                    }

                    artistList.add(tempData)
                }

                for (artist in artistList) {
                    artist["num_of_songs"] = artist["number_of_tracks"]
                }

                return@withContext artistList
            }
        }
}
