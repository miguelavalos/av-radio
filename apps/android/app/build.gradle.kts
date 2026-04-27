plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
    id("org.jetbrains.kotlin.plugin.serialization")
}

import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import java.util.Properties

val localProperties = Properties().apply {
    val file = rootProject.file("local.properties")
    if (file.exists()) {
        file.inputStream().use(::load)
    }
}

fun configValue(name: String, defaultValue: String = ""): String {
    return providers.environmentVariable(name)
        .orElse(localProperties.getProperty(name) ?: defaultValue)
        .get()
}

fun buildConfigString(name: String, defaultValue: String = ""): String {
    val value = configValue(name, defaultValue)
        .replace("\\", "\\\\")
        .replace("\"", "\\\"")
    return "\"$value\""
}

android {
    namespace = "com.avradio"
    compileSdk = 36

    defaultConfig {
        applicationId = configValue("AVRADIO_APPLICATION_ID", "com.avalsys.avradio.dev")
        minSdk = 28
        targetSdk = 35
        versionCode = 1
        versionName = "0.1.0"

        buildConfigField("String", "APPLICATION_ID_RUNTIME", buildConfigString("AVRADIO_APPLICATION_ID", "com.avalsys.avradio.dev"))
        buildConfigField("String", "AUTH_PROVIDER", buildConfigString("AVRADIO_AUTH_PROVIDER", "clerk"))
        buildConfigField("String", "AUTH_WEB_URL", buildConfigString("AVRADIO_AUTH_WEB_URL", ""))
        buildConfigField("String", "AUTH_CALLBACK_SCHEME", buildConfigString("AVRADIO_AUTH_CALLBACK_SCHEME", "avradio"))
        buildConfigField("String", "AUTH_CALLBACK_HOST", buildConfigString("AVRADIO_AUTH_CALLBACK_HOST", "auth"))
        buildConfigField("String", "CLERK_PUBLISHABLE_KEY", buildConfigString("CLERK_PUBLISHABLE_KEY", ""))
        buildConfigField("String", "AVAPPS_API_BASE_URL", buildConfigString("AVAPPS_API_BASE_URL", ""))
        buildConfigField("String", "PREMIUM_PRODUCT_IDS", buildConfigString("AVRADIO_PREMIUM_PRODUCT_IDS", ""))
        buildConfigField("String", "SUPPORT_EMAIL", buildConfigString("AVRADIO_SUPPORT_EMAIL", ""))
        buildConfigField("String", "ACCOUNT_MANAGEMENT_URL", buildConfigString("AVRADIO_ACCOUNT_MANAGEMENT_URL", ""))
        buildConfigField("String", "TERMS_URL", buildConfigString("AVRADIO_TERMS_URL", ""))
        buildConfigField("String", "PRIVACY_URL", buildConfigString("AVRADIO_PRIVACY_URL", ""))

        manifestPlaceholders["authCallbackScheme"] = configValue("AVRADIO_AUTH_CALLBACK_SCHEME", "avradio")
        manifestPlaceholders["authCallbackHost"] = configValue("AVRADIO_AUTH_CALLBACK_HOST", "auth")

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        vectorDrawables.useSupportLibrary = true
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlin {
        compilerOptions {
            jvmTarget.set(JvmTarget.JVM_17)
        }
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
            excludes += "META-INF/versions/9/OSGI-INF/MANIFEST.MF"
        }
    }
}

dependencies {
    val composeBom = platform("androidx.compose:compose-bom:2025.01.01")

    implementation(composeBom)
    androidTestImplementation(composeBom)

    implementation("androidx.core:core-ktx:1.15.0")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.7")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.8.7")
    implementation("androidx.activity:activity-compose:1.10.0")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-graphics")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")
    implementation("com.google.android.material:material:1.12.0")
    implementation("androidx.navigation:navigation-compose:2.8.5")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.7")
    implementation("androidx.lifecycle:lifecycle-viewmodel-ktx:2.8.7")
    implementation("androidx.datastore:datastore-preferences:1.1.1")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.2")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.10.0")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("io.coil-kt.coil3:coil-compose:3.0.4")
    implementation("com.clerk:clerk-android-api:1.0.13")
    implementation("com.clerk:clerk-android-ui:1.0.13")
    implementation("androidx.media3:media3-exoplayer:1.5.1")
    implementation("androidx.media3:media3-session:1.5.1")
    implementation("androidx.media3:media3-ui:1.5.1")

    testImplementation("junit:junit:4.13.2")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.10.2")
    testImplementation("org.jetbrains.kotlin:kotlin-test:2.3.10")

    androidTestImplementation("androidx.test.ext:junit:1.2.1")
    androidTestImplementation("androidx.test.espresso:espresso-core:3.6.1")
    androidTestImplementation("androidx.compose.ui:ui-test-junit4")

    debugImplementation("androidx.compose.ui:ui-tooling")
    debugImplementation("androidx.compose.ui:ui-test-manifest")
}
