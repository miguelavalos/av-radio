package com.avradio.core.player

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.OkHttpClient
import okhttp3.Request
import java.text.Normalizer

data class ResolvedArtwork(
    val albumTitle: String?,
    val artworkUrl: String?
)

class TrackArtworkResolver(
    private val client: OkHttpClient = OkHttpClient(),
    private val json: Json = Json { ignoreUnknownKeys = true }
) {
    fun resolveArtwork(artist: String, title: String): ResolvedArtwork? {
        val trimmedArtist = artist.trim()
        val trimmedTitle = title.trim()
        if (trimmedArtist.isEmpty() || trimmedTitle.isEmpty()) return null

        val url = "https://itunes.apple.com/search".toHttpUrl().newBuilder()
            .addQueryParameter("term", "$trimmedArtist $trimmedTitle")
            .addQueryParameter("entity", "song")
            .addQueryParameter("limit", "8")
            .build()

        val request = Request.Builder()
            .url(url)
            .header("User-Agent", "AVRadio-Android/0.1")
            .build()

        val response = client.newCall(request).execute()
        if (!response.isSuccessful) return null

        val body = response.body?.string().orEmpty()
        val payload = runCatching { json.decodeFromString<ITunesSearchResponse>(body) }.getOrNull() ?: return null
        val best = payload.results.maxByOrNull { matchScore(it, trimmedArtist, trimmedTitle) } ?: return null
        val score = matchScore(best, trimmedArtist, trimmedTitle)
        if (score < 100) return null

        return ResolvedArtwork(
            albumTitle = best.collectionName,
            artworkUrl = best.artworkUrl100?.replace("100x100bb", "600x600bb")
        )
    }

    private fun matchScore(item: ITunesTrack, artist: String, title: String): Int {
        val normalizedArtist = normalize(artist)
        val normalizedTitle = normalize(title)
        val itemArtist = normalize(item.artistName)
        val itemTitle = normalize(item.trackName)

        var score = 0
        if (itemArtist == normalizedArtist) score += 80
        else if (itemArtist.contains(normalizedArtist) || normalizedArtist.contains(itemArtist)) score += 50
        if (itemTitle == normalizedTitle) score += 80
        else if (itemTitle.contains(normalizedTitle) || normalizedTitle.contains(itemTitle)) score += 50
        return score
    }

    private fun normalize(value: String): String =
        Normalizer.normalize(value, Normalizer.Form.NFD)
            .replace("\\p{InCombiningDiacriticalMarks}+".toRegex(), "")
            .replace("[^a-zA-Z0-9]+".toRegex(), " ")
            .trim()
            .lowercase()
}

@Serializable
private data class ITunesSearchResponse(
    val results: List<ITunesTrack>
)

@Serializable
private data class ITunesTrack(
    val artistName: String,
    val trackName: String,
    val collectionName: String? = null,
    @SerialName("artworkUrl100") val artworkUrl100: String? = null
)
