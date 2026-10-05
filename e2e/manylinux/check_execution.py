"""Check platform-specific Docker routing from Bazel's JSON execution log."""

from collections import Counter
import json
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text()
decoder = json.JSONDecoder()
actions = []
while text.strip():
    action, offset = decoder.raw_decode(text.lstrip())
    actions.append(action)
    text = text.lstrip()[offset:]

counts = Counter()
for action in actions:
    props = {
        p["name"]: p["value"] for p in action.get("platform", {}).get("properties", [])
    }
    image = props.get("container-image", "")
    runner = action.get("runner")
    mnemonic = action["mnemonic"]
    if image:
        assert runner == "docker", action
        assert mnemonic in ("CppCompile", "CppLink", "PyManylinuxWheel"), action
        if mnemonic in ("CppCompile", "CppLink"):
            root = "devtoolset-10" if "manylinux2014" in image else "gcc-toolset-14"
            assert action["commandArgs"][0] == f"/opt/rh/{root}/root/usr/bin/gcc", (
                action
            )
    else:
        assert runner != "docker", action
    counts[mnemonic, runner] += 1

assert counts["CppCompile", "docker"] == 2, counts
assert counts["CppLink", "docker"] == 2, counts
assert counts["PyManylinuxWheel", "docker"] == 2, counts
assert counts["Genrule", "linux-sandbox"] >= 1, counts
print(counts)
