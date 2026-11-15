package com.deskbtm.muasic.query.controllers

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

internal class PermissionController(private val context: Context) :
    PluginRegistry.RequestPermissionsResultListener {
    private var nextRequestCode = 8856
    private var activeRequestCode: Int? = null
    var activity: Activity? = null
    private var pending: MethodChannel.Result? = null
    private var retry = false
    private val permissions =
        when {
            Build.VERSION.SDK_INT >= 33 -> arrayOf(Manifest.permission.READ_MEDIA_AUDIO)
            else -> arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE)
        }

    fun permissionStatus(): Boolean =
        permissions.all {
            ContextCompat.checkSelfPermission(context, it) == PackageManager.PERMISSION_GRANTED
        }

    fun requestPermission(result: MethodChannel.Result, retryRequest: Boolean) {
        if (pending != null) {
            result.error(
                "PermissionRequestInProgress",
                "A permission request is already pending",
                null,
            )
            return
        }
        if (permissionStatus()) {
            result.success(true)
            return
        }
        val host = activity
        if (host == null) {
            result.error("NoActivity", "Activity not available to request permissions", null)
            return
        }
        pending = result
        val requestCode = nextRequestCode
        nextRequestCode = if (requestCode == 65535) 8856 else requestCode + 1
        activeRequestCode = requestCode
        retry = retryRequest
        try {
            ActivityCompat.requestPermissions(host, permissions, requestCode)
        } catch (error: Exception) {
            pending = null
            activeRequestCode = null
            result.error("PermissionRequestFailed", error.message, null)
        }
    }

    fun cancel() {
        val result = pending
        pending = null
        activeRequestCode = null
        retry = false
        result?.error("ActivityDetached", "Activity detached during permission request", null)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != activeRequestCode || pending == null) return false
        val granted = grantResults.isNotEmpty() && permissionStatus()
        val host = activity
        if (
            !granted &&
                retry &&
                host != null &&
                this.permissions.any {
                    ActivityCompat.shouldShowRequestPermissionRationale(host, it)
                }
        ) {
            retry = false
            try {
                ActivityCompat.requestPermissions(host, this.permissions, requestCode)
                return true
            } catch (error: Exception) {
                val result = pending
                pending = null
                activeRequestCode = null
                result?.error("PermissionRequestFailed", error.message, null)
                return true
            }
        }
        val result = pending
        pending = null
        activeRequestCode = null
        retry = false
        result?.success(granted)
        return true
    }
}
