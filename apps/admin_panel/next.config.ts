import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Disable Turbopack — falls back to Webpack.
  // Turbopack fails on Windows with ".config" dir access (OS error 5).
};

export default nextConfig;
