allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    // Workaround for legacy plugins (e.g. flutter_jailbreak_detection 1.10.0)
    // whose android/build.gradle predates AGP 8 and never declares a
    // `namespace`. AGP 8+ requires one and fails the build ("Namespace not
    // specified"). Backfill it from the plugin's old AndroidManifest `package`
    // attribute so it builds without forking the package. Registered here,
    // before the evaluationDependsOn(":app") below, so the subproject is not yet
    // evaluated when afterEvaluate is attached. Lives in the app repo (not
    // pub-cache), so it survives `flutter pub get`.
    afterEvaluate {
        val androidExtension = extensions.findByName("android")
        if (androidExtension is com.android.build.gradle.BaseExtension &&
            androidExtension.namespace == null
        ) {
            val manifestFile = file("src/main/AndroidManifest.xml")
            if (manifestFile.exists()) {
                val pkg = Regex("package=\"(.+?)\"")
                    .find(manifestFile.readText())
                    ?.groupValues
                    ?.get(1)
                if (pkg != null) {
                    androidExtension.namespace = pkg
                }
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}


tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
