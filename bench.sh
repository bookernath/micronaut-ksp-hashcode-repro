#!/usr/bin/env bash
# Times kspKotlin with the stock and the patched processor for each bean count.
# Usage: ./bench.sh [reps] N...      e.g. ./bench.sh 3 250 500 1000 2000
# Prints one line per run and a median per (N, processor) at the end; raw lines go to results/bench.txt.
# Needs ./build-patched-processor.sh to have been run once.
set -euo pipefail
cd "$(dirname "$0")"
reps=$1; shift
mkdir -p results
: > results/bench.txt
for n in "$@"; do
  ./gen.py "$n" > /dev/null
  for proc in stock patched; do
    flag=(); [[ $proc == patched ]] && flag=(-PpatchedProcessor)
    # warm-up run (daemon start, dependency resolution, JIT), not counted
    ./gradlew -q kspKotlin --rerun "${flag[@]}" > /dev/null
    for ((r = 1; r <= reps; r++)); do
      ms=$(./gradlew -q kspKotlin --rerun "${flag[@]}" | sed -n 's/^KSP_TIME_MS=\([0-9]*\).*/\1/p')
      echo "n=$n processor=$proc run=$r ms=$ms" | tee -a results/bench.txt
    done
  done
done
./gradlew -q --stop
echo
echo "median kspKotlin time (ms):"
awk '{for(i=1;i<=NF;i++){split($i,kv,"=");v[kv[1]]=kv[2]} k=v["n"]" "v["processor"]; t[k]=t[k]" "v["ms"]}
     END{for(k in t){n=split(substr(t[k],2),a," "); asort_n(a,n); print k, a[int((n+1)/2)]}}
     function asort_n(a,n,  i,j,x){for(i=2;i<=n;i++){x=a[i];for(j=i-1;j>=1&&a[j]+0>x+0;j--)a[j+1]=a[j];a[j+1]=x}}' \
  results/bench.txt | sort -k1,1n -k2,2r
