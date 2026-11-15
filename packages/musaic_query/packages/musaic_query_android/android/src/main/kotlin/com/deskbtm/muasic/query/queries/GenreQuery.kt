package com.deskbtm.muasic.query.queries

import android.content.ContentResolver
import android.net.Uri
import com.deskbtm.muasic.query.QueryRequest
import com.deskbtm.muasic.query.queries.helper.QueryHelper
import com.deskbtm.muasic.query.types.checkGenresUriType
import com.deskbtm.muasic.query.types.sorttypes.checkGenreSortType
import com.deskbtm.muasic.query.utils.genreProjection
import io.flutter.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/** OnGenresQuery */
internal class GenreQuery(private val request: QueryRequest) {

    companion object {
        private const val TAG = "OnGenresQuery"
    }

    // Main parameters.
    private val helper = QueryHelper()

    private lateinit var uri: Uri
    private lateinit var sortType: String
    private lateinit var resolver: ContentResolver

    /** Method to "query" all genres. */
    suspend fun queryGenres() {
        val call = request.call
        val result = request.result
        val context = request.context
        this.resolver = context.contentResolver

        // Sort: Type and Order.
        sortType =
            checkGenreSortType(
                call.argument<Int>("sortType"),
                call.argument<Int>("orderType")!!,
                call.argument<Boolean>("ignoreCase")!!,
            )

        // Check uri:
        //   * 0 -> External
        //   * 1 -> Internal
        uri = checkGenresUriType(call.argument<Int>("uri")!!)

        Log.d(TAG, "Query config: ")
        Log.d(TAG, "\tsortType: $sortType")
        Log.d(TAG, "\turi: $uri")

        // Query everything in background for a better performance.
        val queryResult = loadGenres()
        result.success(queryResult)
    }

    // Loading in Background
    private suspend fun loadGenres(): ArrayList<MutableMap<String, Any?>> =
        withContext(Dispatchers.IO) {
            // Setup the cursor with 'uri', 'projection' and 'sortType'.
            val cursor = resolver.query(uri, genreProjection, null, null, sortType)
            cursor.use {
                val genreList: ArrayList<MutableMap<String, Any?>> = ArrayList()

                Log.d(TAG, "Cursor count: ${cursor?.count}")

                // For each item(genre) inside this "cursor", take one and "format"
                // into a 'Map<String, dynamic>'.
                while (cursor != null && cursor.moveToNext()) {
                    val genreData: MutableMap<String, Any?> = HashMap()

                    for (genreMedia in cursor.columnNames) {
                        genreData[genreMedia] = helper.loadGenreItem(genreMedia, cursor)
                    }

                    // Count and add the number of songs for every genre.
                    val mediaCount = helper.getMediaCount(0, genreData["_id"].toString(), resolver)
                    genreData["num_of_songs"] = mediaCount

                    if (genreData["name"] != null && genreData["_id"] != 0) {
                        genreList.add(genreData)
                    }
                }

                return@withContext genreList
            }
        }
}
