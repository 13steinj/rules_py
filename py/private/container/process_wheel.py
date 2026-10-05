"""Bridge Bazel's wheel/name-file pair to a processor using canonical names."""

import argparse
from email.parser import Parser
from itertools import product
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
from zipfile import ZipFile


def wheel_parts(name: str) -> list[str]:
    if Path(name).name != name or "\\" in name or not name.endswith(".whl"):
        raise ValueError(f"Invalid canonical wheel filename: {name!r}")
    parts = name[:-4].split("-")
    if len(parts) not in (5, 6) or not all(parts):
        raise ValueError(f"Invalid canonical wheel filename: {name!r}")
    return parts


def expand_tag(tag: str) -> set[tuple[str, str, str]]:
    parts = tag.split("-")
    if len(parts) != 3 or any(
        not re.fullmatch(r"[A-Za-z0-9_]+(?:\.[A-Za-z0-9_]+)*", part) for part in parts
    ):
        raise ValueError(f"Invalid wheel tag: {tag!r}")
    return set(product(parts[0].split("."), parts[1].split("."), parts[2].split(".")))


def validate_output(wheel: Path, original_name: str, platform_tag: str) -> None:
    original = wheel_parts(original_name)
    result = wheel_parts(wheel.name)
    if original[:-1] != result[:-1]:
        raise ValueError(
            f"Processor changed wheel identity: {original_name} -> {wheel.name}"
        )
    expected = expand_tag("-".join(result[-3:-1] + [platform_tag]))
    actual = expand_tag("-".join(result[-3:]))
    if actual != expected:
        raise ValueError(
            f"Output filename tags {actual} do not match requested tags {expected}"
        )
    with ZipFile(wheel) as archive:
        metadata = [
            name for name in archive.namelist() if name.endswith(".dist-info/WHEEL")
        ]
        if len(metadata) != 1:
            raise ValueError(f"Expected one WHEEL metadata file, found {metadata}")
        message = Parser().parsestr(archive.read(metadata[0]).decode("utf-8"))
        tags = set()
        for tag in message.get_all("Tag", []):
            tags.update(expand_tag(tag))
        if tags != expected:
            raise ValueError(
                f"WHEEL metadata tags {tags} do not match requested tags {expected}"
            )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    for name in (
        "wheel",
        "name-file",
        "output",
        "output-name",
        "platform-tag",
        "processor",
    ):
        parser.add_argument("--" + name, required=True)
    parser.add_argument("processor_args", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    canonical_name = Path(args.name_file).read_text().strip()
    wheel_parts(canonical_name)
    with tempfile.TemporaryDirectory() as temporary:
        directory = Path(temporary)
        staged = directory / canonical_name
        shutil.copyfile(args.wheel, staged)
        output_dir = directory / "output"
        output_dir.mkdir()
        processor_args = args.processor_args
        if processor_args[:1] == ["--"]:
            processor_args = processor_args[1:]
        command = [args.processor] + [
            arg.replace("{wheel}", str(staged)).replace("{output_dir}", str(output_dir))
            for arg in processor_args
        ]
        subprocess.run(command, check=True)
        wheels = list(output_dir.glob("*.whl"))
        if len(wheels) != 1:
            raise ValueError(
                f"Processor must produce exactly one wheel, found {wheels}"
            )
        result = wheels[0]
        validate_output(result, canonical_name, args.platform_tag)
        shutil.copyfile(result, args.output)
        Path(args.output_name).write_text(result.name + "\n")


if __name__ == "__main__":
    main()
