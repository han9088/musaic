package com.deskbtm.muasic.query.types

import android.annotation.SuppressLint
import android.provider.MediaStore

@SuppressLint("InlinedApi")
fun checkAudiosFromType(sortType: Int): String {
    return when (sortType) {
        0 -> MediaStore.Audio.Media.ALBUM + " LIKE ? ESCAPE '\\'"
        1 -> MediaStore.Audio.Media.ALBUM_ID + " = ?"
        2 -> MediaStore.Audio.Media.ARTIST + " LIKE ? ESCAPE '\\'"
        3 -> MediaStore.Audio.Media.ARTIST_ID + " = ?"
        // Use the [TRIM] to remove all empty space from genre name.
        4 -> "TRIM(\"" + MediaStore.Audio.Media.GENRE + "\") LIKE ? ESCAPE '\\'"
        5 -> MediaStore.Audio.Media.GENRE_ID + " = ?"
        else -> throw Exception("[checkAudiosFromType] value don't exist!")
    }
}
