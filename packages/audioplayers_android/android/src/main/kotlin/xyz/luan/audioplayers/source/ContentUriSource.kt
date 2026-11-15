package xyz.luan.audioplayers.source

import android.content.res.AssetFileDescriptor
import android.media.MediaPlayer
import xyz.luan.audioplayers.player.SoundPoolPlayer

/** Owns one provider descriptor until the source is replaced or released. */
internal class ContentUriSource(private val asset: AssetFileDescriptor) : Source {
    override fun setForMediaPlayer(mediaPlayer: MediaPlayer) {
        if (asset.declaredLength < 0) {
            require(asset.startOffset == 0L) { "Unknown-length content requires offset zero" }
            mediaPlayer.setDataSource(asset.fileDescriptor)
        } else {
            mediaPlayer.setDataSource(asset.fileDescriptor, asset.startOffset, asset.declaredLength)
        }
    }

    override fun setForSoundPool(soundPoolPlayer: SoundPoolPlayer) {
        error("Content URIs require PlayerMode.mediaPlayer")
    }

    override fun dispose() {
        // Closing a stale source must not mask the result of switching tracks.
        runCatching { asset.close() }
    }
}
