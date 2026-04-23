package com.avradio.core.access

import kotlin.test.assertEquals
import kotlin.test.assertNull
import org.junit.Test

class AuthCallbackParserTest {
    @Test
    fun parsesFreeCallback() {
        val parsed = AuthCallbackParser.parse(
            rawUri = "avradio://auth/callback?user_id=123&name=AV%20Listener&email=listener%40example.com",
            expectedScheme = "avradio",
            expectedHost = "auth"
        )

        requireNotNull(parsed)
        assertEquals("123", parsed.userId)
        assertEquals("AV Listener", parsed.displayName)
        assertEquals("listener@example.com", parsed.email)
        assertEquals(AccessMode.SIGNED_IN_FREE, parsed.mode)
    }

    @Test
    fun parsesProCallback() {
        val parsed = AuthCallbackParser.parse(
            rawUri = "avradio://auth/callback?user_id=123&name=AV%20Listener&plan=pro",
            expectedScheme = "avradio",
            expectedHost = "auth"
        )

        requireNotNull(parsed)
        assertEquals(AccessMode.SIGNED_IN_PRO, parsed.mode)
    }

    @Test
    fun rejectsWrongHost() {
        val parsed = AuthCallbackParser.parse(
            rawUri = "avradio://wrong/callback?user_id=123&name=AV%20Listener",
            expectedScheme = "avradio",
            expectedHost = "auth"
        )

        assertNull(parsed)
    }

    @Test
    fun rejectsMissingIdentityFields() {
        val parsed = AuthCallbackParser.parse(
            rawUri = "avradio://auth/callback?name=AV%20Listener",
            expectedScheme = "avradio",
            expectedHost = "auth"
        )

        assertNull(parsed)
    }
}
