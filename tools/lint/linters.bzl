"""Lint aspects (aspect_rules_lint). Enabled via --config=... in .bazelrc."""

load("@aspect_rules_lint//lint:clang_tidy.bzl", "lint_clang_tidy_aspect")
load("@aspect_rules_lint//lint:eslint.bzl", "lint_eslint_aspect")

clang_tidy = lint_clang_tidy_aspect(
    binary = Label("//tools/cpp:clang_tidy"),
    configs = [Label("//:.clang-tidy")],
    lint_target_headers = False,
    angle_includes_are_system = True,
)

eslint = lint_eslint_aspect(
    binary = Label("//tools/js:eslint"),
    configs = [
        Label("//:eslintrc"),
        Label("//:tsconfig"),
    ],
)
