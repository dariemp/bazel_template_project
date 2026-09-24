"""Install PyPI packages with uv into an external repository for rules_python.

rules_uv 0.88 provides pip_compile (locking) and create_venv (dev venvs) but
does not replace rules_python pip.parse hubs. This repository rule uses the
same uv binary family as rules_uv to install a locked requirements.txt into a
site-packages tree that py_library / py_binary / py_test can depend on via
@uv_deps//:pkgs.
"""

_UV_VERSION = "0.8.11"

# Mirrors @rules_uv//uv/private:uv.lock.json (rules_uv 0.88.0).
_UV_BINARIES = {
    "linux_x86_64": {
        "url": "https://github.com/astral-sh/uv/releases/download/{v}/uv-x86_64-unknown-linux-gnu.tar.gz".format(v = _UV_VERSION),
        "sha256": "0c6078318332c100d7d9988ea99144b534e40adef2958aa314a9f7c7b8516ed7",
        "file": "uv-x86_64-unknown-linux-gnu/uv",
    },
    "linux_arm64": {
        "url": "https://github.com/astral-sh/uv/releases/download/{v}/uv-aarch64-unknown-linux-musl.tar.gz".format(v = _UV_VERSION),
        "sha256": "1c6045bec4d5ca17777dd271401a0407c5acad79f74fd38f35c31ca64c689808",
        "file": "uv-aarch64-unknown-linux-musl/uv",
    },
    "darwin_x86_64": {
        "url": "https://github.com/astral-sh/uv/releases/download/{v}/uv-x86_64-apple-darwin.tar.gz".format(v = _UV_VERSION),
        "sha256": "7ed76b0cc314fa0cb6dd7ae99379efd3cf8fc14d71af8d71b0b5238582c7958d",
        "file": "uv-x86_64-apple-darwin/uv",
    },
    "darwin_arm64": {
        "url": "https://github.com/astral-sh/uv/releases/download/{v}/uv-aarch64-apple-darwin.tar.gz".format(v = _UV_VERSION),
        "sha256": "c9e74f779a65798057bca2ff328d5c9952f458391e220c3d3216d7a03a338d9f",
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

py_library(
    name = "pkgs",
    srcs = glob(
        ["site-packages/**/*.py"],
        allow_empty = True,
    ),
    data = glob(
        ["site-packages/**/*"],
        exclude = [
            "site-packages/**/*.py",
            "site-packages/**/__pycache__/**",
            "site-packages/**/*.pyc",
        ],
        allow_empty = True,
    ),
    imports = ["site-packages"],
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
