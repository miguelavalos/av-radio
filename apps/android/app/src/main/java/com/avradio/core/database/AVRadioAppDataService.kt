package com.avradio.core.database

import com.avradio.core.access.AVAppsAPIClient
import com.avradio.core.model.Station
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

private object AVRadioAppDataConstants {
    const val appId = "avradio"
    const val resource = "library"
    const val deviceId = "avradio-android"
}

data class AVRadioLibraryDocument(
    val snapshot: AVRadioLibrarySnapshot?,
    val updatedAt: String
)

@Serializable
data class AVRadioLibrarySnapshot(
    val favorites: List<FavoriteStationRecord>,
    val recents: List<RecentStationRecord>,
    val settings: AppSettingsRecord
) {
    val hasMeaningfulContent: Boolean
        get() = favorites.isNotEmpty() || recents.isNotEmpty() || settings.hasMeaningfulContent
}

@Serializable
data class FavoriteStationRecord(
    val station: StationRecord,
    val createdAt: String
)

@Serializable
data class RecentStationRecord(
    val station: StationRecord,
    val lastPlayedAt: String
)

@Serializable
data class AppSettingsRecord(
    val preferredCountry: String,
    val preferredLanguage: String,
    val preferredTag: String,
    val lastPlayedStationID: String?,
    val sleepTimerMinutes: Int?,
    val updatedAt: String
) {
    val hasMeaningfulContent: Boolean
        get() = preferredCountry.isNotEmpty() ||
            preferredLanguage.isNotEmpty() ||
            preferredTag.isNotEmpty() ||
            lastPlayedStationID != null ||
            sleepTimerMinutes != null
}

@Serializable
data class StationRecord(
    val id: String,
    val name: String,
    val country: String,
    val countryCode: String? = null,
    val state: String? = null,
    val language: String,
    val languageCodes: String? = null,
    val tags: String,
    @SerialName("streamURL")
    val streamUrl: String,
    @SerialName("faviconURL")
    val faviconUrl: String? = null,
    val bitrate: Int? = null,
    val codec: String? = null,
    @SerialName("homepageURL")
    val homepageUrl: String? = null,
    val votes: Int? = null,
    val clickCount: Int? = null,
    val clickTrend: Int? = null,
    @SerialName("isHLS")
    val isHls: Boolean? = null,
    val hasExtendedInfo: Boolean? = null,
    @SerialName("hasSSLError")
    val hasSslError: Boolean? = null,
    @SerialName("lastCheckOKAt")
    val lastCheckOkAt: String? = null,
    val geoLatitude: Double? = null,
    val geoLongitude: Double? = null
)

@Serializable
private data class AppDataResponsePayload(
    val data: AppDataEnvelopePayload,
    val updatedAt: String
)

@Serializable
private data class AppDataEnvelopePayload(
    val appId: String,
    val resource: String,
    val deviceId: String,
    val sentAt: String,
    val entries: List<AVRadioLibrarySnapshot>
)

class AVRadioAppDataService(
    private val apiClient: AVAppsAPIClient
) {
    fun isConfigured(): Boolean = apiClient.isConfigured()

    suspend fun pullLibrary(): AVRadioLibraryDocument? {
        val payload = apiClient.request(
            path = "/v1/apps/${AVRadioAppDataConstants.appId}/data/${AVRadioAppDataConstants.resource}",
            serializer = AppDataResponsePayload.serializer()
        ) ?: return null

        return AVRadioLibraryDocument(
            snapshot = payload.data.entries.firstOrNull(),
            updatedAt = payload.updatedAt
        )
    }

    suspend fun pushLibrary(snapshot: AVRadioLibrarySnapshot) {
        val envelope = AppDataEnvelopePayload(
            appId = AVRadioAppDataConstants.appId,
            resource = AVRadioAppDataConstants.resource,
            deviceId = AVRadioAppDataConstants.deviceId,
            sentAt = isoString(nowMillis()),
            entries = listOf(snapshot)
        )

        apiClient.request(
            path = "/v1/apps/${AVRadioAppDataConstants.appId}/data/${AVRadioAppDataConstants.resource}",
            serializer = AppDataResponsePayload.serializer(),
            method = "PUT",
            body = apiClient.encodeToString(AppDataEnvelopePayload.serializer(), envelope)
        )
    }

    companion object {
        fun isoString(epochMillis: Long): String = java.time.Instant.ofEpochMilli(epochMillis).toString()

        fun nowMillis(): Long = System.currentTimeMillis()

        fun epochMillis(value: String): Long =
            runCatching { java.time.Instant.parse(value).toEpochMilli() }.getOrDefault(0L)
    }
}

val Station.appDataRecord: StationRecord
    get() = StationRecord(
        id = id,
        name = name,
        country = country,
        countryCode = countryCode,
        state = state,
        language = language,
        languageCodes = languageCodes,
        tags = tags,
        streamUrl = streamUrl,
        faviconUrl = faviconUrl,
        bitrate = bitrate,
        codec = codec,
        homepageUrl = homepageUrl,
        votes = votes,
        clickCount = clickCount,
        clickTrend = clickTrend,
        isHls = isHls,
        hasExtendedInfo = hasExtendedInfo,
        hasSslError = hasSslError,
        lastCheckOkAt = lastCheckOkAt,
        geoLatitude = geoLatitude,
        geoLongitude = geoLongitude
    )

fun Station(record: StationRecord): Station = Station(
    id = record.id,
    name = record.name,
    country = record.country,
    countryCode = record.countryCode,
    state = record.state,
    language = record.language,
    languageCodes = record.languageCodes,
    tags = record.tags,
    streamUrl = record.streamUrl,
    faviconUrl = record.faviconUrl,
    bitrate = record.bitrate,
    codec = record.codec,
    homepageUrl = record.homepageUrl,
    votes = record.votes,
    clickCount = record.clickCount,
    clickTrend = record.clickTrend,
    isHls = record.isHls,
    hasExtendedInfo = record.hasExtendedInfo,
    hasSslError = record.hasSslError,
    lastCheckOkAt = record.lastCheckOkAt,
    geoLatitude = record.geoLatitude,
    geoLongitude = record.geoLongitude
)
