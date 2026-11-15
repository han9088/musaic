package xyz.luan.audioplayers.player

import android.content.res.AssetFileDescriptor
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.ParcelFileDescriptor
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec
import java.io.File
import java.lang.reflect.Proxy
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.util.ReflectionHelpers
import xyz.luan.audioplayers.AudioContextAndroid
import xyz.luan.audioplayers.AudioplayersPlugin
import xyz.luan.audioplayers.EventHandler
import xyz.luan.audioplayers.source.ContentUriSource

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [36])
class SourceOwnershipTest {
    private class Harness {
        var failPrepare = false
        var failRelease = false
        var releases = 0
        val plugin = AudioplayersPlugin()
        private val messenger =
            Proxy.newProxyInstance(
                BinaryMessenger::class.java.classLoader,
                arrayOf(BinaryMessenger::class.java),
            ) { _, _, _ ->
                null
            } as BinaryMessenger
        val owner =
            WrappedPlayer(
                plugin,
                EventHandler(EventChannel(messenger, "test")),
                AudioContextAndroid().copy(audioFocus = AudioManager.AUDIOFOCUS_NONE),
                SoundPoolManager(plugin),
            )
        private val backend =
            Proxy.newProxyInstance(
                PlayerWrapper::class.java.classLoader,
                arrayOf(PlayerWrapper::class.java),
            ) { _, method, _ ->
                when (method.name) {
                    "prepare" -> {
                        check(!failPrepare) { "prepare failed" }
                        null
                    }
                    "release" -> {
                        releases++
                        check(!failRelease) { "release failed" }
                        null
                    }
                    "getDuration",
                    "getCurrentPosition" -> 0
                    "isLiveStream" -> false
                    else -> null
                }
            } as PlayerWrapper

        init {
            WrappedPlayer::class
                .java
                .getDeclaredField("player")
                .apply { isAccessible = true }
                .set(owner, backend)
            owner.released = false
        }
    }

    private fun asset(): AssetFileDescriptor {
        val file =
            File.createTempFile("ownership", ".wav", RuntimeEnvironment.getApplication().cacheDir)
        val fd = ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
        file.delete()
        return AssetFileDescriptor(fd, 0, -1)
    }

    @Test
    fun nativeFailuresProduceOneSerializableErrorResponse() {
        var replies = 0
        val response =
            object : MethodChannel.Result {
                override fun success(result: Any?) = error("Unexpected success")

                override fun notImplemented() = error("Unexpected missing method")

                override fun error(code: String, message: String?, details: Any?) {
                    StandardMethodCodec.INSTANCE.encodeErrorEnvelope(code, message, details)
                    assertEquals("SecurityException", details)
                    replies++
                }
            }
        val handler: (MethodCall, MethodChannel.Result) -> Unit = { _, _ ->
            throw SecurityException("revoked")
        }
        AudioplayersPlugin::class
            .java
            .declaredMethods
            .single { it.name == "safeCall" }
            .apply { isAccessible = true }
            .invoke(AudioplayersPlugin(), MethodCall("test", null), response, handler)
        assertEquals(1, replies)
    }

    @Test
    fun mediaPlayerReleaseRunsEvenIfResetFails() {
        val harness = Harness()
        val wrapper = MediaPlayerWrapper(harness.owner)
        val original = ReflectionHelpers.getField<MediaPlayer>(wrapper, "mediaPlayer")
        original.release()
        val broken =
            object : MediaPlayer() {
                var closed = false

                override fun reset() {
                    error("reset failed")
                }

                override fun release() {
                    closed = true
                    super.release()
                }
            }
        ReflectionHelpers.setField(wrapper, "mediaPlayer", broken)
        assertThrows(IllegalStateException::class.java) { wrapper.release() }
        assertTrue(broken.closed)
        harness.owner.dispose()
    }

    @Test
    fun releasedPlayerCannotDeliverPreparedOrCompletionToCurrentOwner() {
        val harness = Harness()
        val wrapper = MediaPlayerWrapper(harness.owner)
        val native = ReflectionHelpers.getField<MediaPlayer>(wrapper, "mediaPlayer")
        val prepared = shadowOf(native).onPreparedListener
        val complete = shadowOf(native).onCompletionListener
        wrapper.release()
        val descriptor = asset()
        harness.owner.source = ContentUriSource(descriptor)
        prepared.onPrepared(native)
        complete.onCompletion(native)
        assertFalse(harness.owner.prepared)
        assertTrue(descriptor.fileDescriptor.valid())
        harness.owner.dispose()
    }

    @Test
    fun replacingThenReleasingClosesEveryOwnedDescriptor() {
        val harness = Harness()
        val first = asset()
        val second = asset()
        harness.owner.source = ContentUriSource(first)
        harness.owner.source = ContentUriSource(second)
        assertFalse(first.fileDescriptor.valid())
        assertTrue(second.fileDescriptor.valid())
        harness.owner.release()
        assertFalse(second.fileDescriptor.valid())
        harness.owner.dispose()
        assertEquals(1, harness.releases)
    }

    @Test
    fun preparationFailureClosesBothSourcesAndReleasesBackend() {
        val harness = Harness()
        val first = asset()
        val second = asset()
        harness.owner.source = ContentUriSource(first)
        harness.failPrepare = true
        assertThrows(IllegalStateException::class.java) {
            harness.owner.source = ContentUriSource(second)
        }
        assertFalse(first.fileDescriptor.valid())
        assertFalse(second.fileDescriptor.valid())
        assertNull(harness.owner.source)
        assertTrue(harness.owner.released)
        assertEquals(1, harness.releases)
        harness.owner.dispose()
    }

    @Test
    fun releaseFailureCannotRetainDescriptorOrSource() {
        val harness = Harness()
        val descriptor = asset()
        harness.owner.source = ContentUriSource(descriptor)
        harness.failRelease = true
        assertThrows(IllegalStateException::class.java) { harness.owner.release() }
        assertFalse(descriptor.fileDescriptor.valid())
        assertNull(harness.owner.source)
        assertTrue(harness.owner.released)
        harness.owner.dispose()
    }
}
