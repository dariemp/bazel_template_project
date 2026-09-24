# bazel_template_project

Template for a Bazel monorepo using **bzlmod**, with **Go** (`rules_go` + Gazelle), **Python** (`rules_python` + `rules_uv`), and **repo-native hooks** (YAML config + git hooks, mirrored in CI).

## Prerequisites

- [Bazelisk](https://github.com/bazelbuild/bazelisk) (recommended). It reads `.bazelversion` and installs that Bazel release.
- Alternatively, install Bazel yourself to match `.bazelversion` (see also `bin/install_bazel.sh` for a Debian/Ubuntu apt path).

## First commands

```bash
git clone https://github.com/dariemp/bazel_template_project.git
cd bazel_template_project

# Go sample
bazel build //cmd/hello:hello
bazel run //cmd/hello:hello
bazel test //cmd/hello:hello_test

# Regenerate BUILD files for Go packages
bazel run //:gazelle

# Python sample
bazel test //python/greeting:greeting_test

# Regenerate Python requirements.txt from pyproject.toml
bazel run //:generate_requirements_txt

# Optional whitespace formatter (PyPI console script via rules_python)
bazel run //:whitespace_format -- --help

# Format Starlark / check formatting
bazel run //:buildifier
bazel test //:buildifier_test
```

## Native pre-commit hooks

This repo does **not** use the Python `pre-commit` package. Checks are declared in `tools/hooks.yaml` and run by `tools/run-hooks.sh`.

```bash
# Install the git hook (sets core.hooksPath=tools/githooks)
./tools/install-hooks.sh

# Run the same checks manually / in CI
./tools/run-hooks.sh
```

Edit `tools/hooks.yaml` to add or change steps (bazel test, buildifier, gofmt, gazelle diff, …). CI (`.github/workflows/ci.yml`) runs the same script.

## Status

- Go: `go.mod`, `go_sdk` / `go_deps` in `MODULE.bazel`, Gazelle-generated `//cmd/hello`.
- Python: `rules_uv` lock (`requirements.txt`), sample `//python/greeting`, `whitespace_format` via `py_console_script_binary`.
- Hooks + CI: YAML-driven native hooks; no Python `pre-commit` dependency.
- Optional owner action: mark this GitHub repo as a **Template repository** in Settings if you want the green “Use this template” button.

`MODULE.bazel.lock` is tracked and should be committed when module deps change.
