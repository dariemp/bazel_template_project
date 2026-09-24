// Command gofmtcheck reports Go files that are not gofmt-formatted.
//
// It uses go/format from the Bazel-managed Go SDK, so no host gofmt is needed:
//
//	bazel run //tools/go/gofmtcheck          # check (exit 1 if unformatted)
//	bazel run //tools/go/gofmtcheck -- -w    # rewrite files in place
package main

import (
	"bytes"
	"flag"
	"fmt"
	"go/format"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
)

func skipDir(name string) bool {
	return name == ".git" || name == "node_modules" || strings.HasPrefix(name, "bazel-")
}

func main() {
	write := flag.Bool("w", false, "rewrite unformatted files in place")
	flag.Parse()

	root := os.Getenv("BUILD_WORKSPACE_DIRECTORY")
	if root == "" {
		root = "."
	}

	var bad []string
	checked := 0
	err := filepath.WalkDir(root, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() {
			if path != root && skipDir(d.Name()) {
				return filepath.SkipDir
			}
			return nil
		}
		if !strings.HasSuffix(path, ".go") {
			return nil
		}
		src, err := os.ReadFile(path)
		if err != nil {
			return err
		}
		checked++
		out, err := format.Source(src)
		if err != nil {
			return fmt.Errorf("%s: %w", path, err)
		}
		if !bytes.Equal(src, out) {
			rel, _ := filepath.Rel(root, path)
			bad = append(bad, rel)
			if *write {
				return os.WriteFile(path, out, d.Type().Perm()|0o644)
			}
		}
		return nil
	})
	if err != nil {
		fmt.Fprintln(os.Stderr, "gofmtcheck:", err)
		os.Exit(2)
	}
	if len(bad) > 0 && !*write {
		fmt.Println("gofmt needed on:")
		for _, f := range bad {
			fmt.Println(f)
		}
		os.Exit(1)
	}
	fmt.Printf("gofmtcheck: ok (%d files)\n", checked)
}
