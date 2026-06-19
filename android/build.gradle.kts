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
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Some plugins (e.g. `health`) pin an older compileSdk than the app, but
// androidx.health.connect:connect-client needs compileSdk >= 35. Force every
// Android module up to 36 so the build doesn't fail on that mismatch. Reflection
// keeps this resilient across Android Gradle Plugin DSL changes (the
// BaseExtension `compileSdkVersion(int)` → CommonExtension `compileSdk` property).
subprojects {
    fun forceCompileSdk36() {
        val androidExt = project.extensions.findByName("android") ?: return
        runCatching {
            val setter = androidExt.javaClass.methods
                .firstOrNull { it.name == "setCompileSdk" && it.parameterCount == 1 }
            if (setter != null) {
                setter.invoke(androidExt, 36)
            } else {
                androidExt.javaClass.methods
                    .firstOrNull {
                        it.name == "compileSdkVersion" &&
                            it.parameterCount == 1 &&
                            it.parameterTypes[0] == Int::class.javaPrimitiveType
                    }
                    ?.invoke(androidExt, 36)
            }
        }
    }
    // Plugin subprojects are evaluated eagerly here, so configure already-evaluated
    // ones directly and defer the rest — afterEvaluate on an evaluated project throws.
    if (project.state.executed) forceCompileSdk36() else afterEvaluate { forceCompileSdk36() }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
