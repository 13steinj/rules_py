"""Declare image tools as executable inputs without inspecting the image."""

load("@bazel_tools//tools/cpp:unix_cc_toolchain_config.bzl", "cc_toolchain_config")

def _quote(value):
    return "'" + value.replace("'", "'\"'\"'") + "'"

def _identifier(value):
    return value and value[0] not in "0123456789" and not value.strip("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_")

def _tools_impl(ctx):
    for name in ctx.attr.args:
        if name not in ctx.attr.tools:
            fail("args references unknown tool: " + name)
    for key in ctx.attr.env:
        if not _identifier(key):
            fail("Invalid environment variable: " + key)
    for name, executable in ctx.attr.tools.items():
        if not _identifier(name):
            fail("Tool names must be identifiers: " + name)
        if not executable:
            fail("Tool executable must not be empty: " + name)
        lines = ["#!/bin/sh"]
        lines.extend(["export %s=%s" % (key, _quote(value)) for key, value in sorted(ctx.attr.env.items())])
        command = [executable] + ctx.attr.args.get(name, [])
        lines.append("exec " + " ".join([_quote(arg) for arg in command]) + " \"$@\"")
        ctx.file(name, "\n".join(lines) + "\n", executable = True)
    build = 'exports_files(%r, visibility = ["//visibility:public"])\n' % sorted(ctx.attr.tools.keys())
    if ctx.attr.cc_toolchain_config:
        build = 'load(%r, "cc_toolchain")\n' % str(Label("@rules_cc//cc/toolchains:cc_toolchain.bzl")) + build
        build += 'filegroup(name = "files", srcs = %r)\n' % sorted(ctx.attr.tools.keys())
        build += "cc_toolchain(\n"
        build += '    name = "cc_toolchain",\n'
        build += "    toolchain_config = %r,\n" % str(ctx.attr.cc_toolchain_config)
        build += "    toolchain_identifier = %r,\n" % ctx.name
        for attr_name in ["all_files", "ar_files", "as_files", "compiler_files", "dwp_files", "linker_files", "objcopy_files", "strip_files"]:
            build += '    %s = ":files",\n' % attr_name
        build += '    supports_param_files = 1,\n    visibility = ["//visibility:public"],\n)\n'
    ctx.file("BUILD.bazel", build)

container_tools = repository_rule(
    implementation = _tools_impl,
    doc = """Create executable shims for tools already installed in an execution image.

Each tools entry produces a public source-file label, e.g. @tools//:gcc.
The shim exports env, then execs the image executable with fixed args followed
by the action's arguments. Values are shell-quoted literally. The image must
provide /bin/sh; executable paths may be absolute or resolved through PATH.
No image inspection, downloads, or host tool discovery are performed.

For C++ tools, set cc_toolchain_config to the caller's
container_cc_toolchain target name plus "_config". This repository owns the
cc_toolchain so its normalized tool paths can refer directly to source shims.
The caller retains compiler flags and registration constraints.
""",
    attrs = {
        "tools": attr.string_dict(mandatory = True),
        "args": attr.string_list_dict(),
        "env": attr.string_dict(),
        "cc_toolchain_config": attr.label(),
    },
)

def _toolchain_impl(ctx):
    tools = {}
    files = []
    runfiles = []
    for target, role in ctx.attr.tools.items():
        if role in tools:
            fail("Duplicate tool role: " + role)
        info = target[DefaultInfo]
        executable = info.files_to_run.executable
        if executable == None:
            candidates = info.files.to_list()
            if len(candidates) != 1:
                fail("Tool %s must provide an executable or a single file" % target.label)
            executable = candidates[0]
        tools[role] = executable
        files.extend([info.files, info.default_runfiles.files, info.data_runfiles.files])

        # FilesToRunProvider stages runfiles trees and manifests for executable
        # rules, in addition to plain source shims.
        if info.files_to_run.executable != None:
            runfiles.append(info.files_to_run)
    return [platform_common.ToolchainInfo(
        tools = tools,
        files = depset(transitive = files),
        runfiles = runfiles,
    )]

container_toolchain = rule(
    implementation = _toolchain_impl,
    attrs = {"tools": attr.label_keyed_string_dict(allow_files = True, cfg = "exec", mandatory = True)},
    doc = "Map executable labels to tool roles for //py/container:toolchain_type.",
)

def container_cc_toolchain(name, tools, target_compatible_with = [], exec_compatible_with = [], **cc_config_options):
    """Register a Unix C++ toolchain backed by source-file image shims.

    Args:
        name: Toolchain registration target name.
        tools: Standard C++ tool role to source shim label mapping. All labels
            must belong to one container_tools repository whose
            cc_toolchain_config points to this target name plus "_config".
        target_compatible_with: Constraints selecting the target environment.
        exec_compatible_with: Constraints selecting the execution image.
        **cc_config_options: Attributes of unix_cc_toolchain_config, including
            CPU, compiler, ABI, system include directories, and compiler/linker
            flags. No image layout, architecture, or runtime flags are assumed.
    """
    labels = {role: native.package_relative_label(label) for role, label in tools.items()}
    if not labels:
        fail("C++ tools must not be empty")
    first = labels.values()[0]
    for label in labels.values():
        if label.workspace_root != first.workspace_root or label.package != first.package:
            fail("All C++ shims must belong to the same container_tools repository package")
    cc_toolchain_config(
        name = name + "_config",
        toolchain_identifier = name,
        tool_paths = {role: label.name for role, label in labels.items()},
        visibility = ["//visibility:public"],
        **cc_config_options
    )
    native.toolchain(
        name = name,
        toolchain = str(first).rsplit(":", 1)[0] + ":cc_toolchain",
        toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
        target_compatible_with = target_compatible_with,
        exec_compatible_with = exec_compatible_with,
    )
