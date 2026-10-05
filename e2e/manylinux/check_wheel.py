"""Load the produced native library using the container's Python."""

import ctypes
from pathlib import Path
import sys
import tempfile
import zipfile

wheel = Path(sys.argv[1])
with tempfile.TemporaryDirectory() as tmp, zipfile.ZipFile(wheel) as archive:
    metadata = [n for n in archive.namelist() if n.endswith(".dist-info/WHEEL")]
    assert len(metadata) == 1
    assert "manylinux" in archive.read(metadata[0]).decode()
    library = [
        n for n in archive.namelist() if n.endswith("/answer.so") or n == "answer.so"
    ]
    assert len(library) == 1
    archive.extract(library[0], tmp)
    assert ctypes.CDLL(str(Path(tmp, library[0]))).answer() == 42
print(wheel.name)
