group = "app.vodadsfree"

patches {
    about {
        name = "VodAdsFree Patches"
        description = "Research patches for ad systems in Android streaming apps"
        source = "https://github.com/undercorp/VodAdsFree"
        author = "VodAdsFree contributors"
        contact = "https://github.com/undercorp/VodAdsFree/issues"
        website = "https://github.com/undercorp/VodAdsFree"
        license = "GNU General Public License v3.0"
    }
}

// Patch sources live next to each service's analysis notes (services/<name>/patches),
// plus a small shared library (services/_shared/patches). Compile them all into one bundle.
kotlin {
    sourceSets {
        main {
            kotlin.srcDirs(
                rootProject.file("services").listFiles()!!
                    .map { it.resolve("patches/src/main/kotlin") }
                    .filter { it.isDirectory },
            )
        }
    }

    compilerOptions {
        freeCompilerArgs.addAll(
            "-Xexplicit-backing-fields",
            "-Xcontext-parameters",
        )
    }
}
