# Flutter & Android ProGuard Rules for LockLeaf Production Release

# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Cryptography primitives & native bindings
-keep class com.cryptography.** { *; }
-dontwarn com.cryptography.**

# SQLite database (sqflite)
-keep class com.tekartik.sqflite.** { *; }
-dontwarn com.tekartik.sqflite.**

# Hardware Keystore (flutter_secure_storage)
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-dontwarn com.it_nomads.fluttersecurestorage.**

# Biometric Authentication (local_auth & AndroidX Biometrics)
-keep class io.flutter.plugins.localauth.** { *; }
-keep class androidx.biometric.** { *; }
-dontwarn androidx.biometric.**

# General attributes preservation for type-safe reflection
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod

# Flutter deferred components & Play Core warnings
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**
