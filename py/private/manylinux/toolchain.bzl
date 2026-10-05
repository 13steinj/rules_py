"""GCC toolchains whose tools and system headers live in the execution image."""

load("@bazel_tools//tools/cpp:unix_cc_toolchain_config.bzl", "cc_toolchain_config")
load("@rules_cc//cc/toolchains:cc_toolchain.bzl", "cc_toolchain")

def manylinux_cc_toolchain(name, compiler_root, target_constraint, exec_constraint, cxx_flags = ["-std=c++17"], **kwargs):
    """Declare an image-backed x86_64 GCC toolchain.

    Args:
        name: Toolchain registration target name.
        compiler_root: Absolute GCC installation root inside the image.
        target_constraint: Constraint selecting this manylinux target ABI.
        exec_constraint: Constraint selecting the matching execution image.
        cxx_flags: Default C++ compiler flags.
        **kwargs: Common attributes for the registration target.
    """
    native.filegroup(name = name + "_empty", srcs = [])
    cc_toolchain_config(
        name = name + "_config",
        toolchain_identifier = name,
        host_system_name = "x86_64-unknown-linux-gnu",
        target_system_name = "x86_64-unknown-linux-gnu",
        cpu = "k8",
        target_libc = "glibc",
        compiler = "gcc",
        abi_version = "gcc",
        abi_libc_version = "glibc",
        tool_paths = {
            tool: compiler_root + "/bin/" + binary
            for tool, binary in {
                "ar": "ar",
                "cpp": "cpp",
                "gcc": "gcc",
                "gcov": "gcov",
                "ld": "ld",
                "nm": "nm",
                "objcopy": "objcopy",
                "objdump": "objdump",
                "strip": "strip",
            }.items()
        },
        # All these paths belong to the digest-pinned execution image. Nothing
        # from the host's /usr or compiler repository is an action input.
        cxx_builtin_include_directories = [compiler_root, "/usr/include", "/usr/local/include"],
        compile_flags = ["-fPIC", "-fno-canonical-system-headers"],
        cxx_flags = cxx_flags,
        opt_compile_flags = ["-O2", "-DNDEBUG"],
        dbg_compile_flags = ["-g"],
        link_flags = ["-Wl,--as-needed", "-static-libgcc"],
        link_libs = ["-Wl,-Bstatic", "-lstdc++", "-Wl,-Bdynamic", "-lm"],
        unfiltered_compile_flags = ["-no-canonical-prefixes"],
        supports_start_end_lib = False,
    )
    cc_toolchain(
        name = name + "_impl",
        toolchain_identifier = name,
        toolchain_config = ":" + name + "_config",
        all_files = ":" + name + "_empty",
        ar_files = ":" + name + "_empty",
        as_files = ":" + name + "_empty",
        compiler_files = ":" + name + "_empty",
        dwp_files = ":" + name + "_empty",
        linker_files = ":" + name + "_empty",
        objcopy_files = ":" + name + "_empty",
        strip_files = ":" + name + "_empty",
        supports_param_files = 1,
    )
    native.toolchain(
        name = name,
        toolchain = ":" + name + "_impl",
        toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
        target_compatible_with = ["@platforms//os:linux", "@platforms//cpu:x86_64", target_constraint],
        exec_compatible_with = ["@platforms//os:linux", "@platforms//cpu:x86_64", exec_constraint],
        **kwargs
    )
