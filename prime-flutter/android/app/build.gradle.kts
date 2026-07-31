import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val fcmEnabled = file("google-services.json").exists()
if (fcmEnabled) {
    apply(plugin = "com.google.gms.google-services")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.prime.prime"
    // Current Android plugins require API 36 metadata at compile time. This
    // does not change minSdk or the set of devices that can install the app.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        buildConfig = true
    }

    defaultConfig {
        // Must match package_name in android/app/google-services.json (Firebase Android app).
        applicationId = "inpr1me.ru"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        buildConfigField("boolean", "FCM_ENABLED", fcmEnabled.toString())
    }

    sourceSets {
        getByName("main") {
            java.srcDir(if (fcmEnabled) "src/fcm/kotlin" else "src/nofcm/kotlin")
        }
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }

}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    if (fcmEnabled) {
        implementation(platform("com.google.firebase:firebase-bom:34.17.0"))
        implementation("com.google.firebase:firebase-messaging")
        implementation("androidx.core:core-ktx:1.15.0")
    }
}

flutter {
    source = "../.."
}
