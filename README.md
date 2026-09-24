# bazel_template_project

A template for a polyglot **Bazel monorepo** (Bazel 8.7.0, bzlmod). Python, Go,
TypeScript, Rust, C, and C++ are built, formatted, linted, type-checked, and
tested through Bazel. Every tool (compilers, SDKs, formatters, linters, test
frameworks, and the [prek](https://github.com/j178/prek) hook runner) is a
pinned external repository declared in `MODULE.bazel`. Nothing is installed on
the host apart from Bazelisk.

Copy it into a new repository (or use GitHub's "Use this template"), delete the
languages you don't need, and replace the `calculator` examples with real code.

- [Quick start](#quick-start)
- [Repository layout](#repository-layout)
- [Python](#python)
- [Go](#go)
- [TypeScript](#typescript)
- [Rust](#rust)
- [C](#c)
- [C++](#c-1)
- [C/C++ toolchain details and caveats](#cc-toolchain-details-and-caveats)
- [Starlark](#starlark)
- [Hooks (prek)](#hooks-prek)
- [CI](#ci)
- [Adding a language or tool](#adding-a-language-or-tool)

## Quick start

### Host requirements

| Tool | Why |
| --- | --- |
| [Bazelisk](https://github.com/bazelbuild/bazelisk), installed as `bazel` | Reads `.bazelversion` (8.7.0) and downloads that Bazel release. The hooks call `bazel` from `PATH`. |
| `git` | Source control; prek installs its hook into `.git/hooks`. |
| `bash` and basic POSIX utilities (`grep`, `sed`, `tr`, `mktemp`) | Used by Bazel-generated launcher scripts and the clang-tidy wrappers. Present on every Linux distribution and on macOS. |

There is no system Python, Go, Node.js, Rust, or C/C++ compiler involved, and
no `pip`, `npm`, or `cargo` install step. C and C++ are compiled by `zig cc`
from [hermetic_cc_toolchain](https://github.com/uber/hermetic_cc_toolchain);
host compiler autodetection is disabled (`BAZEL_DO_NOT_DETECT_CPP_TOOLCHAIN=1`
in `.bazelrc`). On macOS the C/C++ build does not use the Xcode SDK: zig
compiles against its bundled macOS headers and link stubs (CI checks the
compile and link command lines and `otool -L` output). It has not been tried
on a Mac without Xcode or the Command Line Tools installed.

Supported hosts: Linux (x86_64, aarch64, glibc) and macOS (x86_64, arm64). CI
covers Linux x86_64 fully and macOS arm64 for C/C++ (see [CI](#ci)).

### First build

```bash
git clone https://github.com/dariemp/bazel_template_project.git
cd bazel_template_project

bazel test //...                              # build and run every test
bazel run //tools:prek -- install             # install the git pre-commit hook
bazel run //tools:prek -- run --all-files     # run all 16 hooks, same as CI
```

A cold `bazel test //...` plus the C/C++ lint and format hooks downloads about
**830 MB** on Linux x86_64: ~745 MB of Bazel external repositories (the largest
are the Rust toolchain, the Node.js, Go, and Python toolchains, and the 54 MB Zig
SDK), ~78 MB of PyPI wheels installed by uv (clang-tidy alone is 44 MB), and
~7 MB of Go modules. Extracted, the external repositories take about 3.3 GB in
Bazel's output base. After that, everything is served from Bazel's repository
cache, which CI caches too.

Zig also keeps a small compilation cache (libc++, libc stubs; tens of MB) in
`~/.cache/zig`, outside Bazel's output base.

### Everyday commands

```bash
bazel build //...                                   # build everything
bazel test //...                                    # all tests
bazel run //tools:prek -- run --all-files           # all hooks
bazel run //tools:prek -- run clang-tidy --all-files  # one hook by id
bazel run //tools:prek -- uninstall                 # remove the git hook
```

## Repository layout

| Path | Contents |
| --- | --- |
| `MODULE.bazel` | Every external dependency and toolchain, with pinned versions. |
| `.bazelrc` | Lint/format configs (`--config=clang-tidy`, `eslint`, `rustfmt`, `clippy`) and C/C++ toolchain flags. |
| `.pre-commit-config.yaml` | The 16 prek hooks; each one runs a Bazel command. |
| `.github/workflows/ci.yml` | CI: one step per hook on Ubuntu, plus a macOS C/C++ job. |
| `python/`, `cmd/` + `pkg/`, `typescript/`, `rust/`, `c/`, `cpp/` | One `calculator` example per language, each with a unit test. |
| `tools/` | Launchers and Bazel glue for the tools (prek, clang-format, clang-tidy, uv, gofmt, Prettier, ESLint, lint aspects). |
| `pyproject.toml` / `requirements.txt` | Python dependencies (declared / locked). Also pins clang-format and clang-tidy. |
| `go.mod` / `go.sum` | Go version and Go module dependencies. |
| `package.json` / `pnpm-lock.yaml` | npm dev dependencies (TypeScript, ESLint, Prettier, Jest). |
| `.clang-format`, `.clang-tidy`, `rustfmt.toml`, `eslint.config.mjs`, `.prettierrc.json`, `tsconfig.json` | Tool configuration. |

`MODULE.bazel.lock`, `requirements.txt`, `go.sum`, and `pnpm-lock.yaml` are
committed. Commit them whenever dependencies change.

## Python

**Example.** `//python/calculator` is a `py_library` exposing `add(a, b)`,
tested by `//python/calculator:calculator_test` (pytest, parametrized). An older
`//python/greeting` sample follows the same pattern.

| Concern | Tool (version) | Where Bazel gets it |
| --- | --- | --- |
| Interpreter | CPython 3.13.9 | `rules_python` 1.7.0 hermetic toolchain |
| Formatters | Ruff format 0.16.8, Black 26.5.1 | PyPI, installed by uv into `@uv_deps` |
| Linter | Ruff 0.16.8 | PyPI via `@uv_deps` |
| Static checker | mypy 2.3.1 (`strict = true`) | PyPI via `@uv_deps` |
| Tests | pytest 9.1.1 | PyPI via `@uv_deps` |
| Locking | uv (`pip_compile`) | `rules_uv` 0.88.0 |

Dependencies are **not** managed with `rules_python`'s `pip.parse`/`@pypi`. The
flow is:

1. Declare dependencies in `pyproject.toml`.
2. Lock them into `requirements.txt` (with hashes, for every platform) with
   `bazel run //:generate_requirements_txt`. `bazel test //...` includes
   `//:generate_requirements_txt_test`, which fails when the lock is stale.
3. The repository rule in `tools/python/uv_pip.bzl` downloads uv 0.8.11 and runs
   `uv pip install --target` with the hermetic interpreter, producing
   `@uv_deps//:pkgs`. Python targets depend on that one `py_library`.

**Build and test**

```bash
bazel build //python/...
bazel test //python/...
bazel test //python/calculator:calculator_test
```

**Format, lint, and type-check**

| Hook id | Underlying command | Auto-fix |
| --- | --- | --- |
| `format-ruff` | `bazel run //:ruff -- format --check python tools` | `bazel run //:ruff -- format python tools` |
| `format-black` | `bazel run //:black -- --check python tools` | `bazel run //:black -- python tools` |
| `lint-ruff` | `bazel run //:ruff -- check python tools` | `bazel run //:ruff -- check --fix python tools` |
| `typecheck-mypy` | `bazel run //:mypy -- python tools` | none (fix by hand) |

The launchers (`tools/python/*_main.py`) `cd` to the workspace root, so paths
are relative to the repo. Settings live in `pyproject.toml` (`[tool.ruff]`,
`[tool.black]`, `[tool.mypy]`).

**Notes**

- **New Python directory:** the hooks only look at `python` and `tools`. Add
  new top-level directories to the `entry:` of `format-ruff`, `format-black`,
  `lint-ruff`, and `typecheck-mypy` in `.pre-commit-config.yaml`.
- **New package:** add it to `pyproject.toml`, run
  `bazel run //:generate_requirements_txt`, and commit `requirements.txt`. The
  next build reinstalls `@uv_deps` automatically.
- **Editor virtualenv:** `bazel run //:create_venv` creates `.venv/` (ignored
  by git and by the hooks) from `requirements.txt`.
- Imports are rooted at the repo (`from python.calculator.calculator import add`)
  via `imports = ["../.."]` on the `py_library`.

## Go

**Example.** `//pkg/calculator` is a `go_library` with a testify-based test
(`//pkg/calculator:calculator_test`). `//cmd/hello` is a `go_binary` with a unit
test (`//cmd/hello:hello_test`).

| Concern | Tool (version) | Where Bazel gets it |
| --- | --- | --- |
| SDK | Go 1.25.0 (from the `go` line in `go.mod`) | `rules_go` 0.63.0 `go_sdk.from_file` |
| Formatter | gofmt rules via `go/format` | `//tools/go/gofmtcheck`, built with the Bazel Go SDK |
| Linter / static checker | `go vet` analyzers through **nogo** | `rules_go` (`//tools/go:nogo`), runs during every Go compile |
| BUILD files | Gazelle 0.54.0 | `gazelle` module |
| Tests | `testing` + testify 1.12.1 | `go_deps.from_file(go_mod = "//:go.mod")` |

**Build, run, and test**

```bash
bazel build //cmd/... //pkg/...
bazel run //cmd/hello
bazel test //cmd/... //pkg/...
```

**Format and lint**

| Hook id | Underlying command | Auto-fix |
| --- | --- | --- |
| `gofmt` | `bazel run //tools/go/gofmtcheck` | `bazel run //tools/go/gofmtcheck -- -w` |
| `go-vet` | `bazel build //cmd/... //pkg/... //tools/go/...` | none; nogo findings fail the compile |
| `gazelle` | `bazel run //:gazelle -- -mode=diff` | `bazel run //:gazelle` |

**Notes**

- **New Go package or directory:** write the `.go` files, then run
  `bazel run //:gazelle` to generate or update `BUILD.bazel`. The `gazelle`
  hook fails when BUILD files are out of date. gofmtcheck walks the whole repo,
  but the `go-vet` hook only builds `//cmd/...`, `//pkg/...`, and
  `//tools/go/...`; add new top-level Go directories to its `entry:`.
- **New module dependency:** use the Bazel-managed `go` command, then sync the
  repos and BUILD files:

  ```bash
  bazel run @rules_go//go -- get github.com/google/go-cmp@latest
  bazel run @rules_go//go -- mod tidy
  bazel mod tidy          # updates use_repo(go_deps, ...) in MODULE.bazel
  bazel run //:gazelle
  ```

  (`go mod tidy` drops modules that no code imports yet, so import it first.)
- **Go version:** change the `go` line in `go.mod`.
- The Gazelle import prefix is set in the root `BUILD`
  (`# gazelle:prefix github.com/dariemp/bazel_template_project`). Change it to
  your module path together with `go.mod`.

## TypeScript

**Example.** `//typescript/calculator:calculator` is a `ts_project` (compiled and
type-checked by tsc). `//typescript/calculator:calculator_test` is a `jest_test`
that runs the compiled `calculator.test.js`.

| Concern | Tool (version) | Where Bazel gets it |
| --- | --- | --- |
| Runtime | Node.js 24.18.0 | `rules_nodejs` 6.7.5 toolchain |
| Packages | pnpm 10 lockfile (`pnpm-lock.yaml`) | `aspect_rules_js` 3.4.1 `npm_translate_lock` |
| Formatter | Prettier 3.9.9 | npm via `aspect_rules_js` (`//tools/js:prettier`) |
| Linter | ESLint 9.39.5 + typescript-eslint 8.70.1 (`strictTypeChecked`, `stylisticTypeChecked`) | npm, run by an `aspect_rules_lint` 2.9.0 aspect |
| Static checker | TypeScript 5.9.3 (`tsc`, `strict`) | `aspect_rules_ts` 3.10.1, version read from `package.json` |
| Tests | Jest 30.5.2 | `aspect_rules_jest` 0.26.0 |

**Build and test**

```bash
bazel build //typescript/...     # compiles and type-checks
bazel test //typescript/...
```

**Format, lint, and type-check**

| Hook id | Underlying command | Auto-fix |
| --- | --- | --- |
| `format-prettier` | `bazel run //tools/js:prettier -- --check .` | `bazel run //tools/js:prettier -- --write .` |
| `lint-eslint` | `bazel build --config=eslint //...` | see below |
| `typecheck-tsc` | `bazel build //typescript/...` | none (fix by hand) |

ESLint auto-fixes are produced as patch files by the `aspect_rules_lint` fix
mode; apply them with `patch`:

```bash
bazel build --aspects=//tools/lint:linters.bzl%eslint \
  --@aspect_rules_lint//lint:fix --output_groups=rules_lint_patch //...
find bazel-bin/ -name '*AspectRulesLintESLint.patch' -size +0 -exec patch -p1 -i {} \;
```

**Notes**

- **New npm package:** add it to `package.json`, then update the lockfile with
  the Bazel-managed pnpm and commit `pnpm-lock.yaml`:

  ```bash
  bazel run -- @pnpm --dir $PWD install --lockfile-only
  ```

  Reference packages from BUILD files as `//:node_modules/<name>`.
- ESLint is pinned to 9.x because the `aspect_rules_lint` ESLint formatter
  still needs ESLint 9.
- Prettier checks the whole repo except what `.prettierignore` and `.gitignore`
  exclude (Markdown and YAML are excluded on purpose). ESLint and tsc cover
  every `ts_project` automatically, so new directories need no hook changes.
- Jest looks for the root `package.json` in runfiles, so `jest_test` targets
  list `//:package_json` in `data`.

## Rust

**Example.** `//rust/calculator:calculator` is a `rust_library` (edition 2021)
whose `#[cfg(test)]` unit tests run as `//rust/calculator:calculator_test`.

| Concern | Tool (version) | Where Bazel gets it |
| --- | --- | --- |
| Toolchain | rustc 1.98.0 (stable) | `rules_rust` 0.74.0 `rust.toolchain` |
| Formatter | rustfmt (from the same toolchain), `rustfmt.toml` | `rules_rust` `rustfmt_aspect` |
| Linter / static checker | Clippy 0.1.98 with `-D warnings` | `rules_rust` `rust_clippy_aspect` |
| Tests | built-in `#[test]` | `rust_test` |
| Linker | `zig cc` (the C/C++ toolchain below) | `hermetic_cc_toolchain` |

**Build and test**

```bash
bazel build //rust/...
bazel test //rust/...
```

**Format and lint**

| Hook id | Underlying command | Auto-fix |
| --- | --- | --- |
| `rustfmt` | `bazel build --config=rustfmt //...` | `bazel run @rules_rust//:rustfmt` |
| `clippy` | `bazel build --config=clippy //...` | none (fix by hand) |

Both are aspects, so every `rust_*` target in the repo is checked without
touching the hook configuration.

**Notes**

- There is no `Cargo.toml`: crates are declared as Bazel targets. The template
  has no crates.io dependencies. To add some, use `rules_rust`'s
  [crate_universe](https://bazelbuild.github.io/rules_rust/crate_universe_bzlmod.html)
  (`crate.spec(...)` + `crate.from_specs()`, or `crate.from_cargo(...)` if you
  prefer to keep a `Cargo.toml`/`Cargo.lock`), then depend on
  `@crates//:<name>`. This is not set up in the template.
- Change the Rust version in `rust.toolchain(versions = [...])` in `MODULE.bazel`.

## C

**Example.** `//c/calculator:calculator` is a C11 `cc_library` (`add(a, b)`
behind an `extern "C"` header). `//c/calculator:calculator_test` tests it with
GoogleTest, so the test itself is C++.

| Concern | Tool (version) | Where Bazel gets it |
| --- | --- | --- |
| Compiler / linker | `zig cc` from Zig 0.15.2 (clang 20.1.2, lld), glibc 2.28 headers/stubs on Linux, bundled macOS libc headers on macOS | `hermetic_cc_toolchain` 4.3.0 (BCR) |
| Formatter | clang-format 22.1.8, `.clang-format` (Google style) | official PyPI wheel `clang-format==22.1.8`, installed by uv into `@uv_deps` |
| Linter / static checker | clang-tidy 22.1.8 (bugprone, clang-analyzer, misc, modernize, performance, portability, readability; warnings are errors), `.clang-tidy` | official PyPI wheel `clang-tidy==22.1.8` via `@uv_deps`, run by an `aspect_rules_lint` aspect |
| Tests | GoogleTest 1.18.0 | `googletest` module (BCR) |

**Build and test**

```bash
bazel build //c/...
bazel test //c/...
```

**Format and lint**

| Hook id | Underlying command | Auto-fix |
| --- | --- | --- |
| `clang-format` | `bazel run //tools/cpp:clang_format` | `bazel run //tools/cpp:clang_format -- --fix` |
| `clang-tidy` | `bazel build --config=clang-tidy //...` | see below |

`//tools/cpp:clang_format` formats every `.c/.h/.cc/.cpp/.cxx/.hh/.hpp` file in
the repo (skipping `bazel-*`, hidden directories, and `node_modules`), so new
directories are picked up automatically. The clang-tidy aspect visits every
`cc_library` and `cc_binary`; headers under `c/` and `cpp/` are checked when a
source file includes them (`HeaderFilterRegex` in `.clang-tidy`).

clang-tidy fix-its come out as patch files:

```bash
bazel build --aspects=//tools/lint:linters.bzl%clang_tidy \
  --@aspect_rules_lint//lint:fix --output_groups=rules_lint_patch //c/... //cpp/...
find bazel-bin/ -name '*AspectRulesLintClangTidy.patch' -size +0 -exec patch -p1 -i {} \;
```

**Notes**

- **New C directory:** if it isn't under `c/` or `cpp/`, extend
  `HeaderFilterRegex` in `.clang-tidy`, otherwise diagnostics in its headers
  are suppressed.
- Tests (`cc_test`) are not linted; this is the `aspect_rules_lint` default
  (`rule_kinds = ["cc_binary", "cc_library"]` in `tools/lint/linters.bzl`).
- Set the C standard per target with `copts = ["-std=c11"]`.
- See [C/C++ toolchain details and caveats](#cc-toolchain-details-and-caveats).

## C++

**Example.** `//cpp/calculator:calculator` is a C++17 `cc_library`
(`calculator::Add`), tested by `//cpp/calculator:calculator_test` (GoogleTest).

| Concern | Tool (version) | Where Bazel gets it |
| --- | --- | --- |
| Compiler / linker | `zig c++` from Zig 0.15.2 (clang 20.1.2, lld) with zig's bundled libc++ (LLVM 20), linked statically | `hermetic_cc_toolchain` 4.3.0 (BCR) |
| Language standard | C++17 by default (`--cxxopt=-std=c++17` in `.bazelrc`) | |
| Formatter | clang-format 22.1.8, `.clang-format` | PyPI wheel via `@uv_deps` |
| Linter / static checker | clang-tidy 22.1.8, `.clang-tidy` | PyPI wheel via `@uv_deps` + `aspect_rules_lint` |
| Tests | GoogleTest 1.18.0 (`@googletest//:gtest`, `@googletest//:gtest_main`) | `googletest` module (BCR) |

**Build and test**

```bash
bazel build //cpp/...
bazel test //cpp/...
bazel test //c/... //cpp/...
```

**Format and lint:** the same `clang-format` and `clang-tidy` hooks and
commands as [C](#c).

**Notes**

- **New C++ package:** create a directory with a `BUILD.bazel` using
  `cc_library`/`cc_binary`/`cc_test` from `@rules_cc`. Formatting and linting
  pick it up automatically (mind `HeaderFilterRegex` for directories outside
  `c/` and `cpp/`).
- **Third-party C/C++ libraries:** prefer `bazel_dep` from the
  [Bazel Central Registry](https://registry.bazel.build/), as done for
  `googletest`.

## C/C++ toolchain details and caveats

**Toolchain.** `MODULE.bazel` registers these `hermetic_cc_toolchain`
toolchains explicitly:

```starlark
register_toolchains(
    "@zig_sdk//toolchain:linux_amd64_gnu.2.28",
    "@zig_sdk//toolchain:linux_arm64_gnu.2.28",
    "@zig_sdk//toolchain:darwin_amd64",
    "@zig_sdk//toolchain:darwin_arm64",
)
```

Toolchains are created for the host as execution platform. Binaries target
glibc 2.28 on Linux and macOS 13.0 on macOS. Zig ships the libc headers, the
glibc/libSystem link stubs, libc++, and lld, so there is no sysroot to
download. On macOS the compile and link commands carry no `-isysroot` or SDK
path, and the linked test binaries depend only on `/usr/lib/libSystem.B.dylib`.

**`.bazelrc` settings for C/C++**

| Setting | Why |
| --- | --- |
| `common --repo_env=BAZEL_DO_NOT_DETECT_CPP_TOOLCHAIN=1` | Never autodetect a host compiler as a fallback. |
| `build --cxxopt=-std=c++17` / `--host_cxxopt=-std=c++17` | Keep C++17 as the default standard. |
| `build --dynamic_mode=off` | zig links libc++ statically into every binary and shared object. With fastbuild's default dynamic mode, `cc_test` links each `cc_library` as its own `.so`, libc++ ends up in several DSOs, and GoogleTest aborts at exit with `double free or corruption`. Fully static test binaries avoid that. |

**clang-format and clang-tidy from PyPI.** Both are the official LLVM wheels,
pinned in `pyproject.toml`/`requirements.txt` like any other Python package.
Wheels exist for Linux (manylinux x86_64 and aarch64) and macOS (x86_64 and
arm64). The binaries are exported from `@uv_deps` (and kept out of
`@uv_deps//:pkgs`, so Python targets don't carry them). To upgrade, change both
pins in `pyproject.toml` and run `bazel run //:generate_requirements_txt`.

**clang-tidy with zig flags.** `zig c++ -target <triple>` adds the target
triple, the libc and libc++ include paths, and libc++'s configuration macros
internally, so none of them appear in the compile flags Bazel records, and
`aspect_rules_lint` passes only the recorded flags to clang-tidy. Run as is,
clang-tidy would parse the code for its own default triple against the host's
`/usr/include` (or fail with `'vector' file not found` on a host without
headers). `//tools/cpp:clang_tidy` (`tools/cpp/zig_clang_tidy.bzl`) wraps the
wheel's clang-tidy and adds:

- `--target=` matching the zig target (`x86_64-unknown-linux-gnu`,
  `aarch64-unknown-linux-gnu`, `arm64-apple-macosx13.0`, ...);
- `-nostdlibinc`/`-nostdinc++`, so no host headers are searched;
- zig's libc++/libc++abi headers (`-isystem`) and the target's libc headers
  (`-idirafter`), plus the `_LIBCPP_*` macros and `__GLIBC_MINOR__` that zig
  defines (zig ships libc++ without a `__config_site`);
- clang-tidy's own resource directory, so builtin headers (`stddef.h`,
  intrinsics) match clang-tidy's clang version.

All of these headers are declared runfiles of the wrapper, so lint actions
stay sandboxed. Remaining caveats:

- Compilation uses clang 20 (zig 0.15.2) but analysis uses clang 22
  (clang-tidy 22.1.8), against libc++ 20 headers. Code that only one of the two
  accepts may compile but fail lint, or the other way round.
- The macOS arm64 toolchain passes `-mcpu=apple_m1` (zig's spelling), which
  clang rejects. The wrapper rewrites it to `apple-m1`, including inside the
  flag file `aspect_rules_lint` hands to clang-tidy (`--config <file>`).
- The include layout and macros mirror `zig c++ -###` for Zig 0.15.2. Recheck
  `tools/cpp/zig_clang_tidy.bzl` when upgrading `hermetic_cc_toolchain`.
- The wrapper lints for the host target. Cross-configured builds
  (`--platforms=...`) are still linted with host headers and triple.
- Windows is not supported by the wrapper.

**macOS.** CI builds and tests `//c/...` and `//cpp/...` natively on
`macos-latest` (arm64) with zig targeting `aarch64-macos-none` (macOS 13.0);
clang-format and clang-tidy run there too. Only the C/C++ targets and hooks are
exercised on macOS in CI. The runner has Xcode installed, but the build does not
use it (see above). macOS x86_64 is registered but not tested in CI.

## Starlark

`BUILD.bazel`, `.bzl`, and `MODULE.bazel` files are formatted and linted by
Buildifier 8.5.1 (`buildifier_prebuilt` 8.5.1.4).

| Hook id | Underlying command | Auto-fix |
| --- | --- | --- |
| `buildifier` | `bazel test //:buildifier_test` | `bazel run //:buildifier` |

## Hooks (prek)

[prek](https://github.com/j178/prek) 0.5.3 is a Rust reimplementation of
`pre-commit` that reads the same `.pre-commit-config.yaml`. Bazel fetches the
pinned release binary for the host (Linux/macOS, x86_64/aarch64, with sha256)
and exposes it as `//tools:prek`. Every hook is `repo: local`,
`language: system`, `pass_filenames: false`, `always_run: true`, and its
`entry` is a Bazel command.

| Hook id | Command |
| --- | --- |
| `format-ruff` | `bazel run //:ruff -- format --check python tools` |
| `format-black` | `bazel run //:black -- --check python tools` |
| `lint-ruff` | `bazel run //:ruff -- check python tools` |
| `typecheck-mypy` | `bazel run //:mypy -- python tools` |
| `gofmt` | `bazel run //tools/go/gofmtcheck` |
| `go-vet` | `bazel build //cmd/... //pkg/... //tools/go/...` |
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
bazel run //tools:prek -- install                  # git pre-commit hook
bazel run //tools:prek -- run --all-files          # all hooks
bazel run //tools:prek -- run clippy --all-files   # one hook
bazel run //tools:prek -- uninstall                # remove the git hook
```

Because every hook runs on the whole repo through Bazel, a commit runs all 16
checks. They are incremental: after the first run, unchanged targets are cache
hits.

## CI

`.github/workflows/ci.yml` runs on pushes to `main` (and to the
`lighter-cc-toolchain` branch), on pull requests, and on demand
(`workflow_dispatch`).

- **`hooks` (ubuntu-latest):** checkout, then `bazel-contrib/setup-bazel`
  (Bazelisk plus disk, repository, and Bazelisk caches) as the only host setup.
  Then one step per hook id, each running
  `bazel run //tools:prek -- run <hook-id> --all-files`, so a failure points
  straight at the check that broke.
- **`macos` (macos-latest, arm64):** `bazel test //c/... //cpp/...`, a
  diagnostics step (selected C++ toolchain, compile/link command lines, and
  `otool -L` of a test binary), then the `clang-format` and `clang-tidy` hooks.

When you add a hook, add a matching step to the `hooks` job.

## Adding a language or tool

1. **Rules and toolchain:** add the ruleset with `bazel_dep` in `MODULE.bazel`
   (from the [BCR](https://registry.bazel.build/)), pin the toolchain version,
   and register it. Avoid anything that falls back to host tools.
2. **Tools:** fetch formatters and linters as pinned external repositories:
   a BCR module, `http_archive` with `sha256` (like prek in `MODULE.bazel`), an
   npm package in `package.json`, or a PyPI package in `pyproject.toml` (like
   clang-format and clang-tidy). Wrap them in a `*_binary` target under
   `tools/<lang>/`. Launchers that operate on the source tree should `cd` to
   `$BUILD_WORKSPACE_DIRECTORY` (see `tools/python/ruff_main.py`).
3. **Lint aspects:** if the tool has an `aspect_rules_lint` or rules-provided
   aspect, define it in `tools/lint/linters.bzl` and add a `--config=<name>`
   block to `.bazelrc`. Aspects cover new targets automatically.
4. **Example:** add `<lang>/calculator` with a library and a test so
   `bazel test //...` covers it.
5. **Hooks:** add a `repo: local`, `language: system` hook whose `entry` is the
   Bazel command to `.pre-commit-config.yaml`, then a matching step in
   `.github/workflows/ci.yml`.
6. **Docs:** add a section here with versions, targets, commands, and
   auto-fix instructions.
7. Run `bazel run //tools:prek -- run --all-files` and commit
   `MODULE.bazel.lock` plus any lockfiles.
