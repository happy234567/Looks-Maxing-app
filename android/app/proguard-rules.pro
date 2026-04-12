# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

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

# In-App Purchase
-keep class com.android.billingclient.** { *; }
-dontwarn com.android.billingclient.**

# Kotlin
-keep class kotlin.** { *; }
-keep class kotlinx.** { *; }
-dontwarn kotlin.**

# Keep crash reporting working
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# Gson / JSON (used by http package)
-keepattributes Signature
-keep class sun.misc.Unsafe { *; }