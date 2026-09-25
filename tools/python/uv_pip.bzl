"""Install PyPI packages with uv into an external repository for rules_python.

rules_uv 0.89 provides pip_compile (locking) and create_venv (dev venvs) but
does not replace rules_python pip.parse hubs. This repository rule uses the
same uv binary family as rules_uv to install a locked requirements.txt into a
site-packages tree that py_library / py_binary / py_test can depend on via
@uv_deps//:pkgs.
"""

_UV_VERSION = "0.12.19"

# Keep in sync with //tools/python:uv.lock.json (overrides rules_uv's uv).
_UV_BINARIES = {
    "linux_x86_64": {
        "url": "https://github.com/astral-sh/uv/releases/download/{v}/uv-x86_64-unknown-linux-gnu.tar.gz".format(v = _UV_VERSION),
        "sha256": "23bf5552d220e0842b65c862097b2ebaeba0064b74eda5e565e77fd25969d8c8",
        "file": "uv-x86_64-unknown-linux-gnu/uv",
    },
    "linux_arm64": {
        "url": "https://github.com/astral-sh/uv/releases/download/{v}/uv-aarch64-unknown-linux-musl.tar.gz".format(v = _UV_VERSION),
        "sha256": "ad8d8448a2ff642ba62c2f684d7dd22a03f8eb3fc9918c2c3e8ec975f4ed6710",
        "file": "uv-aarch64-unknown-linux-musl/uv",
    },
    "darwin_x86_64": {
        "url": "https://github.com/astral-sh/uv/releases/download/{v}/uv-x86_64-apple-darwin.tar.gz".format(v = _UV_VERSION),
        "sha256": "cb5fa57bafe68fc0fb94b17f06bee0b0b9a7feb94ccbd110445afa0696e39273",
        "file": "uv-x86_64-apple-darwin/uv",
    },
    "darwin_arm64": {
        "url": "https://github.com/astral-sh/uv/releases/download/{v}/uv-aarch64-apple-darwin.tar.gz".format(v = _UV_VERSION),
        "sha256": "a9a8df1eedeb192f2e47e40e2faabfb387db4b850209118786d42f89dde3e0ba",
        "file": "uv-aarch64-apple-darwin/uv",
    },
}

def _host_key(rctx):
    os_name = rctx.os.name.lower()
    arch = rctx.os.arch.lower()

    if arch in ("amd64", "x86_64", "x64"):
        cpu = "x86_64"
    elif arch in ("aarch64", "arm64"):
        cpu = "arm64"
    else:
        fail("Unsupported host CPU for uv download: " + arch)

    if "linux" in os_name:
        os_key = "linux"
    elif "mac" in os_name or os_name == "darwin":
        os_key = "darwin"
    else:
        fail("Unsupported host OS for uv download: " + os_name)

    return "{}_{}".format(os_key, cpu)

def _download_uv(rctx):
    key = _host_key(rctx)
    meta = _UV_BINARIES[key]
    rctx.download_and_extract(
        url = meta["url"],
        sha256 = meta["sha256"],
        output = "uv_download",
    )
    uv = rctx.path("uv_download/" + meta["file"])
    return uv

_BUILD_TEMPLATE = """\
load("@rules_python//python:defs.bzl", "py_library")

package(default_visibility = ["//visibility:public"])

_NATIVE_TOOL_DIRS = [
    "site-packages/clang_format/**",
    "site-packages/clang_tidy/**",
    "site-packages/bin/clang-*",
]

py_library(
    name = "pkgs",
    srcs = glob(
        ["site-packages/**/*.py"],
        exclude = _NATIVE_TOOL_DIRS,
        allow_empty = True,
    ),
    data = glob(
        ["site-packages/**/*"],
        exclude = [
            "site-packages/**/*.py",
            "site-packages/**/__pycache__/**",
            "site-packages/**/*.pyc",
        ] + _NATIVE_TOOL_DIRS,
        allow_empty = True,
    ),
    imports = ["site-packages"],
)

# Native executables shipped inside PyPI wheels (e.g. the official LLVM
# clang-format / clang-tidy wheels). They are exposed as plain files and kept
# out of :pkgs so Python targets do not carry them in their runfiles.
exports_files(
    glob(
        [
            "site-packages/clang_format/data/bin/*",
            "site-packages/clang_tidy/data/bin/*",
        ],
        allow_empty = True,
    ),
)

# Full clang-tidy wheel payload: the binary plus its resource directory
# (lib/clang/<ver>/include), which clang-tidy needs for builtin headers.
filegroup(
    name = "clang_tidy_data",
    srcs = glob(
        ["site-packages/clang_tidy/data/**"],
        allow_empty = True,
    ),
)
"""

def _uv_pip_repository_impl(rctx):
    uv = _download_uv(rctx)
    python = rctx.path(rctx.attr.python_interpreter)
    requirements = rctx.path(rctx.attr.requirements)

    # Re-run the install whenever the lockfile changes.
    rctx.watch(requirements)

    # Install locked deps into site-packages (runtime install via uv).
    result = rctx.execute(
        [
            str(uv),
            "pip",
            "install",
            "--python",
            str(python),
            "--target",
            "site-packages",
            "--no-compile",
            "-r",
            str(requirements),
        ],
        environment = {
            # Keep installs deterministic / offline-friendly when cache exists.
            "UV_LINK_MODE": "copy",
        },
        quiet = False,
    )
    if result.return_code != 0:
        fail("uv pip install failed:\\nstdout:\\n{}\\nstderr:\\n{}".format(
            result.stdout,
            result.stderr,
        ))

    rctx.file("BUILD.bazel", _BUILD_TEMPLATE)
    rctx.file("WORKSPACE", "")

uv_pip_repository = repository_rule(
    implementation = _uv_pip_repository_impl,
    attrs = {
        "python_interpreter": attr.label(
            mandatory = True,
            allow_single_file = True,
            doc = "Hermetic Python interpreter (e.g. @python_3_13_host//:python).",
        ),
        "requirements": attr.label(
            mandatory = True,
            allow_single_file = True,
            doc = "Locked requirements.txt (from rules_uv pip_compile).",
        ),
    },
    doc = "Install Python packages with uv into site-packages for Bazel targets.",
)
