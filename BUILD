load("@buildifier_prebuilt//:rules.bzl", "buildifier", "buildifier_test")
load("@gazelle//:def.bzl", "gazelle")
load("@rules_python//python:defs.bzl", "py_binary")
load("@rules_uv//uv:pip.bzl", "pip_compile")
load("@rules_uv//uv:venv.bzl", "create_venv")

# gazelle:prefix github.com/dariemp/bazel_template_project
gazelle(name = "gazelle")

# Lock: pyproject.toml -> requirements.txt via uv (rules_uv).
pip_compile(
    name = "generate_requirements_txt",
    requirements_in = "//:pyproject.toml",
    requirements_txt = "//:requirements.txt",
)

# Dev / IDE venv (optional): bazel run //:create_venv
create_venv(
    name = "create_venv",
    destination_folder = ".venv",
    requirements_txt = "//:requirements.txt",
)

# Console script from uv-installed site-packages (@uv_deps), not @pypi.
py_binary(
    name = "whitespace_format",
    srcs = ["//tools/python:whitespace_format_main.py"],
    main = "whitespace_format_main.py",
    deps = ["@uv_deps//:pkgs"],
)

buildifier(
    name = "buildifier",
    exclude_patterns = ["./.git/*"],
    lint_mode = "fix",
    mode = "fix",
)

buildifier_test(
    name = "buildifier_test",
    size = "small",
    exclude_patterns = ["./.git/*"],
    lint_mode = "warn",
    no_sandbox = True,
    workspace = "//:BUILD",
)
