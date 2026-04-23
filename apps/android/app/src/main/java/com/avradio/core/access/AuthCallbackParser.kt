package com.avradio.core.access

import java.net.URI
import java.net.URLDecoder
import java.nio.charset.StandardCharsets

data class ParsedAuthCallback(
    val userId: String,
    val displayName: String,
    val email: String?,
    val mode: AccessMode,
    val code: String?,
    val state: String?
)

object AuthCallbackParser {
    fun parse(rawUri: String, expectedScheme: String, expectedHost: String): ParsedAuthCallback? {
        val uri = runCatching { URI(rawUri) }.getOrNull() ?: return null
        if (uri.scheme != expectedScheme) return null
        if (uri.host != expectedHost) return null
        if (uri.path != "/callback") return null

        val params = parseQuery(uri.rawQuery)
        val userId = params["user_id"]?.trim().orEmpty()
        val displayName = params["name"]?.trim().orEmpty()
        val email = params["email"]?.trim()?.ifBlank { null }
        val mode = when (params["plan"]?.trim()?.lowercase()) {
            "pro" -> AccessMode.SIGNED_IN_PRO
            else -> AccessMode.SIGNED_IN_FREE
        }

        if (userId.isBlank() || displayName.isBlank()) {
            return null
        }

        return ParsedAuthCallback(
            userId = userId,
            displayName = displayName,
            email = email,
            mode = mode,
            code = params["code"]?.trim()?.ifBlank { null },
            state = params["state"]?.trim()?.ifBlank { null }
        )
    }

    private fun parseQuery(rawQuery: String?): Map<String, String> {
        if (rawQuery.isNullOrBlank()) return emptyMap()
        return rawQuery.split("&")
            .mapNotNull { part ->
                val pieces = part.split("=", limit = 2)
                val key = pieces.getOrNull(0)?.decodeQueryPart().orEmpty()
                if (key.isBlank()) return@mapNotNull null
                val value = pieces.getOrNull(1)?.decodeQueryPart().orEmpty()
                key to value
            }
            .toMap()
    }
}

private fun String.decodeQueryPart(): String =
    URLDecoder.decode(this, StandardCharsets.UTF_8)
