# Keep rules for plugins that use reflection or JNI and would otherwise be
# broken by R8 shrinking/obfuscation in the release build.

# flutter_secure_storage (Tink-based EncryptedSharedPreferences)
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-keep class com.google.crypto.tink.** { *; }

# local_auth (biometric prompt)
-keep class androidx.biometric.** { *; }

# mobile_scanner (ML Kit barcode scanning)
-keep class com.google.mlkit.vision.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_barcode.** { *; }

# Keep Flutter plugin registrant / embedding classes.
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }

# Flutter's engine references the Play Store "deferred components" API even
# though this app doesn't use deferred/dynamic feature delivery (it's
# sideloaded, not distributed via Play). Those classes genuinely aren't on
# the classpath here, so R8 just needs to be told not to fail on them.
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task
