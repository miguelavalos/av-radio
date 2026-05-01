package com.avradio.core.access

import android.content.Context
import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.emptyPreferences
import androidx.datastore.preferences.preferencesDataStoreFile
import com.clerk.api.Clerk
import com.clerk.api.network.serialization.ClerkResult
import com.clerk.api.session.GetTokenOptions
import java.io.IOException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch

class ClerkAccessRepository(
    context: Context,
    private val avAppsAccessApi: AVAppsAccessApi
) : AccessRepository {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val dataStore = PreferenceDataStoreFactory.create(
        scope = scope,
        produceFile = { context.preferencesDataStoreFile("avradio_clerk_access.preferences_pb") }
    )

    private val _state = MutableStateFlow(AccessState())
    override val state: StateFlow<AccessState> = _state.asStateFlow()

    init {
        scope.launch {
            combine(
                dataStore.data
                    .catch { error ->
                        if (error is IOException) emit(emptyPreferences()) else throw error
                    }
                    .map { preferences -> preferences[ONBOARDING_SEEN_KEY] ?: false },
                Clerk.userFlow
            ) { onboardingSeen, user ->
                onboardingSeen to user
            }.collectLatest { (onboardingSeen, user) ->
                val accountUser = user?.toAccountUser()
                val resolvedAccess = if (accountUser == null) {
                    ResolvedAccess.guest
                } else {
                    resolveSignedInAccess()
                }
                val state = AccessState(
                    onboardingSeen = onboardingSeen || accountUser != null,
                    mode = resolvedAccess.accessMode,
                    planTier = resolvedAccess.planTier,
                    user = accountUser,
                    capabilities = resolvedAccess.capabilities
                )
                _state.value = state
                if (state.user != null && !state.onboardingSeen) {
                    markOnboardingSeen()
                }
            }
        }
    }

    override suspend fun completeOnboarding() {
        markOnboardingSeen()
    }

    override suspend fun continueAsGuest() {
        markOnboardingSeen()
    }

    override suspend fun signOut() {
        markOnboardingSeen()
        Clerk.auth.signOut()
    }

    private suspend fun markOnboardingSeen() {
        dataStore.edit { prefs ->
            prefs[ONBOARDING_SEEN_KEY] = true
        }
    }

    private suspend fun resolveSignedInAccess(): ResolvedAccess {
        if (!avAppsAccessApi.isConfigured()) {
            return ResolvedAccess.signedInFree
        }

        return avAppsAccessApi.fetchResolvedAccess()
            ?.takeIf { it.capabilities.isSignedIn }
            ?: ResolvedAccess.signedInFree
    }

    private fun Any.toAccountUser(): AccountUser {
        val user = this as com.clerk.api.user.User
        val displayName = listOfNotNull(
            user.firstName?.takeIf { it.isNotBlank() },
            user.lastName?.takeIf { it.isNotBlank() }
        ).joinToString(" ")
            .ifBlank {
                user.username?.takeIf { it.isNotBlank() }
                    ?: user.primaryEmailAddress?.emailAddress?.substringBefore("@")
                    ?: "AV Listener"
            }

        return AccountUser(
            id = user.id,
            displayName = displayName,
            emailAddress = user.primaryEmailAddress?.emailAddress
        )
    }

    companion object {
        private val ONBOARDING_SEEN_KEY = booleanPreferencesKey("onboarding_seen")
    }
}
