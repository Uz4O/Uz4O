package top.uzbox.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import top.uzbox.app.ui.home.HomeScreen
import top.uzbox.app.ui.theme.UzBoxTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            UzBoxTheme {
                HomeScreen()
            }
        }
    }
}
