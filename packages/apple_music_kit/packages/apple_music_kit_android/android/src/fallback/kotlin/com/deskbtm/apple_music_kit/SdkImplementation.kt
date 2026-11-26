package com.deskbtm.apple_music_kit
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
class SdkImplementation(@Suppress("UNUSED_PARAMETER") binding: FlutterPlugin.FlutterPluginBinding) : SdkApi {
    override fun handle(call: MethodCall, result: MethodChannel.Result) = MethodHandler(null).onMethodCall(call, result)
    override fun dispose() {}
}
