"""Example image profiles; GCC layout and runtime policy belong to the caller."""

load("@aspect_rules_py//py:container.bzl", "container_cc_toolchain", "container_toolchain")

def profile_toolchains(name, compiler_root):
    constraints = ["@platforms//os:linux", "@platforms//cpu:x86_64", "//:env_" + name]
    container_cc_toolchain(
        name = "gcc_" + name,
        tools = {role: "@tools_" + name + "//:" + role for role in ["ar", "cpp", "gcc", "gcov", "ld", "nm", "objcopy", "objdump", "strip"]},
        target_compatible_with = constraints,
        exec_compatible_with = constraints,
        host_system_name = "x86_64-unknown-linux-gnu",
        target_system_name = "x86_64-unknown-linux-gnu",
        cpu = "k8",
        target_libc = "glibc",
        compiler = "gcc",
        abi_version = "gcc",
        abi_libc_version = "glibc",
        cxx_builtin_include_directories = [compiler_root, "/usr/include", "/usr/local/include"],
        compile_flags = ["-fPIC", "-fno-canonical-system-headers"],
        cxx_flags = ["-std=c++17"],
        opt_compile_flags = ["-O2", "-DNDEBUG"],
        dbg_compile_flags = ["-g"],
        link_flags = ["-Wl,--as-needed", "-static-libgcc"],
        link_libs = ["-Wl,-Bstatic", "-lstdc++", "-Wl,-Bdynamic", "-lm"],
        unfiltered_compile_flags = ["-no-canonical-prefixes"],
        supports_start_end_lib = False,
    )
    container_toolchain(
        name = "processor_" + name + "_impl",
        tools = {"@tools_" + name + "//:python": "python", "@tools_" + name + "//:wheel_processor": "wheel_processor", "//:copy_processor": "copy"},
    )
    native.toolchain(
        name = "processor_" + name,
        toolchain_type = "@aspect_rules_py//py/container:toolchain_type",
        toolchain = ":processor_" + name + "_impl",
        exec_compatible_with = constraints,
    )
