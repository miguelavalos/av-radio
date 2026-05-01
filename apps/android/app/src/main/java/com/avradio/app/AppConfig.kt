package com.avradio.app

import com.avradio.BuildConfig
import okhttp3.HttpUrl
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull

object AppConfig {
    val applicationId: String
        get() = BuildConfig.APPLICATION_ID_RUNTIME.trim().ifBlank { BuildConfig.APPLICATION_ID }

    val clerkPublishableKey: String?
        get() = BuildConfig.AVAPPS_ACCOUNT_PUBLISHABLE_KEY.trim().ifBlank { null }

    val avAppsApiBaseUrl: HttpUrl?
        get() = BuildConfig.AVAPPS_API_BASE_URL.trim().ifBlank { null }?.toHttpUrlOrNull()

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

    val authCallbackScheme: String
        get() = BuildConfig.AUTH_CALLBACK_SCHEME.trim().ifBlank { "avradio" }

    val authCallbackHost: String
        get() = BuildConfig.AUTH_CALLBACK_HOST.trim().ifBlank { "auth" }

    val isClerkAuthAvailable: Boolean
        get() = !clerkPublishableKey.isNullOrBlank()

    val isAvAppsBackendConfigured: Boolean
        get() = avAppsApiBaseUrl != null

    val authCallbackUrlExample: String
        get() = "${authCallbackScheme}://${authCallbackHost}/callback"
}
