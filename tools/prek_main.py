"""Bazel launcher for the pinned prek binary (fetched by MODULE.bazel).

Usage: bazel run //tools:prek -- run --all-files
"""

import os
import sys


def main() -> None:
    if len(sys.argv) < 2:
        sys.exit("usage: prek_main.py <path-to-prek> [args...]")
    prek = os.path.abspath(sys.argv[1])
    # bazel run sets this to the workspace root; prek must run inside the repo.
    ws = os.environ.get("BUILD_WORKSPACE_DIRECTORY")
    if ws:
        os.chdir(ws)
    os.execv(prek, [prek, *sys.argv[2:]])


if __name__ == "__main__":
    main()
