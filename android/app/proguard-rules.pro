# Flutter / Android release keep rules (R8)
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep Flutter plugin registrants
-keep class * extends io.flutter.embedding.engine.plugins.FlutterPlugin { *; }
-keep class * extends io.flutter.plugin.common.PluginRegistry$PluginRegistrantCallback { *; }

# Play Core / deferred components (safe no-op if unused)
-dontwarn com.google.android.play.core.**

# local_auth / biometric related
-keep class androidx.biometric.** { *; }
-dontwarn androidx.biometric.**

# file_saver / share / pickers often use reflection
-keep class androidx.core.content.FileProvider { *; }

# Suppress common unused warnings from plugins
-dontwarn org.bouncycastle.**
-dontwarn org.conscrypt.**
-dontwarn org.openjsse.**
