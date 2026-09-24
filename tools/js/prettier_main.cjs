// Bazel launcher for Prettier (npm package from pnpm-lock.yaml via rules_js).
// `bazel run` starts us in the runfiles tree; run Prettier from the workspace
// root instead so paths and .prettierrc.json resolve against the source tree.
//
//   bazel run //tools/js:prettier -- --check .
//   bazel run //tools/js:prettier -- --write .
const path = require("node:path");

const workspace = process.env.BUILD_WORKSPACE_DIRECTORY;
if (workspace) {
  process.chdir(workspace);
}
const pkgDir = path.dirname(require.resolve("prettier/package.json"));
require(path.join(pkgDir, "bin", "prettier.cjs"));
