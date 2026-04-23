package com.avradio.core.access

import android.net.Uri
import kotlinx.coroutines.flow.StateFlow

enum class AccessMode {
    GUEST,
    SIGNED_IN_FREE,
    SIGNED_IN_PRO
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

data class AccessCapabilities(
    val isLocalOnly: Boolean,
    val usesBackend: Boolean,
    val canAccessPremiumFeatures: Boolean,
    val canManageAccount: Boolean,
    val canUpgradeToPro: Boolean
) {
    companion object {
        fun forMode(mode: AccessMode): AccessCapabilities = when (mode) {
            AccessMode.GUEST -> AccessCapabilities(
                isLocalOnly = true,
                usesBackend = false,
                canAccessPremiumFeatures = false,
                canManageAccount = false,
                canUpgradeToPro = false
            )

            AccessMode.SIGNED_IN_FREE -> AccessCapabilities(
                isLocalOnly = true,
                usesBackend = false,
                canAccessPremiumFeatures = false,
                canManageAccount = true,
                canUpgradeToPro = true
            )

            AccessMode.SIGNED_IN_PRO -> AccessCapabilities(
                isLocalOnly = false,
                usesBackend = false,
                canAccessPremiumFeatures = true,
                canManageAccount = true,
                canUpgradeToPro = false
            )
        }
    }
}

data class AccessState(
    val onboardingSeen: Boolean = false,
    val mode: AccessMode = AccessMode.GUEST,
    val user: AccountUser? = null
) {
    val capabilities: AccessCapabilities
        get() = AccessCapabilities.forMode(mode)

    val isSignedIn: Boolean
        get() = user != null
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
