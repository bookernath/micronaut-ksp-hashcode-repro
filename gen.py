#!/usr/bin/env python3
"""Generate N Micronaut beans that all mention a shared set of M model types.

Usage: ./gen.py N [M]

Writes src/main/kotlin/example/ (deleted and recreated each time). Every bean has
an injected constructor and a few @Executable methods whose parameter and return
types are drawn from the shared models plus String/Int/List, so each shared type
is mentioned at many use sites. The total number of mentions grows linearly
with N; kspKotlin time with the stock processor grows much faster than that.
"""
import shutil
import sys
from pathlib import Path

n = int(sys.argv[1])
m = int(sys.argv[2]) if len(sys.argv) > 2 else 20
methods_per_bean = 6

out = Path(__file__).resolve().parent / "src/main/kotlin/example"
shutil.rmtree(out, ignore_errors=True)
out.mkdir(parents=True)

for j in range(m):
    (out / f"Model{j}.kt").write_text(
        f"""package example

data class Model{j}(
    val id: String,
    val count: Int,
    val tags: List<String>,
)
"""
    )

for i in range(n):
    deps = [f"Service{d}" for d in range(max(0, i - 2), i)]
    ctor = ",\n".join(f"    private val dep{k}: {d}" for k, d in enumerate(deps))
    lines = [
        "package example",
        "",
        "import io.micronaut.context.annotation.Executable",
        "import jakarta.inject.Singleton",
        "",
        "@Singleton",
        f"open class Service{i}(" + ("\n" + ctor + ",\n" if ctor else "") + ") {",
    ]
    for k in range(methods_per_bean):
        a = f"Model{(i + k) % m}"
        b = f"Model{(i * 7 + k * 3) % m}"
        r = f"Model{(i * 3 + k) % m}"
        lines += [
            "    @Executable",
            f"    open fun op{k}(a: {a}, b: List<{b}>, name: String, limit: Int): {r}? = null",
            "",
        ]
    lines.append("}")
    (out / f"Service{i}.kt").write_text("\n".join(lines) + "\n")

print(f"generated {n} beans x {methods_per_bean} methods over {m} shared models in {out}")
