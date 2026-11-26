package com.cloudflypeng.btb

import android.content.res.Configuration
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.cloudflypeng.btb.data.ThemeMode
import com.cloudflypeng.btb.ui.BtbApp
import com.cloudflypeng.btb.ui.theme.BtbTheme

class MainActivity : ComponentActivity() {
    private val pipMode = mutableStateOf(false)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            val container = (application as BtbApplication).container
            val settings by container.settings.state.collectAsStateWithLifecycle()
            val systemDark = isSystemInDarkTheme()
            val darkTheme = when (settings.themeMode) {
                ThemeMode.System -> systemDark
                ThemeMode.Dark -> true
                ThemeMode.Light -> false
            }
            BtbTheme(darkTheme = darkTheme) {
                BtbApp(pipMode = pipMode.value)
            }
        }
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration,
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        pipMode.value = isInPictureInPictureMode
    }
}
