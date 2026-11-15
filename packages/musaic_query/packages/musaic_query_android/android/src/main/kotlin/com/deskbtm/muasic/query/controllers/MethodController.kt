package com.deskbtm.muasic.query.controllers

import com.deskbtm.muasic.query.QueryRequest
import com.deskbtm.muasic.query.consts.Method
import com.deskbtm.muasic.query.queries.*

internal class MethodController(private val request: QueryRequest) {

    //
    suspend fun find() {
        when (request.call.method) {
            // Query methods
            Method.QUERY_AUDIOS,
            "queryFromFolder" -> AudioQuery(request).querySongs()
            Method.QUERY_ALBUMS -> AlbumQuery(request).queryAlbums()
            Method.QUERY_ARTISTS -> ArtistQuery(request).queryArtists()
            Method.QUERY_PLAYLISTS -> PlaylistQuery(request).queryPlaylists()
            Method.QUERY_GENRES -> GenreQuery(request).queryGenres()
            Method.QUERY_ARTWORK -> ArtworkQuery(request).queryArtwork()
            Method.QUERY_AUDIOS_FROM -> AudioFromQuery(request).querySongsFrom()
            Method.QUERY_WITH_FILTERS -> WithFiltersQuery(request).queryWithFilters()
            Method.QUERY_ALL_PATHS -> AllPathQuery(request).queryAllPath()
            // Playlists methods
            Method.CREATE_PLAYLIST -> PlaylistController(request).createPlaylist()
            Method.REMOVE_PLAYLIST -> PlaylistController(request).removePlaylist()
            Method.ADD_TO_PLAYLIST -> PlaylistController(request).addToPlaylist()
            Method.REMOVE_FROM_PLAYLIST -> PlaylistController(request).removeFromPlaylist()
            Method.RENAME_PLAYLIST -> PlaylistController(request).renamePlaylist()
            Method.MOVE_ITEM_TO -> PlaylistController(request).moveItemTo()
            else -> request.result.notImplemented()
        }
    }
}
