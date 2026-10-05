"""Check the wheel processor boundary without requiring image tooling."""

from pathlib import Path
import tempfile
import unittest
from zipfile import ZipFile

from process_wheel import validate_output, wheel_parts


class WheelValidationTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.original = "example-1.0-2-py2.py3-none-original_platform.whl"

    def wheel(self, name: str, tags: list[str]) -> Path:
        wheel = self.directory / name
        with ZipFile(wheel, "w") as archive:
            archive.writestr(
                "example-1.0.dist-info/WHEEL",
                "Wheel-Version: 1.0\n" + "".join(f"Tag: {tag}\n" for tag in tags),
            )
        return wheel

    def test_compressed_and_reordered_tags(self) -> None:
        wheel = self.wheel(
            "example-1.0-2-py2.py3-none-platform_b.platform_a.whl",
            ["py3-none-platform_a.platform_b", "py2-none-platform_b.platform_a"],
        )
        validate_output(wheel, self.original, "platform_a.platform_b")

    def test_inaccurate_filename(self) -> None:
        wheel = self.wheel(
            "example-1.0-2-py2.py3-none-wrong_platform.whl",
            ["py2.py3-none-wrong_platform"],
        )
        with self.assertRaisesRegex(ValueError, "Output filename tags"):
            validate_output(wheel, self.original, "expected_platform")

    def test_inaccurate_metadata(self) -> None:
        wheel = self.wheel(
            "example-1.0-2-py2.py3-none-expected_platform.whl",
            ["py2.py3-none-wrong_platform"],
        )
        with self.assertRaisesRegex(ValueError, "WHEEL metadata tags"):
            validate_output(wheel, self.original, "expected_platform")

    def test_changed_identity(self) -> None:
        for original, replacement in [
            ("example", "different"),
            ("1.0", "2.0"),
            ("-2-", "-3-"),
            ("py2.py3", "py3"),
            ("none", "abi3"),
        ]:
            with self.subTest(field=original):
                name = self.original.replace("original_platform", "expected_platform")
                wheel = self.wheel(name.replace(original, replacement), [])
                with self.assertRaisesRegex(ValueError, "changed wheel identity"):
                    validate_output(wheel, self.original, "expected_platform")

    def test_unsafe_canonical_name(self) -> None:
        for name in ["../example-1.0-py3-none-any.whl", "not-a-wheel", "a/b.whl"]:
            with self.subTest(name=name), self.assertRaises(ValueError):
                wheel_parts(name)


if __name__ == "__main__":
    unittest.main()
