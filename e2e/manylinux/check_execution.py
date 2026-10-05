"""Check image-specific Docker routing and declared shim inputs."""

from collections import Counter
import json
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text()
decoder = json.JSONDecoder()
actions = []
offset = 0
while offset < len(text):
    while offset < len(text) and text[offset].isspace():
        offset += 1
    if offset == len(text):
        break
    action, offset = decoder.raw_decode(text, offset)
    actions.append(action)

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
        assert mnemonic in ("CppCompile", "CppLink", "PyWheelProcess"), action
        executable = action["commandArgs"][0]
        assert executable.startswith("external/+container_tools+tools_"), action
        inputs = {item["path"] for item in action["inputs"]}
        assert executable in inputs, action
        if mnemonic in ("CppCompile", "CppLink"):
            assert executable.endswith("/gcc"), action
            profile = "2014" if "manylinux2014" in image else ("2_28", "alternate")
            profiles = (profile,) if isinstance(profile, str) else profile
            assert any(f"tools_{p}/gcc" in executable for p in profiles), action
        else:
            assert executable.endswith("/python"), action
            assert any("processor_marker.txt" in path for path in inputs), action
    else:
        assert runner != "docker", action
    counts[mnemonic, runner] += 1

assert counts["CppCompile", "docker"] == 3, counts
assert counts["CppLink", "docker"] == 3, counts
assert counts["PyWheelProcess", "docker"] == 4, counts
assert counts["Genrule", "linux-sandbox"] >= 1, counts
print(counts)
