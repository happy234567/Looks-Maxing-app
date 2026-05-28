package com.levelmaxing.app

import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import androidx.activity.enableEdgeToEdge
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Opt in to edge-to-edge display for Android 15+ (SDK 35) backward compatibility.
        // Flutter already handles system insets via SafeArea widgets, so this is safe.
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)

        // Tell the system this window handles insets itself (the modern replacement
        // for the deprecated setStatusBarColor / setNavigationBarColor APIs).
        WindowCompat.setDecorFitsSystemWindows(window, false)

        // On Android 15+ (SDK 35), ensure the display cutout mode uses the modern
        // ALWAYS constant instead of the deprecated SHORT_EDGES.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.attributes.layoutInDisplayCutoutMode =
                WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS
        }
    }
}
