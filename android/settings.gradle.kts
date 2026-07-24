pluginManagement {
    val flutterSdk = java.util.Properties().apply {
        val localProperties = file("local.properties")
        if (localProperties.exists()) {
            localProperties.inputStream().use { load(it) }
        }
    }.getProperty("flutter.sdk") ?: System.getenv("FLUTTER_ROOT")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }

    includeBuild("$flutterSdk/packages/flutter_tools/gradle")
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}
include(":app")