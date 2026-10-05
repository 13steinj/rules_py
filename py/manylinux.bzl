"""Optional auditwheel policy adapter for the generic container tools API."""

load("//py:container.bzl", "py_wheel_process")

def py_auditwheel(name, wheel, platform, policy, platform_tag, **kwargs):
    """Repair and validate a wheel with the execution toolchain's auditwheel.

    Args:
        name: Target name.
        wheel: Input target providing PyWheelInfo.
        platform: Target platform for the input wheel's native dependencies.
        policy: Policy passed to auditwheel's --plat option.
        platform_tag: Expected output platform tag, including any legacy aliases.
        **kwargs: Other py_wheel_process attributes, e.g. exec_compatible_with.
    """
    py_wheel_process(
        name = name,
        wheel = wheel,
        platform = platform,
        platform_tag = platform_tag,
        processor_args = ["repair", "--plat", policy, "--only-plat", "--wheel-dir", "{output_dir}", "{wheel}"],
        **kwargs
    )
