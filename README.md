# bazel_template_project

Template for a polyglot Bazel monorepo using **bzlmod**. **Python, Go, TypeScript, Rust, C, and C++** are all built, formatted, linted, type-checked, and tested through Bazel. Every tool (compilers, SDKs, formatters, linters, test frameworks, and the **prek** hook runner) is declared as a pinned Bazel external repository in `MODULE.bazel`. The host only needs **Bazelisk**.

## Prerequisites

- [Bazelisk](https://github.com/bazelbuild/bazelisk). It reads `.bazelversion` (Bazel 8.7.0) and downloads that release.
- Nothing else: no system Python/Go/Node/Rust/clang, no `pip`/`npm`/`cargo` installs.

## Quick start

```bash
git clone https://github.com/dariemp/bazel_template_project.git
cd bazel_template_project

bazel test //...                              # every test in every language
bazel run //tools:prek -- run --all-files     # every hook (same as CI)
bazel run //tools:prek -- install             # install the git pre-commit hook
```

## Languages

Each language has a small `calculator` sample exposing `add(a, b)`, with a unit test.

### Python

| Concern | Tool | Provided by | Run |
| --- | --- | --- | --- |
| Interpreter | CPython 3.13 | `rules_python` toolchain | |
| Format | Ruff format + Black | `@uv_deps` (uv, `requirements.txt`) | `bazel run //:ruff -- format --check python tools` / `bazel run //:black -- --check python tools` |
| Lint | Ruff | `@uv_deps` | `bazel run //:ruff -- check python tools` |
| Type check | mypy (strict) | `@uv_deps` | `bazel run //:mypy -- python tools` |
| Tests | pytest | `@uv_deps` | `bazel test //python/calculator:calculator_test` |

Targets: `//python/calculator:calculator` (`py_library`), `//python/calculator:calculator_test` (`py_test`), plus the older `//python/greeting` sample.

This repo does **not** use `rules_python` `pip.parse` / `@pypi`:

| Concern | Tool |
| --- | --- |
| Declare deps | `pyproject.toml` |
| Lock | `rules_uv` `pip_compile` → `requirements.txt` (`bazel run //:generate_requirements_txt`) |
| Install for Bazel targets | `uv pip install --target` via repository rule `//tools/python:uv_pip.bzl` → `@uv_deps//:pkgs` |
| Dev / editor venv | `rules_uv` `create_venv` (`bazel run //:create_venv` → `.venv/`) |

### Go

| Concern | Tool | Provided by | Run |
| --- | --- | --- | --- |
| SDK | Go (version from `go.mod`) | `rules_go` `go_sdk` | |
| Format | gofmt (`go/format`) | `//tools/go/gofmtcheck`, built with the Bazel Go SDK | `bazel run //tools/go/gofmtcheck` (`-- -w` to fix) |
| Lint / static | `go vet` analyzers via **nogo** | `rules_go` (`//tools/go:nogo`) | runs on every Go compile; `bazel build //cmd/... //pkg/...` |
| BUILD files | Gazelle | `gazelle` | `bazel run //:gazelle` |
| Tests | `testing` + testify | `go_deps` (`go.mod`) | `bazel test //pkg/calculator:calculator_test` |

Targets: `//pkg/calculator:calculator`, `//pkg/calculator:calculator_test`, `//cmd/hello:hello`, `//cmd/hello:hello_test`.

### TypeScript

| Concern | Tool | Provided by | Run |
| --- | --- | --- | --- |
| Runtime | Node.js 24 | `rules_nodejs` toolchain | |
| Packages | pnpm lockfile | `aspect_rules_js` (`npm_translate_lock`) | `bazel run -- @pnpm --dir $PWD install --lockfile-only` |
| Format | Prettier | npm via `aspect_rules_js` | `bazel run //tools/js:prettier -- --check .` (`--write .` to fix) |
| Lint | ESLint + typescript-eslint | npm + `aspect_rules_lint` aspect | `bazel build --config=eslint //...` |
| Type check | tsc | `aspect_rules_ts` (`ts_project`) | `bazel build //typescript/...` |
| Tests | Jest | `aspect_rules_jest` | `bazel test //typescript/calculator:calculator_test` |

Targets: `//typescript/calculator:calculator` (`ts_project`), `//typescript/calculator:calculator_test` (`jest_test`).

ESLint is pinned to 9.x because the `aspect_rules_lint` formatter still needs ESLint 9.

### Rust

| Concern | Tool | Provided by | Run |
| --- | --- | --- | --- |
| Toolchain | rustc 1.98.0 (stable) | `rules_rust` | |
| Format | rustfmt | `rules_rust` toolchain (aspect) | `bazel build --config=rustfmt //...` |
| Lint / static | Clippy (`-D warnings`) | `rules_rust` toolchain (aspect) | `bazel build --config=clippy //...` |
| Tests | built-in `#[test]` | `rules_rust` `rust_test` | `bazel test //rust/calculator:calculator_test` |

Targets: `//rust/calculator:calculator` (`rust_library`), `//rust/calculator:calculator_test` (`rust_test`). No crates.io deps.

### C and C++

| Concern | Tool | Provided by | Run |
| --- | --- | --- | --- |
| Compiler | clang 22.1.8 + libc++ | `toolchains_llvm`, with a pinned Chromium Debian sysroot | |
| Format | clang-format (`.clang-format`) | `toolchains_llvm` LLVM distribution | `bazel run //tools/cpp:clang_format` (`-- --fix` to fix) |
| Lint / static | clang-tidy (`.clang-tidy`, includes clang-analyzer) | LLVM distribution + `aspect_rules_lint` aspect | `bazel build --config=clang-tidy //...` |
| Tests | GoogleTest | `googletest` (BCR) | `bazel test //c/calculator:calculator_test //cpp/calculator:calculator_test` |

Targets: `//c/calculator:calculator` (C11 `cc_library`), `//c/calculator:calculator_test`, `//cpp/calculator:calculator` (C++17 `cc_library`), `//cpp/calculator:calculator_test`. The C library is tested with GoogleTest via its `extern "C"` header.

### Starlark

- `bazel run //:buildifier` formats BUILD, .bzl, and MODULE files. `bazel test //:buildifier_test` checks them.

## Pre-commit hooks (prek)

**[prek](https://github.com/j178/prek)** reads the standard `.pre-commit-config.yaml` format. It is a Rust binary and replaces the Python `pre-commit` package. prek itself is a pinned release binary fetched by Bazel (`http_archive` with sha256 for linux/macOS x86_64 and aarch64) and exposed as `//tools:prek`. Each hook is `repo: local` / `language: system` and runs a `bazel run`, `bazel build`, or `bazel test` command.

| Hook id | Command |
| --- | --- |
| `format-ruff` | `bazel run //:ruff -- format --check python tools` |
| `format-black` | `bazel run //:black -- --check python tools` |
| `lint-ruff` | `bazel run //:ruff -- check python tools` |
| `typecheck-mypy` | `bazel run //:mypy -- python tools` |
| `gofmt` | `bazel run //tools/go/gofmtcheck` |
| `go-vet` | `bazel build //cmd/... //pkg/... //tools/go/...` (nogo) |
| `gazelle` | `bazel run //:gazelle -- -mode=diff` |
| `format-prettier` | `bazel run //tools/js:prettier -- --check .` |
| `lint-eslint` | `bazel build --config=eslint //...` |
| `typecheck-tsc` | `bazel build //typescript/...` |
| `rustfmt` | `bazel build --config=rustfmt //...` |
| `clippy` | `bazel build --config=clippy //...` |
| `clang-format` | `bazel run //tools/cpp:clang_format` |
| `clang-tidy` | `bazel build --config=clang-tidy //...` |
| `buildifier` | `bazel test //:buildifier_test` |
| `tests` | `bazel test //...` |

```bash
bazel run //tools:prek -- install                        # git pre-commit hook
bazel run //tools:prek -- run --all-files                # all hooks
bazel run //tools:prek -- run clippy --all-files         # one hook
```

CI (`.github/workflows/ci.yml`) installs only Bazelisk (`bazel-contrib/setup-bazel`). It runs each hook as its own step with `bazel run //tools:prek -- run <hook-id> --all-files`.

## Notes

- `MODULE.bazel.lock`, `pnpm-lock.yaml`, `go.sum`, and `requirements.txt` are tracked. Commit them when deps change.
- The first build downloads the LLVM distribution (~1.9 GB). After that it is served from Bazel's repository cache, which CI caches too.
- Optional owner action: mark this GitHub repo as a **Template repository** in Settings to get the "Use this template" button.
