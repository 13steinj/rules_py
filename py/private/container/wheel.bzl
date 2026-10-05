"""Transition a wheel's native graph and invoke a configurable processor."""

load("@rules_python//python:packaging.bzl", "PyWheelInfo")

_TOOLCHAIN = "//py/container:toolchain_type"

def _platform_impl(_settings, attr):
    return {"//command_line_option:platforms": str(attr.platform)}

_platform_transition = transition(
    implementation = _platform_impl,
    inputs = [],
    outputs = ["//command_line_option:platforms"],
)

def _impl(ctx):
    wheel = ctx.attr.wheel[0][PyWheelInfo]
    toolchain = ctx.toolchains[_TOOLCHAIN]
    for role in [ctx.attr.python_tool, ctx.attr.processor_tool]:
        if role not in toolchain.tools:
            fail("Container toolchain is missing tool role: " + role)
    basename = wheel.wheel.basename.rsplit("-", 1)[0] + "-" + ctx.attr.platform_tag + ".whl"
    output = ctx.actions.declare_file(ctx.label.name + "/" + basename)
    name_file = ctx.actions.declare_file(ctx.label.name + ".name")
    args = ctx.actions.args()
    args.add(ctx.file._adapter)
    args.add("--wheel", wheel.wheel)
    args.add("--name-file", wheel.name_file)
    args.add("--output", output)
    args.add("--output-name", name_file)
    args.add("--platform-tag", ctx.attr.platform_tag)
    args.add("--processor", toolchain.tools[ctx.attr.processor_tool])
    args.add("--")
    args.add_all(ctx.attr.processor_args)
    ctx.actions.run(
        executable = toolchain.tools[ctx.attr.python_tool],
        arguments = [args],
        inputs = depset([wheel.wheel, wheel.name_file, ctx.file._adapter], transitive = [toolchain.files]),
        tools = toolchain.runfiles,
        outputs = [output, name_file],
        mnemonic = "PyWheelProcess",
        progress_message = "Processing wheel %s" % ctx.label,
        env = {"SOURCE_DATE_EPOCH": "315532800"},
        toolchain = _TOOLCHAIN,
    )
    return [
        DefaultInfo(files = depset([output])),
        PyWheelInfo(wheel = output, name_file = name_file),
        OutputGroupInfo(wheel_name = depset([name_file])),
    ]

py_wheel_process = rule(
    implementation = _impl,
    doc = """Build a wheel for platform and process it with execution-image tools.

processor_args substitutes {wheel} with a staged canonical input wheel path
and {output_dir} with an empty directory. The processor must place exactly one
wheel there, preserve its distribution/version/build/Python/ABI identity, and
emit the requested platform tags in its filename and WHEEL metadata. This
assertion is not an ABI compatibility check; choose a processor that performs
required validation. platform_tag may contain dot-separated tags in any order.
Both the adapter's Python interpreter and the processor are declared tools
resolved from //py/container:toolchain_type. Set exec_compatible_with to the
constraint selecting the intended image. Use py_wheel_dist to export the
canonical output filename recorded in PyWheelInfo.
""",
    attrs = {
        "wheel": attr.label(mandatory = True, providers = [PyWheelInfo], cfg = _platform_transition),
        "platform": attr.label(mandatory = True, providers = [platform_common.PlatformInfo]),
        "processor_args": attr.string_list(mandatory = True),
        "platform_tag": attr.string(mandatory = True),
        "python_tool": attr.string(default = "python"),
        "processor_tool": attr.string(default = "wheel_processor"),
        "_adapter": attr.label(default = ":process_wheel.py", allow_single_file = True),
        "_allowlist_function_transition": attr.label(default = "@bazel_tools//tools/allowlists/function_transition_allowlist"),
    },
    toolchains = [_TOOLCHAIN],
)
