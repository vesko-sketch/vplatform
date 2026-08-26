import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  output: 'standalone',
  // `pnpm typecheck` is mandatory; Next 16.3.2 currently cannot parse tsc's
  // valid --showConfig output under this pnpm workspace.
  typescript: { ignoreBuildErrors: true },
};

export default nextConfig;
