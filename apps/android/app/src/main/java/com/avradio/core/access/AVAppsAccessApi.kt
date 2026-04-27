package com.avradio.core.access

import kotlinx.serialization.Serializable

class AVAppsAccessApi(
    private val apiClient: AVAppsAPIClient
) {
    fun isConfigured(): Boolean = apiClient.isConfigured()

    suspend fun fetchResolvedAccess(): ResolvedAccess? {
        val payload = apiClient.request(
            path = "/v1/me/access",
            serializer = MeAccessResponse.serializer()
        ) ?: return null
        val appAccess = payload.apps.firstOrNull { it.appId == "avradio" } ?: return null
        return ResolvedAccess(
            planTier = appAccess.planTier,
            accessMode = appAccess.accessMode,
            capabilities = appAccess.capabilities
        )
    }
}

@Serializable
private data class MeAccessResponse(
    val apps: List<AppAccessPayload>
)

@Serializable
private data class AppAccessPayload(
    val appId: String,
    val accessMode: AccessMode,
    val planTier: PlanTier,
    val capabilities: AccessCapabilities
)
