@file:OptIn(KotlinNativeCacheApi::class)

import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.jetbrains.kotlin.gradle.plugin.mpp.DisableCacheInKotlinVersion
import org.jetbrains.kotlin.gradle.plugin.mpp.KotlinNativeCacheApi

plugins {
    alias(libs.plugins.kotlinMultiplatform)
    alias(libs.plugins.androidMultiplatformLibrary)
}

kotlin {
    listOf(
        iosArm64(),
        iosSimulatorArm64(),
        macosArm64(),
    ).forEach { appleTarget ->
        appleTarget.binaries.framework {
            baseName = "SharedLogic"
            isStatic = true
            export(project(":domain"))
            if (appleTarget.name == "macosArm64") {
                disableNativeCache(
                    DisableCacheInKotlinVersion.`2_4_20`,
                    reason = "The prebuilt posix cache links symbols missing from the macOS SDK (_fdscandir, _thread_suspend2, ...)",
                )
            }
        }
    }
    
    jvm()
    
    android {
       namespace = "com.drahanov.purrgets.sharedLogic"
       compileSdk = libs.versions.android.compileSdk.get().toInt()
       minSdk = libs.versions.android.minSdk.get().toInt()
    
       compilerOptions {
           jvmTarget = JvmTarget.JVM_11
       }
       androidResources {
           enable = true
       }
       withHostTest {
           isIncludeAndroidResources = true
       }
    }
    
    compilerOptions {
        optIn.add("kotlin.time.ExperimentalTime")
    }

    sourceSets {
        commonMain.dependencies {
            api(project(":domain"))
            implementation(project(":data"))
        }
        commonTest.dependencies {
            implementation(libs.kotlin.test)
        }
    }
}