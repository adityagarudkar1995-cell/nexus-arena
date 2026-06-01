# Razorpay SDK keep rules (required when R8/ProGuard minification is enabled).
# Razorpay drives checkout through a WebView + JS bridge; stripping these
# classes or annotations causes runtime crashes during payment.
-keep class com.razorpay.** { *; }
-keepattributes JavascriptInterface
-keepattributes *Annotation*
-dontwarn com.razorpay.**
-optimizations !method/inlining/*
-keepclasseswithmembers class * {
  public void onPayment*(...);
}
