package xyz.luan.audioplayers

import android.content.Context
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.FlutterPlugin.FlutterPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import xyz.luan.audioplayers.player.SoundPoolManager
import xyz.luan.audioplayers.player.WrappedPlayer
import xyz.luan.audioplayers.source.ContentSourceLoader
import xyz.luan.audioplayers.source.BytesSource
import xyz.luan.audioplayers.source.UrlSource
import java.io.FileNotFoundException

typealias FlutterHandler = (call: MethodCall, response: MethodChannel.Result) -> Unit

class AudioplayersPlugin : FlutterPlugin {
    private var session: AudioSession? = null

    override fun onAttachedToEngine(binding: FlutterPluginBinding) {
        session = AudioSession(binding.applicationContext, binding.binaryMessenger)
    }

    override fun onDetachedFromEngine(binding: FlutterPluginBinding) {
        session?.close()
        session = null
    }

    private fun safeCall(
        call: MethodCall,
        response: MethodChannel.Result,
        handler: FlutterHandler,
    ) {
        try {
            handler(call, response)
        } catch (e: Throwable) {
            response.error("Unexpected AndroidAudioError", e.message, e.javaClass.simpleName)
        }
    }

    private inner class AudioSession(
        private val context: Context,
        private val binaryMessenger: BinaryMessenger,
    ) {
        // Every MediaPlayer access, including callbacks, stays on this Looper.
        private val audioThread = HandlerThread("MusaicAudio").apply { start() }
        private val audio = Handler(audioThread.looper)
        private val methods = MethodChannel(binaryMessenger, "xyz.luan/audioplayers")
        private val globalMethods = MethodChannel(binaryMessenger, "xyz.luan/audioplayers.global")
        private val globalEvents = EventHandler(EventChannel(binaryMessenger, "xyz.luan/audioplayers.global/events"))
        private val soundPoolManager = SoundPoolManager(::handleGlobalLog)
        private val contentSources = ContentSourceLoader(context.contentResolver, audio)

        // Register Flutter channels on the platform thread and own players on the audio thread.
        private val playerEvents = mutableMapOf<String, EventHandler>()
        private val players = mutableMapOf<String, WrappedPlayer>()
        private var defaultAudioContext = AudioContextAndroid()

        init {
            methods.setMethodCallHandler { call, response -> safeCall(call, response, ::dispatchPlayerCall) }
            globalMethods.setMethodCallHandler { call, response ->
                if (call.method == "init") disposePlayerEvents()
                audio.post { safeCall(call, response, ::globalMethodHandler) }
            }
        }

        private fun dispatchPlayerCall(call: MethodCall, response: MethodChannel.Result) {
            val playerId = call.argument<String>("playerId") ?: error("playerId is required")
            val events =
                when (call.method) {
                    "create" -> {
                        playerEvents.remove(playerId)?.dispose()
                        EventHandler(EventChannel(binaryMessenger, "xyz.luan/audioplayers/events/$playerId"))
                            .also { playerEvents[playerId] = it }
                    }

                    "dispose" -> {
                        playerEvents.remove(playerId)?.dispose()
                        null
                    }

                    else -> null
                }
            audio.post {
                safeCall(call, response) { method, result -> methodHandler(playerId, method, result, events) }
            }
        }

        private fun disposePlayerEvents() {
            playerEvents.values.forEach { it.dispose() }
            playerEvents.clear()
        }

        private fun releasePlayers() {
            for (player in players.values) {
                try {
                    player.release()
                } catch (error: Exception) {
                    Log.w("Audioplayers", "Could not release player", error)
                }
            }
            players.clear()
        }

        fun close() {
            methods.setMethodCallHandler(null)
            globalMethods.setMethodCallHandler(null)
            disposePlayerEvents()
            globalEvents.dispose()
            audio.post {
                try {
                    contentSources.dispose()
                    releasePlayers()
                    soundPoolManager.dispose()
                } finally {
                    audioThread.quitSafely()
                }
            }
        }

        private fun globalMethodHandler(call: MethodCall, response: MethodChannel.Result) {
            when (call.method) {
                "init" -> {
                    contentSources.cancelAll()
                    releasePlayers()
                }

                "setAudioContext" -> {
                    val audioManager = getAudioManager()
                    audioManager.mode = defaultAudioContext.audioMode
                    audioManager.isSpeakerphoneOn = defaultAudioContext.isSpeakerphoneOn

                    defaultAudioContext = call.audioContext()
                }

                "emitLog" -> {
                    val message = call.argument<String>("message") ?: error("message is required")
                    handleGlobalLog(message)
                }

                "emitError" -> {
                    val code = call.argument<String>("code") ?: error("code is required")
                    val message = call.argument<String>("message") ?: error("message is required")
                    handleGlobalError(code, message, null)
                }

                else -> {
                    response.notImplemented()
                    return
                }
            }

            response.success(1)
        }

        private fun methodHandler(
            playerId: String,
            call: MethodCall,
            response: MethodChannel.Result,
            events: EventHandler?,
        ) {
            when (call.method) {
                "create", "setSourceUrl", "setSourceBytes", "stop", "release", "dispose" ->
                    contentSources.cancel(playerId)
            }
            if (call.method == "create") {
                players.remove(playerId)?.release()
                players[playerId] =
                    WrappedPlayer(context, audio, checkNotNull(events), defaultAudioContext.copy(), soundPoolManager)
                response.success(1)
                return
            }
            val player = getPlayer(playerId)
            try {
                when (call.method) {
                    "setSourceUrl" -> {
                        val url = call.argument<String>("url") ?: error("url is required")
                        val isLocal = call.argument<Boolean>("isLocal") ?: false
                        val uri = Uri.parse(url)
                        if (uri.scheme == "content") {
                            player.release()
                            contentSources.load(playerId, uri) { result ->
                                result.fold(
                                    onSuccess = { source ->
                                        try {
                                            player.source = source
                                            response.success(1)
                                        } catch (error: Exception) {
                                            response.error("AndroidAudioError", error.message, null)
                                        }
                                    },
                                    onFailure = { error ->
                                        response.error("AndroidAudioError", error.message, null)
                                    },
                                )
                            }
                            return
                        }
                        try {
                            player.source = UrlSource(url, isLocal)
                        } catch (e: FileNotFoundException) {
                            response.error(
                                "AndroidAudioError",
                                "Failed to set source. For troubleshooting, see: " +
                                    "https://github.com/bluefireteam/audioplayers/blob/main/troubleshooting.md",
                                e.javaClass.simpleName,
                            )
                            return
                        }
                    }

                    "setSourceBytes" -> {
                        val bytes = call.argument<ByteArray>("bytes") ?: error("bytes are required")
                        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
                            error("BytesSource is not supported on Android <= M")
                        }
                        player.source = BytesSource(bytes)
                    }

                    "resume" -> player.play()
                    "pause" -> player.pause()
                    "stop" -> player.stop()
                    "release" -> player.release()
                    "seek" -> {
                        val position = call.argument<Int>("position") ?: error("position is required")
                        player.seek(position)
                    }

                    "setVolume" -> {
                        val volume = call.argument<Double>("volume") ?: error("volume is required")
                        player.volume = volume.toFloat()
                    }

                    "setBalance" -> {
                        val balance = call.argument<Double>("balance") ?: error("balance is required")
                        player.balance = balance.toFloat()
                    }

                    "setPlaybackRate" -> {
                        val rate = call.argument<Double>("playbackRate") ?: error("playbackRate is required")
                        player.rate = rate.toFloat()
                    }

                    "getDuration" -> {
                        response.success(player.getDuration())
                        return
                    }

                    "getCurrentPosition" -> {
                        response.success(player.getCurrentPosition())
                        return
                    }

                    "setReleaseMode" -> {
                        val releaseMode = call.enumArgument<ReleaseMode>("releaseMode") ?: error("releaseMode is required")
                        player.releaseMode = releaseMode
                    }

                    "setPlayerMode" -> {
                        val playerMode = call.enumArgument<PlayerMode>("playerMode") ?: error("playerMode is required")
                        player.playerMode = playerMode
                    }

                    "setAudioContext" -> {
                        val audioContext = call.audioContext()
                        player.updateAudioContext(audioContext)
                    }

                    "emitLog" -> {
                        val message = call.argument<String>("message") ?: error("message is required")
                        player.handleLog(message)
                    }

                    "emitError" -> {
                        val code = call.argument<String>("code") ?: error("code is required")
                        val message = call.argument<String>("message") ?: error("message is required")
                        player.handleError(code, message, null)
                    }

                    "dispose" -> {
                        players.remove(playerId)
                        player.release()
                    }

                    else -> {
                        response.notImplemented()
                        return
                    }
                }
                response.success(1)
            } catch (e: Exception) {
                response.error("AndroidAudioError", e.message, e.javaClass.simpleName)
            }
        }

        private fun getPlayer(playerId: String): WrappedPlayer {
            return players[playerId] ?: error("Player has not yet been created or has already been disposed.")
        }

        private fun getAudioManager(): AudioManager {
            return context.applicationContext.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        }

        private fun handleGlobalLog(message: String) {
            globalEvents.success("audio.onLog", hashMapOf("value" to message))
        }

        private fun handleGlobalError(errorCode: String?, errorMessage: String?, errorDetails: Any?) {
            globalEvents.error(errorCode, errorMessage, errorDetails)
        }
    }
}

private inline fun <reified T : Enum<T>> MethodCall.enumArgument(name: String): T? {
    val enumName = argument<String>(name) ?: return null
    return enumValueOf<T>(enumName.split('.').last().toConstantCase())
}

fun String.toConstantCase(): String {
    return replace(Regex("(.)(\\p{Upper})"), "$1_$2").replace(Regex("(.) (.)"), "$1_$2").uppercase()
}

private fun MethodCall.audioContext(): AudioContextAndroid {
    return AudioContextAndroid(
        isSpeakerphoneOn = argument<Boolean>("isSpeakerphoneOn") ?: error("isSpeakerphoneOn is required"),
        stayAwake = argument<Boolean>("stayAwake") ?: error("stayAwake is required"),
        contentType = argument<Int>("contentType") ?: error("contentType is required"),
        usageType = argument<Int>("usageType") ?: error("usageType is required"),
        audioFocus = argument<Int>("audioFocus") ?: error("audioFocus is required"),
        audioMode = argument<Int>("audioMode") ?: error("audioMode is required"),
    )
}

class EventHandler(private val eventChannel: EventChannel) : EventChannel.StreamHandler {
    private val platform = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null

    init {
        eventChannel.setStreamHandler(this)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    fun success(method: String, arguments: Map<String, Any> = HashMap()) {
        onPlatform { eventSink?.success(arguments + Pair("event", method)) }
    }

    fun error(errorCode: String?, errorMessage: String?, errorDetails: Any?) {
        onPlatform { eventSink?.error(errorCode, errorMessage, errorDetails) }
    }

    private fun onPlatform(send: () -> Unit) {
        if (Looper.myLooper() == platform.looper) send() else platform.post { send() }
    }

    fun dispose() {
        eventSink?.let {
            it.endOfStream()
            onCancel(null)
        }
        eventChannel.setStreamHandler(null)
    }
}
