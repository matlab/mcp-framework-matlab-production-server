// Copyright 2026 The MathWorks, Inc.

import { defineConfig } from "vite";
import { viteSingleFile } from "vite-plugin-singlefile";

export default defineConfig({
  plugins: [viteSingleFile()],
  resolve: {
    preserveSymlinks: true,
  },
  build: {
    outDir: "dist",
    rollupOptions: {
      input: process.env.INPUT || "mcp-app.html",
      // Some packages' comments mention @__PURE__ where Rollup can't use
      // it as a hint; Rollup drops them, harmlessly. Hide that warning
      // for installed packages only.
      onwarn(warning, warn) {
        if (warning.code === "INVALID_ANNOTATION" &&
            warning.id?.includes("node_modules")) {
          return;
        }
        warn(warning);
      },
    },
  },
});
