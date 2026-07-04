# Flutter Local Notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Required for Flutter plugins reflection
-keepattributes *Annotation*
-keepattributes Signature

# Keep Flutter engine safe
-keep class io.flutter.** { *; }

# Prevent stripping plugin registrant
-keep class io.flutter.plugins.** { *; }

# 🔥 الحل الأساسي لمشكلتك
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**