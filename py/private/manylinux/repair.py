"""Audit and repair a wheel in the selected manylinux execution image."""

import argparse
from pathlib import Path
import shutil
import subprocess
import tempfile


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("wheel", "name-file", "policy", "output", "output-name", "report"):
        parser.add_argument("--" + name, required=True)
    args = parser.parse_args()
    wheel_name = Path(args.name_file).read_text().strip()
    if Path(wheel_name).name != wheel_name or not wheel_name.endswith(".whl"):
        raise ValueError("Invalid wheel filename: " + wheel_name)
    with tempfile.TemporaryDirectory() as tmp:
        source = Path(tmp, wheel_name)
        shutil.copyfile(args.wheel, source)
        repaired = Path(tmp, "repaired")
        subprocess.run(
            [
                "auditwheel",
                "repair",
                "--plat",
                args.policy,
                "--only-plat",
                "--wheel-dir",
                str(repaired),
                str(source),
            ],
            check=True,
        )
        wheels = list(repaired.glob("*.whl"))
        if len(wheels) != 1:
            raise RuntimeError("Expected exactly one repaired wheel")
        report = subprocess.run(
            ["auditwheel", "show", str(wheels[0])],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            check=True,
        ).stdout
        Path(args.report).write_text(report)
        shutil.copyfile(wheels[0], args.output)
        Path(args.output_name).write_text(wheels[0].name + "\n")


if __name__ == "__main__":
    main()
