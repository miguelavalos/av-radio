package com.avradio.core.model

import kotlinx.serialization.Serializable
import java.net.URLEncoder
import java.nio.charset.StandardCharsets

@Serializable
data class Station(
    val id: String,
    val name: String,
    val country: String,
    val countryCode: String? = null,
    val state: String? = null,
    val language: String,
    val languageCodes: String? = null,
    val tags: String,
    val streamUrl: String,
    val faviconUrl: String? = null,
    val bitrate: Int? = null,
    val codec: String? = null,
    val homepageUrl: String? = null,
    val votes: Int? = null,
    val clickCount: Int? = null,
    val clickTrend: Int? = null,
    val isHls: Boolean? = null,
    val hasExtendedInfo: Boolean? = null,
    val hasSslError: Boolean? = null,
    val lastCheckOkAt: String? = null,
    val geoLatitude: Double? = null,
    val geoLongitude: Double? = null
)

val Station.displayArtworkUrl: String?
    get() {
        faviconUrl?.trim()?.takeIf { it.isNotEmpty() }?.let { return it }

        val homepage = homepageUrl?.trim()?.takeIf { it.isNotEmpty() } ?: return null
        val encodedHomepage = URLEncoder.encode(homepage, StandardCharsets.UTF_8.toString())
        return "https://www.google.com/s2/favicons?sz=256&domain_url=$encodedHomepage"
    }

val Station.initials: String
    get() = name
        .trim()
        .split(Regex("\\s+"))
        .mapNotNull { token -> token.firstOrNull()?.uppercaseChar()?.toString() }
        .take(2)
        .joinToString("")
        .ifBlank { name.take(2).uppercase() }
