package com.avradio.core.access

import android.net.Uri
import kotlinx.coroutines.flow.StateFlow
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
enum class AccessMode {
    @SerialName("guest")
    GUEST,

    @SerialName("signedInFree")
    SIGNED_IN_FREE,

    @SerialName("signedInPro")
    SIGNED_IN_PRO
}

@Serializable
enum class PlanTier {
    @SerialName("free")
    FREE,

    @SerialName("pro")
    PRO;

    companion object {
        fun forMode(mode: AccessMode): PlanTier = when (mode) {
            AccessMode.SIGNED_IN_PRO -> PRO
            AccessMode.GUEST, AccessMode.SIGNED_IN_FREE -> FREE
        }
    }
}

data class AccountUser(
    val id: String,
    val displayName: String,
    val emailAddress: String?
) {
    val initials: String
        get() = displayName
            .split(" ")
            .take(2)
            .joinToString("") { it.take(1).uppercase() }
            .ifBlank { "AV" }
}

@Serializable
data class AccessCapabilities(
    val isSignedIn: Boolean,
    val canUseBackend: Boolean,
    @SerialName("canUsePremiumFeatures")
    val canAccessPremiumFeatures: Boolean,
    val canUseCloudSync: Boolean,
    val canManagePlan: Boolean
) {
    val isLocalOnly: Boolean
        get() = !canUseBackend && !canUseCloudSync

    val usesBackend: Boolean
        get() = canUseBackend || canUseCloudSync

    val canManageAccount: Boolean
        get() = isSignedIn

    val canUpgradeToPro: Boolean
        get() = isSignedIn && !canAccessPremiumFeatures

    companion object {
        fun forMode(mode: AccessMode): AccessCapabilities = when (mode) {
            AccessMode.GUEST -> AccessCapabilities(
                isSignedIn = false,
                canUseBackend = false,
                canAccessPremiumFeatures = false,
                canUseCloudSync = false,
                canManagePlan = false
            )

            AccessMode.SIGNED_IN_FREE -> AccessCapabilities(
                isSignedIn = true,
                canUseBackend = false,
                canAccessPremiumFeatures = false,
                canUseCloudSync = false,
                canManagePlan = true
            )

            AccessMode.SIGNED_IN_PRO -> AccessCapabilities(
                isSignedIn = true,
                canUseBackend = true,
                canAccessPremiumFeatures = true,
                canUseCloudSync = true,
                canManagePlan = true
            )
        }
    }
}

data class ResolvedAccess(
    val planTier: PlanTier,
    val accessMode: AccessMode,
    val capabilities: AccessCapabilities
) {
    companion object {
        val guest = ResolvedAccess(
            planTier = PlanTier.FREE,
            accessMode = AccessMode.GUEST,
            capabilities = AccessCapabilities.forMode(AccessMode.GUEST)
        )

        val signedInFree = ResolvedAccess(
            planTier = PlanTier.FREE,
            accessMode = AccessMode.SIGNED_IN_FREE,
            capabilities = AccessCapabilities.forMode(AccessMode.SIGNED_IN_FREE)
        )
    }
}

data class AccessState(
    val onboardingSeen: Boolean = false,
    val mode: AccessMode = AccessMode.GUEST,
    val planTier: PlanTier = PlanTier.forMode(mode),
    val user: AccountUser? = null,
    val capabilities: AccessCapabilities = AccessCapabilities.forMode(mode)
) {

    val isSignedIn: Boolean
        get() = capabilities.isSignedIn
}

interface AccessRepository {
    val state: StateFlow<AccessState>

    suspend fun completeOnboarding()
    suspend fun continueAsGuest()
    suspend fun signInDemo()
    suspend fun completeWebSignIn(uri: Uri): Boolean
    suspend fun enableProDemo()
    suspend fun disableProDemo()
    suspend fun signOut()
}
