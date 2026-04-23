package com.avradio.core.access

data class ResolvedAuthSession(
    val user: AccountUser,
    val mode: AccessMode
)

interface AuthSessionExchange {
    suspend fun exchange(callback: ParsedAuthCallback): ResolvedAuthSession?
}

class LocalAuthSessionExchange : AuthSessionExchange {
    override suspend fun exchange(callback: ParsedAuthCallback): ResolvedAuthSession? {
        if (callback.userId.isBlank() || callback.displayName.isBlank()) return null
        return ResolvedAuthSession(
            user = AccountUser(
                id = callback.userId,
                displayName = callback.displayName,
                emailAddress = callback.email
            ),
            mode = callback.mode
        )
    }
}
