# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# AndroidX Activity (edge-to-edge)
-keep class androidx.activity.** { *; }
-dontwarn androidx.activity.**

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Firebase Auth
-keepattributes Signature
-keepattributes *Annotation*

# Firestore
-keep class com.google.firestore.** { *; }

# Google Mobile Ads (AdMob)
-keep class com.google.android.gms.ads.** { *; }
-dontwarn com.google.android.gms.ads.**

# Meta Audience Network (Facebook) — AdMob mediation adapter
-keep class com.facebook.ads.** { *; }
-dontwarn com.facebook.ads.**
-keep class com.google.ads.mediation.facebook.** { *; }

# In-App Purchase — keeps BillingClient intact so ProxyBillingActivity doesn't NPE
-keep class com.android.billingclient.** { *; }
-dontwarn com.android.billingclient.**

# Kotlin
-keep class kotlin.** { *; }
-keep class kotlinx.** { *; }
-dontwarn kotlin.**

# Keep crash reporting working
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# ─── FIX: Gson TypeToken crash (Crashes #1 & #2) ────────────────────────────
# R8 strips generic type signatures which breaks Gson's TypeToken.
# flutter_local_notifications uses Gson internally — this keeps it intact.
-keepattributes Signature
-keepattributes EnclosingMethod
-keep class sun.misc.Unsafe { *; }
-keep class com.google.gson.** { *; }
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken { *; }
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken
# ─────────────────────────────────────────────────────────────────────────────

# ─── FIX: flutter_local_notifications scheduled boot receiver ─────────────────
# Keeps the boot receiver and its internal classes so notifications survive reboot
-keep class com.dexterous.** { *; }
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-dontwarn com.dexterous.**
# ─────────────────────────────────────────────────────────────────────────────

# ─── FIX: Google Sign-In SignInHubActivity NPE (Crash #4) ────────────────────
# Keeps Google Sign-In classes from being incorrectly stripped by R8
-keep class com.google.android.gms.auth.** { *; }
-keepnames class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.auth.api.signin.** { *; }
-keepnames class com.google.android.gms.auth.api.signin.** { *; }
-keep class com.google.android.gms.auth.api.signin.internal.** { *; }
-keepnames class com.google.android.gms.auth.api.signin.internal.** { *; }
-keep class com.google.android.gms.common.api.** { *; }
-keepnames class com.google.android.gms.common.api.** { *; }
-keep class com.google.android.gms.auth.api.signin.internal.SignInHubActivity { *; }
# ─────────────────────────────────────────────────────────────────────────────

# Google Play Core / Split Compat
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# Keep Flutter's PlayStoreDeferredComponentManager references intact
-keep class io.flutter.embedding.engine.deferredcomponents.PlayStoreDeferredComponentManager { *; }