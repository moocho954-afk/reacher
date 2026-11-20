// Standalone client bundler for the public ReacheR front end.
// Mirrors the Space SDK's Bun.build configuration (production React bundle,
// Tailwind plugin, hashed asset names) without any Space runtime dependency.
//
// Build-time env:
//   REACHER_API_URL — baked into the bundle as the default API base URL.
//     Leave unset for a front-end-only Pages deploy; the page then shows the
//     "backend not deployed yet" state and `window.__REACHER_API__` can still
//     point it at a backend at runtime without rebuilding.
//
// Output: ./dist/ (served by GitHub Pages).
import { rm } from "node:fs/promises";
import tailwindPlugin from "bun-plugin-tailwind";

const OUTDIR = "./dist";

await rm(OUTDIR, { force: true, recursive: true });

const result = await Bun.build({
  entrypoints: ["./index.html"],
  outdir: OUTDIR,
  minify: true,
  define: {
    "process.env.NODE_ENV": JSON.stringify("production"),
    __REACHER_API_URL__: JSON.stringify(process.env.REACHER_API_URL ?? ""),
  },
  naming: {
    asset: "assets/[name]-[hash].[ext]",
    chunk: "assets/[name]-[hash].[ext]",
    entry: "[name].[ext]",
  },
  plugins: [tailwindPlugin],
});

if (!result.success) {
  for (const log of result.logs) console.error(log);
  throw new Error("frontend build failed; see logged diagnostics");
}

console.log(`frontend build OK -> ${OUTDIR}/`);
for (const o of result.outputs) console.log(" ", o.path);
