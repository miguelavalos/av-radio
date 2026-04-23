package com.avradio.core.datastore

data class AppPreferences(
    val preferredCountry: String = "",
    val preferredTag: String = "",
    val lastPlayedStationId: String? = null,
    val sleepTimerMinutes: Int? = null
)
