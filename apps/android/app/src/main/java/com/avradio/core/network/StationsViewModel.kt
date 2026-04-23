package com.avradio.core.network

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.avradio.core.model.Station
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

data class HomeUiState(
    val isLoading: Boolean = false,
    val stations: List<Station> = emptyList(),
    val errorMessage: String? = null
)

data class SearchUiState(
    val isLoading: Boolean = false,
    val stations: List<Station> = emptyList(),
    val errorMessage: String? = null
)

class StationsViewModel(
    private val stationRepository: StationRepository
) : ViewModel() {
    private val _homeState = MutableStateFlow(HomeUiState())
    val homeState: StateFlow<HomeUiState> = _homeState.asStateFlow()

    private val _searchState = MutableStateFlow(SearchUiState())
    val searchState: StateFlow<SearchUiState> = _searchState.asStateFlow()

    fun loadHome() {
        if (_homeState.value.isLoading) return

        viewModelScope.launch {
            _homeState.value = _homeState.value.copy(isLoading = true, errorMessage = null)
            runCatching {
                withContext(Dispatchers.IO) {
                    stationRepository.searchStations(
                        StationSearchFilters(
                            limit = 24,
                            allowsEmptySearch = true
                        )
                    )
                }
            }.onSuccess { stations ->
                _homeState.value = HomeUiState(stations = stations)
            }.onFailure { error ->
                _homeState.value = HomeUiState(errorMessage = error.message ?: "Unexpected error")
            }
        }
    }

    fun search(filters: StationSearchFilters) {
        viewModelScope.launch {
            _searchState.value = _searchState.value.copy(isLoading = true, errorMessage = null)
            runCatching {
                withContext(Dispatchers.IO) {
                    stationRepository.searchStations(filters.copy(limit = 30))
                }
            }.onSuccess { stations ->
                _searchState.value = SearchUiState(stations = stations)
            }.onFailure { error ->
                _searchState.value = SearchUiState(errorMessage = error.message ?: "Unexpected error")
            }
        }
    }

    companion object {
        fun factory(
            stationRepository: StationRepository
        ): ViewModelProvider.Factory = object : ViewModelProvider.Factory {
            @Suppress("UNCHECKED_CAST")
            override fun <T : ViewModel> create(modelClass: Class<T>): T {
                return StationsViewModel(stationRepository) as T
            }
        }
    }
}
