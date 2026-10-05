# Building manylinux wheels

`py_manylinux_wheel` transitions an existing `py_wheel` and its native
dependencies to a manylinux target platform, then runs `auditwheel repair`
and `auditwheel show` in its execution image. A wheel that requires newer
glibc symbols fails instead of receiving an inaccurate compatibility tag.
The result provides `PyWheelInfo`; export stamped, canonical filenames with
`@rules_python//python:packaging.bzl`'s `py_wheel_dist`.

The `e2e/manylinux` example contains complete configurations for x86_64
manylinux_2_28 (AlmaLinux 8, GCC 14) and manylinux2014 (CentOS 7, GCC 10).
The example pins both images by digest. Image updates must also review
`compiler_root`: these paths refer to the compiler **inside the image**.
No host compiler, sysroot, or C++ runtime is copied into the container.

## Toolchains and platforms

Load `manylinux_cc_toolchain` and `py_manylinux_wheel` from
`@aspect_rules_py//py:manylinux.bzl`. Define separate target constraints for
each libc policy, and execution platforms carrying both that constraint and
`exec_properties = {"container-image": "docker://...@sha256:..."}`.
Register the image toolchains and execution platforms in `MODULE.bazel`.

Register the ordinary host execution platform first. Constrain any existing
C++ toolchain to your ordinary target ABI; an unconstrained C++ toolchain
can otherwise satisfy a manylinux target on the host execution platform.
Disable Bazel's auto-detected fallback with
`common --repo_env=BAZEL_DO_NOT_DETECT_CPP_TOOLCHAIN=1` when explicitly
registering all C++ toolchains. Use a constraint setting with an ordinary ABI default if existing platform
definitions should continue to work unchanged.

Set the wheel rule's `platform` to the manylinux target and its
`exec_compatible_with` to the matching image constraint. This selects the
image compiler for the complete native dependency graph and the same image
for the audit action. Code generators and wheel assembly can still execute
on the host. The Python headers must match the wheel ABI. Native code must
also support the compiler version provided by the chosen image.

The toolchain defaults to C++17 and statically links the C++ runtime. Use
`cxx_flags` to choose another language standard. External prebuilt libraries
can still impose a newer libc requirement; auditwheel checks the final
linked wheel, including those libraries.

## Local Docker execution

With Bazel 9.1.1, use the following flags (substitute your platform labels):

```text
build:manylinux-docker --experimental_enable_docker_sandbox
build:manylinux-docker --noexperimental_docker_use_customized_images
build:manylinux-docker --spawn_strategy=worker,sandboxed,docker,local
build:manylinux-docker --allowed_strategies_by_exec_platform=//:manylinux_2_28=docker
build:manylinux-docker --allowed_strategies_by_exec_platform=//:manylinux2014=docker
```

The allowlist restricts only actions assigned to those execution platforms.
Other actions keep their normal worker/sandbox/local strategies, even when
they have the same mnemonic. Image actions fail if Docker is unavailable;
they cannot silently fall back to a host compiler. Do not set a global
`--experimental_docker_image` or route all `CppCompile` actions to Docker.

Bazel's experimental Docker strategy may pull a missing image. Fetch the
pinned images explicitly before builds when downloads must be controlled.
Disabling customized images keeps the actual execution image identical to
the digest used for remote execution and avoids rebuilding it for each UID.

## Remote execution

Use the same platforms and toolchains, configure your `--remote_executor`,
and replace the Docker flags with:

```text
build:manylinux-remote --spawn_strategy=remote,worker,sandboxed,local
build:manylinux-remote --allowed_strategies_by_exec_platform=//:manylinux_2_28=remote
build:manylinux-remote --allowed_strategies_by_exec_platform=//:manylinux2014=remote
```

The executor must honor `container-image` and provide the pinned image.
Host generators still require an execution platform appropriate to your
executor. The audit action uses the image's Python and auditwheel and needs
no network access. This example is validated locally with Docker; a remote
service must be validated against its own scheduling and image policy.
