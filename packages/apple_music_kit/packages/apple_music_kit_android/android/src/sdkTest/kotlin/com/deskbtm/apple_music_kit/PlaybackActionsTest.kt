package com.deskbtm.apple_music_kit
import com.apple.android.music.playback.controller.MediaPlayerController
import java.lang.reflect.Proxy
import org.junit.Assert.*
import org.junit.Test
class PlaybackActionsTest {
    @Test fun notificationActionsReachThePlayerAndStopEndsTheService() {
        val calls = mutableListOf<String>()
        val player = Proxy.newProxyInstance(MediaPlayerController::class.java.classLoader,
            arrayOf(MediaPlayerController::class.java)) { _, method, _ -> calls.add(method.name); null } as MediaPlayerController
        for (action in listOf("play", "pause", "next", "previous")) assertFalse(dispatchPlaybackAction(player, action))
        assertEquals(listOf("play", "pause", "skipToNextItem", "skipToPreviousItem"), calls)
        assertTrue(dispatchPlaybackAction(player, "stop"))
        assertFalse(dispatchPlaybackAction(null, "play"))
        assertFalse(dispatchPlaybackAction(player, "unknown"))
        assertEquals(4, calls.size)
    }
}
