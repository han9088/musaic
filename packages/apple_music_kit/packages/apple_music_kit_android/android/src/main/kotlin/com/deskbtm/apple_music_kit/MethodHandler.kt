package com.deskbtm.apple_music_kit

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel

/**
 * Routes method calls to the SDK-backed implementation when present, and
 * returns clear `sdkUnavailable` errors when it is not.
 */
class MethodHandler(private val implementation: Any?) : MethodChannel.MethodCallHandler {

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (implementation == null) {
            result.error(
                "sdkUnavailable",
                "Apple's MusicKit Android SDK is not available in this build. " +
                    "Download musickitauth.aar and musickitplayback.aar from " +
                    "https://developer.apple.com/download/all/ (search 'MusicKit'), place them in a " +
                    "local directory, and set MUSICKIT_ANDROID_SDK_DIR (env var or Gradle property) " +
                    "to that directory, then rebuild. See the plugin README for details.",
                mapOf("method" to call.method)
            )
            return
        }
        // The SDK implementation (SdkMethodHandler) is compiled in the same
        // source set when the AARs exist; dispatch through it.
        (implementation as? SdkApi)?.handle(call, result)
            ?: result.error("sdkUnavailable", "SDK implementation does not implement SdkApi.", null)
    }

    fun dispose() {
        (implementation as? SdkApi)?.dispose()
    }
}

/** Contract implemented by the SDK-backed handler. */
interface SdkApi : io.flutter.embedding.engine.plugins.activity.ActivityAware {
    override fun onAttachedToActivity(binding: io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding) {}
    override fun onDetachedFromActivityForConfigChanges() {}
    override fun onReattachedToActivityForConfigChanges(binding: io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding) {}
    override fun onDetachedFromActivity() {}

    fun handle(call: MethodCall, result: MethodChannel.Result)
    fun dispose()

    /** Stream handler for the authEvents EventChannel; null when the SDK
     *  provides no change notifications. */
    fun authEventHandler(): EventChannel.StreamHandler? = null

    /** Stream handler for the playerEvents EventChannel; null when the SDK
     *  provides no change notifications. */
    fun playerEventHandler(): EventChannel.StreamHandler? = null
}
