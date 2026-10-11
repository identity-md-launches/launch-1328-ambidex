import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// The export is served from an IPFS gateway subpath or an ENS name, so every
// asset URL must be relative. The build lands in the repository-root dist/.
export default defineConfig({
  base: './',
  plugins: [react()],
  build: {
    outDir: '../dist',
    emptyOutDir: true,
    sourcemap: false,
    target: 'es2022',
  },
});
