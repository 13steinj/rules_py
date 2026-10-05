"""Executable fixture that requires a runfile before copying a wheel."""

def _impl(ctx):
    executable = ctx.actions.declare_file(ctx.label.name)
    ctx.actions.write(
        executable,
        """#!/bin/sh
set -eu
test "$(cat "$0.runfiles/%s/%s")" = 'processor runfile available'
exec /bin/cp "$@"
""" % (ctx.workspace_name, ctx.file.data.short_path),
        is_executable = True,
    )
    return [DefaultInfo(executable = executable, runfiles = ctx.runfiles(files = [ctx.file.data]))]

copy_processor = rule(
    implementation = _impl,
    executable = True,
    attrs = {"data": attr.label(allow_single_file = True)},
)
