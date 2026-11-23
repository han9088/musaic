package xyz.luan.audioplayers.source

import android.content.ContentResolver
import android.net.Uri
import android.os.CancellationSignal
import android.os.Handler
import android.os.Looper
import java.io.FileNotFoundException
import java.util.concurrent.ArrayBlockingQueue
import java.util.concurrent.CancellationException
import java.util.concurrent.Future
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.TimeUnit

/** Provider I/O runs separately from the Looper that owns the players and requests. */
internal class ContentSourceLoader(
    private val resolver: ContentResolver,
    private val owner: Handler = Handler(Looper.getMainLooper()),
) {
    private val worker = ThreadPoolExecutor(1, 1, 0, TimeUnit.SECONDS, ArrayBlockingQueue(16))
    private val pending = mutableMapOf<String, Request>()

    private class Request(val complete: (Result<ContentUriSource>) -> Unit) {
        val signal = CancellationSignal()
        var task: Future<*>? = null
    }

    fun load(id: String, uri: Uri, complete: (Result<ContentUriSource>) -> Unit) {
        cancel(id)
        // Include completed opens awaiting delivery in the bound.
        if (pending.size >= 17) {
            complete(
                Result.failure(
                    java.util.concurrent.RejectedExecutionException("Content source queue full")
                )
            )
            return
        }
        val request = Request(complete)
        pending[id] = request
        try {
            request.task =
                worker.submit {
                    val result = runCatching {
                        request.signal.throwIfCanceled()
                        val asset =
                            resolver.openAssetFileDescriptor(uri, "r", request.signal)
                                ?: throw FileNotFoundException(
                                    "Provider returned no descriptor for $uri"
                                )
                        ContentUriSource(asset)
                    }
                    val posted =
                        owner.post {
                            if (pending[id] !== request) {
                                result.getOrNull()?.dispose()
                            } else {
                                pending.remove(id)
                                request.complete(result)
                            }
                        }
                    // The engine can detach while the provider is still opening the file.
                    if (!posted) result.getOrNull()?.dispose()
                }
        } catch (error: Exception) {
            pending.remove(id)
            complete(Result.failure(error))
        }
    }

    fun cancel(id: String) {
        val request = pending.remove(id) ?: return
        request.signal.cancel()
        request.task?.cancel(true)
        worker.purge()
        request.complete(Result.failure(CancellationException("Content source request cancelled")))
    }

    fun cancelAll() {
        pending.keys.toList().forEach(::cancel)
    }

    fun dispose() {
        cancelAll()
        worker.shutdownNow()
    }
}
