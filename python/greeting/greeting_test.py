"""Tests for the greeting sample."""

import unittest

from python.greeting.greeting import greet


class GreetingTest(unittest.TestCase):
    def test_default(self):
        self.assertEqual(greet(), "hello, world")

    def test_name(self):
        self.assertEqual(greet("bazel"), "hello, bazel")


if __name__ == "__main__":
    unittest.main()
