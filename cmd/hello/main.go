package main

import "fmt"

func greeting() string {
	return "hello from bazel_template_project"
}

func main() {
	fmt.Println(greeting())
}
