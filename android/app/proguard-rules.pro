# Flutter specific ProGuard rules

# Audio Service - keep classes needed for background media notification
-keep class com.ryanheise.audioservice.** { *; }
-dontwarn com.ryanheise.audioservice.**

# Stripe SDK - suppress warnings for push provisioning classes
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivity$g
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Args
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Error
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningEphemeralKeyProvider

# React Native Stripe SDK (referenced by flutter_stripe)
-dontwarn com.reactnativestripesdk.**

# ucrop optional okhttp3 dependency (not bundled)
-dontwarn okhttp3.**
-dontwarn okio.**
