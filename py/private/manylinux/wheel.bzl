"""Transition a wheel's native dependency graph, then enforce its ABI policy."""

load("@rules_python//python:packaging.bzl", "PyWheelInfo")

def _platform_impl(_settings, attr):
    return {"//command_line_option:platforms": str(attr.platform)}

_platform_transition = transition(
    implementation = _platform_impl,
    inputs = [],
    outputs = ["//command_line_option:platforms"],
)

def _impl(ctx):
    wheel = ctx.attr.wheel[0][PyWheelInfo]

    # auditwheel may also add legacy equivalent tags. --only-plat guarantees
    # that it does not opportunistically add unrelated older platform tags.
    platform_tag = ctx.attr.policy
    if platform_tag == "manylinux2014_x86_64":
        platform_tag = "manylinux2014_x86_64.manylinux_2_17_x86_64"
    basename = wheel.wheel.basename.rsplit("-", 1)[0] + "-" + platform_tag + ".whl"
    output = ctx.actions.declare_file(ctx.label.name + "/" + basename)
    name_file = ctx.actions.declare_file(ctx.label.name + ".name")
    report = ctx.actions.declare_file(ctx.label.name + ".auditwheel.txt")
    args = ctx.actions.args()
    args.add(ctx.file._repair)
    args.add("--wheel", wheel.wheel)
    args.add("--name-file", wheel.name_file)
    args.add("--policy", ctx.attr.policy)
    args.add("--output", output)
    args.add("--output-name", name_file)
    args.add("--report", report)
    ctx.actions.run(
        executable = "/opt/python/cp311-cp311/bin/python",
        arguments = [args],
        inputs = [wheel.wheel, wheel.name_file, ctx.file._repair],
        outputs = [output, name_file, report],
        mnemonic = "PyManylinuxWheel",
        progress_message = "Auditing manylinux wheel %s" % ctx.label,
        env = {"PATH": "/usr/local/bin:/usr/bin:/bin", "SOURCE_DATE_EPOCH": "315532800"},
    )
    return [
        DefaultInfo(files = depset([output])),
        PyWheelInfo(wheel = output, name_file = name_file),
        OutputGroupInfo(auditwheel = depset([report]), wheel_name = depset([name_file])),
    ]

py_manylinux_wheel = rule(
    implementation = _impl,
    doc = """Build a py_wheel dependency for an image platform and run auditwheel.

The platform must select an image-backed C++ toolchain. Set
exec_compatible_with to the matching image constraint so the audit action
runs in that same image. The result provides PyWheelInfo, including the
canonical filename discovered at execution time; use py_wheel_dist to export it.
""",
    attrs = {
        "wheel": attr.label(mandatory = True, providers = [PyWheelInfo], cfg = _platform_transition),
        "platform": attr.label(mandatory = True, providers = [platform_common.PlatformInfo]),
        "policy": attr.string(mandatory = True, values = ["manylinux_2_28_x86_64", "manylinux2014_x86_64"]),
        "_repair": attr.label(default = ":repair.py", allow_single_file = True),
        "_allowlist_function_transition": attr.label(default = "@bazel_tools//tools/allowlists/function_transition_allowlist"),
    },
)
