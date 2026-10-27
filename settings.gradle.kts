rootProject.name = "vodadsfree"

pluginManagement {
    repositories {
        gradlePluginPortal()
        google()
        // The ReVanced patches Gradle plugin and ReVanced Patcher are published to GitHub Packages,
        // which requires a GitHub token with the read:packages scope even for public packages.
        // See README.md -> "Build the patch bundle".
        maven {
            name = "githubPackages"
            url = uri("https://maven.pkg.github.com/revanced/revanced-patches-gradle-plugin")
            credentials(PasswordCredentials::class)
        }
    }
}

plugins {
    id("app.revanced.patches") version "1.0.0-dev.10"
}

settings {
    extensions {
        defaultNamespace = "app.vodadsfree.extension"
    }
}
