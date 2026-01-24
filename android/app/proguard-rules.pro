# Flutter specific rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Hive specific rules
-keep class * extends com.hivedb.** { *; }
-keep class * implements com.hivedb.** { *; }

# Keep app models
-keep class com.andygreen.goaliedadtracker.** { *; }

# Play Core library rules
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**
