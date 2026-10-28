#!/usr/bin/env bash
# Runs kspKotlin with the stock and the patched processor on the same sources and checks that
# everything KSP generated (bean definition classes and resources) is byte-identical.
# Usage: ./verify-identical.sh N      (needs ./build-patched-processor.sh to have been run once)
set -euo pipefail
cd "$(dirname "$0")"
n=${1:-1000}
./gen.py "$n" > /dev/null
rm -rf results/out-stock results/out-patched
mkdir -p results
for proc in stock patched; do
  flag=(); [[ $proc == patched ]] && flag=(-PpatchedProcessor)
  ./gradlew -q kspKotlin --rerun "${flag[@]}" > /dev/null
  cp -R build/generated/ksp "results/out-$proc"
done
./gradlew -q --stop
count=$(find results/out-stock -type f | wc -l | tr -d ' ')
(cd results/out-stock && find . -type f -exec shasum -a 256 {} + | sort -k2) > results/stock.sha256
(cd results/out-patched && find . -type f -exec shasum -a 256 {} + | sort -k2) > results/patched.sha256
if diff -q results/stock.sha256 results/patched.sha256 > /dev/null && diff -r results/out-stock results/out-patched > /dev/null; then
  echo "IDENTICAL: $count/$count generated files byte-identical (n=$n)"
else
  echo "DIFFERENT (n=$n):"; diff results/stock.sha256 results/patched.sha256 | head -20; exit 1
fi
