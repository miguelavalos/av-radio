package com.avradio.core.network

import com.avradio.core.model.Station
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.IOException
import java.text.Normalizer

class DefaultStationRepository(
    private val client: OkHttpClient,
    private val json: Json = Json { ignoreUnknownKeys = true }
) : StationRepository {
    private val baseUrl = "https://de1.api.radio-browser.info/json/stations/search".toHttpUrl()

    override suspend fun searchStations(filters: StationSearchFilters): List<Station> {
        val trimmedQuery = filters.query.trim()
        val trimmedCountry = filters.country.trim()
        val trimmedCountryCode = filters.countryCode.trim()
        val trimmedLanguage = filters.language.trim()
        val trimmedTag = filters.tag?.trim().orEmpty()

        if (
            !filters.allowsEmptySearch &&
            trimmedQuery.isEmpty() &&
            trimmedCountry.isEmpty() &&
            trimmedCountryCode.isEmpty() &&
            trimmedLanguage.isEmpty() &&
            trimmedTag.isEmpty()
        ) {
            return emptyList()
        }

        val url = baseUrl.newBuilder()
            .addQueryParameter("name", trimmedQuery.ifEmpty { null })
            .addQueryParameter("country", trimmedCountry.ifEmpty { null })
            .addQueryParameter("countrycode", trimmedCountryCode.ifEmpty { null })
            .addQueryParameter("language", trimmedLanguage.ifEmpty { null })
            .addQueryParameter("tag", trimmedTag.ifEmpty { null })
            .addQueryParameter("hidebroken", "true")
            .addQueryParameter("order", "clickcount")
            .addQueryParameter("reverse", "true")
            .addQueryParameter("limit", filters.limit.toString())
            .build()

        val request = Request.Builder()
            .url(url)
            .header("User-Agent", "AVRadio-Android/0.1")
            .build()

        val response = client.newCall(request).execute()
        if (!response.isSuccessful) {
            throw IOException("Radio Browser responded with ${response.code}")
        }

        val body = response.body?.string().orEmpty()
        val stations = json.decodeFromString<List<RadioBrowserStationDto>>(body)
            .mapNotNull { it.toStation() }

        if (trimmedTag.isEmpty()) {
            return stations
        }

        val exactTagMatches = stations.filter { it.matchesTag(trimmedTag) }
        return if (exactTagMatches.isNotEmpty()) exactTagMatches.take(filters.limit) else stations
    }
}

private fun Station.matchesTag(rawTag: String): Boolean {
    val requested = rawTag.normalizedTag()
    if (requested.isBlank()) return false
    return tags.split(",")
        .map { it.normalizedTag() }
        .contains(requested)
}

private fun String.normalizedTag(): String =
    Normalizer.normalize(this, Normalizer.Form.NFD)
        .replace("\\p{InCombiningDiacriticalMarks}+".toRegex(), "")
        .replace("-", " ")
        .trim()
        .lowercase()

@Serializable
private data class RadioBrowserStationDto(
    @SerialName("stationuuid") val stationUuid: String,
    val name: String,
    val country: String? = null,
    @SerialName("countrycode") val countryCode: String? = null,
    val state: String? = null,
    val language: String? = null,
    @SerialName("languagecodes") val languageCodes: String? = null,
    val tags: String? = null,
    val url: String? = null,
    @SerialName("url_resolved") val urlResolved: String? = null,
    val favicon: String? = null,
    val bitrate: Int? = null,
    val codec: String? = null,
    val homepage: String? = null,
    val votes: Int? = null,
    @SerialName("clickcount") val clickCount: Int? = null,
    @SerialName("clicktrend") val clickTrend: Int? = null,
    val hls: Int? = null,
    @SerialName("has_extended_info") val hasExtendedInfo: Boolean? = null,
    @SerialName("ssl_error") val sslError: Int? = null,
    @SerialName("lastcheckoktime_iso8601") val lastCheckOkTime: String? = null,
    @SerialName("geo_lat") val geoLat: Double? = null,
    @SerialName("geo_long") val geoLong: Double? = null,
    @SerialName("lastcheckok") val lastCheckOk: Int? = null
) {
    fun toStation(): Station? {
        val stream = if (!urlResolved.isNullOrBlank()) urlResolved else url
        if (stream.isNullOrBlank()) return null
        if ((lastCheckOk ?: 1) != 1) return null

        return Station(
            id = stationUuid,
            name = name.ifBlank { "Unnamed station" },
            country = country.normalizedOrFallback("Unknown country"),
            countryCode = countryCode.normalizedOrNull(),
            state = state.normalizedOrNull(),
            language = language.normalizedOrFallback("Unknown language"),
            languageCodes = languageCodes.normalizedOrNull(),
            tags = tags.normalizedOrFallback("live"),
            streamUrl = stream,
            faviconUrl = favicon.normalizedOrNull(),
            bitrate = bitrate,
            codec = codec.normalizedOrNull(),
            homepageUrl = homepage.normalizedOrNull(),
            votes = votes,
            clickCount = clickCount,
            clickTrend = clickTrend,
            isHls = hls?.let { it == 1 },
            hasExtendedInfo = hasExtendedInfo,
            hasSslError = sslError?.let { it == 1 },
            lastCheckOkAt = lastCheckOkTime.normalizedOrNull(),
            geoLatitude = geoLat,
            geoLongitude = geoLong
        )
    }
}

private fun String?.normalizedOrNull(): String? = this?.trim()?.takeIf { it.isNotEmpty() }

private fun String?.normalizedOrFallback(fallback: String): String = normalizedOrNull() ?: fallback
