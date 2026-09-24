# bazel_template_project

Template for a Bazel monorepo using **bzlmod**, with **Go** (`rules_go` + Gazelle), **Python** (`rules_python` + **uv** via `rules_uv` locking + a uv install repository), and **prek** hooks (standard `.pre-commit-config.yaml`, mirrored in CI).

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

# Ruff / Black (hermetic via @uv_deps)
bazel run //:ruff -- --help
bazel run //:black -- --help
bazel run //:ruff -- format --check python tools
bazel run //:ruff -- check python tools
bazel run //:black -- --check python tools

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
| Format / lint | `ruff` + `black` console scripts via `@uv_deps` (`//:ruff`, `//:black`) |

Depend on third-party packages from `py_library` / `py_binary` / `py_test` with:

```starlark
deps = ["@uv_deps//:pkgs"]
```

`rules_uv` 0.88 provides locking and venv helpers only (no pip hub). The small `uv_pip_repository` rule fills that gap using the same uv release family as `rules_uv`.

## Pre-commit hooks (prek)

This repo uses **[prek](https://github.com/j178/prek)** — a single Rust binary that understands the standard `.pre-commit-config.yaml` format — **not** the Python `pre-commit` package and **not** lefthook. Same discrete-hook config model, faster installs/CI, no Python runtime for the hook runner. Each check is its own hook (`repo: local` / `language: system`) calling hermetic Bazel targets (or `./tools/check-gofmt.sh`).

Hooks (in order):

1. **format-ruff** — `bazel run //:ruff -- format --check python tools`
2. **format-black** — `bazel run //:black -- --check python tools`
3. **lint-ruff** — `bazel run //:ruff -- check python tools`
4. **tests** — `bazel test //...`
5. **buildifier** — `bazel test //:buildifier_test`
6. **gofmt** — `./tools/check-gofmt.sh`
7. **gazelle** — `bazel run //:gazelle -- -mode=diff`

```bash
# Install prek (pinned example; see https://github.com/j178/prek/releases)
curl --proto '=https' --tlsv1.2 -LsSf \
  https://github.com/j178/prek/releases/download/v0.5.3/prek-installer.sh | sh

# Install the git pre-commit hook
prek install
# or: ./tools/install-prek-hooks.sh

# Run all hooks (same as CI)
prek run --all-files

# Run one hook
prek run format-ruff --all-files
prek run lint-ruff --all-files
```

Edit `.pre-commit-config.yaml` to add or change hooks. CI (`.github/workflows/ci.yml`) installs pinned prek **0.5.3** and runs each hook id as its own named step.

## Status

- Go: `go.mod`, `go_sdk` / `go_deps` in `MODULE.bazel`, Gazelle-generated `//cmd/hello`.
- Python: uv lock + uv runtime install (`@uv_deps`), sample `//python/greeting` with pytest, `whitespace_format` / `ruff` / `black` via uv site-packages.
- Hooks + CI: prek + discrete `.pre-commit-config.yaml` hooks (`format-ruff` / `format-black` / `lint-ruff` / `tests` / `buildifier` / `gofmt` / `gazelle`); no Python `pre-commit` dependency.
- Optional owner action: mark this GitHub repo as a **Template repository** in Settings if you want the green “Use this template” button.

`MODULE.bazel.lock` is tracked and should be committed when module deps change.
