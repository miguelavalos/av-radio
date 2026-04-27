package com.avradio.app

import android.app.Application
import com.clerk.api.Clerk
import com.clerk.api.network.serialization.ClerkResult
import com.clerk.api.session.GetTokenOptions
import com.avradio.core.access.AccessRepository
import com.avradio.core.access.AVAppsAccessApi
import com.avradio.core.access.AVAppsAPIClient
import com.avradio.core.access.ClerkAccessRepository
import com.avradio.core.access.DataStoreAccessRepository
import com.avradio.core.database.AVRadioAppDataService
import com.avradio.core.database.DataStoreLibraryRepository
import com.avradio.core.database.LibraryRepository
import com.avradio.core.network.DefaultStationRepository
import com.avradio.core.network.StationRepository
import com.avradio.core.player.PlaybackManager
import okhttp3.OkHttpClient

class AvRadioApplication : Application() {
    val httpClient: OkHttpClient by lazy { OkHttpClient() }
    val avAppsApiClient: AVAppsAPIClient by lazy {
        AVAppsAPIClient(
            httpClient = httpClient,
            getToken = {
                when (val result = Clerk.auth.getToken(GetTokenOptions())) {
                    is ClerkResult.Success -> result.value
                    is ClerkResult.Failure -> null
                }?.takeIf { it.isNotBlank() }
            }
        )
    }

    val accessRepository: AccessRepository by lazy {
        when (AppConfig.authProvider) {
            AppConfig.AuthProvider.CLERK -> ClerkAccessRepository(
                applicationContext,
                AVAppsAccessApi(avAppsApiClient)
            )
            else -> DataStoreAccessRepository(applicationContext)
        }
    }

    val libraryRepository: LibraryRepository by lazy {
        DataStoreLibraryRepository(
            context = applicationContext,
            accessRepository = accessRepository,
            appDataService = AVRadioAppDataService(avAppsApiClient)
        )
    }

    val stationRepository: StationRepository by lazy {
        DefaultStationRepository(httpClient)
    }

    override fun onCreate() {
        super.onCreate()
        AppConfig.clerkPublishableKey?.let { publishableKey ->
            Clerk.initialize(this, publishableKey = publishableKey)
        }
        PlaybackManager.initialize(this)
    }
}
