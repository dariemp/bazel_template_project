"""Run the Bazel-managed clang-format over all C/C++ sources in the repo.

bazel run //tools/cpp:clang_format            # check (--dry-run --Werror)
bazel run //tools/cpp:clang_format -- --fix   # rewrite files in place
"""

import os
import subprocess
import sys

EXTENSIONS = (".c", ".h", ".cc", ".cpp", ".cxx", ".hh", ".hpp")


def _sources(root: str) -> list[str]:
    found: list[str] = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = sorted(
            d
            for d in dirnames
            # Skip Bazel output links, VCS metadata, hidden dirs (e.g. the
            # .venv from `bazel run //:create_venv`), and vendored trees.
            if not (d.startswith(("bazel-", ".")) or d in ("node_modules", "venv"))
        )
        found.extend(
            os.path.relpath(os.path.join(dirpath, f), root)
            for f in sorted(filenames)
            if f.endswith(EXTENSIONS)
        )
    return found


def main() -> int:
    clang_format = os.path.abspath(sys.argv[1])
    fix = "--fix" in sys.argv[2:]
    root = os.environ.get("BUILD_WORKSPACE_DIRECTORY", ".")
    os.chdir(root)
    files = _sources(".")
    if not files:
        print("clang-format: no C/C++ files")
        return 0
    mode = ["-i"] if fix else ["--dry-run", "--Werror"]
    result = subprocess.run([clang_format, "--style=file", *mode, *files], check=False)
    if result.returncode == 0:
        print(f"clang-format: ok ({len(files)} files)")
    return result.returncode


if __name__ == "__main__":
    sys.exit(main())
