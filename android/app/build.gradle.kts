import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // Flutter plugin должен идти после android/kotlin
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "ru.cakecost.app"

    compileSdk = 35
    // Указываем нужную версию NDK только ОДИН раз:
    ndkVersion = "27.0.12077973"

    defaultConfig {
        applicationId = "ru.cakecost.app"
        minSdk = 21
        targetSdk = 35
        versionCode = 1
        versionName = "1.0.0"
    }

    // Java/Kotlin 17 — современная конфигурация для AGP/Flutter
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }

    signingConfigs {
        create("release") {
            // ВНИМАНИЕ: key.properties лежит в КОРНЕ Gradle-проекта (папка android/)
            val keystorePropsFile = rootProject.file("key.properties")
            if (keystorePropsFile.exists()) {
                val props = Properties()
                props.load(FileInputStream(keystorePropsFile))
                val storePath = props.getProperty("storeFile")
                if (!storePath.isNullOrBlank()) {
                    // storeFile указываем относительно модуля app (android/app)
                    storeFile = file(storePath)
                }
                storePassword = props.getProperty("storePassword")
                keyAlias = props.getProperty("keyAlias")
                keyPassword = props.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
        }
        getByName("debug") {
            // настройки по умолчанию
        }
    }
}

flutter {
    source = "../.."
}
