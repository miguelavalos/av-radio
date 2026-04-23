package com.avradio.app

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Surface
import androidx.compose.ui.Modifier
import androidx.lifecycle.lifecycleScope
import com.clerk.api.Clerk
import com.avradio.core.designsystem.theme.AvRadioTheme
import com.avradio.core.player.PlaybackManager
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {
    private val appDependencies: AvRadioApplication
        get() = application as AvRadioApplication

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
        enableEdgeToEdge()
        setContent {
            AvRadioTheme {
                Surface(modifier = Modifier.fillMaxSize()) {
                    AvRadioApp(
                        accessRepository = appDependencies.accessRepository,
                        stationRepository = appDependencies.stationRepository,
                        libraryRepository = appDependencies.libraryRepository,
                        playerController = PlaybackManager.controller
                    )
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        val data = intent?.data ?: return

        if (AppConfig.authProvider == AppConfig.AuthProvider.CLERK && AppConfig.isClerkAuthAvailable) {
            Clerk.auth.handle(data)
            return
        }

        if (data.scheme != AppConfig.authCallbackScheme) return
        if (data.host != AppConfig.authCallbackHost) return
        if (data.path != "/callback") return

        lifecycleScope.launch {
            appDependencies.accessRepository.completeWebSignIn(data)
        }
    }
}
