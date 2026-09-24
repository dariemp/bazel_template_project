"""Bazel entrypoint for the ruff console script (uv-installed)."""

import os
import runpy
import sys


def _chdir_workspace() -> None:
    # bazel run sets this to the workspace root; without it, relative paths
    # would resolve under the runfiles tree.
    ws = os.environ.get("BUILD_WORKSPACE_DIRECTORY")
    if ws:
        os.chdir(ws)


if __name__ == "__main__":
    _chdir_workspace()
    sys.argv[0] = "ruff"
    runpy.run_module("ruff", run_name="__main__", alter_sys=True)
