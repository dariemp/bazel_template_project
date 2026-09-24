package main

import "testing"

func TestGreeting(t *testing.T) {
	got := greeting()
	want := "hello from bazel_template_project"
	if got != want {
		t.Fatalf("greeting() = %q, want %q", got, want)
	}
}
