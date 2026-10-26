# R8 / ProGuard for the Android release build only (minifyEnabled on release).
# GDScript and libgodot.so are not in the DEX. Keep types loaded by name
# (JNI, manifest, JavaClassWrapper). SDK AARs ship their own consumer rules.

-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

-keepclasseswithmembernames,includedescriptorclasses class * {
    native <methods>;
}

-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
}

-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Godot engine. JNI and the plugin registry look these up by name.
-keep class org.godotengine.** { *; }

# App classes Godot instantiates from the manifest or JavaClassWrapper.
-keep class com.godot.game.GodotApp { *; }
-keep class com.godot.game.TapticoHapticsBridge { *; }
-keep class com.godot.game.InAppReviewBridge { *; }

# GodotGooglePlayBilling — manifest value org.godotengine.plugin.googleplaybilling.GodotGooglePlayBilling
-keep class org.godotengine.plugin.googleplaybilling.** { *; }

# InappReviewPlugin — manifest value org.godotengine.plugin.inappreview.InappReviewPlugin
-keep class org.godotengine.plugin.inappreview.** { *; }

-keep class com.google.android.play.core.review.** { *; }

-dontwarn com.android.billingclient.**
-dontwarn com.google.android.play.core.**
-dontwarn org.godotengine.**
