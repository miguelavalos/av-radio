package com.avradio.app

import com.avradio.BuildConfig

object AppConfig {
    enum class AuthProvider {
        CLERK,
        DEMO,
        WEB,
        NONE
    }

    val applicationId: String
        get() = BuildConfig.APPLICATION_ID_RUNTIME.trim().ifBlank { BuildConfig.APPLICATION_ID }

    val authProvider: AuthProvider
        get() = when (BuildConfig.AUTH_PROVIDER.trim().lowercase()) {
            "clerk" -> AuthProvider.CLERK
            "demo" -> AuthProvider.DEMO
            "web" -> AuthProvider.WEB
            else -> AuthProvider.NONE
        }

    val clerkPublishableKey: String?
        get() = BuildConfig.CLERK_PUBLISHABLE_KEY.trim().ifBlank { null }

    val premiumProductIds: List<String>
        get() = BuildConfig.PREMIUM_PRODUCT_IDS.split(',')
            .map { it.trim() }
            .filter { it.isNotEmpty() }

    val supportEmail: String?
        get() = BuildConfig.SUPPORT_EMAIL.trim().ifBlank { null }

    val supportUrl: String?
        get() = supportEmail?.let { "mailto:$it?subject=AV%20Radio%20Support" }

    val accountManagementUrl: String?
        get() = BuildConfig.ACCOUNT_MANAGEMENT_URL.trim().ifBlank { null }

    val termsUrl: String?
        get() = BuildConfig.TERMS_URL.trim().ifBlank { null }

    val privacyUrl: String?
        get() = BuildConfig.PRIVACY_URL.trim().ifBlank { null }

    val isPremiumSubscriptionAvailable: Boolean
        get() = premiumProductIds.isNotEmpty()

    val authWebUrl: String?
        get() = BuildConfig.AUTH_WEB_URL.trim().ifBlank { null }

    val authCallbackScheme: String
        get() = BuildConfig.AUTH_CALLBACK_SCHEME.trim().ifBlank { "avradio" }

    val authCallbackHost: String
        get() = BuildConfig.AUTH_CALLBACK_HOST.trim().ifBlank { "auth" }

    val isDemoAuthAvailable: Boolean
        get() = authProvider == AuthProvider.DEMO

    val isClerkAuthAvailable: Boolean
        get() = authProvider == AuthProvider.CLERK && !clerkPublishableKey.isNullOrBlank()

    val isWebAuthAvailable: Boolean
        get() = authProvider == AuthProvider.WEB && !authWebUrl.isNullOrBlank()

    val authCallbackUrlExample: String
        get() = "${authCallbackScheme}://${authCallbackHost}/callback"
}
