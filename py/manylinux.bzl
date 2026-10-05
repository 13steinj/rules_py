"""Build and audit Linux wheels with a compiler supplied by an execution image.

See docs/manylinux.md for local Docker and remote execution configuration.
"""

load("//py/private/manylinux:toolchain.bzl", _manylinux_cc_toolchain = "manylinux_cc_toolchain")
load("//py/private/manylinux:wheel.bzl", _py_manylinux_wheel = "py_manylinux_wheel")

manylinux_cc_toolchain = _manylinux_cc_toolchain
py_manylinux_wheel = _py_manylinux_wheel
