package com.avradio.core.designsystem.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val LightColors = lightColorScheme(
    primary = Color(0xFF0F766E),
    onPrimary = Color(0xFFFFFFFF),
    secondary = Color(0xFF1D4ED8),
    background = Color(0xFFF4F7FB),
    onBackground = Color(0xFF111827),
    surface = Color(0xFFFFFFFF),
    onSurface = Color(0xFF111827),
    surfaceVariant = Color(0xFFE5EEF7),
    onSurfaceVariant = Color(0xFF4B5563)
)

private val DarkColors = darkColorScheme(
    primary = Color(0xFF5EEAD4),
    onPrimary = Color(0xFF042F2E),
    secondary = Color(0xFF93C5FD),
    background = Color(0xFF09111F),
    onBackground = Color(0xFFE5EEF7),
    surface = Color(0xFF101826),
    onSurface = Color(0xFFE5EEF7),
    surfaceVariant = Color(0xFF1D293B),
    onSurfaceVariant = Color(0xFF94A3B8)
)

@Composable
fun AvRadioTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit
) {
    MaterialTheme(
        colorScheme = if (darkTheme) DarkColors else LightColors,
        content = content
    )
}
