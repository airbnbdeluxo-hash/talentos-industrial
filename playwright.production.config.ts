import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests/e2e-production',
  timeout: 30_000,
  expect: { timeout: 5_000 },
  retries: 1,
  workers: 1,
  reporter: [['list']],
  use: {
    baseURL: 'http://127.0.0.1:4173',
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
  },
  projects: [
    {
      name: 'chromium-production-preview',
      use: { ...devices['Desktop Chrome'] },
    },
  ],
});
