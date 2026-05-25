package com.levelmaxing.app

import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Opt in to edge-to-edge display for Android 15+ (SDK 35) backward compatibility.
        // Flutter already handles system insets via SafeArea widgets, so this is safe.
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
    }
}
