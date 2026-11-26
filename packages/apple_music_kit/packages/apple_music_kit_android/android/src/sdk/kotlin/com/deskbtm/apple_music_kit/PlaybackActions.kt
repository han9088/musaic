package com.deskbtm.apple_music_kit
import com.apple.android.music.playback.controller.MediaPlayerController

/** Returns true when the owning service must end the playback session. */
internal fun dispatchPlaybackAction(player: MediaPlayerController?, action: String?): Boolean {
    when (action) {
        "play" -> player?.play()
        "pause" -> player?.pause()
        "next" -> player?.skipToNextItem()
        "previous" -> player?.skipToPreviousItem()
        "stop" -> return true
    }
    return false
}
