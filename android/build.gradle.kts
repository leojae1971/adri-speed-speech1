allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Redirige el buildDir de cada módulo hacia <raíz-del-proyecto>/build/<módulo>.
// Sin esto, Gradle escribe el APK en android/app/build/outputs/... pero
// `flutter build apk` busca en build/app/outputs/flutter-apk/... y no lo
// encuentra — exactamente el síntoma que acabas de ver (BUILD SUCCESSFUL
// pero "couldn't find" el .apk).
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