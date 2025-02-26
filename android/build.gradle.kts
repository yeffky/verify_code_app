allprojects {
    repositories {
        maven { url=uri("https://maven.aliyun.com/nexus/content/repositories/google") }
        maven { url=uri("https://maven.aliyun.com/nexus/content/groups/public") }
        maven { url=uri("https://maven.aliyun.com/nexus/content/repositories/jcenter")}
        gradlePluginPortal()
        google()
        mavenCentral()
    }
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
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

buildscript{
    val kotlinVersion = "1.5.20"
    dependencies{
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")
    }
    repositories {
        maven { url=uri("https://maven.aliyun.com/nexus/content/repositories/google") }
        maven { url=uri("https://maven.aliyun.com/nexus/content/groups/public") }
        maven { url=uri("https://maven.aliyun.com/nexus/content/repositories/jcenter")}
        gradlePluginPortal()
        google()
        mavenCentral()
    }
}