# Suppress missing ML Kit language model classes (Chinese, Japanese, Korean, Devanagari)
# We only use Latin text recognition, so these are safe to ignore.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# Keep ML Kit text recognition classes so R8 doesn't strip them
-keep class com.google.mlkit.vision.text.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text_common.** { *; }
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**
