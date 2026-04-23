package com.avradio.core.access

import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlinx.coroutines.test.runTest
import org.junit.Test

class LocalAuthSessionExchangeTest {
    private val exchange = LocalAuthSessionExchange()

    @Test
    fun resolvesSessionFromParsedCallback() = runTest {
        val session = exchange.exchange(
            ParsedAuthCallback(
                userId = "123",
                displayName = "AV Listener",
                email = "listener@example.com",
                mode = AccessMode.SIGNED_IN_PRO,
                code = "abc",
                state = "xyz"
            )
        )

        assertNotNull(session)
        assertEquals("123", session.user.id)
        assertEquals("AV Listener", session.user.displayName)
        assertEquals("listener@example.com", session.user.emailAddress)
        assertEquals(AccessMode.SIGNED_IN_PRO, session.mode)
    }

    @Test
    fun rejectsMissingIdentity() = runTest {
        val session = exchange.exchange(
            ParsedAuthCallback(
                userId = "",
                displayName = "",
                email = null,
                mode = AccessMode.SIGNED_IN_FREE,
                code = null,
                state = null
            )
        )

        assertNull(session)
    }
}
