"""Bazel entrypoint for the black console script (uv-installed)."""

import os

from black import patched_main


def _chdir_workspace() -> None:
    # bazel run sets this to the workspace root; without it, relative paths
    # would resolve under the runfiles tree.
    ws = os.environ.get("BUILD_WORKSPACE_DIRECTORY")
    if ws:
        os.chdir(ws)


if __name__ == "__main__":
    _chdir_workspace()
    patched_main()
