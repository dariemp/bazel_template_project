"""Tiny greeting helper used as a py_library sample."""


def greet(name: str = "world") -> str:
    """Return a short greeting."""
    return f"hello, {name}"
