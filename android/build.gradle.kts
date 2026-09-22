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

        // Packaged into the AAR and applied to the host app's R8 run, so
        // integrators need no ProGuard configuration of their own. See the file
        // for what breaks without it.
        consumerProguardFiles("consumer-rules.pro")
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
    // Widening this to `api` later is non-breaking; narrowing it is not — so it
    // stays narrow until something in the public surface actually needs it.
    //
    // 1.0.13 is the floor, not merely the newest:
    //  * 1.0.9  fixed a spurious NotificationClick on an ordinary launcher tap
    //  * 1.0.10 added the 4-argument initialize this plugin calls for `isDebug`
    //  * 1.0.13 ships consumer ProGuard rules. Before it, `proguard.txt` in the
    //    AAR was empty, so a host app building release with `isMinifyEnabled`
    //    let R8 obfuscate BMEvent's field names — which Gson uses verbatim as
    //    JSON keys. Events still uploaded and still returned 200, but arrived
    //    unreadable, so nothing showed up in reporting.
    implementation("com.booleanmaths:bm-sdk:1.0.13")

    testImplementation("org.jetbrains.kotlin:kotlin-test")
    testImplementation("org.mockito:mockito-core:5.0.0")
}
