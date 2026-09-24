"""Pytest tests for the calculator sample (run via bazel test)."""

import pytest

from python.calculator.calculator import add


@pytest.mark.parametrize(
    ("a", "b", "expected"),
    [(2, 3, 5), (-1, 1, 0), (0, 0, 0), (-4, -6, -10)],
)
def test_add(a: int, b: int, expected: int) -> None:
    assert add(a, b) == expected


if __name__ == "__main__":
    raise SystemExit(pytest.main([__file__, "-v"]))
