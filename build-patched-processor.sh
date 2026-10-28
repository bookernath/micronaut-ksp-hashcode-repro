#!/usr/bin/env bash
# Builds micronaut-inject-kotlin 5.2.20 with patch/KotlinNativeElement-hashCode.patch applied and
# installs it into ./patched/repo as io.micronaut:micronaut-inject-kotlin:5.2.20-patched
# (same POM as the release, so the processor class path is otherwise identical).
#
# Usage: ./build-patched-processor.sh [path-to-existing-micronaut-core-clone]
# Needs JDK 25 (JAVA_HOME) and network access for the first build.
set -euo pipefail
cd "$(dirname "$0")"
here=$PWD
version=5.2.20
work=$here/build/micronaut-core-$version

if [[ $# -ge 1 ]]; then
  src=$1
  rm -rf "$work"
  git -C "$src" worktree add --force --detach "$work" "v$version"
else
  [[ -d $work ]] || git clone --depth 1 --branch "v$version" https://github.com/micronaut-projects/micronaut-core.git "$work"
fi

git -C "$work" checkout -- .
git -C "$work" apply "$here/patch/KotlinNativeElement-hashCode.patch"
(cd "$work" && ./gradlew :micronaut-inject-kotlin:jar -x test --max-workers=4 \
   -Dorg.gradle.jvmargs="-Xmx4g -Djava.awt.headless=true" -q && ./gradlew --stop -q)

dest=$here/patched/repo/io/micronaut/micronaut-inject-kotlin/$version-patched
mkdir -p "$dest"
cp "$work/inject-kotlin/build/libs/micronaut-inject-kotlin-$version.jar" "$dest/micronaut-inject-kotlin-$version-patched.jar"
curl -fsSL "https://repo1.maven.org/maven2/io/micronaut/micronaut-inject-kotlin/$version/micronaut-inject-kotlin-$version.pom" \
  | perl -0pe "s{<version>$version</version>}{<version>$version-patched</version>}" \
  > "$dest/micronaut-inject-kotlin-$version-patched.pom"
echo "installed $dest"
