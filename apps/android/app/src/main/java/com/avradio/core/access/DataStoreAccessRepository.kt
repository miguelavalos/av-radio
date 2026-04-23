package com.avradio.core.access

import android.content.Context
import android.net.Uri
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.emptyPreferences
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStoreFile
import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch
import java.io.IOException

class DataStoreAccessRepository(
    context: Context,
    private val authSessionExchange: AuthSessionExchange = LocalAuthSessionExchange()
) : AccessRepository {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val dataStore = PreferenceDataStoreFactory.create(
        scope = scope,
        produceFile = { context.preferencesDataStoreFile("avradio_access.preferences_pb") }
    )

    private val _state = MutableStateFlow(AccessState())
    override val state: StateFlow<AccessState> = _state.asStateFlow()

    init {
        scope.launch {
            dataStore.data
                .catch { error ->
                    if (error is IOException) emit(emptyPreferences()) else throw error
                }
                .map(::toAccessState)
                .collect { _state.value = it }
        }
    }

    override suspend fun completeOnboarding() {
        dataStore.edit { prefs ->
            prefs[ONBOARDING_SEEN_KEY] = true
        }
    }

    override suspend fun continueAsGuest() {
        dataStore.edit { prefs ->
            prefs[ONBOARDING_SEEN_KEY] = true
            prefs[MODE_KEY] = AccessMode.GUEST.name
            prefs.remove(USER_ID_KEY)
            prefs.remove(USER_NAME_KEY)
            prefs.remove(USER_EMAIL_KEY)
        }
    }

    override suspend fun signInDemo() {
        dataStore.edit { prefs ->
            prefs[ONBOARDING_SEEN_KEY] = true
            prefs[MODE_KEY] = AccessMode.SIGNED_IN_FREE.name
            prefs[USER_ID_KEY] = "demo-listener"
            prefs[USER_NAME_KEY] = "AV Listener"
            prefs[USER_EMAIL_KEY] = "listener@avradio.local"
        }
    }

    override suspend fun completeWebSignIn(uri: Uri): Boolean {
        val parsed = AuthCallbackParser.parse(
            rawUri = uri.toString(),
            expectedScheme = "avradio",
            expectedHost = "auth"
        ) ?: return false

        val resolvedSession = authSessionExchange.exchange(parsed) ?: return false

        dataStore.edit { prefs ->
            prefs[ONBOARDING_SEEN_KEY] = true
            prefs[MODE_KEY] = resolvedSession.mode.name
            prefs[USER_ID_KEY] = resolvedSession.user.id
            prefs[USER_NAME_KEY] = resolvedSession.user.displayName
            prefs[USER_EMAIL_KEY] = resolvedSession.user.emailAddress.orEmpty()
        }
        return true
    }

    override suspend fun enableProDemo() {
        dataStore.edit { prefs ->
            prefs[ONBOARDING_SEEN_KEY] = true
            prefs[MODE_KEY] = AccessMode.SIGNED_IN_PRO.name
            if (prefs[USER_ID_KEY].isNullOrBlank()) {
                prefs[USER_ID_KEY] = "demo-listener"
                prefs[USER_NAME_KEY] = "AV Listener"
                prefs[USER_EMAIL_KEY] = "listener@avradio.local"
            }
        }
    }

    override suspend fun disableProDemo() {
        dataStore.edit { prefs ->
            prefs[MODE_KEY] = AccessMode.SIGNED_IN_FREE.name
        }
    }

    override suspend fun signOut() {
        dataStore.edit { prefs ->
            prefs[MODE_KEY] = AccessMode.GUEST.name
            prefs.remove(USER_ID_KEY)
            prefs.remove(USER_NAME_KEY)
            prefs.remove(USER_EMAIL_KEY)
        }
    }

    private fun toAccessState(preferences: Preferences): AccessState {
        val mode = preferences[MODE_KEY]
            ?.let { runCatching { AccessMode.valueOf(it) }.getOrNull() }
            ?: AccessMode.GUEST

        val userId = preferences[USER_ID_KEY]
        val userName = preferences[USER_NAME_KEY]
        val userEmail = preferences[USER_EMAIL_KEY]
        val user = if (!userId.isNullOrBlank() && !userName.isNullOrBlank()) {
            AccountUser(userId, userName, userEmail)
        } else {
            null
        }

        return AccessState(
            onboardingSeen = preferences[ONBOARDING_SEEN_KEY] ?: false,
            mode = mode,
            user = user
        )
    }

    companion object {
        private val ONBOARDING_SEEN_KEY = booleanPreferencesKey("onboarding_seen")
        private val MODE_KEY = stringPreferencesKey("access_mode")
        private val USER_ID_KEY = stringPreferencesKey("user_id")
        private val USER_NAME_KEY = stringPreferencesKey("user_name")
        private val USER_EMAIL_KEY = stringPreferencesKey("user_email")
    }
}
