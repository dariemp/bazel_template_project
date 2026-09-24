# bazel_template_project

Template for a Bazel monorepo using **bzlmod**, with **Go** (`rules_go` + Gazelle), **Python** (`rules_python` + **uv** via `rules_uv` locking + a uv install repository), and **repo-native hooks** (YAML config + git hooks, mirrored in CI).

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

# Python sample (pytest via bazel test; deps from uv-installed @uv_deps)
bazel test //python/greeting:greeting_test

# Regenerate Python requirements.txt from pyproject.toml (rules_uv + uv)
bazel run //:generate_requirements_txt

# Optional local IDE venv (same lockfile; not used by bazel test/build)
bazel run //:create_venv

# Optional whitespace formatter (console script from uv site-packages)
bazel run //:whitespace_format -- --help

# Format Starlark / check formatting
bazel run //:buildifier
bazel test //:buildifier_test
```

## Python + uv

This repo does **not** use `rules_python` `pip.parse` / `@pypi` for installing packages.

| Concern | Tool |
| --- | --- |
| Declare deps | `pyproject.toml` |
| Lock | `rules_uv` `pip_compile` → `requirements.txt` (`bazel run //:generate_requirements_txt`) |
| Install for Bazel targets | `uv pip install --target` via repository rule `//tools/python:uv_pip.bzl` → `@uv_deps//:pkgs` |
| Dev / editor venv | `rules_uv` `create_venv` (`bazel run //:create_venv` → `.venv/`) |
| Tests | `pytest` on `@uv_deps//:pkgs`; `py_test` calls `pytest.main` |

Depend on third-party packages from `py_library` / `py_binary` / `py_test` with:

```starlark
deps = ["@uv_deps//:pkgs"]
```

`rules_uv` 0.88 provides locking and venv helpers only (no pip hub). The small `uv_pip_repository` rule fills that gap using the same uv release family as `rules_uv`.

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
- Python: uv lock + uv runtime install (`@uv_deps`), sample `//python/greeting` with pytest, `whitespace_format` via uv site-packages.
- Hooks + CI: YAML-driven native hooks; no Python `pre-commit` dependency.
- Optional owner action: mark this GitHub repo as a **Template repository** in Settings if you want the green “Use this template” button.

`MODULE.bazel.lock` is tracked and should be committed when module deps change.
