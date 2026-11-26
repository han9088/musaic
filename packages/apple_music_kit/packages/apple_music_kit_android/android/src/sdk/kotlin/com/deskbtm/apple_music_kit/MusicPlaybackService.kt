package com.deskbtm.apple_music_kit

import android.app.*
import android.content.Intent
import android.media.MediaMetadata
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.os.*
import com.apple.android.music.playback.controller.MediaPlayerController
import com.apple.android.music.playback.model.PlaybackState as SdkState

/** Owns playback independently of the Flutter engine and its Activity. */
class MusicPlaybackService : Service() {
    companion object { var controller: MediaPlayerController? = null; private const val ID = 8142 }
    private val noisy = object : android.content.BroadcastReceiver() {
        override fun onReceive(context: android.content.Context?, intent: Intent?) {
            if (intent?.action == android.media.AudioManager.ACTION_AUDIO_BECOMING_NOISY) controller?.pause()
        }
    }
    private lateinit var session: MediaSession
    private val handler = Handler(Looper.getMainLooper())
    private val update = object : Runnable {
        override fun run() {
            val player = controller
            if (player == null) { stopSelf(); return }
            val playing = player.playbackState == SdkState.PLAYING
            val item = player.currentItem?.item
            session.setMetadata(MediaMetadata.Builder().putString(MediaMetadata.METADATA_KEY_TITLE, item?.title ?: "Apple Music")
                .putString(MediaMetadata.METADATA_KEY_ARTIST, item?.artistName ?: "")
                .putLong(MediaMetadata.METADATA_KEY_DURATION, player.duration.coerceAtLeast(0)).build())
            session.setPlaybackState(PlaybackState.Builder().setActions(PlaybackState.ACTION_PLAY or PlaybackState.ACTION_PAUSE or
                PlaybackState.ACTION_PLAY_PAUSE or PlaybackState.ACTION_SKIP_TO_NEXT or PlaybackState.ACTION_SKIP_TO_PREVIOUS or
                PlaybackState.ACTION_SEEK_TO or PlaybackState.ACTION_STOP)
                .setState(if (playing) PlaybackState.STATE_PLAYING else PlaybackState.STATE_PAUSED,
                    player.currentPosition.coerceAtLeast(0), if (playing) 1f else 0f).build())
            val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this@MusicPlaybackService, "apple_music_playback") else Notification.Builder(this@MusicPlaybackService)
            val notification = builder.setSmallIcon(android.R.drawable.ic_media_play).setContentTitle(item?.title ?: "Apple Music")
                .setContentText(item?.artistName ?: "").setOnlyAlertOnce(true).setOngoing(playing)
                .addAction(android.R.drawable.ic_media_previous, "Previous", action("previous"))
                .addAction(if (playing) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play,
                    if (playing) "Pause" else "Play", action(if (playing) "pause" else "play"))
                .addAction(android.R.drawable.ic_media_next, "Next", action("next"))
                .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Stop", action("stop"))
                .setStyle(Notification.MediaStyle().setMediaSession(session.sessionToken).setShowActionsInCompactView(0,1,2)).build()
            startForeground(ID, notification)
            handler.postDelayed(this, 1000)
        }
    }
    private fun action(name: String) = PendingIntent.getService(this, name.hashCode(),
        Intent(this, MusicPlaybackService::class.java).setAction(name), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    override fun onCreate() {
        super.onCreate()
        if (Build.VERSION.SDK_INT >= 26) getSystemService(NotificationManager::class.java).createNotificationChannel(
            NotificationChannel("apple_music_playback", "Music playback", NotificationManager.IMPORTANCE_LOW))
        val filter = android.content.IntentFilter(android.media.AudioManager.ACTION_AUDIO_BECOMING_NOISY)
        if (Build.VERSION.SDK_INT >= 33) registerReceiver(noisy, filter, RECEIVER_NOT_EXPORTED) else registerReceiver(noisy, filter)
        session = MediaSession(this, "AppleMusicKit")
        session.setCallback(object : MediaSession.Callback() {
            override fun onPlay() { controller?.play() }
            override fun onPause() { controller?.pause() }
            override fun onSkipToNext() { controller?.skipToNextItem() }
            override fun onSkipToPrevious() { controller?.skipToPreviousItem() }
            override fun onSeekTo(pos: Long) { controller?.seekToPosition(pos.coerceAtLeast(0)) }
            override fun onStop() { stopSelf() }
        })
        session.isActive = true
    }
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (dispatchPlaybackAction(controller, intent?.action)) {
            stopSelf(); return START_NOT_STICKY
        }
        handler.removeCallbacks(update); update.run()
        return START_NOT_STICKY
    }
    override fun onBind(intent: Intent?) = null
    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        unregisterReceiver(noisy)
        controller?.stop(); controller?.release(); controller = null
        session.isActive = false; session.release()
        stopForeground(true)
        super.onDestroy()
    }
}
