package com.deskbtm.apple_music_kit

import android.app.Activity
import android.os.Handler
import android.os.Looper
import com.apple.android.sdk.authentication.*
import com.apple.android.music.playback.controller.*
import com.apple.android.music.playback.model.*
import com.apple.android.music.playback.queue.*
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.*

class SdkImplementation(binding: FlutterPlugin.FlutterPluginBinding) : SdkApi, ActivityAware {
    private val context = binding.applicationContext
    private val auth = AuthenticationFactory.createAuthenticationManager(context)
    private var activity: ActivityPluginBinding? = null
    private var pendingAuth: MethodChannel.Result? = null
    @Volatile private var developerToken: String? = null
    @Volatile private var userToken: String? = null
    private var storefront: String? = null
    private var appleStorefront: String? = null
    private var initialized = false
    private var player: MediaPlayerController?
        get() = MusicPlaybackService.controller
        set(value) { MusicPlaybackService.controller = value }
    private val main = Handler(Looper.getMainLooper())
    private var authSink: EventChannel.EventSink? = null
    private var playerSink: EventChannel.EventSink? = null
    private val tokens = object : TokenProvider {
        override fun getDeveloperToken(): String? = this@SdkImplementation.developerToken
        override fun getUserToken(): String? = this@SdkImplementation.userToken
        override fun getAppleMusicStoreFrontId(): String? = this@SdkImplementation.appleStorefront
    }
    private val api = AppleMusicApi({ developerToken }, { userToken }, { storefront })
    private fun status() = if (userToken == null) "notDetermined" else "authorized"
    private fun controller(): MediaPlayerController {
        check(userToken != null) { "Apple Music authorization required." }
        return player ?: MediaPlayerControllerFactory.createLocalController(context, tokens).also { player = it; it.addListener(listener)
            val intent = android.content.Intent(context, MusicPlaybackService::class.java)
            try {
                if (android.os.Build.VERSION.SDK_INT >= 26) context.startForegroundService(intent) else context.startService(intent)
            } catch (error: RuntimeException) {
                it.removeListener(listener); it.release(); player = null
                throw error
            }
        }
    }
    private var queueResult: MethodChannel.Result? = null
    private val queueTimeout = Runnable {
        queueResult?.error("requestTimeout", "Queue update timed out.", null)
        queueResult = null
    }
    private fun queueFinished(error: String? = null) {
        val reply = queueResult ?: return
        queueResult = null
        main.removeCallbacks(queueTimeout)
        if (error == null) reply.success(null) else reply.error("playbackFailed", error, null)
    }
    private val listener = object : MediaPlayerController.Listener {
        override fun onPlayerStateRestored(p: MediaPlayerController) {}
        override fun onPlaybackStateChanged(p: MediaPlayerController, previous: Int, current: Int) {}
        override fun onPlaybackStateUpdated(p: MediaPlayerController) {}
        override fun onBufferingStateChanged(p: MediaPlayerController, buffering: Boolean) {}
        override fun onCurrentItemChanged(p: MediaPlayerController, previous: PlayerQueueItem?, current: PlayerQueueItem?) {}
        override fun onItemEnded(p: MediaPlayerController, item: PlayerQueueItem, position: Long) {}
        override fun onMetadataUpdated(p: MediaPlayerController, item: PlayerQueueItem) {}
        override fun onPlaybackQueueChanged(p: MediaPlayerController, items: List<PlayerQueueItem>) { main.post { queueFinished() } }
        override fun onPlaybackQueueItemsAdded(p: MediaPlayerController, items: PlaybackQueueItemsAdded) { main.post { queueFinished() } }
        override fun onPlaybackError(p: MediaPlayerController, error: MediaPlayerException) { main.post {
            queueFinished("Playback SDK reported an error.")
            playerSink?.error("playbackFailed", "Playback SDK reported an error.", null)
        } }
        override fun onPlaybackModeChanged(p: MediaPlayerController, mode: PlaybackModeContainer) {}
        override fun onPlaybackRepeatModeChanged(p: MediaPlayerController, mode: Int) {}
        override fun onPlaybackShuffleModeChanged(p: MediaPlayerController, mode: Int) {}
    }
    private val authResult = PluginRegistry.ActivityResultListener { request, resultCode, data ->
        if (request != 8472) false else {
            val reply = pendingAuth
            pendingAuth = null
            if (reply != null) {
                if (resultCode != Activity.RESULT_OK || data == null) {
                    reply.error("authorizationCancelled", "Authorization cancelled.", null)
                } else {
                    val result = auth.handleTokenResult(data)
                    if (result.isError) {
                        reply.error("authenticationFailed", "Authorization failed: ${result.error}", null)
                    } else {
                        userToken = result.musicUserToken
                        storefront = result.storefrontId
                        appleStorefront = result.appleMusicStorefrontId
                        player?.removeListener(listener)
                player?.addListener(listener)
                player?.playbackStoreConfiguration?.notifyTokenChanged(context, tokens)
                        authSink?.success(status())
                        reply.success(status())
                    }
                }
            }
            true
        }
    }
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding
        binding.addActivityResultListener(authResult)
    }
    override fun onDetachedFromActivityForConfigChanges() {
        activity?.removeActivityResultListener(authResult)
        activity = null
    }
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) = onAttachedToActivity(binding)
    override fun onDetachedFromActivity() {
        onDetachedFromActivityForConfigChanges()
        pendingAuth?.error("authorizationCancelled", "Activity detached.", null)
        pendingAuth = null
    }
    override fun authEventHandler() = object : EventChannel.StreamHandler {
        override fun onListen(arguments: Any?, events: EventChannel.EventSink) { authSink = events; events.success(status()) }
        override fun onCancel(arguments: Any?) { authSink = null }
    }
    private fun ref(item: PlayerQueueItem): Map<String, Any?> {
        val media = item.item
        val library = media.cloudLibraryUniversalId
        return mapOf("id" to (library?.takeIf { it.isNotEmpty() } ?: media.playbackStoreId),
            "type" to "songs", "source" to if (library.isNullOrEmpty()) "catalog" else "library")
    }
    private fun snapshot(): Map<String, Any?> {
        val p = player
        val playing = p?.playbackState == PlaybackState.PLAYING
        return mapOf("status" to when(p?.playbackState) {
            PlaybackState.PLAYING -> "playing"; PlaybackState.PAUSED -> "paused"; else -> "stopped"
        }, "currentItem" to p?.currentItem?.let { ref(it) },
            "currentIndex" to p?.playbackQueueIndex?.takeIf { it >= 0 },
            "positionMillis" to (p?.currentPosition ?: 0).coerceAtLeast(0),
            "durationMillis" to p?.duration?.takeIf { it >= 0 },
            "queueLength" to (p?.playbackQueueItemCount ?: 0),
            "shuffleMode" to if (p?.shuffleMode == PlaybackShuffleMode.SHUFFLE_MODE_SONGS) "on" else "off",
            "repeatMode" to when(p?.repeatMode) {
                PlaybackRepeatMode.REPEAT_MODE_ONE -> "one"; PlaybackRepeatMode.REPEAT_MODE_ALL -> "all"; else -> "off"
            }, "isPlaying" to playing, "isBuffering" to (p?.isBuffering ?: false))
    }
    private val tick = object : Runnable {
        override fun run() { playerSink?.success(snapshot()); if (playerSink != null) main.postDelayed(this, 400) }
    }
    override fun playerEventHandler() = object : EventChannel.StreamHandler {
        override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
            main.removeCallbacks(tick); playerSink = events; tick.run()
        }
        override fun onCancel(arguments: Any?) { playerSink = null; main.removeCallbacks(tick) }
    }
    private fun provider(call: MethodCall): PlaybackQueueItemProvider {
        val items = call.argument<List<Map<String, Any?>>>("items") ?: emptyList()
        require(items.isNotEmpty() && items.all { it["type"] == "songs" }) { "Queue requires songs." }
        val library = items.first()["source"] == "library"
        require(items.all { (it["source"] == "library") == library }) { "Mixed catalog/library queues are unsupported." }
        val ids = items.map { (it["id"] as? String)?.takeIf { id -> id.isNotBlank() } ?: error("Missing song ID") }.toTypedArray()
        val index = call.argument<Int>("startIndex") ?: 0
        require(index in items.indices) { "Invalid start index." }
        return if (library) LibraryPlaybackQueueItemProvider.Builder().items(MediaItemType.SONG, *ids).startItemIndex(index).build()
        else CatalogPlaybackQueueItemProvider.Builder().items(MediaItemType.SONG, *ids).startItemIndex(index).build()
    }
    override fun handle(call: MethodCall, result: MethodChannel.Result) {
        try {
            if (call.method == "initialize") {
                developerToken = call.argument<String>("developerToken")?.takeIf { it.isNotBlank() }
                require(developerToken != null) { "Missing developer token." }
                player?.removeListener(listener)
                player?.addListener(listener)
                player?.playbackStoreConfiguration?.notifyTokenChanged(context, tokens)
                initialized = true
                result.success(null); return
            }
            if (call.method == "dispose") {
                initialized = false
                pendingAuth?.error("authorizationCancelled", "Client disposed.", null)
                pendingAuth = null
                main.removeCallbacks(tick); playerSink = null; authSink = null
                if (call.argument<Boolean>("stopPlayback") == true) { player?.stop(); context.stopService(android.content.Intent(context, MusicPlaybackService::class.java)) }
                result.success(null); return
            }
            if (!initialized) { result.error("notInitialized", "Call initialize first.", null); return }
            when (call.method) {
                "getAuthorizationStatus" -> { result.success(status()); return }
                "requestAuthorization" -> {
                    val host = activity?.activity
                    if (host == null || pendingAuth != null) { result.error("platformUnavailable", "Authorization is unavailable or already in progress.", null); return }
                    pendingAuth = result
                    try { host.startActivityForResult(auth.createIntentBuilder(developerToken!!).build(), 8472) }
                    catch (e: Exception) { pendingAuth = null; throw e }
                    return
                }
                "getCapabilities" -> {
                    val supported = mapOf("supported" to true, "reason" to "available")
                    val denied = mapOf("supported" to false, "reason" to "authorizationRequired")
                    result.success(listOf("canPlayCatalog", "canAccessLibrary", "canSeek", "canSetQueue", "canEditQueue", "canShuffle", "canRepeat", "canCreatePlaylist", "canPlayInBackground").associateWith { if (userToken != null) supported else denied } +
                        listOf("canControlVolume").associateWith { mapOf("supported" to false, "reason" to "unsupportedOnPlatform") }); return
                }
                "setQueue", "appendToQueue" -> {
                    check(queueResult == null) { "Queue update in progress." }
                    val p = controller()
                    val items = provider(call)
                    queueResult = result
                    main.postDelayed(queueTimeout, 30000)
                    try {
                        if (call.method == "setQueue") p.prepare(items, call.argument<Boolean>("autoplay") ?: true)
                        else p.addQueueItems(items, PlaybackQueueInsertionType.INSERTION_TYPE_AT_END)
                    } catch (e: Exception) { queueFinished("Queue update failed.") }
                    return
                }
                "removeFromQueue" -> { val p = controller(); val index = call.argument<Int>("index") ?: -1; require(index in p.queueItems.indices); p.removeQueueItemWithId(p.queueItems[index].playbackQueueId) }
                "getQueue" -> { val p = controller(); result.success(mapOf("entries" to p.queueItems.map { mapOf("ref" to ref(it)) }, "currentIndex" to p.playbackQueueIndex.takeIf { it >= 0 })); return }
                "play" -> controller().play()
                "pause" -> controller().pause()
                "stop" -> controller().stop()
                "togglePlayPause" -> { val p = controller(); if (p.playbackState == PlaybackState.PLAYING) p.pause() else p.play() }
                "seekTo" -> controller().seekToPosition((call.argument<Number>("positionMillis")?.toLong() ?: 0).coerceAtLeast(0))
                "skipToNext" -> controller().skipToNextItem()
                "skipToPrevious" -> controller().skipToPreviousItem()
                "setShuffleMode" -> controller().setShuffleMode(if (call.argument<String>("mode") == "on") PlaybackShuffleMode.SHUFFLE_MODE_SONGS else PlaybackShuffleMode.SHUFFLE_MODE_OFF)
                "setRepeatMode" -> controller().setRepeatMode(when(call.argument<String>("mode")) { "one" -> PlaybackRepeatMode.REPEAT_MODE_ONE; "all" -> PlaybackRepeatMode.REPEAT_MODE_ALL; else -> PlaybackRepeatMode.REPEAT_MODE_OFF })
                else -> { api.handle(call, result); return }
            }
            result.success(null)
        } catch (e: Exception) { result.error(if (userToken == null) "authorizationDenied" else "playbackFailed", e.message, null) }
    }
    override fun dispose() {
        onDetachedFromActivity()
        main.removeCallbacks(tick)
        queueFinished("Plugin detached.")
        player?.removeListener(listener)
        api.dispose()
    }
}
