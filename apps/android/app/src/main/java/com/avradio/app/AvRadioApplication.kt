package com.avradio.app

import android.app.Application
import com.clerk.api.Clerk
import com.avradio.core.access.AccessRepository
import com.avradio.core.access.ClerkAccessRepository
import com.avradio.core.access.DataStoreAccessRepository
import com.avradio.core.database.DataStoreLibraryRepository
import com.avradio.core.database.LibraryRepository
import com.avradio.core.network.DefaultStationRepository
import com.avradio.core.network.StationRepository
import com.avradio.core.player.PlaybackManager
import okhttp3.OkHttpClient

class AvRadioApplication : Application() {
    val httpClient: OkHttpClient by lazy { OkHttpClient() }

    val accessRepository: AccessRepository by lazy {
        when (AppConfig.authProvider) {
            AppConfig.AuthProvider.CLERK -> ClerkAccessRepository(applicationContext)
            else -> DataStoreAccessRepository(applicationContext)
        }
    }

    val libraryRepository: LibraryRepository by lazy {
        DataStoreLibraryRepository(applicationContext)
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
