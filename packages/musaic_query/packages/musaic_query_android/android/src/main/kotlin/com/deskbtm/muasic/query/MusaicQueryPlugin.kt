/*
=============
Author: Lucas Josino
Github: https://github.com/LucJosin
Website: https://www.lucasjosino.com/
=============
Plugin/Id: musaic_query#0
Copyright: © 2021, Lucas Josino. All rights reserved.
=============
*/

package com.deskbtm.muasic.query

import android.content.Context
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Handler
import android.os.Looper
import com.deskbtm.muasic.query.consts.Method
import com.deskbtm.muasic.query.controllers.MethodController
import com.deskbtm.muasic.query.controllers.PermissionController
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean
import kotlinx.coroutines.*
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

class MusaicQueryPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {
    private lateinit var directories: AudioDirectories
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private lateinit var permissions: PermissionController
    private lateinit var scope: CoroutineScope
    private var binding: ActivityPluginBinding? = null
    private var showDetailedLog = false
    private val playlistMutex = Mutex()
    private val playlistWrites =
        setOf(
            Method.CREATE_PLAYLIST,
            Method.REMOVE_PLAYLIST,
            Method.ADD_TO_PLAYLIST,
            Method.REMOVE_FROM_PLAYLIST,
            Method.RENAME_PLAYLIST,
            Method.MOVE_ITEM_TO,
        )
    private val pending = mutableSetOf<MethodChannel.Result>()
    private val main = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        directories = AudioDirectories(context, binding.binaryMessenger)
        permissions = PermissionController(context)
        scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
        channel = MethodChannel(binding.binaryMessenger, "com.deskbtm.muasic.query")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, callback: MethodChannel.Result) {
        val result =
            object : MethodChannel.Result {
                private val completed = AtomicBoolean(false)

                private fun finish(reply: () -> Unit) {
                    if (!completed.compareAndSet(false, true)) return
                    val deliver = {
                        pending.remove(this)
                        reply()
                    }
                    if (Looper.myLooper() == Looper.getMainLooper()) deliver()
                    else main.post { deliver() }
                }

                override fun success(value: Any?) = finish { callback.success(value) }

                override fun error(code: String, message: String?, details: Any?) = finish {
                    callback.error(code, message, details)
                }

                override fun notImplemented() = finish { callback.notImplemented() }
            }
        pending.add(result)
        try {
            when (call.method) {
                Method.PERMISSION_STATUS -> result.success(permissions.permissionStatus())
                Method.PERMISSION_REQUEST ->
                    permissions.requestPermission(
                        result,
                        call.argument<Boolean>("retryRequest") ?: false,
                    )
                Method.QUERY_DEVICE_INFO ->
                    result.success(
                        mapOf(
                            "device_model" to Build.MODEL,
                            "device_sys_version" to Build.VERSION.SDK_INT,
                            "device_sys_type" to "Android",
                        )
                    )
                Method.SCAN -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrBlank()) {
                        result.success(false)
                        return
                    }
                    MediaScannerConnection.scanFile(context, arrayOf(path), null) { _, uri ->
                        result.success(uri != null)
                    }
                }
                Method.SET_LOG_CONFIG -> {
                    io.flutter.Log.setLogLevel(call.argument<Int>("level") ?: io.flutter.Log.WARN)
                    showDetailedLog = call.argument<Boolean>("showDetailedLog") ?: false
                    result.success(true)
                }
                else -> {
                    if (!permissions.permissionStatus()) {
                        result.error(
                            "MissingPermissions",
                            "Application doesn't have access to the library",
                            null,
                        )
                        return
                    }
                    val request = QueryRequest(call, result, context, showDetailedLog)
                    scope.launch {
                        try {
                            if (call.method in playlistWrites) {
                                playlistMutex.withLock {
                                    withContext(Dispatchers.IO) { MethodController(request).find() }
                                }
                            } else {
                                withContext(Dispatchers.IO) { MethodController(request).find() }
                            }
                        } catch (error: CancellationException) {
                            result.error("QueryCancelled", "Plugin detached during query", null)
                            throw error
                        } catch (error: Exception) {
                            result.error("QueryFailed", error.message, null)
                        }
                    }
                }
            }
        } catch (error: Exception) {
            result.error("QueryFailed", error.message, null)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        directories.dispose()
        detachActivity()
        pending.toList().forEach { it.error("PluginDetached", "Plugin detached", null) }
        scope.cancel()
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        this.binding = binding
        directories.activity = binding.activity
        binding.addActivityResultListener(directories)
        permissions.activity = binding.activity
        binding.addRequestPermissionsResultListener(permissions)
    }

    private fun detachActivity(forConfigChange: Boolean = false) {
        binding?.removeActivityResultListener(directories)
        directories.detachActivity(cancelPicker = !forConfigChange)
        binding?.removeRequestPermissionsResultListener(permissions)
        binding = null
        permissions.activity = null
        if (!forConfigChange) permissions.cancel()
    }

    override fun onDetachedFromActivityForConfigChanges() = detachActivity(forConfigChange = true)

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        onAttachedToActivity(binding)

    override fun onDetachedFromActivity() = detachActivity()
}
