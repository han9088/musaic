package xyz.luan.audioplayers.source

import android.content.ContentProvider
import android.content.ContentValues
import android.content.pm.ProviderInfo
import android.content.res.AssetFileDescriptor
import android.database.Cursor
import android.media.MediaPlayer
import android.net.Uri
import android.os.Looper
import android.os.ParcelFileDescriptor
import java.io.File
import java.io.FileDescriptor
import java.io.FileNotFoundException
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowContentResolver

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [36])
class ContentSourceTest {
    private val app = RuntimeEnvironment.getApplication()
    private val uri = Uri.parse("content://music/tracks/without-path")

    @Test
    fun opensOffMainAndPassesProviderOffsetWithoutCopying() {
        val provider = Provider()
        provider.attachInfo(app, ProviderInfo().apply { authority = "music" })
        ShadowContentResolver.registerProviderInternal("music", provider)
        val loader = ContentSourceLoader(app.contentResolver)
        var result: Result<ContentUriSource>? = null
        try {
            loader.load("player", uri) { result = it }
            await { result != null }
            val source = result!!.getOrThrow()
            assertFalse(provider.openedOnMain)
            val player = RecordingPlayer()
            source.setForMediaPlayer(player)
            assertSame(provider.asset!!.fileDescriptor, player.descriptor)
            assertEquals(4L, player.offset)
            assertEquals(16L, player.length)
            assertEquals(1, provider.opens)
            source.setForMediaPlayer(player) // Re-prepare reuses the descriptor.
            assertEquals(1, provider.opens)
            source.dispose()
            assertFalse(player.descriptor!!.valid())
            player.release()
        } finally {
            loader.dispose()
            provider.file.delete()
        }
    }

    @Test
    fun unknownLengthUsesDescriptorOverload() {
        val file = File.createTempFile("content", ".wav", app.cacheDir)
        val descriptor = ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
        val source = ContentUriSource(AssetFileDescriptor(descriptor, 0, -1))
        val player = RecordingPlayer()
        try {
            source.setForMediaPlayer(player)
            assertSame(descriptor.fileDescriptor, player.descriptor)
            assertNull(player.length)
        } finally {
            source.dispose()
            player.release()
            file.delete()
        }
    }

    @Test
    fun missingAndRevokedResourcesFailWithoutSuccess() {
        for (failure in listOf(FileNotFoundException("gone"), SecurityException("revoked"))) {
            val provider = Provider().apply { error = failure }
            provider.attachInfo(app, ProviderInfo().apply { authority = "music" })
            ShadowContentResolver.registerProviderInternal("music", provider)
            val loader = ContentSourceLoader(app.contentResolver)
            var result: Result<ContentUriSource>? = null
            try {
                loader.load("player", uri) { result = it }
                await { result != null }
                assertEquals(failure.javaClass, result!!.exceptionOrNull()!!.javaClass)
            } finally {
                loader.dispose()
                provider.file.delete()
            }
        }
    }

    @Test
    fun cancellingSlowProviderClosesLateDescriptorAndCompletesOnce() {
        val provider = Provider().apply { blocked = true }
        provider.attachInfo(app, ProviderInfo().apply { authority = "music" })
        ShadowContentResolver.registerProviderInternal("music", provider)
        val loader = ContentSourceLoader(app.contentResolver)
        var replies = 0
        try {
            loader.load("player", uri) {
                replies++
                assertTrue(it.isFailure)
            }
            assertTrue(provider.entered.await(5, TimeUnit.SECONDS))
            loader.cancel("player")
            assertEquals(1, replies)
            provider.proceed.countDown()
            await { provider.asset != null && !provider.asset!!.fileDescriptor.valid() }
            assertEquals(1, replies)
        } finally {
            provider.proceed.countDown()
            loader.dispose()
            provider.file.delete()
        }
    }

    @Test
    fun replacingPendingRequestPublishesOnlyNewestSource() {
        val provider = Provider().apply { blocked = true }
        provider.attachInfo(app, ProviderInfo().apply { authority = "music" })
        ShadowContentResolver.registerProviderInternal("music", provider)
        val loader = ContentSourceLoader(app.contentResolver)
        var oldReplies = 0
        var latest: ContentUriSource? = null
        try {
            loader.load("player", uri) {
                oldReplies++
                assertTrue(it.isFailure)
            }
            assertTrue(provider.entered.await(5, TimeUnit.SECONDS))
            loader.load("player", uri) { latest = it.getOrThrow() }
            provider.proceed.countDown()
            await { latest != null }
            assertEquals(1, oldReplies)
            assertEquals(2, provider.assets.size)
            assertFalse(provider.assets[0].fileDescriptor.valid())
            assertTrue(provider.assets[1].fileDescriptor.valid())
        } finally {
            provider.proceed.countDown()
            latest?.dispose()
            loader.dispose()
            provider.file.delete()
        }
    }

    @Test
    fun pendingQueueIsBoundedAndDisposalCompletesEveryRequest() {
        val provider = Provider().apply { blocked = true }
        provider.attachInfo(app, ProviderInfo().apply { authority = "music" })
        ShadowContentResolver.registerProviderInternal("music", provider)
        val loader = ContentSourceLoader(app.contentResolver)
        var failures = 0
        try {
            loader.load("blocked", uri) {
                assertTrue(it.isFailure)
                failures++
            }
            assertTrue(provider.entered.await(5, TimeUnit.SECONDS))
            repeat(20) { id ->
                loader.load("$id", uri) {
                    assertTrue(it.isFailure)
                    failures++
                }
            }
            assertEquals(4, failures)
            assertEquals(1, provider.opens)
            loader.dispose()
            assertEquals(21, failures)
            provider.proceed.countDown()
            await { provider.asset != null && !provider.asset!!.fileDescriptor.valid() }
            assertEquals(21, failures)
        } finally {
            provider.proceed.countDown()
            loader.dispose()
            provider.file.delete()
        }
    }

    @Test
    fun completedOpensAwaitingDeliveryAlsoCountTowardsLimit() {
        val provider = Provider()
        provider.attachInfo(app, ProviderInfo().apply { authority = "music" })
        ShadowContentResolver.registerProviderInternal("music", provider)
        val loader = ContentSourceLoader(app.contentResolver)
        var replies = 0
        try {
            repeat(17) { id ->
                loader.load("$id", uri) {
                    assertTrue(it.isFailure)
                    replies++
                }
            }
            // Hold the main looper while the worker finishes opening descriptors.
            val deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(5)
            while (provider.assets.size < 17 && System.nanoTime() < deadline) Thread.sleep(5)
            assertEquals(17, provider.assets.size)
            loader.load("overflow", uri) {
                assertTrue(it.isFailure)
                replies++
            }
            assertEquals(1, replies)
            loader.dispose()
            assertEquals(18, replies)
            shadowOf(Looper.getMainLooper()).idle()
            assertTrue(provider.assets.all { !it.fileDescriptor.valid() })
            assertEquals(18, replies)
        } finally {
            loader.dispose()
            provider.file.delete()
        }
    }

    private fun await(done: () -> Boolean) {
        val deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(5)
        while (!done() && System.nanoTime() < deadline) {
            shadowOf(Looper.getMainLooper()).idle()
            Thread.sleep(5)
        }
        assertTrue("Background result did not arrive", done())
    }

    private class RecordingPlayer : MediaPlayer() {
        var descriptor: FileDescriptor? = null
        var offset: Long? = null
        var length: Long? = null

        override fun setDataSource(fd: FileDescriptor) {
            descriptor = fd
        }

        override fun setDataSource(fd: FileDescriptor, offset: Long, length: Long) {
            descriptor = fd
            this.offset = offset
            this.length = length
        }
    }

    private class Provider : ContentProvider() {
        val file =
            File.createTempFile("content", ".wav", RuntimeEnvironment.getApplication().cacheDir)
                .apply { writeBytes(ByteArray(32)) }
        val assets = java.util.concurrent.CopyOnWriteArrayList<AssetFileDescriptor>()
        @Volatile var asset: AssetFileDescriptor? = null
        @Volatile var openedOnMain = true
        @Volatile var opens = 0
        var error: Exception? = null
        var blocked = false
        val entered = CountDownLatch(1)
        val proceed = CountDownLatch(1)

        override fun openAssetFile(uri: Uri, mode: String): AssetFileDescriptor {
            openedOnMain = Looper.myLooper() == Looper.getMainLooper()
            opens++
            entered.countDown()
            if (blocked) {
                // Simulate a provider that ignores cancellation.
                while (proceed.count != 0L) {
                    try {
                        proceed.await()
                    } catch (_: InterruptedException) {}
                }
            }
            error?.let { throw it }
            return AssetFileDescriptor(
                    ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY),
                    4,
                    16,
                )
                .also {
                    asset = it
                    assets.add(it)
                }
        }

        override fun onCreate() = true

        override fun getType(uri: Uri) = "audio/wav"

        override fun query(
            uri: Uri,
            projection: Array<out String>?,
            selection: String?,
            selectionArgs: Array<out String>?,
            sortOrder: String?,
        ): Cursor? = error("No path queries")

        override fun insert(uri: Uri, values: ContentValues?): Uri? = error("Read only")

        override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?) = 0

        override fun update(
            uri: Uri,
            values: ContentValues?,
            selection: String?,
            selectionArgs: Array<out String>?,
        ) = 0
    }
}
