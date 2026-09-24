load("@aspect_rules_js//js:defs.bzl", "js_library")
load("@aspect_rules_ts//ts:defs.bzl", "ts_config")
load("@buildifier_prebuilt//:rules.bzl", "buildifier", "buildifier_test")
load("@gazelle//:def.bzl", "gazelle")
load("@npm//:defs.bzl", "npm_link_all_packages")
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

# Console scripts from uv-installed site-packages (@uv_deps), not @pypi.
py_binary(
    name = "whitespace_format",
    srcs = ["//tools/python:whitespace_format_main.py"],
    main = "whitespace_format_main.py",
    deps = ["@uv_deps//:pkgs"],
)

py_binary(
    name = "ruff",
    srcs = ["//tools/python:ruff_main.py"],
    main = "ruff_main.py",
    deps = ["@uv_deps//:pkgs"],
)

py_binary(
    name = "mypy",
    srcs = ["//tools/python:mypy_main.py"],
    main = "mypy_main.py",
    deps = ["@uv_deps//:pkgs"],
)

py_binary(
    name = "black",
    srcs = ["//tools/python:black_main.py"],
    main = "black_main.py",
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

# TypeScript: link npm packages from pnpm-lock.yaml into bazel-bin/node_modules.
npm_link_all_packages(name = "node_modules")

ts_config(
    name = "tsconfig",
    src = "tsconfig.json",
    visibility = ["//visibility:public"],
)

js_library(
    name = "eslintrc",
    srcs = ["eslint.config.mjs"],
    visibility = ["//visibility:public"],
    deps = [
        ":node_modules/@eslint/js",
        ":node_modules/typescript-eslint",
    ],
)

# Root package.json in runfiles: Jest walks up from the runfiles root looking for it.
js_library(
    name = "package_json",
    srcs = ["package.json"],
    visibility = ["//visibility:public"],
)

exports_files(
    [
        ".clang-tidy",
        ".prettierrc.json",
        "eslint.config.mjs",
        "package.json",
        "rustfmt.toml",
        "tsconfig.json",
    ],
    visibility = ["//visibility:public"],
)
