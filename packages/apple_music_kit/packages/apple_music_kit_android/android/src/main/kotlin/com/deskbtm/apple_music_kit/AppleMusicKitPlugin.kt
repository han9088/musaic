package com.deskbtm.apple_music_kit

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * SDK-wired entry point, compiled only when the Apple MusicKit Android
 * AARs are provisioned (see build.gradle source-set wiring). Replaces the
 * fallback [AppleMusicKitPlugin] of the same name so the generated
 * plugin registrant finds this class instead.
 *
 * Instantiates [SdkImplementation] and registers the method + event
 * channels the Dart layer expects.
 */
class AppleMusicKitPlugin : FlutterPlugin, io.flutter.embedding.engine.plugins.activity.ActivityAware {
    private var channel: MethodChannel? = null
    private var authEvents: EventChannel? = null
    private var playerEvents: EventChannel? = null
    private var handler: MethodHandler? = null
    private var implementation: SdkApi? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        implementation = SdkImplementation(binding)
        handler = MethodHandler(implementation)
        channel = MethodChannel(binding.binaryMessenger, "deskbtm.apple_music_kit/methods")
        channel?.setMethodCallHandler(handler)

        authEvents = EventChannel(binding.binaryMessenger, "deskbtm.apple_music_kit/authEvents")
            .also { it.setStreamHandler(implementation?.authEventHandler()) }
        playerEvents = EventChannel(binding.binaryMessenger, "deskbtm.apple_music_kit/playerEvents")
            .also { it.setStreamHandler(implementation?.playerEventHandler()) }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        authEvents?.setStreamHandler(null)
        playerEvents?.setStreamHandler(null)
        handler?.dispose()
        channel = null
        authEvents = null
        playerEvents = null
        handler = null
        implementation = null
    }

    // ActivityAware: forward lifecycle to the implementation so it can
    // launch the auth intent for results.
    override fun onAttachedToActivity(binding: io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding) {
        implementation?.onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        implementation?.onDetachedFromActivityForConfigChanges()
    }

    override fun onReattachedToActivityForConfigChanges(binding: io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding) {
        implementation?.onReattachedToActivityForConfigChanges(binding)
    }

    override fun onDetachedFromActivity() {
        implementation?.onDetachedFromActivity()
    }
}
