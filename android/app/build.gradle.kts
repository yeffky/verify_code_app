plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}
subprojects {
    afterEvaluate {
        if (this is org.gradle.api.Project && (plugins.hasPlugin("com.android.library") || plugins.hasPlugin("com.android.application"))) {
            val androidExtension = extensions.findByType<com.android.build.gradle.BaseExtension>()
            androidExtension?.let { android ->
                val currentNamespace = android.namespace
                println("project: ${this.name} Namespace get: $currentNamespace")

                val packageName = currentNamespace
                    ?: android.defaultConfig.applicationId
                    ?: android.sourceSets.getByName("main").manifest.srcFile.readText().let { manifestText ->
                        val regex = Regex("package=\"([^\"]*)\"")
                        regex.find(manifestText)?.groupValues?.get(1)
                    }
                    ?: group.toString()

                android.namespace = packageName
                println("Namespace set to: $packageName for project: ${this.name}")

                val manifestFile = android.sourceSets.getByName("main").manifest.srcFile
                if (manifestFile.exists()) {
                    var manifestText = manifestFile.readText()
                    if (manifestText.contains("package=")) {
                        manifestText = manifestText.replace(Regex("package=\"[^\"]*\""), "")
                        manifestFile.writeText(manifestText)
                        println("Package attribute removed in AndroidManifest.xml for project: ${this.name}")
                    } else {
                        println("No package attribute found in AndroidManifest.xml for project: ${this.name}")
                    }
                } else {
                    println("AndroidManifest.xml not found for project: ${this.name}")
                }
            }
        }
    }
}

android {
    namespace = "com.yeffky.verify_code_app_new"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"
    ext

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    java {
        toolchain {
            languageVersion.set(JavaLanguageVersion.of(17))
        }
    }



            defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.yeffky.verify_code_app_new"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }


    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }


}

flutter {
    source = "../.."
}




