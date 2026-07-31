package top.uzbox.app.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable

private val LightColorScheme = lightColorScheme(
    primary = UzBoxText,
    onPrimary = UzBoxSurface,
    secondary = UzBoxAccent,
    onSecondary = UzBoxText,
    background = UzBoxBackground,
    onBackground = UzBoxText,
    surface = UzBoxSurface,
    onSurface = UzBoxText,
    surfaceVariant = UzBoxSoftSurface,
    onSurfaceVariant = UzBoxMuted,
    outline = UzBoxOutline
)

@Composable
fun UzBoxTheme(
    content: @Composable () -> Unit
) {
    MaterialTheme(
        colorScheme = LightColorScheme,
        typography = Typography,
        content = content
    )
}
