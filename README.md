# bazel_template_project

Template for a Bazel monorepo using **bzlmod**, with **Go** (`rules_go` + Gazelle), **Python** (`rules_python` + `rules_uv`), and Bazel-managed **pre-commit**.

## Prerequisites

- [Bazelisk](https://github.com/bazelbuild/bazelisk) (recommended). It reads `.bazelversion` and installs that Bazel release.
- Alternatively, install Bazel yourself to match `.bazelversion` (see also `bin/install_bazel.sh` for a Debian/Ubuntu apt path).

## First commands

```bash
git clone https://github.com/dariemp/bazel_template_project.git
cd bazel_template_project

# Regenerate Python requirements.txt from pyproject.toml
bazel run //:generate_requirements_txt

# Run Gazelle (BUILD file generation; limited until Go packages exist)
bazel run //:gazelle

# Pre-commit hooks via Bazel
bazel run //pre_commit_hooks:pre_commit_hooks

# Whitespace formatter
bazel run //:whitespace_format
```

## Status

Go sample code and full Gazelle wiring (`go.mod`, `go_sdk` / `go_deps`) are **not** set up yet. `rules_go` and Gazelle are declared in `MODULE.bazel`, but there are no Go packages to build or test. Python tooling and lock generation are present; there is no sample application library yet.

`MODULE.bazel.lock` is tracked and should be committed when module deps change.
