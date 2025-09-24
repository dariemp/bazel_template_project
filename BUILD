load("@gazelle//:def.bzl", "gazelle")
load("@rules_uv//uv:pip.bzl", "pip_compile")

gazelle(name = "gazelle")

pip_compile(
    name = "generate_requirements_txt",
    requirements_in = "//:pyproject.toml",
    requirements_txt = "//:requirements.txt",
)

py_binary(
    name = "whitespace_format",
    srcs = [
        "@pypi//whitespace_format"
    ],
    deps = [
        "@pypi//whitespace_format"
    ],
    args = [
        "--exclude",
        '".git/|.pyc$$"',
        "--new-line-marker",
        "linux",
        "--normalize-new-line-markers",
    ]
)
