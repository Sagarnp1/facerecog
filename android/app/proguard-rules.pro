# Add project specific ProGuard rules here.
# By default, the flags in this file are appended to flags specified
# in C:\android-sdk/tools/proguard/proguard-android.txt
# You can edit the include path and order by changing the proguardFiles
# directive in build.gradle.
#
# For more details, see
#   http://developer.android.com/guide/developing/tools/proguard.html

# Add any project specific keep options here:

# If your project uses WebView with JS, uncomment the following
# and specify the fully qualified class name to the JavaScript interface
# class:
#-keepclassmembers class fqcn.of.javascript.interface.for.webview {
#   public *;
#}

# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Face Detection
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# Dart/Flutter
-keep class ** implements io.flutter.plugin.common.MethodChannel$MethodCallHandler { *; }
-keep class com.google.android.gms.** { *; }

# ML Kit
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.vision.** { *; }

# Play Core - allow missing classes since we're not using dynamic delivery
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# Flutter specific
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.** { *; }

# Camera plugin
-keep class io.flutter.plugins.camera.** { *; }

# Provider
-keep class ** extends androidx.lifecycle.ViewModel { *; }

# ML Kit Text Recognition - handle missing language modules gracefully
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# Allow reflection for ML Kit
-keepclassmembers class * {
    @com.google.android.gms.common.annotation.KeepForSdk <methods>;
}

# Preserve generic signatures for ML Kit
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses
