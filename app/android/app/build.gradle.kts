plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "pl.edu.bezpiecznik.bezpiecznik"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "pl.edu.bezpiecznik.bezpiecznik"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 30 // flutter_edge_ai: LiteRT (.litertlm) needs minSdk 30
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

// The knowledge base, the shelter points and the readable guides are generated
// by tools/ and are git-ignored. An APK built without them installs fine but
// its chat refuses every question, the shelter list is empty and "Poradniki"
// has nothing to read, so fail the build instead.
val requiredGeneratedAssets = mapOf(
    "kb.sqlite" to "uv run --script tools/build_knowledge.py",
    "points.sqlite" to "uv run --script tools/build_points.py",
    "guides.json" to "uv run --script tools/build_guides.py",
)
tasks.matching { it.name == "preBuild" }.configureEach {
    doFirst {
        val dir = rootProject.projectDir.parentFile.resolve("assets/generated")
        val missing = requiredGeneratedAssets.filterKeys { name ->
            val file = dir.resolve(name)
            !file.isFile || file.length() == 0L
        }
        if (missing.isNotEmpty()) {
            throw GradleException(
                "Missing generated assets in ${dir.path}:\n" +
                    missing.entries.joinToString("\n") { "  ${it.key}  (build it: ${it.value})" },
            )
        }
    }
}
