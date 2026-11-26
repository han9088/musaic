package com.deskbtm.apple_music_kit

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.util.concurrent.Executors

/** Apple REST requests run off the UI thread. Tokens never leave native memory. */
class AppleMusicApi(private val developer: () -> String?, private val user: () -> String?, private val storefront: () -> String?) {
    internal companion object {
        fun httpErrorCode(status: Int): String = when (status) {
            401 -> "authenticationFailed"
            403 -> "authorizationDenied"
            404 -> "resourceNotFound"
            408 -> "requestTimeout"
            409, 410 -> "resourceUnavailable"
            429 -> "rateLimited"
            in 500..599 -> "networkError"
            else -> "unknown"
        }
    }

    private val executor = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private class ApiError(val code: String) : Exception(code)
    private fun segment(value: String): String {
        require(value.isNotBlank() && !value.contains('/') && value != "." && value != "..")
        return URLEncoder.encode(value, "UTF-8")
    }
    private fun request(path: String, query: Map<String, Any?> = emptyMap(), body: JSONObject? = null, post: Boolean = false): JSONObject {
        if (path.startsWith("v1/me/") && user().isNullOrEmpty()) throw ApiError("authorizationDenied")
        val suffix = query.filterValues { it != null }.entries.joinToString("&") { (key, value) ->
            URLEncoder.encode(key, "UTF-8") + "=" + URLEncoder.encode(value.toString(), "UTF-8")
        }
        val connection = URL("https://api.music.apple.com/$path${if (suffix.isEmpty()) "" else "?$suffix"}").openConnection() as HttpURLConnection
        try {
            connection.connectTimeout = 15000; connection.readTimeout = 15000
            connection.instanceFollowRedirects = false
            connection.setRequestProperty("Authorization", "Bearer ${developer() ?: throw ApiError("developerTokenMissing")}")
            user()?.let { connection.setRequestProperty("Music-User-Token", it) }
            if (post) connection.requestMethod = "POST"
            if (body != null) {
                connection.doOutput = true
                connection.setRequestProperty("Content-Type", "application/json")
                connection.outputStream.use { it.write(body.toString().toByteArray(Charsets.UTF_8)) }
            }
            val status = connection.responseCode
            if (status !in 200..299) throw ApiError(httpErrorCode(status))
            val text = connection.inputStream.bufferedReader().use { it.readText() }
            return if (text.isBlank()) JSONObject() else JSONObject(text)
        } finally { connection.disconnect() }
    }
    private fun first(json: JSONObject): JSONObject = json.optJSONArray("data")?.optJSONObject(0) ?: throw ApiError("resourceNotFound")
    private fun convert(value: Any?): Any? = when(value) {
        null, JSONObject.NULL -> null
        is JSONObject -> value.keys().asSequence().associateWith { convert(value.opt(it)) }
        is JSONArray -> (0 until value.length()).map { convert(value.opt(it)) }
        else -> value
    }
    fun handle(call: MethodCall, result: MethodChannel.Result) {
        executor.execute {
            try {
                val answer = execute(call)
                main.post { result.success(convert(answer)) }
            } catch (e: Exception) {
                val code = when(e) { is ApiError -> e.code; is java.net.SocketTimeoutException -> "requestTimeout"; is org.json.JSONException -> "unknown"; is IllegalArgumentException -> "resourceNotFound"; else -> "networkError" }
                main.post { result.error(code, "Apple Music request failed.", null) }
            }
        }
    }
    private fun execute(call: MethodCall): Any? {
        fun string(key: String) = call.argument<String>(key) ?: ""
        fun refs(key: String) = call.argument<List<Map<String, Any?>>>(key) ?: emptyList()
        fun tracks(key: String) = JSONArray(refs(key).map { mapOf("id" to it["id"], "type" to if (it["source"] == "library") "library-${it["type"]}" else it["type"]) })
        val limit = call.argument<Int>("limit") ?: 25
        require(limit > 0)
        val paging = mapOf("limit" to limit, "offset" to call.argument<Int>("offset"))
        fun country() = segment(call.argument<String>("storefront") ?: storefront() ?: first(request("v1/me/storefront")).getString("id"))
        return when(call.method) {
            "getAlbumAnimatedArtwork" -> request(
                "v1/catalog/${segment(string("storefront"))}/albums/${segment(string("id"))}",
                mapOf("extend" to "editorialVideo"))
            "getCurrentStorefront" -> first(request("v1/me/storefront"))
            "getSubscription" -> {
                val json = request("v1/me/account", mapOf("meta" to "subscription"))
                val active = json.optJSONObject("meta")?.optJSONObject("subscription")?.optBoolean("active")
                JSONObject().put("status", if (active == null) "unknown" else if (active) "subscribed" else "notSubscribed").put("canPlayCatalogContent", active ?: false)
            }
            "searchCatalog", "searchLibrary" -> {
                val library = call.method == "searchLibrary"
                val types = call.argument<List<String>>("types") ?: listOf("songs")
                request(if (library) "v1/me/library/search" else "v1/catalog/${country()}/search", mapOf("term" to string("term"), "limit" to limit,
                    "types" to types.joinToString(",") { if (library) "library-$it" else it })).optJSONObject("results")?.let { json ->
                    if (library) JSONObject().also { mapped -> types.forEach { mapped.put(it, json.opt("library-$it")) } } else json
                } ?: JSONObject()
            }
            "getCatalogSong", "getCatalogAlbum", "getCatalogArtist", "getCatalogPlaylist" -> {
                val type = when(call.method) { "getCatalogSong" -> "songs"; "getCatalogAlbum" -> "albums"; "getCatalogArtist" -> "artists"; else -> "playlists" }
                first(request("v1/catalog/${country()}/$type/${segment(string("id"))}", if (call.argument<Boolean>("includeTracks") == true) mapOf("include" to "tracks") else emptyMap()))
            }
            "getCharts" -> {
                val kind = string("kind"); val type = if (kind == "musicVideos") "music-videos" else kind
                val charts = request("v1/catalog/${country()}/charts", mapOf("types" to type, "limit" to limit)).optJSONObject("results")?.optJSONArray(type) ?: JSONArray()
                JSONArray((0 until charts.length()).map { val chart = charts.getJSONObject(it); JSONObject().put("name", chart.optString("name")).put(type, JSONObject().put("data", chart.optJSONArray("data"))) })
            }
            "getLibrarySongs", "getLibraryAlbums", "getLibraryPlaylists" -> request("v1/me/library/${when(call.method) { "getLibrarySongs" -> "songs"; "getLibraryAlbums" -> "albums"; else -> "playlists" }}", paging)
            "addToLibrary" -> { request("v1/me/library", mapOf("ids[songs]" to refs("songs").joinToString(",") { it["id"].toString() }), post = true); null }
            "createPlaylist" -> {
                require(string("name").isNotBlank())
                val attributes = JSONObject().put("name", string("name"))
                call.argument<String>("description")?.let { attributes.put("description", it) }
                val body = JSONObject().put("attributes", attributes).put("relationships", JSONObject().put("tracks", JSONObject().put("data", tracks("tracks"))))
                val created = first(request("v1/me/library/playlists", body = body, post = true))
                JSONObject().put("id", created.getString("id")).put("name", created.getJSONObject("attributes").getString("name")).put("description", created.getJSONObject("attributes").optJSONObject("description")?.optString("standard"))
            }
            "addToPlaylist" -> {
                request("v1/me/library/playlists/${segment(string("playlistId"))}/tracks", body = JSONObject().put("data", tracks("tracks")), post = true)
                JSONObject().put("playlistId", string("playlistId")).put("added", JSONArray(refs("tracks")))
            }
            else -> throw ApiError("unsupportedFeature")
        }
    }
    fun dispose() { executor.shutdown() }
}
