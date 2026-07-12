# Flutter's Gradle plugin ships the core keep rules for the engine and the
# generated plugin registrant. These entries silence R8 warnings and keep
# classes that release-mode shrinking might otherwise strip.

# Play Core / deferred components (referenced by Flutter, not used by this app).
-dontwarn com.google.android.play.core.**

# pdfx: keep the whole plugin (Kotlin, uses the platform PdfRenderer + coroutines).
-keep class io.scer.** { *; }
-dontwarn io.scer.**

# Kotlin coroutines used by pdfx.
-keep class kotlinx.coroutines.** { *; }
-dontwarn kotlinx.coroutines.**
-keepclassmembers class kotlinx.coroutines.** { volatile <fields>; }
