# google_mlkit_text_recognition exposes optional non-Latin recognizers as
# compileOnly dependencies. The app only uses Latin OCR for VIN scanning.
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions

# ─── R8/minify keep rules (minify enabled in build.gradle.kts release) ───
# The Flutter Gradle plugin contributes engine keep-rules, but native-bridge
# plugins that resolve classes reflectively need explicit keeps so shrinking
# doesn't strip them. Keep these conservative; widen only if a release build
# crashes with a ClassNotFound / MissingPluginException.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }
-dontwarn io.flutter.embedding.**

# ML Kit text recognition (VIN OCR) — keep the Latin recognizer + barhopper.
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text_common.** { *; }
-dontwarn com.google.mlkit.**

# flutter_secure_storage — uses Android Keystore via reflection-ish lookups.
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# Tink (crypto backing EncryptedSharedPreferences / secure storage).
-keep class com.google.crypto.tink.** { *; }
-dontwarn com.google.crypto.tink.**
