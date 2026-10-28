plugins {
    kotlin("jvm") version "2.4.10"
    id("com.google.devtools.ksp") version "2.3.10"
}

val micronautVersion = "5.2.20"

// -PpatchedProcessor swaps in micronaut-inject-kotlin 5.2.20 with the one-line
// KotlinNativeElement.hashCode fix, installed in ./patched/repo by build-patched-processor.sh.
val patched = providers.gradleProperty("patchedProcessor").isPresent
val injectKotlinVersion = if (patched) "$micronautVersion-patched" else micronautVersion

repositories {
    if (patched) {
        maven { url = uri("patched/repo") }
    }
    mavenCentral()
}

dependencies {
    ksp("io.micronaut:micronaut-inject-kotlin:$injectKotlinVersion")
    implementation("io.micronaut:micronaut-inject:$micronautVersion")
}

kotlin {
    jvmToolchain(25)
}

// Print the wall-clock time of kspKotlin so runs can be compared without a build scan.
tasks.matching { it.name == "kspKotlin" }.configureEach {
    var start = 0L
    doFirst { start = System.nanoTime() }
    doLast {
        val ms = (System.nanoTime() - start) / 1_000_000
        println("KSP_TIME_MS=$ms processor=${if (patched) "patched" else "stock"}")
    }
}
