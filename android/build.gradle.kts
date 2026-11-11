allprojects {
    repositories {
        google()
        mavenCentral()
        // Signal'in resmi Maven deposu (ADR-0010, güncelleme 2026-11-11).
        // Yalnızca org.signal grubu buradan, org.signal grubu yalnızca
        // buradan çözülür; sürüm ve SHA-256 gradle/verification-metadata.xml'de
        // sabittir.
        exclusiveContent {
            forRepository {
                maven {
                    name = "SignalBuildArtifacts"
                    url = uri("https://build-artifacts.signal.org/libraries/maven/")
                }
            }
            filter {
                includeGroup("org.signal")
            }
        }
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
