# Suppress missing ML Kit language model classes (Chinese, Japanese, Korean, Devanagari)
# We only use Latin text recognition, so these are safe to ignore.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
