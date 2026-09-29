-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# The Flutter engine references Google Play Core (deferred components /
# split-install) classes that this app does not bundle. Silence R8 warnings
# about them so a shrinking release build won't fail on the missing refs.
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }
