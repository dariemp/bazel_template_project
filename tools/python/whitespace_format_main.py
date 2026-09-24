"""Bazel entrypoint for the whitespace-format console script (uv-installed)."""

from whitespace_format import main

if __name__ == "__main__":
    raise SystemExit(main())
