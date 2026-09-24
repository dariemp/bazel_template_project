"""clang-tidy (PyPI wheel) wired to the zig cc toolchain's headers and target.

hermetic_cc_toolchain compiles through a `zig c++ -target <zigtarget>` wrapper.
Zig adds the target triple, libc headers (glibc/musl/macOS) and libc++ headers
internally, so none of them show up in the flags Bazel records. aspect_rules_lint
forwards only those recorded flags to clang-tidy, which would otherwise parse the
code for the *host* triple against whatever is in /usr/include (or fail with
"'vector' file not found" on a machine without system headers).

This rule wraps the clang-tidy binary so every invocation also gets:

  * --target=<clang triple matching the zig target>
  * -nostdlibinc / -nostdinc++ (never look at host headers)
  * zig's libc++ / libc++abi headers (-isystem) and libc headers (-idirafter),
    plus the libc++ configuration macros zig defines (zig ships libc++ without
    a __config_site header)
  * clang-tidy's own resource directory (builtin headers such as stddef.h and
    the intrinsics, matching clang-tidy's clang version rather than zig's)

All of these files are declared as runfiles, so the lint actions stay sandboxed
and hermetic. The toolchain is resolved for the configuration the wrapper is
built in (exec configuration when used by the lint aspect), i.e. the host.

The include layout and macros mirror `zig c++ -###` from Zig 0.15.2 (the
version pinned by hermetic_cc_toolchain 4.3.0). Re-check them when upgrading.
"""

load("@rules_cc//cc:find_cc_toolchain.bzl", "find_cpp_toolchain", "use_cc_toolchain")

_LIBCXX_DEFINES = [
    "_LIBCPP_ABI_VERSION=1",
    "_LIBCPP_ABI_NAMESPACE=__1",
    "_LIBCPP_HAS_THREADS=1",
    "_LIBCPP_HAS_MONOTONIC_CLOCK",
    "_LIBCPP_HAS_TERMINAL",
    "_LIBCXXABI_DISABLE_VISIBILITY_ANNOTATIONS",
    "_LIBCPP_DISABLE_VISIBILITY_ANNOTATIONS",
    "_LIBCPP_HAS_VENDOR_AVAILABILITY_ANNOTATIONS=0",
    "_LIBCPP_HAS_FILESYSTEM=1",
    "_LIBCPP_HAS_RANDOM_DEVICE",
    "_LIBCPP_HAS_LOCALIZATION",
    "_LIBCPP_HAS_UNICODE",
    "_LIBCPP_HAS_WIDE_CHARACTERS",
    "_LIBCPP_HAS_NO_STD_MODULES",
    "_LIBCPP_PSTL_BACKEND_SERIAL",
    "_LIBCPP_HARDENING_MODE=_LIBCPP_HARDENING_MODE_NONE",
    "_LIBCPP_ENABLE_CXX17_REMOVED_UNEXPECTED_FUNCTIONS",
]

def _target_info(zigtarget):
    """Map a zig target (e.g. x86_64-linux-gnu.2.28) to clang flags."""
    parts = zigtarget.split("-")
    if len(parts) != 3:
        fail("unexpected zig target: " + zigtarget)
    cpu, os, abi = parts
    zcpu = "x86" if cpu == "x86_64" else cpu

    if os == "linux" and abi.startswith("gnu"):
        glibc_minor = abi.split(".")[-1] if "." in abi else "28"
        return struct(
            triple = "{}-unknown-linux-gnu".format(cpu),
            libc_dirs = [
                "libc/include/{}-linux-gnu".format(zcpu),
                "libc/include/generic-glibc",
                "libc/include/{}-linux-any".format(zcpu),
                "libc/include/any-linux-any",
            ],
            defines = ["__GLIBC_MINOR__=" + glibc_minor],
            cxx_defines = _LIBCXX_DEFINES + [
                "_LIBCPP_HAS_MUSL_LIBC=0",
                "_LIBCPP_HAS_TIME_ZONE_DATABASE",
            ],
        )
    if os == "linux" and abi == "musl":
        return struct(
            triple = "{}-unknown-linux-musl".format(cpu),
            libc_dirs = [
                "libc/include/{}-linux-musl".format(cpu),
                "libc/include/generic-musl",
                "libc/include/{}-linux-any".format(zcpu),
                "libc/include/any-linux-any",
            ],
            defines = [],
            cxx_defines = _LIBCXX_DEFINES + [
                "_LIBCPP_HAS_MUSL_LIBC=1",
                "_LIBCPP_HAS_TIME_ZONE_DATABASE",
            ],
        )
    if os == "macos":
        # Zig's default deployment target for macOS in 0.15 is 13.0.
        return struct(
            triple = "{}-apple-macosx13.0".format("arm64" if cpu == "aarch64" else cpu),
            libc_dirs = ["libc/include/any-macos-any"],
            defines = [],
            cxx_defines = _LIBCXX_DEFINES + ["_LIBCPP_HAS_MUSL_LIBC=0"],
        )
    fail("zig_clang_tidy: unsupported zig target " + zigtarget)

def _runfiles_path(ctx, short_path):
    if short_path.startswith("../"):
        return short_path[3:]
    return ctx.workspace_name + "/" + short_path

def _find_prefix(files, marker):
    for f in files:
        idx = f.short_path.find(marker)
        if idx >= 0:
            return f.short_path[:idx]
    return None

def _zig_clang_tidy_impl(ctx):
    cc_toolchain = find_cpp_toolchain(ctx)
    toolchain_id = cc_toolchain.toolchain_id
    if not toolchain_id.endswith("-toolchain"):
        fail("zig_clang_tidy expects a hermetic_cc_toolchain toolchain, got " + toolchain_id)
    info = _target_info(toolchain_id.removesuffix("-toolchain"))

    toolchain_files = cc_toolchain.all_files.to_list()
    zig_root_short = _find_prefix(toolchain_files, "/lib/libcxx/include/")
    if zig_root_short == None:
        fail("zig_clang_tidy: could not locate zig's lib/libcxx/include in the toolchain files")
    zig_root = _runfiles_path(ctx, zig_root_short) + "/lib/"

    # Only ship the header directories clang-tidy actually searches.
    header_prefixes = [
        zig_root_short + "/lib/" + d + "/"
        for d in info.libc_dirs + ["libcxx/include", "libcxxabi/include"]
    ]
    header_files = [
        f
        for f in toolchain_files
        if any([f.short_path.startswith(p) for p in header_prefixes])
    ]

    data_files = ctx.files.data
    resource_dir = _find_prefix(data_files, "/include/stddef.h")
    if resource_dir == None:
        fail("zig_clang_tidy: could not locate clang-tidy's resource dir (lib/clang/<ver>/include)")
    resource_dir = _runfiles_path(ctx, resource_dir)

    common = ["--target=" + info.triple, "-nostdlibinc"]
    common += ["-resource-dir", "$R/" + resource_dir]
    for d in info.libc_dirs:
        common += ["-idirafter", "$R/" + zig_root + d]
    common += ["-D" + d for d in info.defines]
    cxx = ["-nostdinc++"]
    for d in ["libcxx/include", "libcxxabi/include"]:
        cxx += ["-isystem", "$R/" + zig_root + d]
    cxx += ["-D" + d for d in info.cxx_defines]

    def _extra(flags):
        return " ".join(['"--extra-arg={}"'.format(f) for f in flags])

    script = ctx.actions.declare_file(ctx.label.name)
    ctx.actions.write(
        output = script,
        is_executable = True,
        content = """#!/usr/bin/env bash
# Generated by //tools/cpp:zig_clang_tidy.bzl ({zigtarget}).
set -euo pipefail
if [[ -d "$0.runfiles" ]]; then
  R="$0.runfiles"
elif [[ -n "${{RUNFILES_DIR:-}}" ]]; then
  R="$RUNFILES_DIR"
else
  echo "clang-tidy wrapper: cannot find runfiles for $0" >&2
  exit 1
fi
lang=c
args=()
tmp_files=()
for a in "$@"; do
  case "$a" in
    -xc++ | *.cc | *.cpp | *.cxx | *.hh | *.hpp) lang=c++ ;;
  esac
  # zig spells CPU names with underscores (the macOS arm64 toolchain adds
  # -mcpu=apple_m1); clang rejects those, so translate to clang's spelling.
  # aspect_rules_lint passes the compiler flags in a params file (@file).
  case "$a" in
    -mcpu=*_*) a="$(printf '%s' "$a" | tr '_' '-')" ;;
    @*)
      f="${{a#@}}"
      if [[ -f "$f" ]] && grep -q -e '-mcpu=.*_' "$f"; then
        grep -q -e '-xc++' "$f" && lang=c++
        t="$(mktemp "${{TMPDIR:-/tmp}}/clang_tidy_params.XXXXXX")"
        sed -e '/-mcpu=/y/_/-/' "$f" >"$t"
        tmp_files+=("$t")
        a="@$t"
      elif [[ -f "$f" ]] && grep -q -e '-xc++' "$f"; then
        lang=c++
      fi
      ;;
  esac
  args+=("$a")
done
extra=({common})
if [[ $lang == c++ ]]; then
  extra+=({cxx})
fi
rc=0
"$R/{clang_tidy}" "${{extra[@]}}" "${{args[@]}}" || rc=$?
if [[ ${{#tmp_files[@]}} -gt 0 ]]; then
  rm -f "${{tmp_files[@]}}"
fi
exit "$rc"
""".format(
            zigtarget = toolchain_id,
            common = _extra(common),
            cxx = _extra(cxx),
            clang_tidy = _runfiles_path(ctx, ctx.file.clang_tidy.short_path),
        ),
    )
    runfiles = ctx.runfiles(
        files = [ctx.file.clang_tidy] + data_files + header_files,
    )
    return [DefaultInfo(executable = script, runfiles = runfiles)]

zig_clang_tidy = rule(
    implementation = _zig_clang_tidy_impl,
    attrs = {
        "clang_tidy": attr.label(
            mandatory = True,
            allow_single_file = True,
            doc = "The clang-tidy executable (from the PyPI wheel).",
        ),
        "data": attr.label_list(
            allow_files = True,
            doc = "The wheel's data tree, including lib/clang/<ver>/include.",
        ),
    },
    executable = True,
    fragments = ["cpp"],
    toolchains = use_cc_toolchain(),
    doc = "clang-tidy wrapper that uses the zig toolchain's target and headers.",
)
