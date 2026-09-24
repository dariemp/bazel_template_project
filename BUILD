load("@buildifier_prebuilt//:rules.bzl", "buildifier", "buildifier_test")
load("@gazelle//:def.bzl", "gazelle")
load("@rules_python//python/entry_points:py_console_script_binary.bzl", "py_console_script_binary")
load("@rules_uv//uv:pip.bzl", "pip_compile")

# gazelle:prefix github.com/dariemp/bazel_template_project
gazelle(name = "gazelle")

pip_compile(
    name = "generate_requirements_txt",
    requirements_in = "//:pyproject.toml",
    requirements_txt = "//:requirements.txt",
)

py_console_script_binary(
    name = "whitespace_format",
    pkg = "@pypi//whitespace_format",
    script = "whitespace-format",
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
