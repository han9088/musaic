package com.deskbtm.apple_music_kit

import org.junit.Assert.assertEquals
import org.junit.Test

class AppleMusicApiTest {
    @Test fun httpFailuresKeepTheirMeaning() {
        val expected = mapOf(
            401 to "authenticationFailed", 403 to "authorizationDenied",
            404 to "resourceNotFound", 408 to "requestTimeout",
            409 to "resourceUnavailable", 410 to "resourceUnavailable",
            429 to "rateLimited", 500 to "networkError", 503 to "networkError",
            302 to "unknown", 400 to "unknown"
        )
        expected.forEach { (status, code) ->
            assertEquals("HTTP $status", code, AppleMusicApi.httpErrorCode(status))
        }
    }
}
