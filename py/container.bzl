"""Tools supplied by execution images, and generic wheel post-processing."""

load("//py/private/container:tools.bzl", _container_cc_toolchain = "container_cc_toolchain", _container_toolchain = "container_toolchain", _container_tools = "container_tools")
load("//py/private/container:wheel.bzl", _py_wheel_process = "py_wheel_process")

container_tools = _container_tools
container_cc_toolchain = _container_cc_toolchain
container_toolchain = _container_toolchain
py_wheel_process = _py_wheel_process
