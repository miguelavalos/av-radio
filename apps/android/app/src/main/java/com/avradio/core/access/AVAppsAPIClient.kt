package com.avradio.core.access

import com.avradio.app.AppConfig
import java.io.IOException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.KSerializer
import kotlinx.serialization.json.Json
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody

class AVAppsAPIClient(
    private val httpClient: OkHttpClient,
    private val getToken: suspend () -> String?,
    private val json: Json = Json { ignoreUnknownKeys = true }
) {
    fun isConfigured(): Boolean = AppConfig.isAvAppsBackendConfigured

    suspend fun <T> request(
        path: String,
        serializer: KSerializer<T>,
        method: String = "GET",
        body: String? = null
    ): T? = withContext(Dispatchers.IO) {
        val baseUrl = AppConfig.avAppsApiBaseUrl ?: return@withContext null
        val token = getToken()?.takeIf { it.isNotBlank() } ?: return@withContext null
        val sanitizedPath = path.trimStart('/')
        val url = baseUrl.newBuilder()
            .addPathSegments(sanitizedPath)
            .build()
        val request = Request.Builder()
            .url(url)
            .header("Authorization", "Bearer $token")
            .method(
                method,
                body?.toRequestBody("application/json; charset=utf-8".toMediaType())
            )
            .build()

        runCatching {
            httpClient.newCall(request).execute().use { response ->
                if (!response.isSuccessful) return@use null
                val responseBody = response.body.string()
                if (responseBody.isBlank()) return@use null
                json.decodeFromString(serializer, responseBody)
            }
        }.getOrElse { error ->
            if (error is IOException) null else throw error
        }
    }

    fun <T> encodeToString(serializer: KSerializer<T>, value: T): String {
        return json.encodeToString(serializer, value)
    }
}
