group = "com.booleanmaths.flutter"
version = "1.0-SNAPSHOT"

buildscript {
    val kotlinVersion = "2.4.0"
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:9.1.0")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

plugins {
    id("com.android.library")
}

android {
    namespace = "com.booleanmaths.flutter"

    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
        getByName("test") {
            java.srcDirs("src/test/kotlin")
        }
    }

    defaultConfig {
        minSdk = 24
    }

    testOptions {
        unitTests {
            isIncludeAndroidResources = true
            all {
                it.useJUnitPlatform()

                it.outputs.upToDateWhen { false }

                it.testLogging {
                    events("passed", "skipped", "failed", "standardOut", "standardError")
                    showStandardStreams = true
                }
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
    // The native BooleanMaths Android SDK that this plugin wraps.
    //
    // `implementation`, not `api`: bm-sdk is an internal detail. Nothing in this
    // plugin's public surface names a bm-sdk type — every value crossing to Dart
    // is marshalled to a message-codec primitive — so consumers have no reason to
    // compile against it. The artifact still ships in the host APK either way.
    //
    // A host app that wants to call BooleanMathsSDK directly from Kotlin/Java
    // should declare `implementation("com.booleanmaths:bm-sdk:1.0.5")` itself.
    // Widening this to `api` later is non-breaking; narrowing it is not.
    implementation("com.booleanmaths:bm-sdk:1.0.5")

    testImplementation("org.jetbrains.kotlin:kotlin-test")
    testImplementation("org.mockito:mockito-core:5.0.0")
}
