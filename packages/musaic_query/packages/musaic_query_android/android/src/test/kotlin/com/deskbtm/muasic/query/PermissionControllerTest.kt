package com.deskbtm.muasic.query

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import com.deskbtm.muasic.query.controllers.PermissionController
import com.deskbtm.muasic.query.queries.folderPattern
import io.flutter.plugin.common.MethodChannel
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [36])
class PermissionControllerTest {
    @Test
    fun stalePermissionCallbackCannotCompleteNewRequest() {
        val host = Robolectric.buildActivity(Activity::class.java).setup()
        try {
            val controller = PermissionController(host.get()).apply { activity = host.get() }
            controller.requestPermission(Reply(), false)
            controller.cancel()
            val current = Reply()
            controller.requestPermission(current, false)
            assertFalse(
                controller.onRequestPermissionsResult(
                    8856,
                    arrayOf(Manifest.permission.READ_MEDIA_AUDIO),
                    intArrayOf(PackageManager.PERMISSION_DENIED),
                )
            )
            assertEquals(0, current.count)
            assertTrue(
                controller.onRequestPermissionsResult(
                    8857,
                    arrayOf(Manifest.permission.READ_MEDIA_AUDIO),
                    intArrayOf(PackageManager.PERMISSION_DENIED),
                )
            )
            assertEquals(1, current.count)
        } finally {
            host.pause().stop().destroy()
        }
    }

    @Test
    @Config(sdk = [28])
    fun readingLegacyLibraryDoesNotRequireWritePermission() {
        val app = RuntimeEnvironment.getApplication()
        shadowOf(app).grantPermissions(Manifest.permission.READ_EXTERNAL_STORAGE)
        shadowOf(app).denyPermissions(Manifest.permission.WRITE_EXTERNAL_STORAGE)
        assertTrue(PermissionController(app).permissionStatus())
    }

    @Test
    fun audioPermissionDoesNotRequirePhotos() {
        val app = RuntimeEnvironment.getApplication()
        shadowOf(app).grantPermissions(Manifest.permission.READ_MEDIA_AUDIO)
        assertTrue(PermissionController(app).permissionStatus())
    }

    @Test
    fun pendingRequestSurvivesStatusCheckAndRejectsConcurrentRequest() {
        val host = Robolectric.buildActivity(Activity::class.java).setup()
        try {
            val controller = PermissionController(host.get()).apply { activity = host.get() }
            val first = Reply()
            val second = Reply()
            controller.requestPermission(first, false)
            controller.permissionStatus()
            controller.requestPermission(second, false)
            assertEquals("PermissionRequestInProgress", second.error)
            assertEquals(0, first.count)
            controller.onRequestPermissionsResult(
                8856,
                arrayOf(Manifest.permission.READ_MEDIA_AUDIO),
                intArrayOf(PackageManager.PERMISSION_DENIED),
            )
            assertEquals(false, first.value)
            assertEquals(1, first.count)
        } finally {
            host.pause().stop().destroy()
        }
    }

    @Test
    fun deniedRetryAndDetachAlwaysComplete() {
        val host = Robolectric.buildActivity(Activity::class.java).setup()
        try {
            val controller = PermissionController(host.get()).apply { activity = host.get() }
            val denied = Reply()
            controller.requestPermission(denied, true)
            controller.onRequestPermissionsResult(
                8856,
                arrayOf(Manifest.permission.READ_MEDIA_AUDIO),
                intArrayOf(PackageManager.PERMISSION_DENIED),
            )
            assertEquals(false, denied.value)
            assertEquals(1, denied.count)
            val detached = Reply()
            controller.requestPermission(detached, false)
            controller.cancel()
            controller.cancel()
            assertEquals("ActivityDetached", detached.error)
            assertEquals(1, detached.count)
        } finally {
            host.pause().stop().destroy()
        }
    }

    @Test
    fun missingActivityReturnsError() {
        val reply = Reply()
        PermissionController(RuntimeEnvironment.getApplication()).requestPermission(reply, false)
        assertEquals("NoActivity", reply.error)
    }

    @Test
    fun folderNamesAreLiteralAndDoNotMatchOtherPrefixes() {
        assertEquals("/Music/John's 100\\%\\_mix/%", folderPattern("/Music/John's 100%_mix/"))
        assertEquals("/Music/%", folderPattern("/Music"))
    }

    private class Reply : MethodChannel.Result {
        var count = 0
        var value: Any? = null
        var error: String? = null

        override fun success(result: Any?) {
            count++
            value = result
        }

        override fun error(code: String, message: String?, details: Any?) {
            count++
            error = code
        }

        override fun notImplemented() {
            count++
        }
    }
}
