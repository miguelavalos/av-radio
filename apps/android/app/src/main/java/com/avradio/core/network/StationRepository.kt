package com.avradio.core.network

import com.avradio.core.model.Station

interface StationRepository {
    suspend fun searchStations(filters: StationSearchFilters): List<Station>
}

data class StationSearchFilters(
    val query: String = "",
    val country: String = "",
    val countryCode: String = "",
    val language: String = "",
    val tag: String? = null,
    val limit: Int = 30,
    val allowsEmptySearch: Boolean = false
)
