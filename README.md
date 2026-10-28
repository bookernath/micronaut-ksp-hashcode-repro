# micronaut-ksp-hashcode-repro

Minimal reproduction for slow `kspKotlin` with Micronaut 5.2.x's KSP processor (`micronaut-inject-kotlin`).

`KotlinNativeElement` and `KotlinClassNativeElement` compare `kotlinNativeType` **and** `owner` (the use site) in
`equals`, but `hashCode` returns `kotlinNativeType.hashCode()` only. The annotation metadata caches are hash maps
keyed by these elements, so every use site of one type (`String`, `Int`, a shared model class, ...) lands in the same
hash bin and each lookup scans that bin with `equals`. The work grows with the square of the number of mentions of a
type.

The fix ([`patch/KotlinNativeElement-hashCode.patch`](patch/KotlinNativeElement-hashCode.patch)) adds the owner's hash:

```kotlin
override fun hashCode(): Int {
    return 31 * kotlinNativeType.hashCode() + (owner?.hashCode() ?: 0)
}
```

## The project

- `gen.py N [M]` writes `N` `@Singleton` beans to `src/main/kotlin/example/`. Each bean injects the previous two and
  has six `@Executable` methods whose parameters and return types come from `M` (default 20) shared `data class`es plus
  `String`, `Int` and `List`.
- `build.gradle.kts`: Kotlin 2.4.10, KSP 2.3.10, `io.micronaut:micronaut-inject-kotlin:5.2.20`. The `kspKotlin` task
  prints `KSP_TIME_MS=...`.
- `-PpatchedProcessor` switches the KSP processor to `micronaut-inject-kotlin:5.2.20-patched`: the 5.2.20 sources with
  the patch applied, built by `build-patched-processor.sh` into `./patched/repo` with the release POM. Apart from the
  two patched classes it is identical to the release jar (`diff -r` of the unpacked jars lists only
  `KotlinNativeElement.class` and `KotlinClassNativeElement.class`).

## Steps

Needs JDK 25 (`JAVA_HOME`), Python 3, and network access.

```bash
./build-patched-processor.sh            # clones micronaut-core v5.2.20, applies the patch, builds the jar (a few minutes)
./gen.py 2000
./gradlew kspKotlin --rerun                     # stock 5.2.20
./gradlew kspKotlin --rerun -PpatchedProcessor  # patched
./bench.sh 3 500 1000 2000 4000         # medians of 3 runs per size and processor, after one warm-up run each
./verify-identical.sh 2000              # everything KSP generates is byte-identical
./gradlew --stop
```

## Results

Apple M5 Max (18 cores, 128 GB), macOS, Temurin JDK 25.0.5, Gradle 9.7.1, Kotlin 2.4.10, KSP 2.3.10,
Micronaut 5.2.20, `gen.py N` with the default 20 shared models. Median of 3 `kspKotlin --rerun` runs after one warm-up
run in the same daemon; raw numbers in [`bench-results.txt`](bench-results.txt).

| beans (N) | generated files | stock 5.2.20 | patched | stock / patched |
|----------:|----------------:|-------------:|--------:|----------------:|
|       500 |           1,500 |        3.2 s |   3.0 s |            1.07 |
|     1,000 |           3,000 |        6.4 s |   4.4 s |            1.45 |
|     2,000 |           6,000 |       14.4 s |   7.6 s |            1.90 |
|     4,000 |          12,000 |       47.7 s |  16.9 s |            2.82 |

Doubling N from 2,000 to 4,000 makes the stock processor 3.3x slower; the patched one 2.2x.

A JFR profile (`settings=profile`) of the stock run at N = 4,000 has 60% of execution samples in
`kotlin.jvm.internal.Intrinsics.areEqual`, plus 4% in `HashMap$TreeNode.find`. 92% of the `areEqual` samples are
under `AbstractAnnotationMetadataBuilder.lookupOrBuild`, most of them via
`KotlinElementAnnotationMetadataFactory.lookupTypeAnnotationsForClass`.

`./verify-identical.sh 4000` prints `IDENTICAL: 12000/12000 generated files byte-identical (n=4000)`: every file under
`build/generated/ksp` (bean definition classes and `META-INF` service files) has the same SHA-256 with both processors.
