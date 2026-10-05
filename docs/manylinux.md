# Building manylinux wheels

`py_auditwheel`, loaded from `@aspect_rules_py//py:manylinux.bzl`, is a policy
adapter for the [generic execution-image tools API](container.md). It supplies
`auditwheel repair --plat <policy> --only-plat --wheel-dir {output_dir} {wheel}`
to `py_wheel_process`. A wheel requiring newer glibc symbols fails instead of
receiving an inaccurate compatibility tag.

```starlark
py_auditwheel(
    name = "repaired",
    wheel = ":wheel",
    platform = ":manylinux2014",
    exec_compatible_with = [":manylinux2014_environment"],
    policy = "manylinux2014_x86_64",
    platform_tag = "manylinux2014_x86_64.manylinux_2_17_x86_64",
)
```

The execution toolchain supplies Python and auditwheel shims. `policy` is
passed through to auditwheel; `platform_tag` explicitly asserts the emitted
tag set, including aliases. There is no built-in policy or architecture enum.
`py_wheel_dist` exports the canonical filename from the returned `PyWheelInfo`.

The [complete example](../e2e/manylinux) pins cached-compatible x86_64 profiles
for manylinux_2_28 (AlmaLinux 8, GCC 14) and manylinux2014 (CentOS 7, GCC 10).
Compiler paths, system include directories, C++17, and static runtime flags
are choices in the example, not rules defaults. Review tool locations when
changing the image digest. No host compiler or sysroot is copied into an image.

A third profile uses the same manylinux_2_28 image with PATH-resolved compiler
shims, a required fixed compiler argument, a Python 3.12 adapter interpreter,
and a different processor command. A generic copy processor additionally
checks executable-tool runfiles without any auditwheel CLI assumptions.

Run `e2e/manylinux/test.sh` after explicitly fetching its two pinned images.
The test checks Docker routing, declared shims, all three profiles under Python
3.11/3.12/3.13, literal argument/environment quoting, and rejection of a wheel
requiring glibc 2.25 by manylinux2014. The adapter's unit tests cover changed
identity and incorrect filename/metadata tags. No image pull is initiated by
the test. See [execution configuration](container.md#local-docker-execution)
for scoped Docker and remote flags.
