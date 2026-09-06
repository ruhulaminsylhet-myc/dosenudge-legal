import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    // Rules tests share one emulator instance, so run files serially.
    fileParallelism: false,
    testTimeout: 20000,
    hookTimeout: 30000,
  },
});
