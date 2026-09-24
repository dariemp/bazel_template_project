"""Pytest tests for the greeting sample (run via bazel test)."""

import pytest

from python.greeting.greeting import greet


def test_default() -> None:
    assert greet() == "hello, world"


def test_name() -> None:
    assert greet("bazel") == "hello, bazel"


if __name__ == "__main__":
    raise SystemExit(pytest.main([__file__, "-v"]))
