import org.gradle.api.DefaultTask
import org.gradle.api.file.ConfigurableFileCollection
import org.gradle.api.file.DirectoryProperty
import org.gradle.api.file.FileSystemOperations
import org.gradle.api.file.RegularFile
import org.gradle.api.provider.Property
import org.gradle.api.provider.Provider
import org.gradle.api.tasks.Input
import org.gradle.api.tasks.InputFiles
import org.gradle.api.tasks.Internal
import org.gradle.api.tasks.OutputFiles
import org.gradle.api.tasks.PathSensitive
import org.gradle.api.tasks.PathSensitivity
import org.gradle.api.tasks.TaskAction
import org.gradle.work.DisableCachingByDefault
import javax.inject.Inject

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.path_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.path_mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
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

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

@DisableCachingByDefault(because = "Copies local APKs; a cache entry would only duplicate them")
abstract class CopyVersionedApkTask : DefaultTask() {
    @get:InputFiles
    @get:PathSensitive(PathSensitivity.NAME_ONLY)
    abstract val sourceApks: ConfigurableFileCollection

    @get:Input
    abstract val appName: Property<String>

    @get:Input
    abstract val appVersion: Property<String>

    @get:Internal
    abstract val outputDir: DirectoryProperty

    private fun targetApkFileName(sourceName: String, base: String): String {
        val suffix = sourceName
            .removePrefix("app")
            .removeSuffix("-release.apk")
        return "$base$suffix.apk"
    }

    @get:OutputFiles
    val targetApks: Provider<List<RegularFile>>
        get() = appName.zip(appVersion) { n, v -> "$n-$v" }.flatMap { base ->
            outputDir.flatMap { dir ->
                sourceApks.elements.map { elements ->
                    elements.map { loc ->
                        dir.file(targetApkFileName(loc.asFile.name, base))
                    }
                }
            }
        }

    @get:Inject
    abstract val fileSystemOperations: FileSystemOperations

    @TaskAction
    fun copyApks() {
        val base = "${appName.get()}-${appVersion.get()}"
        val dest = outputDir.get()
        sourceApks.files.forEach { apk ->
            val targetName = targetApkFileName(apk.name, base)
            fileSystemOperations.copy {
                from(apk)
                into(dest)
                rename { targetName }
            }
        }
    }
}

fun readPubspecField(
    pubspecText: Provider<String>,
    key: String,
    fallback: String,
): Provider<String> = pubspecText.map { text ->
    val match = Regex("""(?m)^${Regex.escape(key)}\s*:\s*([^#\r\n]+)""").find(text)
    val raw = match?.groupValues?.get(1)?.trim()
        ?.removeSurrounding("\"")
        ?.removeSurrounding("'")
        ?.trim()
    if (raw.isNullOrEmpty()) fallback else raw.replace(Regex("""[^A-Za-z0-9._+-]"""), "_")
}

val pubspecText = providers.fileContents(layout.projectDirectory.file("../../pubspec.yaml")).asText

val copyVersionedReleaseApk = tasks.register<CopyVersionedApkTask>("copyVersionedReleaseApk") {
    val copyFlutterTask = tasks.named("copyFlutterApksRelease")
    dependsOn(copyFlutterTask)
    sourceApks.from(copyFlutterTask.map { it.outputs.files })
    appName.set(readPubspecField(pubspecText, "name", "path_mobile"))
    appVersion.set(readPubspecField(pubspecText, "version", flutter.versionName))
    outputDir.set(layout.buildDirectory.dir("outputs/flutter-apk"))
}

tasks.configureEach {
    if (name == "assembleRelease") {
        dependsOn(copyVersionedReleaseApk)
    }
}
